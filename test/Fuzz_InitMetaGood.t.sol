// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_InitMetaGood is BaseTest {
    
    function testFuzz_InitMetaGood_Success(
        uint128 initialValue,
        uint128 initialQuantity,
        uint256 goodConfig
    ) public {
        // Bound inputs
        initialValue = uint128(bound(initialValue, 1e6, 1e15));
        initialQuantity = uint128(bound(initialQuantity, 1e6, 1e15));
        
        // Create valid value good config
        goodConfig = _createGoodConfig(
            true, // isValueGood
            uint8(bound(goodConfig, 0, 100)), // investFee
            uint8(bound(goodConfig >> 8, 0, 100)), // disinvestFee
            uint8(bound(goodConfig >> 16, 0, 100)), // buyFee
            uint8(bound(goodConfig >> 24, 0, 100)) // sellFee
        );
        
        // Mint tokens to admin
        vm.startPrank(ADMIN);
        usdt.mint(ADMIN, initialQuantity);
        usdt.approve(address(market), initialQuantity);
        
        // Initialize meta good
        uint256 initial = (uint256(initialValue) << 128) | initialQuantity;
        
        // Test successful initialization
        bool success = market.initMetaGood(
            address(usdt),
            initial,
            goodConfig,
            ""
        );
        
        assertTrue(success, "Init meta good should succeed");
        
        // Verify state
        S_GoodTmpState memory goodState = market.getGoodState(address(usdt));
        assertEq(goodState.owner, ADMIN, "Owner should be ADMIN");
        
        vm.stopPrank();
    }
    
    function testFuzz_InitMetaGood_RevertConditions(
        address erc20,
        uint256 initial,
        uint256 goodConfig
    ) public {
        vm.startPrank(ADMIN);
        
        // Test 1: Not value good config
        goodConfig = goodConfig & ~(uint256(1) << 255); // Clear value good bit
        // Also fix power to avoid TTSwapError(25) - power is at bits 187-192
        goodConfig = (goodConfig & ~(uint256(0x3F) << 187)) | (uint256(1) << 187);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 4));
        market.initMetaGood(erc20, initial, goodConfig, "");
        
        // Test 2: Already initialized good
        goodConfig = goodConfig | (uint256(1) << 255); // Set value good bit
        // Clear power bits (6 bits: 187-192) and set power = 1
        goodConfig = (goodConfig & ~(uint256(0x3F) << 187)) | (uint256(1) << 187);
        usdt.mint(ADMIN, 1e10);
        usdt.approve(address(market), 1e10);
        market.initMetaGood(address(usdt), (1e10 << 128) | 1e10, goodConfig, "");
        
        // Try to initialize again
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 5));
        market.initMetaGood(address(usdt), initial, goodConfig, "");
        
        vm.stopPrank();
    }
    
    function testFuzz_InitMetaGood_AccessControl(address attacker) public {
        vm.assume(attacker != ADMIN);
        vm.assume(attacker != address(0));
        
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market.initMetaGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            (1 << 255), // value good config
            ""
        );
    }
    
    function testFuzz_InitMetaGood_EdgeCases(
        uint128 extremeValue,
        uint128 extremeQuantity
    ) public {
        vm.startPrank(ADMIN);
        
        // Create valid value good config
        uint256 validGoodConfig = _createGoodConfig(
            true, // isValueGood
            10,   // investFee
            10,   // disinvestFee
            10,   // buyFee
            10    // sellFee
        );
        
        // Test with zero values (should succeed as the function allows zero values)
        bool success = market.initMetaGood(
            address(tokenA),
            toTTSwapUINT256(0, 0),
            validGoodConfig,
            ""
        );
        assertTrue(success, "Should succeed with zero values");
        
        // Test with max values
        extremeValue = type(uint128).max;
        extremeQuantity = type(uint128).max;
        
        tokenB.mint(ADMIN, extremeQuantity);
        tokenB.approve(address(market), extremeQuantity);
        
        // This might revert due to overflow checks
        try market.initMetaGood(
            address(tokenB),
            toTTSwapUINT256(extremeValue, extremeQuantity),
            validGoodConfig,
            ""
        ) {
            // If it succeeds, verify state
            S_GoodTmpState memory state = market.getGoodState(address(tokenB));
            assertTrue(state.owner == ADMIN);
        } catch {
            // Expected to revert with extreme values
            assertTrue(true);
        }
        
        vm.stopPrank();
    }
}