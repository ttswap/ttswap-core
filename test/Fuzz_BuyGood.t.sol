// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz buyGood swaps (TASK-P3-004).
contract Fuzz_BuyGood is FuzzBase {
    function setUp() public override {
        super.setUp();
        _fuzzPoolSetUp();
    }

    function testFuzz_BuyGood_usdtToBtc(uint128 swapAmount) public {
        swapAmount = uint128(bound(swapAmount, 1e6, 10_000 * 10 ** 6));

        vm.startPrank(FUZZ_USER);
        deal(address(usdt), FUZZ_USER, swapAmount, false);
        usdt.approve(address(market), swapAmount);
        _warp();

        uint256 balBefore = btc.balanceOf(FUZZ_USER);
        try
            market.buyGood(
                _usdtKey(),
                _btcKey(),
                toTTSwapUINT256(swapAmount, 0),
                address(0),
                defaultdata,
                FUZZ_USER,
                defaultdata,
                0
            )
        returns (uint256 good1change, uint256 good2change) {
            assertGt(btc.balanceOf(FUZZ_USER), balBefore, "received btc");
            assertTrue(good1change > 0 || good2change > 0, "state change");
        } catch (bytes memory reason) {
            uint256 code = _decodeTTSwapError(reason);
            assertTrue(
                code == 14 || code == 45 || code == 15,
                "expected 14/45/15 on rejected swap"
            );
        }
        vm.stopPrank();
    }

    function testFuzz_BuyGood_btcToUsdt(uint128 swapAmount) public {
        swapAmount = uint128(bound(swapAmount, 1e4, 1 * 10 ** 8));

        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, swapAmount, false);
        btc.approve(address(market), swapAmount);
        _warp();

        uint256 balBefore = usdt.balanceOf(FUZZ_USER);
        try
            market.buyGood(
                _btcKey(),
                _usdtKey(),
                toTTSwapUINT256(swapAmount, 0),
                address(0),
                defaultdata,
                FUZZ_USER,
                defaultdata,
                0
            )
        returns (uint256, uint256) {
            assertGt(usdt.balanceOf(FUZZ_USER), balBefore, "received usdt");
        } catch (bytes memory reason) {
            uint256 code = _decodeTTSwapError(reason);
            assertTrue(code == 14 || code == 45 || code == 15, "rejected swap");
        }
        vm.stopPrank();
    }

    /// @dev Fixed-input gas baseline for fuzz-covered buyGood paths.
    function testGas_BuyGood_usdtToBtc() public {
        uint128 swapAmount = 1000 * 10 ** 6;
        vm.startPrank(FUZZ_USER);
        deal(address(usdt), FUZZ_USER, swapAmount, false);
        usdt.approve(address(market), swapAmount);
        _warp();
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(swapAmount, 0),
            address(0),
            defaultdata,
            FUZZ_USER,
            defaultdata,
            0
        );
        _snapMarket("gas_baseline_buy_usdt_btc");
        vm.stopPrank();
    }

    function testGas_BuyGood_btcToUsdt() public {
        uint128 swapAmount = 1 * 10 ** 6;
        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, swapAmount, false);
        btc.approve(address(market), swapAmount);
        _warp();
        market.buyGood(
            _btcKey(),
            _usdtKey(),
            toTTSwapUINT256(swapAmount, 0),
            address(0),
            defaultdata,
            FUZZ_USER,
            defaultdata,
            0
        );
        _snapMarket("gas_baseline_buy_btc_usdt");
        vm.stopPrank();
    }
}
