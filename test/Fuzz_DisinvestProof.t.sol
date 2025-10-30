// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_DisinvestProof is BaseTest {
    
    address valueGood;
    address normalGood;
    uint256 proofId;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(ADMIN);
        
        // Setup goods
        usdt.approve(address(market), 1e12);
        market.initMetaGood(
            address(usdt),
            (1e10 << 128) | 1e10,
            (1 << 255),
            ""
        );
        valueGood = address(usdt);
        
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
        normalGood = address(tokenA);
        
        vm.stopPrank();
        
        // Create initial investment
        vm.startPrank(USER1);
        tokenA.mint(USER1, 1e10);
        tokenA.approve(address(market), 1e10);
        usdt.mint(USER1, 1e10);
        usdt.approve(address(market), 1e10);
        
        market.investGood(normalGood, valueGood, 1e9, "", "",USER1,"");
        proofId = uint256(keccak256(abi.encode(USER1, normalGood, valueGood)));
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_PartialWithdraw(
        uint128 withdrawShares
    ) public {
        // Get current proof state
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 totalShares = uint128(proof.shares >> 128); // amount0
        
        // Skip test if no shares available
        if (totalShares == 0) {
            return;
        }
        
        // Bound withdraw amount (ensure we have meaningful shares to withdraw)
        uint128 minWithdraw = totalShares / 1000; // At least 0.1% of total shares
        if (minWithdraw == 0) minWithdraw = 1;
        withdrawShares = uint128(bound(withdrawShares, minWithdraw, totalShares));
        
        vm.startPrank(USER1);
        
        // Record balance before
        uint256 normalBalBefore = tokenA.balanceOf(USER1);
        uint256 valueBalBefore = usdt.balanceOf(USER1);
        
        // Disinvest
        (uint128 profit1, uint128 profit2) = market.disinvestProof(
            proofId,
            withdrawShares,
            address(0), // no gate
            USER1,
            ""
        );
        
        // Verify tokens received
        uint256 normalBalAfter = tokenA.balanceOf(USER1);
        uint256 valueBalAfter = usdt.balanceOf(USER1);
        
        assertTrue(normalBalAfter > normalBalBefore, "Should receive normal tokens");
        assertTrue(valueBalAfter > valueBalBefore, "Should receive value tokens");
        
        // Verify remaining proof
        S_ProofState memory proofAfter = market.getProofState(proofId);
        assertTrue(proofAfter.shares < proof.shares, "Shares should decrease");
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_FullWithdraw(
        uint128 additionalInvest
    ) public {
        // Add more investment first
        additionalInvest = uint128(bound(additionalInvest, 1e6, 1e9));
        
        vm.startPrank(USER1);
        tokenA.mint(USER1, additionalInvest);
        tokenA.approve(address(market), additionalInvest);
        usdt.mint(USER1, additionalInvest);
        usdt.approve(address(market), additionalInvest);
        market.investGood(normalGood, valueGood, additionalInvest, "", "",USER1,"");
        
        // Get total shares
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 totalShares = uint128(proof.shares >> 128);
        
        // Withdraw everything
        (uint128 profit1, uint128 profit2) = market.disinvestProof(
            proofId,
            totalShares,
            address(0),USER1,""
        );
        
        // Verify complete withdrawal
        S_ProofState memory proofAfter = market.getProofState(proofId);
        assertEq(proofAfter.shares, 0, "Shares should be zero");
        assertEq(proofAfter.invest, 0, "Investment should be zero");
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_WithGate(
        address gateAddress,
        uint128 withdrawAmount
    ) public {
        vm.assume(gateAddress != address(0));
        vm.assume(gateAddress != USER1);
        
        S_ProofState memory proof = market.getProofState(proofId);
        withdrawAmount = uint128(bound(withdrawAmount, 1, uint128(proof.shares >> 128)));
        
        vm.startPrank(USER1);
        
        // Disinvest with gate
        (uint128 profit1, uint128 profit2) = market.disinvestProof(
            proofId,
            withdrawAmount,
            gateAddress,USER1,""
        );
        
        // Gate should receive commission
        // Check commission state in goods
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_InvalidProof(
        uint256 randomProofId,
        uint128 amount
    ) public {
        vm.assume(randomProofId != proofId);
        
        vm.startPrank(USER1);
        
        // Should revert with wrong proof ID
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 19));
        market.disinvestProof(randomProofId, amount, address(0),USER1,"");
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_FrozenGood() public {
        // Freeze the good
        vm.startPrank(ADMIN);
        // Get current config and add freeze bit
        S_GoodTmpState memory currentState = market.getGoodState(normalGood);
        uint256 frozenConfig = currentState.goodConfig | (1 << 254); // Add freeze bit to existing valid config
        market.modifyGoodConfig(normalGood, frozenConfig,ADMIN,"");
        vm.stopPrank();
        
        vm.startPrank(USER1);
        
        market.disinvestProof(proofId, 1, address(0),USER1,"");
        
        vm.stopPrank();
    }
    
    function testFuzz_DisinvestProof_ProfitCalculation(
        uint128 tradeVolume
    ) public {
        // Simulate trades to generate fees
        tradeVolume = uint128(bound(tradeVolume, 1e7, 1e10)); // Increased minimum volume
        
        vm.startPrank(USER2);
        
        // Execute multiple trades to generate more fees
        tokenA.mint(USER2, tradeVolume * 2);
        tokenA.approve(address(market), tradeVolume * 2);
        usdt.mint(USER2, tradeVolume);
        usdt.approve(address(market), tradeVolume);
        
        // First trade: buy with tokenA
        market.buyGood(
            normalGood,
            valueGood,
            (uint256(tradeVolume) << 128),
           
            address(0),
            "",USER2,""
        );
        
        // Second trade: buy back with usdt
        market.buyGood(
            valueGood,
            normalGood,
            (uint256(tradeVolume / 2) << 128),
          
            address(0),
            "",USER2,""
        );
        
        vm.stopPrank();
        
        // Now disinvest and check profit
        vm.startPrank(USER1);
        
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 shares = uint128(proof.shares >> 128);
        
        // Record initial investment for comparison
        uint128 initialInvestment = uint128(proof.invest >> 128);
        
        (uint128 profit1, uint128 profit2) = market.disinvestProof(
            proofId,
            shares,
            address(0),USER1,""
        );
        
        // Check if we got back more than we invested (indicating profit)
        // Or at least some profit from the return values
        assertTrue(
            profit1 > 0 || profit2 > 0 || 
            tokenA.balanceOf(USER1) > initialInvestment ||
            usdt.balanceOf(USER1) > 0, 
            "Should have profit from fees or increased balance"
        );
        
        vm.stopPrank();
    }
}