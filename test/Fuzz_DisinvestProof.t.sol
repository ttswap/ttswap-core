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
            _packInvest(btcGoodId, uint128(1 * 10 ** 8)),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );
        _snapMarket("market_investGood_Fuzz_DisinvestProof.t_30");
        vm.stopPrank();
        proofId = _proofId(FUZZ_USER, btcGoodId);
    }

    function testFuzz_DisinvestProof_partial(uint128 withdrawShares) public {
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 total = proof.shares.amount0();
        if (total < 100) return;

        // Stay above the protocol dust path (`disinvestvalue.amount1 < 1e12`),
        // which rewrites a partial exit into a full-position chip check.
        uint128 minWithdraw = total / 50;
        uint128 maxWithdraw = total / 10;
        if (minWithdraw == 0 || minWithdraw >= maxWithdraw) return;
        withdrawShares = uint128(bound(withdrawShares, minWithdraw, maxWithdraw));
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
        _snapMarket("market_disinvestProof_Fuzz_DisinvestProof.t_56");
        vm.stopPrank();

        assertGe(btc.balanceOf(FUZZ_USER), balBefore, "tokens returned");
        S_ProofState memory afterProof = market.getProofState(proofId);
        assertLe(afterProof.shares.amount0(), total, "shares reduced");
    }

    function testGas_DisinvestProof_partial() public {
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 withdrawShares = proof.shares.amount0() / 10;
        if (withdrawShares < 1) withdrawShares = 1;

        vm.startPrank(FUZZ_USER);
        _warp();
        market.disinvestProof(
            proofId,
            withdrawShares,
            address(0),
            FUZZ_USER,
            defaultdata
        );
        _snapMarket("market_disinvestProof_Fuzz_DisinvestProof.t_77");
        _snapMarket("gas_baseline_disinvest_btc_partial");
        vm.stopPrank();
    }
}
