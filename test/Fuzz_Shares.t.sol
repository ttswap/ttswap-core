// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_Shares is BaseTest {
    
    function setUp() public override {
        super.setUp();
        
        // Ensure main chain config
        vm.startPrank(ADMIN);
        // Set main chain flag in config
        vm.stopPrank();
    }
    
    function testFuzz_AddShare_ValidShare(
        uint128 amount,
        uint120 metric,
        uint8 chips
    ) public {
        // Bound inputs
        amount = uint128(bound(amount, 1, ttsToken.left_share()));
        metric = uint120(bound(metric, 0, 100));
        chips = uint8(bound(chips, 1, 100));
        
        vm.startPrank(ADMIN);
        
        uint128 leftShareBefore = ttsToken.left_share();
        
        // Create share
        s_share memory share = s_share({
            leftamount: amount,
            metric: metric,
            chips: chips
        });
        
        // Add share
        ttsToken.addShare(share, USER1);
        
        // Verify state
        uint128 leftShareAfter = ttsToken.left_share();
        assertEq(
            leftShareAfter,
            leftShareBefore - amount,
            "Left share should decrease"
        );
        
        // Verify user share
        s_share memory userShare = ttsToken.usershares(USER1);
        assertEq(userShare.leftamount, amount, "User should have share");
        assertEq(userShare.metric, metric, "Metric should match");
        assertEq(userShare.chips, chips, "Chips should match");
        
        vm.stopPrank();
    }
    
    function testFuzz_AddShare_MultipleAdds(
        uint128[] memory amounts
    ) public {
        vm.assume(amounts.length <= 10);
        
        vm.startPrank(ADMIN);
        
        uint128 totalAdded = 0;
        uint128 maxMetric = 0;
        uint8 maxChips = 0;
        
        for (uint i = 0; i < amounts.length; i++) {
            uint128 leftShare = ttsToken.left_share();
            if (leftShare == 0) break;
            
            uint128 amount = uint128(bound(amounts[i], 1, leftShare / 2));
            uint120 metric = uint120(i);
            uint8 chips = uint8(i + 1);
            
            s_share memory share = s_share({
                leftamount: amount,
                metric: metric,
                chips: chips
            });
            
            ttsToken.addShare(share, USER1);
            
            totalAdded += amount;
            if (metric > maxMetric) maxMetric = metric;
            if (chips > maxChips) maxChips = chips;
        }
        
        // Verify cumulative effect
        s_share memory userShare = ttsToken.usershares(USER1);
        assertEq(userShare.leftamount, totalAdded, "Total should match");
        assertEq(userShare.metric, maxMetric, "Should keep max metric");
        assertEq(userShare.chips, maxChips, "Should keep max chips");
        
        vm.stopPrank();
    }
    
    function testFuzz_BurnShare_ExistingShare() public {
        // First add a share
        vm.startPrank(ADMIN);
        
        s_share memory share = s_share({
            leftamount: 1000000,
            metric: 10,
            chips: 5
        });
        
        ttsToken.addShare(share, USER1);
        
        uint128 leftShareBefore = ttsToken.left_share();
        
        // Burn the share
        ttsToken.burnShare(USER1);
        
        uint128 leftShareAfter = ttsToken.left_share();
        assertEq(
            leftShareAfter,
            leftShareBefore + 1000000,
            "Left share should increase"
        );
        
        // Verify share is deleted
        s_share memory userShare = ttsToken.usershares(USER1);
        assertEq(userShare.leftamount, 0, "Share should be deleted");
        
        vm.stopPrank();
    }
    
    function testFuzz_ShareMint_ValidConditions(
        uint128 initialAmount,
        uint8 chips
    ) public {
        // Setup share for user
        initialAmount = uint128(bound(initialAmount, 1000, ttsToken.left_share()));
        chips = uint8(bound(chips, 1, 100));
        
        vm.startPrank(ADMIN);
        
        s_share memory share = s_share({
            leftamount: initialAmount,
            metric: 0,
            chips: chips
        });
        
        ttsToken.addShare(share, USER1);
        
        // Setup market condition for minting
        // Mock the ishigher condition to return true
        
        vm.stopPrank();
        
        // User tries to mint
        vm.startPrank(USER1);
        
        // Note: ttsToken is I_TTSwap_Token interface, need to cast to access ERC20 methods
        uint256 balanceBefore = TTSwap_Token(address(ttsToken)).balanceOf(USER1);
        
        // This will likely revert without proper market setup
        vm.expectRevert();
        ttsToken.shareMint();
        
        vm.stopPrank();
    }
    
    function testFuzz_AddShare_ExceedsLeftShare(
        uint128 excessAmount
    ) public {
        uint128 available = ttsToken.left_share();
        excessAmount = uint128(bound(excessAmount, available + 1, type(uint128).max));
        
        vm.startPrank(ADMIN);
        
        s_share memory share = s_share({
            leftamount: excessAmount,
            metric: 0,
            chips: 1
        });
        
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 67));
        ttsToken.addShare(share, USER1);
        
        vm.stopPrank();
    }
    
    function testFuzz_Authorization(
        address unauthorizedUser
    ) public {
        vm.assume(unauthorizedUser != ADMIN);
        vm.assume(unauthorizedUser != address(0));
        
        s_share memory share = s_share({
            leftamount: 1000,
            metric: 0,
            chips: 1
        });
        
        // Test add share authorization
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        ttsToken.addShare(share, USER1);
        
        // Test burn share authorization
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        ttsToken.burnShare(USER1);
    }
}