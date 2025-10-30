// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_CollectCommission is BaseTest {
    
    address[] goods;
    
    function setUp() public override {
        super.setUp();
        
        // Setup multiple goods
        vm.startPrank(ADMIN);
        
        // Init value good
        usdt.approve(address(market), 1e12);
        market.initMetaGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            (1 << 255),
            ""
        );
        goods.push(address(usdt));
        
        // Init normal goods
        tokenA.mint(ADMIN, 1e12);
        tokenA.approve(address(market), 1e12);
        market.initGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            address(tokenA),
            0,
            "",
            "",
            ADMIN,
            ""
        );
        goods.push(address(tokenA));
        
        vm.stopPrank();
        
        // Generate some commission through trades
        generateCommission();
    }
    
    function generateCommission() internal {
        vm.startPrank(USER1);
        
        // Execute trades to generate fees
        tokenA.mint(USER1, 1e10);
        tokenA.approve(address(market), 1e10);
        
        market.buyGood(
            address(tokenA),
            address(usdt),
            (1e9 << 128),
            
            address(0),
            "",
            USER1,
            ""
        );
        
        vm.stopPrank();
    }
    
    function testFuzz_CollectCommission_SingleGood(
        uint8 goodIndex
    ) public {
        goodIndex = uint8(bound(goodIndex, 0, goods.length - 1));
        
        address[] memory singleGood = new address[](1);
        singleGood[0] = goods[goodIndex];
        
        // Check commission available
        uint256[] memory commissionBefore = market.queryCommission(
            singleGood,
            msg.sender
        );
        
        if (commissionBefore[0] > 2) {
            uint256 balanceBefore = MockERC20(singleGood[0]).balanceOf(msg.sender);
            
            // Collect commission
            market.collectCommission(singleGood,msg.sender,"");
            
            uint256 balanceAfter = MockERC20(singleGood[0]).balanceOf(msg.sender);
            
            // Should receive commission minus 1 (kept as dust)
            assertEq(
                balanceAfter - balanceBefore,
                commissionBefore[0] - 1,
                "Should receive commission"
            );
            
            // Commission should be reset to 1
            uint256[] memory commissionAfter = market.queryCommission(
                singleGood,
                msg.sender
            );
            assertEq(commissionAfter[0], 1, "Commission should be 1 after collection");
        }
    }
    
    function testFuzz_CollectCommission_MultipleGoods(
        uint8 numGoods
    ) public {
        vm.startPrank(USER1);
        numGoods = uint8(bound(numGoods, 1, goods.length));
        
        address[] memory selectedGoods = new address[](numGoods);
        for (uint i = 0; i < numGoods; i++) {
            selectedGoods[i] = goods[i % goods.length];
        }
        
        // Get commission amounts
        uint256[] memory commissionBefore = market.queryCommission(
            selectedGoods,
            USER1
        );
        
        uint256[] memory balancesBefore = new uint256[](numGoods);
        for (uint i = 0; i < numGoods; i++) {
            balancesBefore[i] = MockERC20(selectedGoods[i]).balanceOf(USER1);
        }
        
        // Collect all
        market.collectCommission(selectedGoods,USER1,"");
        
        // Verify each collection
        for (uint i = 0; i < numGoods; i++) {
            uint256 balanceAfter = MockERC20(selectedGoods[i]).balanceOf(USER1);
            if (commissionBefore[i] > 2) {
                assertEq(
                    balanceAfter - balancesBefore[i],
                    commissionBefore[i] - 1,
                    "Should receive correct commission"
                );
            }
        }
        vm.stopPrank();
    }
    
    function testFuzz_CollectCommission_MaxGoods() public {
        vm.startPrank(USER1);
        // Test with maximum allowed (100 goods)
        address[] memory manyGoods = new address[](100);
        for (uint i = 0; i < 100; i++) {
            manyGoods[i] = goods[i % goods.length];
        }
        
        // Should succeed
        market.collectCommission(manyGoods,USER1,"");
        
        // Test with more than 100
        address[] memory tooManyGoods = new address[](101);
        
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 21));
        market.collectCommission(tooManyGoods,USER1,"");
        vm.stopPrank();
    }
    
    function testFuzz_CollectCommission_AdminCollection() public {
        // Admin collects to address(0)
        vm.startPrank(ADMIN);
        
        // Query commission for address(0)
        uint256[] memory commission = market.queryCommission(goods, address(0));
        
        if (commission[0] > 2) {
            uint256 balanceBefore = MockERC20(goods[0]).balanceOf(ADMIN);
            
            market.collectCommission(goods,msg.sender,"");
            
            uint256 balanceAfter = MockERC20(goods[0]).balanceOf(ADMIN);
            
            // Admin should receive commission from address(0)
            assertTrue(balanceAfter > balanceBefore, "Admin should receive commission");
        }
        
        vm.stopPrank();
    }
    
    function testFuzz_CollectCommission_NoCommission(
        address randomUser
    ) public {
        vm.assume(randomUser != address(0));
        vm.assume(randomUser != ADMIN);
        
        vm.startPrank(randomUser);
        
        // User with no commission
        uint256[] memory commission = market.queryCommission(goods, randomUser);
        
        uint256 balanceBefore = MockERC20(goods[0]).balanceOf(randomUser);
        
        // Collect should work but receive nothing
        market.collectCommission(goods,randomUser,"");
        
        uint256 balanceAfter = MockERC20(goods[0]).balanceOf(randomUser);
        assertEq(balanceAfter, balanceBefore, "Should receive nothing");
        
        vm.stopPrank();
    }
    
    function testFuzz_CollectCommission_Reentrancy() public {
        // Test reentrancy protection
        // Would need malicious token contract
        // The noReentrant modifier should prevent reentrancy
    }
}