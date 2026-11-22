// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression test for issue #308: the staking anti-dilution fee
///         (`netconstruct`) was gated on `poolstate.amount1() == 0`, but
///         `poolstate.amount1()` only ever grows via `netconstruct` itself —
///         so the fee could never activate and a late/flash staker diluted
///         every earlier staker's emission share for free.
///         The gate now checks the real denominator, `stakestate.amount1()`.
contract StakeConstructFee is BaseSetup {
    using L_TTSwapUINT256Library for uint256;

    address internal callerA;
    address internal callerB;
    address internal alice;
    address internal attacker;

    uint128 internal constant SMALL_STAKE = 100_000;
    uint128 internal constant BIG_STAKE = 900_000;

    function setUp() public override {
        BaseSetup.setUp();
        callerA = users[1];
        callerB = users[3];
        alice = users[2];
        attacker = users[4];
        vm.warp(1_000_000);
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(callerA, true);
        tts_token.setCallMintTTS(callerB, true);
        vm.stopPrank();
    }

    function test_firstStake_paysNoConstructFee() public {
        vm.prank(callerA);
        uint128 netconstruct = tts_token.stake(alice, SMALL_STAKE);
        assertEq(netconstruct, 0, "no existing stake -> no dilution fee");
        assertEq(tts_token.stakestate().amount1(), SMALL_STAKE, "stake recorded");
    }

    function test_lateStaker_paysConstructFee() public {
        // Honest staker joins first.
        vm.prank(callerA);
        tts_token.stake(alice, SMALL_STAKE);

        // Let a day pass so _stakeFee accrues emission into poolstate.amount0.
        vm.warp(block.timestamp + 86_401);

        // Late (flash) staker joins with 9x the stake. Their stake() call
        // triggers the emission checkpoint, then must pay the anti-dilution
        // construct fee on the accrued pool value.
        vm.prank(callerB);
        uint128 netconstruct = tts_token.stake(attacker, BIG_STAKE);

        assertGt(netconstruct, 0, "anti-dilution fee must be non-zero");
        // The construct is added to both poolstate legs and recorded per-proof.
        assertEq(
            tts_token.poolstate().amount1(),
            netconstruct,
            "pool construct ledger tracks the fee"
        );
    }

    function test_unstake_afterFee_active_stillSettles() public {
        vm.prank(callerA);
        tts_token.stake(alice, SMALL_STAKE);
        vm.warp(block.timestamp + 86_401);
        vm.prank(callerB);
        tts_token.stake(attacker, BIG_STAKE);

        // Both stakers can exit; construct is returned from their own ledger.
        vm.prank(callerB);
        tts_token.unstake(attacker, BIG_STAKE);
        vm.prank(callerA);
        tts_token.unstake(alice, SMALL_STAKE);
        assertEq(tts_token.stakestate().amount1(), 0, "all stakes exited");
    }
}
