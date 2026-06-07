// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz disinvestProof partial withdraw (TASK-P3-004).
contract Fuzz_DisinvestProof is FuzzBase {
    using L_TTSwapUINT256Library for uint256;
    uint256 internal proofId;

    function setUp() public override {
        super.setUp();
        _fuzzPoolSetUp();

        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, 1 * 10 ** 8, false);
        btc.approve(address(market), type(uint256).max);
        _warp();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, uint128(1 * 10 ** 8)),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );
        vm.stopPrank();
        proofId = _proofId(FUZZ_USER, btcGoodId);
    }

    function testFuzz_DisinvestProof_partial(uint128 withdrawShares) public {
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 total = proof.shares.amount0();
        if (total == 0) return;

        uint128 maxWithdraw = total / 100;
        if (maxWithdraw < 1) return;
        withdrawShares = uint128(bound(withdrawShares, 1, maxWithdraw));
        uint256 balBefore = btc.balanceOf(FUZZ_USER);

        vm.startPrank(FUZZ_USER);
        _warp();
        market.disinvestProof(
            proofId,
            withdrawShares,
            address(0),
            FUZZ_USER,
            defaultdata
        );
        vm.stopPrank();

        assertGe(btc.balanceOf(FUZZ_USER), balBefore, "tokens returned");
        S_ProofState memory afterProof = market.getProofState(proofId);
        assertLe(afterProof.shares.amount0(), total, "shares reduced");
    }
}
