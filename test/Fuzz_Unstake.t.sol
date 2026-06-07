// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {s_proof} from "../src/interfaces/I_TTSwap_Token.sol";
import {L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz unstake (TASK-P3-004).
contract Fuzz_Unstake is FuzzBase {
    using L_TTSwapUINT256Library for uint256;
    address internal staker = users[1];
    uint256 internal proofId;

    function setUp() public override {
        super.setUp();
        vm.warp(1_000_000);
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(address(this), true);
        tts_token.stake(staker, 1_000_000);
        proofId = uint256(keccak256(abi.encode(staker, address(this))));
    }

    function testFuzz_Unstake_partial(uint128 unstakeAmount) public {
        s_proof memory proofBefore = tts_token.stakeproofinfo(proofId);
        uint128 total = uint128(proofBefore.proofstate.amount0());
        unstakeAmount = uint128(bound(unstakeAmount, 1, total));

        vm.warp(block.timestamp + 86_400);
        tts_token.unstake(staker, unstakeAmount);

        s_proof memory proofAfter = tts_token.stakeproofinfo(proofId);
        assertEq(
            proofAfter.proofstate.amount0(),
            total - unstakeAmount,
            "proof reduced"
        );
    }

    function testFuzz_Unstake_full() public {
        s_proof memory proof = tts_token.stakeproofinfo(proofId);
        uint128 full = uint128(proof.proofstate.amount0());

        vm.warp(block.timestamp + 86_400);
        tts_token.unstake(staker, full);

        s_proof memory cleared = tts_token.stakeproofinfo(proofId);
        assertEq(cleared.proofstate.amount0(), 0, "proof cleared");
    }
}
