// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {stdStorage, StdStorage} from "forge-std/src/StdStorage.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for #317: `_stakeFee` floored the daily emission at
/// 1e12 whenever `leftamount < 1e12` — including `leftamount == 0` (cap
/// reached) and `0 < leftamount < 1e12` (partial remainder). The 200M cap
/// therefore never held: +1 TTS/day forever, and up to 1 TTS overshoot on
/// the final partial day. The daily mint must never exceed `leftamount`.
/// (Cross-day accrual vs the cap is #324's scope — PR #345.)
contract testStakeFeeFloorCap is BaseSetup {
    using L_TTSwapUINT256Library for uint256;
    using stdStorage for StdStorage;

    uint256 internal constant CAP = 200_000_000_000_000_000_000;
    uint128 internal constant FLOOR = 1e12;

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

    function _poke() internal returns (uint128 credited) {
        uint128 before_ = tts_token.poolstate().amount0();
        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, 1_000);
        credited = tts_token.poolstate().amount0() - before_;
        vm.warp(block.timestamp + 86_401);
    }

    /// @dev At the cap, consecutive daily pokes must credit zero emission.
    ///      On the unfixed base each poke credits the full 1e12 floor.
    function testStakeFee_zeroEmission_atCap() public {
        stdstore.target(address(tts_token)).sig("totalSupply()").checked_write(CAP);
        stdstore.target(address(tts_token)).sig("poolstate()").checked_write(toTTSwapUINT256(uint128(0), 0));

        uint128 c1 = _poke();
        uint128 c2 = _poke();
        assertEq(c1 + c2, 0, "no emission may be minted once the cap is reached");
    }

    /// @dev With 5e11 remaining (< 1e12 floor), a single poke must mint at
    ///      most the remainder — never the full 1e12 floor.
    function testStakeFee_neverExceedsRemaining() public {
        uint256 remaining = 500_000_000_000; // 0.5 TTS < 1e12 floor
        stdstore.target(address(tts_token)).sig("totalSupply()").checked_write(CAP - remaining);
        stdstore.target(address(tts_token)).sig("poolstate()").checked_write(toTTSwapUINT256(uint128(0), 0));

        uint128 credited = _poke();
        assertLe(credited, uint128(remaining), "daily mint must not exceed leftamount");
        assertLt(credited, FLOOR, "floor branch must not overshoot the remainder");
    }

    /// @dev Control: far below the cap the normal tapered emission still flows.
    function testStakeFee_normalEmission_belowCap() public {
        stdstore.target(address(tts_token)).sig("totalSupply()").checked_write(uint256(100e18));
        stdstore.target(address(tts_token)).sig("poolstate()").checked_write(toTTSwapUINT256(uint128(0), 0));

        uint128 credited = _poke();
        assertGt(credited, 1e14, "normal emission still flows");
        assertLt(credited, 1e17, "emission stays tapered");
    }
}
