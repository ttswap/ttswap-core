// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice P2-01: stake / unstake boundaries and _stakeFee.
contract testTTSwapTokenStakeGap is BaseSetup {
    using L_TTSwapUINT256Library for uint256;

    address internal stakeCaller;
    address internal beneficiary;
    address internal beneficiary2;

    uint128 internal constant STAKE_VALUE = 100_000;
    uint128 internal constant UNSTAKE_VALUE = 10_000;

    function setUp() public override {
        BaseSetup.setUp();
        stakeCaller = users[1];
        beneficiary = users[2];
        beneficiary2 = users[3];
        vm.warp(1_000_000);
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(stakeCaller, true);
    }

    function testStake_whenPoolstateHasConstruct_calculatesNetConstruct() public {
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        uint128 poolBefore = tts_token.poolstate().amount0();
        vm.warp(block.timestamp + 86_401);
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary2, STAKE_VALUE);
        assertGt(tts_token.poolstate().amount0(), poolBefore, "daily fee accrues to pool");
    }

    function testUnstake_moreThanUserProof_clampsToFullExit() public {
        vm.startPrank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        vm.warp(block.timestamp + 86_400);
        tts_token.unstake(beneficiary, STAKE_VALUE + 1);
        vm.stopPrank();
        assertEq(tts_token.stakestate().amount1(), 0, "full exit");
    }

    function testUnstake_afterFullExit_revertsOnFurtherUnstake() public {
        vm.startPrank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        vm.warp(block.timestamp + 86_400);
        tts_token.unstake(beneficiary, STAKE_VALUE);
        vm.expectRevert();
        tts_token.unstake(beneficiary, 0);
        vm.stopPrank();
    }

    function testStakeFee_noMintBeforeOneDay() public {
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        uint128 tsBefore = tts_token.stakestate().amount0();
        vm.prank(stakeCaller);
        tts_token.unstake(beneficiary, UNSTAKE_VALUE);
        assertEq(tts_token.stakestate().amount0(), tsBefore, "timestamp not bumped before 1 day");
    }

    function testStakeFee_afterOneDay_updatesStakeTimestamp() public {
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        uint128 tsBefore = tts_token.stakestate().amount0();
        vm.warp(block.timestamp + 86_401);
        vm.prank(stakeCaller);
        tts_token.unstake(beneficiary, UNSTAKE_VALUE);
        assertGt(tts_token.stakestate().amount0(), tsBefore, "timestamp bumped after fee");
    }

    function testUnstake_profitMintedAfterOneDay() public {
        vm.startPrank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        vm.warp(block.timestamp + 86_401);
        uint256 supplyBefore = tts_token.totalSupply();
        tts_token.unstake(beneficiary, UNSTAKE_VALUE);
        vm.stopPrank();
        assertGt(tts_token.totalSupply(), supplyBefore, "profit minted after daily fee");
    }
}
