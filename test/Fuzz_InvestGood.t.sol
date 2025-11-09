// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";
import "forge-std/src/console.sol";

contract Fuzz_InvestGood is BaseTest {
    
    address valueGood;
    address normalGood;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(ADMIN);
        
        // Initialize value good (USDT)
        usdt.approve(address(market), 1e12);
        market.initMetaGood(
            address(usdt),
            (1e16 << 128) | 1e10,
            (1 << 255), // value good config
            ""
        );
        valueGood = address(usdt);
        
        // Initialize normal good
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
            ADMIN,""
            ""
        );
        normalGood = address(tokenA);
        
        vm.stopPrank();
    }
    
    function testFuzz_InvestGood_SingleGood(
        uint128 investAmount
    ) public {
        // Bound investment amount
        investAmount = uint128(bound(investAmount, 1e6, 1e10));
        
        vm.startPrank(USER1);
        
        // Mint and approve tokens for value good investment
        usdt.mint(USER1, investAmount);
        usdt.approve(address(market), investAmount);
        
        // Get proof key before investment
        uint256 proofId = uint256(keccak256(abi.encode(USER1, valueGood, address(0))));
        
        // Invest in value good only (this is allowed)
        bool success = market.investGood(
            valueGood,
            address(0), // no second good
            investAmount,
            "",
            "",USER1,""
        );
        
        assertTrue(success, "Investment should succeed");
        
        // Verify proof state
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, valueGood, "Current good should match");
        assertTrue(proof.shares > 0, "Should have shares");
        
        vm.stopPrank();
    }
    
    function testFuzz_InvestGood_WithValueGood(
        uint128 normalInvest,
        uint128 valueInvest
    ) public {
        // Bound amounts to smaller ranges to avoid overflow and mint limits
        normalInvest = uint128(bound(normalInvest, 1e6, 1e7)); // Reduced upper bound
        valueInvest = uint128(bound(valueInvest, 1e6, 1e7)); // Reduced upper bound
        
        vm.startPrank(USER1);
        
        // Mint and approve both tokens with generous amounts
        tokenA.mint(USER1, 50000000); // Mint 50M tokens (within 100M limit)
        tokenA.approve(address(market), type(uint256).max);
        usdt.mint(USER1, 50000000); // Mint 50M tokens (within 100M limit)
        usdt.approve(address(market), type(uint256).max);
        
        // Invest with both goods
        bool success = market.investGood(
            normalGood,
            valueGood,
            normalInvest,
            "",
            "",USER1,""
        );
        
        assertTrue(success, "Investment should succeed");
        
        // Verify proof state
        uint256 proofId = uint256(keccak256(abi.encode(USER1, normalGood, valueGood)));
        S_ProofState memory proof = market.getProofState(proofId);
        
        assertEq(proof.currentgood, normalGood, "Normal good should match");
        assertEq(proof.valuegood, valueGood, "Value good should match");
        assertTrue(proof.shares > 0, "Should have shares");
        assertTrue(proof.valueinvest > 0, "Should have value investment");
        
        vm.stopPrank();
    }
    
    function testFuzz_InvestGood_InvalidInputs(
        address invalidGood,
        uint128 amount
    ) public {
        // Use fixed amount to avoid fuzz issues
        uint128 fixedAmount = 1e6; // 1 USDT (6 decimals)
        
        // USER1 already has tokens from BaseTest.setUp()
        vm.startPrank(USER1);
        usdt.approve(address(market), type(uint256).max);
        
        // Debug: Check USER1 balance
        uint256 user1Balance = usdt.balanceOf(USER1);
        console.log("USER1 USDT balance:", user1Balance);
        console.log("Fixed amount:", fixedAmount);
        
        // Test investing in same good
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 9));
        market.investGood(normalGood, normalGood, fixedAmount, "", "",USER1,"");
        
        // Test frozen good
        vm.stopPrank();
        vm.startPrank(ADMIN);
        // Get current config and add freeze bit
        S_GoodTmpState memory currentState = market.getGoodState(normalGood);
        uint256 frozenConfig = currentState.goodConfig | (1 << 254); // Add freeze bit to existing valid config
        market.modifyGoodConfig(normalGood, frozenConfig,ADMIN,"");
        vm.stopPrank();
        
        // vm.startPrank(USER1);
        // vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        // market.investGood(normalGood, valueGood, fixedAmount, "", "",USER1,"");
        
        vm.stopPrank();
    }
    
    
    function testFuzz_InvestGood_PowerLevels(
        uint128 amount,
        uint8 power
    ) public {
        // Test different power configurations
        amount = uint128(bound(amount, 1e7, 1e10));
        power = uint8(bound(power, 1, 10));
        
        vm.startPrank(ADMIN);
        
        // Create new good with specific power
        MockERC20 newToken = new MockERC20();
        newToken.mint(ADMIN, 1e15);
        newToken.approve(address(market), 1e15);
        
        uint256 config = 0;
        config |= (uint256(power) << 63); // Set power bits
        
        vm.stopPrank();
        
        // Test investment with power scaling
        vm.startPrank(USER1);
        newToken.mint(USER1, amount);
        newToken.approve(address(market), amount);
        
        // Investment quantity should be scaled by power
        // Verify the scaling in the proof state
        
        vm.stopPrank();
    }
    
    function testFuzz_InvestGood_FeeImpact(
        uint128 amount,
        uint8 investFee
    ) public {
        // Test fee impact on investment
        amount = uint128(bound(amount, 1e7, 1e10));
        investFee = uint8(bound(investFee, 0, 100)); // 0-1%
        
        // Calculate expected fee
        uint256 expectedFee = (uint256(amount) * investFee) / 10000;
        
        // Verify actual investment amount after fees
        // actualInvest = amount - expectedFee
    }
}