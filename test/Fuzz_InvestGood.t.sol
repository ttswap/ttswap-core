// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz investGood (TASK-P3-004).
contract Fuzz_InvestGood is FuzzBase {
    using L_TTSwapUINT256Library for uint256;
    function setUp() public override {
        super.setUp();
        _fuzzPoolSetUp();
    }

    function testFuzz_InvestGood_btc(uint128 investQty) public {
        investQty = uint128(bound(investQty, 1e4, 1 * 10 ** 8));

        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, investQty, false);
        btc.approve(address(market), investQty);
        _warp();

        uint256 proofId = _proofId(FUZZ_USER, btcGoodId);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );

        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, btcGoodId, "proof good");
        assertGt(proof.shares.amount0(), 0, "shares minted");
        vm.stopPrank();
    }

    function testFuzz_InvestGood_usdtValueGood(uint128 investQty) public {
        investQty = uint128(bound(investQty, 10 * 10 ** 6, 10_000 * 10 ** 6));

        vm.startPrank(FUZZ_USER);
        deal(address(usdt), FUZZ_USER, investQty, false);
        usdt.approve(address(market), investQty);
        _warp();

        uint256 proofId = _proofId(FUZZ_USER, usdtGoodId);
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.shares.amount0(), 0, "value good shares");
        vm.stopPrank();
    }

    function testGas_InvestGood_btc() public {
        uint128 investQty = 1 * 10 ** 7;
        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, investQty, false);
        btc.approve(address(market), investQty);
        _warp();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );
        _snapMarket("gas_baseline_invest_btc");
        vm.stopPrank();
    }

    function testGas_InvestGood_usdtValueGood() public {
        uint128 investQty = 1000 * 10 ** 6;
        vm.startPrank(FUZZ_USER);
        deal(address(usdt), FUZZ_USER, investQty, false);
        usdt.approve(address(market), investQty);
        _warp();
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );
        _snapMarket("gas_baseline_invest_usdt_value");
        vm.stopPrank();
    }
}
