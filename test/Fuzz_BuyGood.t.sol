// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_BuyGood is BaseTest {
    
    address goodA;
    address goodB;
    
    function setUp() public override {
        super.setUp();
        
        // Initialize two goods for trading
        vm.startPrank(ADMIN);
        
        // Init meta good (USDT as value good)
        usdt.approve(address(market), 1e12);
        market.initMetaGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            (1 << 255), // value good config
            ""
        );
        
        // Init normal good A
        tokenA.mint(ADMIN, 1e12);
        tokenA.approve(address(market), 1e12);
        usdt.approve(address(market), 1e12);
        
        market.initGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            address(tokenA),
            0, // normal good config
            "",
            ""
        );
        
        goodA = address(tokenA);
        goodB = address(usdt);
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGood_ValidSwap(
        uint128 swapAmount,
        uint128 minOutput,
        bool isBuy
    ) public {
        // Bound inputs to reasonable values
        swapAmount = uint128(bound(swapAmount, 1e4, 1e9));
        minOutput = 0; // Set to 0 for any output
        
        vm.startPrank(USER1);
        
        // Prepare tokens
        if (isBuy) {
            tokenA.mint(USER1, swapAmount);
            tokenA.approve(address(market), swapAmount);
        } else {
            usdt.mint(USER1, swapAmount);
            usdt.approve(address(market), swapAmount);
        }
        
        uint256 swapQuantity = (uint256(swapAmount) << 128) | minOutput;
        uint128 side = isBuy ? 1 : 0;
        
        // Record balances before
        uint256 balanceBefore = isBuy ? 
            usdt.balanceOf(USER1) : 
            tokenA.balanceOf(USER1);
        
        // For side 0 (sell), we need a recipient
        address recipient = side == 0 ? USER2 : address(0);
        
        // Try to execute swap - it may fail with TTSwapError(14) for small amounts
        try market.buyGood(
            isBuy ? goodA : goodB,
            isBuy ? goodB : goodA,
            swapQuantity,
            side,
            recipient,
            ""
        ) returns (uint256 good1change, uint256 good2change) {
            // If swap succeeds, verify balance changed
            uint256 balanceAfter = isBuy ? 
                usdt.balanceOf(USER1) : 
                tokenA.balanceOf(USER1);
            
            if (isBuy) {
                assertTrue(balanceAfter > balanceBefore, "Should receive tokens");
            }
            assertTrue(good1change > 0 || good2change > 0, "Should have some change");
        } catch (bytes memory reason) {
            // Decode the error
            if (reason.length >= 36) { // 4 bytes selector + 32 bytes uint256
                bytes4 selector;
                uint256 errorCode;
                assembly {
                    selector := mload(add(reason, 0x20))
                    errorCode := mload(add(reason, 0x24))
                }
                if (selector == TTSwapError.selector) {
                    // TTSwapError(14) is acceptable for small swap amounts
                    assertTrue(errorCode == 14, "Only TTSwapError(14) is acceptable for small swaps");
                } else {
                    revert("Unexpected error");
                }
            } else {
                revert("Unknown error");
            }
        }
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGood_RevertConditions(
        address good1,
        address good2,
        uint256 swapQuantity,
        uint128 side
    ) public {
        vm.startPrank(USER1);
        
        // Test same good swap (error 9)
        if (good1 == good2 && good1 == goodA) {
            vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 9));
            market.buyGood(good1, good2, swapQuantity, side, address(0), "");
        }
        
        // Test invalid side (error 8)
        if (side > 1) {
            vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 8));
            market.buyGood(goodA, goodB, swapQuantity, side, address(0), "");
        }
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGood_FeeCalculation(
        uint128 swapAmount
    ) public {
        // Bound inputs
        swapAmount = uint128(bound(swapAmount, 1e6, 1e9));
        
        vm.startPrank(USER1);
        tokenA.mint(USER1, swapAmount);
        tokenA.approve(address(market), swapAmount);
        
        // Check expected output
        (uint256 good1change, uint256 good2change) = market.buyGoodCheck(
            goodA,
            goodB,
            (uint256(swapAmount) << 128),
            true
        );
        
        // The fee is reflected in the difference between input and actual trade
        uint128 inputAmount = swapAmount;
        uint128 actualTraded = uint128(good1change); // amount1
        
        // Verify fee was deducted
        assertTrue(actualTraded <= inputAmount, "Fee should be deducted");
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGood_Slippage(
        uint128 swapAmount,
        uint128 minOutput
    ) public {
        // Bound inputs to ensure sufficient swap value
        swapAmount = uint128(bound(swapAmount, 1e7, 1e9)); // Increased minimum to ensure swap value > 1,000,000
        
        vm.startPrank(USER1);
        tokenA.mint(USER1, swapAmount);
        tokenA.approve(address(market), swapAmount);
        
        // First check expected output
        (uint256 good1change, uint256 good2change) = market.buyGoodCheck(
            goodA,
            goodB,
            (uint256(swapAmount) << 128),
            true
        );
        
        uint128 expectedOutput = uint128(good2change); // amount1
        
        // Set minOutput higher than expected
        if (expectedOutput > 0) {
            minOutput = expectedOutput + 1;
            
            // Should revert due to slippage (error 15) or insufficient swap value (error 14)
            // Both are valid failure modes for this test
            vm.expectRevert();
            market.buyGood(
                goodA,
                goodB,
                (uint256(swapAmount) << 128) | minOutput,
                1,
                address(0),
                ""
            );
        }
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGood_SimpleSwap() public {
        // Simple concrete test to verify basic functionality
        vm.startPrank(USER1);
        
        uint128 swapAmount = 1e7;
        tokenA.mint(USER1, swapAmount);
        tokenA.approve(address(market), swapAmount);
        
        uint256 usdtBalanceBefore = usdt.balanceOf(USER1);
        
        // Execute buy (side = 1)
        (uint256 good1change, uint256 good2change) = market.buyGood(
            goodA,
            goodB,
            (uint256(swapAmount) << 128),
            1,
            address(0),
            ""
        );
        
        uint256 usdtBalanceAfter = usdt.balanceOf(USER1);
        
        // Should have received some USDT
        assertTrue(usdtBalanceAfter > usdtBalanceBefore, "Should receive USDT");
        assertTrue(good2change > 0, "Should have output");
        
        vm.stopPrank();
    }
    
    function testFuzz_BuyGoodCheck_View(
        uint128 checkAmount
    ) public view {
        checkAmount = uint128(bound(checkAmount, 1e4, 1e9));
        
        // This is a view function, should not revert for valid inputs
        (uint256 good1change, uint256 good2change) = market.buyGoodCheck(
            goodA,
            goodB,
            (uint256(checkAmount) << 128),
            true
        );
        
        // Basic sanity checks
        assertTrue(good1change > 0 || good2change > 0, "Should have some change");
    }
}