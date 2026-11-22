// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {stdStorage, StdStorage} from "forge-std/src/StdStorage.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for #324: `_stakeFee` computed daily emission headroom
/// from `totalSupply` only, ignoring accrued-but-unclaimed rewards sitting in
/// `poolstate.amount0()`. Over ~50 years of unclaimed accrual the eventual
/// unstake mints past the 200M cap. The cap basis now reserves the accrued
/// liability: `200e18 - totalSupply - poolstate.amount0()`.
contract testStakeFeeCapLiability is BaseSetup {
    using L_TTSwapUINT256Library for uint256;
    using stdStorage for StdStorage;

    address internal stakeCaller;
    address internal beneficiary;

    function setUp() public override {
        BaseSetup.setUp();
        stakeCaller = users[1];
        beneficiary = users[2];
        vm.warp(1_000_000);
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(stakeCaller, true);
    }

    /// @dev With supply 100e18 and 100e18 already accrued in the pool, the
    ///      remaining headroom is 0 — the daily poke must credit only the
    ///      1e12 floor, not ~5.5e15 (leftamount/18250 at ratio 1).
    function testStakeFee_reservesAccruedLiability() public {
        stdstore.target(address(tts_token)).sig("totalSupply()").checked_write(uint256(100e18));
        stdstore.target(address(tts_token)).sig("poolstate()").checked_write(toTTSwapUINT256(uint128(100e18), 0));

        uint128 poolBefore = tts_token.poolstate().amount0();
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, 1_000);

        uint128 credited = tts_token.poolstate().amount0() - poolBefore;
        assertLt(credited, 2e12, "emission must be floored once liability is reserved");
    }

    /// @dev Control: same poke with no accrued liability still emits the
    ///      normal tapered amount (~100e18/18250), proving the guard only
    ///      bites when poolstate.amount0 is large.
    function testStakeFee_normalEmission_whenNoLiability() public {
        stdstore.target(address(tts_token)).sig("totalSupply()").checked_write(uint256(100e18));
        stdstore.target(address(tts_token)).sig("poolstate()").checked_write(toTTSwapUINT256(uint128(0), 0));

        uint128 poolBefore = tts_token.poolstate().amount0();
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, 1_000);

        uint128 credited = tts_token.poolstate().amount0() - poolBefore;
        // ratio may be < 10000; expect on the order of 1e15, far above floor.
        assertGt(credited, 1e14, "normal emission still flows");
        assertLt(credited, 1e17, "emission stays tapered");
    }
}
