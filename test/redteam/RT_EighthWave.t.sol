// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {s_share} from "../../src/interfaces/I_TTSwap_Token.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice Eighth-wave red-team PoCs (2026-09-25):
///  - RT-41 goodWelfare dilution -> buyGood extraction (NEW hunt, permissionless)
///  - RT-09/RT-13 run-slot classes re-proven DEAD on current tree (no error 46,
///    no lastRunSlot writes; old wave PoCs fail only because they expectRevert 46)
///  - RT-10 zero-share guard re-proven LIVE with fixed harness (old PoC passed a
///    view call inside expectRevert args, consuming the cheatcode)
///  - RT-43 TokenAdmin burnShare victim + addShare self = allocation theft (NEW)
contract RT_EighthWave is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodConfigLibrary for uint256;

    address internal attacker = address(5);
    address internal victim = address(15);

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
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
    // RT-41: goodWelfare has no access control and no price guard. Donating w
    // output tokens raises Q (and investQty) 1:1 while V is unchanged, so the
    // pool price V/Q drops. A follow-up buyGood through the diluted pool buys
    // more tokens per unit of input value. Gain ~= X*w/V; profitable iff the
    // trade value X exceeds pool value V (i.e. a small victim pool + a big
    // input pool). Loss sits with the output-pool LPs (their tokens paid out).
    // ─────────────────────────────────────────────────────────────────────────

    // NOTE (negative result, proven below): the donor can never recover the
    // donation. Pool inventory caps payout: out <= Q + w always, so
    // (out_w - w) - out_wo <= 0 in every regime — the gift subsidizes other
    // swappers/LPs. goodWelfare is donor-safe; NOT an extraction primitive.
    function test_RT41_welfare_dilution_swap_extraction() public {
        uint256 usdtId = _init(_usdtKey(), marketcreator, uint128(50_000 * 10 ** 12), uint128(50_000 * 10 ** 6));
        uint256 ethId = _init(_ethKey(), marketcreator, uint128(10 ** 15), 500_000);
        _relaxSafeLine(usdtId);
        _relaxSafeLine(ethId);

        // Small enough to execute against the tiny pool (can't buy out more
        // value than the pool holds); large enough to measure dilution.
        uint128 tradeIn = uint128(5 * 10 ** 6); // 5 USDT
        uint128 welfare = 500_000; // double the tiny pool depth

        deal(address(usdt), attacker, 10 * uint256(tradeIn), false);
        deal(address(eth), attacker, 10 * uint256(welfare), false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        eth.approve(address(market), type(uint256).max);

        // Baseline: same-size swap with NO donation (state snapshot -> revert).
        uint256 snap = vm.snapshotState();
        (, uint256 baseOut) = market.buyGood(
            _usdtKey(), _ethKey(), toTTSwapUINT256(tradeIn, 0),
            address(0), defaultdata, attacker, defaultdata, 0
        );
        uint256 plainOut = baseOut.amount1();
        vm.revertToState(snap);

        // Attack: donate w, then the same swap.
        market.goodWelfare(ethId, welfare, defaultdata, attacker, defaultdata);
        (, uint256 atkOut) = market.buyGood(
            _usdtKey(), _ethKey(), toTTSwapUINT256(tradeIn, 0),
            address(0), defaultdata, attacker, defaultdata, 0
        );
        vm.stopPrank();
        uint256 grossOut = atkOut.amount1();

        emit log_named_uint("RT41 plain swap out (no donation)", plainOut);
        emit log_named_uint("RT41 gross out after welfare", grossOut);
        emit log_named_uint("RT41 welfare cost", welfare);

        // Kill: donor net (gross - cost) never beats the plain swap.
        assertLe(grossOut, plainOut + welfare, "welfare somehow profitable - recheck model");
        emit log("RT41 NEGATIVE: welfare dilution is a pure gift, donor cannot profit");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-09 DEAD: 1-wei same-token self-pay no longer consumes any run slot
    // (no TTSwapError 46 exists in src). Victim swap in the same block succeeds.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT09_dead_same_block_selfpay_censors_nothing() public {
        uint256 usdtId = _init(_usdtKey(), marketcreator, uint128(50_000 * 10 ** 12), uint128(50_000 * 10 ** 6));
        uint256 btcId = _init(_btcKey(), users[1], uint128(63_000 * 10 ** 12), uint128(1 * 10 ** 8));
        _relaxSafeLine(usdtId);
        _relaxSafeLine(btcId);

        deal(address(usdt), attacker, 1, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), 1);
        market.payGood(_usdtKey(), _usdtKey(), toTTSwapUINT256(0, 1), attacker, defaultdata, attacker, defaultdata, 0);
        vm.stopPrank();

        // Same block: victim swap must SUCCEED (no censorship primitive left).
        deal(address(usdt), victim, 1e9, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        (, uint256 g2) = market.buyGood(
            _usdtKey(), _btcKey(), toTTSwapUINT256(uint128(1e6), 0),
            address(0), defaultdata, victim, defaultdata, 0
        );
        vm.stopPrank();
        assertGt(g2.amount1(), 0, "victim swap censored - run-slot back?");
        emit log("RT09 dead: dust self-pay does not censor the block");
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-13 DEAD: no lastRunSlot anywhere in src; fresh goods work at every
    // block number, including block.number % 4095 == 0.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT13_dead_fresh_good_works_at_block_mod_4095_zero() public {
        uint256 usdtId = _init(_usdtKey(), marketcreator, uint128(50_000 * 10 ** 12), uint128(50_000 * 10 ** 6));
        uint256 target = ((block.number / 4095) + 1) * 4095;
        vm.roll(target);

        deal(address(usdt), victim, 1e8, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        bool ok = market.investGood(_usdtKey(), _packInvest(usdtId, uint128(1e7)), defaultdata, defaultdata, victim);
        vm.stopPrank();
        assertTrue(ok, "fresh good bricked - run-slot back?");
        emit log("RT13 dead: no per-block brick on current tree");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-10 guard LIVE: welfare-inflated investQty floors investShare to 0 and
    // L_Good.investGood reverts 56 BEFORE any token/share accounting commits.
    // (Old wave PoC put a view call inside expectRevert args, eating the cheat.)
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT10_guard_live_zero_share_reverts_56() public {
        uint256 ethId = _init(_ethKey(), attacker, uint128(2 ** 109), 500_000);
        deal(address(eth), attacker, 1e15, false);
        deal(address(eth), victim, 1e6, false);

        vm.startPrank(attacker);
        eth.approve(address(market), type(uint256).max);
        market.goodWelfare(ethId, 5e11, defaultdata, attacker, defaultdata);
        vm.stopPrank();

        uint256 victimBalBefore = eth.balanceOf(victim);
        // NOTE: quote computed BEFORE expectRevert (view call would eat it).
        uint256 packed = _packInvest(ethId, 1e6);
        vm.startPrank(victim);
        eth.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        market.investGood(_ethKey(), packed, defaultdata, defaultdata, victim);
        vm.stopPrank();

        assertEq(eth.balanceOf(victim), victimBalBefore, "victim tokens taken on 0-share");
        uint256 proofId = S_ProofKey(victim, ethId).toId();
        assertEq(market.getProofState(proofId).shares.amount0(), 0, "zombie shares minted");
        emit log("RT10 guard live: zero-share invest reverts 56, deposit untouched");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-43: TokenAdmin burns the victim's locked share allocation, then
    // re-grants the same amount to the attacker. Victim's future shareMint
    // value moves to the attacker. Privilege required: TokenAdmin. Grief +
    // indirect theft (no AMM interaction, no capital).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT43_admin_burnShare_regrant_steals_allocation() public {
        s_share memory grant = s_share({leftamount: 1_000 * 1e12, metric: 0, chips: 10});
        vm.prank(marketcreator);
        tts_token.addShare(grant, victim);
        assertEq(tts_token.usershares(victim).leftamount, 1_000 * 1e12, "setup: victim grant");

        // Admin destroys the victim allocation...
        vm.prank(marketcreator);
        tts_token.burnShare(victim);
        assertEq(tts_token.usershares(victim).leftamount, 0, "victim allocation not destroyed");

        // ...and re-grants the same units to the attacker.
        vm.prank(marketcreator);
        tts_token.addShare(grant, attacker);

        assertEq(tts_token.usershares(attacker).leftamount, 1_000 * 1e12, "attacker did not receive allocation");
        assertEq(tts_token.usershares(victim).leftamount, 0, "victim kept allocation");
        emit log("RT43: victim locked allocation moved to attacker via burn+regrant");
    }
}
