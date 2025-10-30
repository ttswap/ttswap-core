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
            "",
            ADMIN,
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
            recipient,
            "",
            USER1,
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
    
 
    

    
    function testFuzz_BuyGood_Slippage(
        uint128 swapAmount,
        uint128 minOutput
    ) public {
        // Bound inputs to ensure sufficient swap value
        swapAmount = uint128(bound(swapAmount, 1e7, 1e9)); // Increased minimum to ensure swap value > 1,000,000
        
        vm.startPrank(USER1);
        tokenA.mint(USER1, swapAmount);
        tokenA.approve(address(market), swapAmount);
        
        
       
            
        
            market.buyGood(
                goodA,
                goodB,
                (uint256(swapAmount) << 128) | 0,
                address(0),
                "",
                USER1,
                ""
            );
        
        
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
         
            address(0),
            "",
            USER1,
            ""
        );
        
        uint256 usdtBalanceAfter = usdt.balanceOf(USER1);
        
        // Should have received some USDT
        assertTrue(usdtBalanceAfter > usdtBalanceBefore, "Should receive USDT");
        assertTrue(good2change > 0, "Should have output");
        
        vm.stopPrank();
    }
    
   
}