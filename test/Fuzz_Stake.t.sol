// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {s_proof} from "../src/interfaces/I_TTSwap_Token.sol";
import {L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz stake (TASK-P3-004).
contract Fuzz_Stake is FuzzBase {
    using L_TTSwapUINT256Library for uint256;
    function setUp() public override {
        super.setUp();
        vm.warp(1_000_000);
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(address(this), true);
    }

    function testFuzz_Stake_valid(address staker, uint128 proofValue) public {
        vm.assume(staker != address(0));
        proofValue = uint128(bound(proofValue, 1e6, 1e12));

        uint256 stakeBefore = tts_token.stakestate().amount1();
        uint128 construct = tts_token.stake(staker, proofValue);

        assertEq(
            tts_token.stakestate().amount1(),
            stakeBefore + proofValue,
            "stakestate increased"
        );

        uint256 proofId = uint256(keccak256(abi.encode(staker, address(this))));
        s_proof memory proof = tts_token.stakeproofinfo(proofId);
        assertEq(proof.fromcontract, address(this), "caller recorded");
        assertEq(proof.proofstate.amount0(), proofValue, "proof value");

        if (tts_token.poolstate().amount1() == 0) {
            assertEq(construct, 0, "no construct on empty pool");
        }
    }
}
