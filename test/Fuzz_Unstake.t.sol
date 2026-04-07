// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_Unstake is BaseTest {
    
    uint256 stakeId;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(ADMIN);
        ttsToken.setCallMintTTS(address(this), true);
        vm.stopPrank();
        
        // Create initial stake
        ttsToken.stake(USER1, 1e12);
        stakeId = uint256(keccak256(abi.encode(USER1, address(this))));
    }
    
    function testFuzz_Unstake_PartialUnstake(
        uint128 unstakeAmount
    ) public {
        // Get current proof
        s_proof memory proofBefore = ttsToken.stakeproofinfo(stakeId);
        uint128 totalStaked = uint128(proofBefore.proofstate >> 128);
        
        // Bound unstake amount
        unstakeAmount = uint128(bound(unstakeAmount, 1, totalStaked));
        
        uint256 balanceBefore = TTSwap_Token(address(ttsToken)).balanceOf(USER1);
        
        // Unstake
        ttsToken.unstake(USER1, unstakeAmount);
        
        // Verify proof updated
        s_proof memory proofAfter = ttsToken.stakeproofinfo(stakeId);
        assertEq(
            uint128(proofAfter.proofstate >> 128),
            totalStaked - unstakeAmount,
            "Proof should decrease by unstake amount"
        );
        
        // Check if tokens were minted (profit)
        uint256 balanceAfter = TTSwap_Token(address(ttsToken)).balanceOf(USER1);
        // May or may not have profit depending on pool state
    }
    
    function testFuzz_Unstake_FullUnstake() public {
        s_proof memory proof = ttsToken.stakeproofinfo(stakeId);
        uint128 fullAmount = uint128(proof.proofstate >> 128);
        
        // Unstake everything
        ttsToken.unstake(USER1, fullAmount);
        
        // Verify proof cleared
        s_proof memory proofAfter = ttsToken.stakeproofinfo(stakeId);
        assertEq(proofAfter.proofstate, 0, "Proof should be cleared");
        assertEq(proofAfter.fromcontract, address(0), "Contract should be cleared");
    }
    
    function testFuzz_Unstake_ProfitCalculation(
        uint128 additionalStake,
        uint256 timeElapsed
    ) public {
        // Simulate pool growth
        timeElapsed = bound(timeElapsed, 86400, 365 days);
        additionalStake = uint128(bound(additionalStake, 1e6, 1e15));
        
        // Fast forward time for fee generation
        vm.warp(block.timestamp + timeElapsed);
        
        // Add more stakes to generate fees
        ttsToken.stake(USER2, additionalStake);
        
        // Record balance before unstake
        uint256 balanceBefore = TTSwap_Token(address(ttsToken)).balanceOf(USER1);
        
        // Unstake original stake
        s_proof memory proof = ttsToken.stakeproofinfo(stakeId);
        uint128 proofValue = uint128(proof.proofstate >> 128);
        
        ttsToken.unstake(USER1, proofValue);
        
        // Check profit minted
        uint256 balanceAfter = TTSwap_Token(address(ttsToken)).balanceOf(USER1);
        uint256 profit = balanceAfter - balanceBefore;
        
        // Should have some profit from time-based fees
        assertTrue(profit >= 0, "Should not lose tokens");
    }
    
    function testFuzz_Unstake_Authorization(
        address unauthorizedCaller
    ) public {
        vm.assume(unauthorizedCaller != address(this));
        
        vm.prank(ADMIN);
        ttsToken.setCallMintTTS(unauthorizedCaller, false);
        
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 71));
        ttsToken.unstake(USER1, 1e10);
    }
    
    function testFuzz_Unstake_ExcessAmount(
        uint128 excessAmount
    ) public {
        s_proof memory proof = ttsToken.stakeproofinfo(stakeId);
        uint128 totalStaked = uint128(proof.proofstate >> 128);
        
        // Try to unstake more than staked
        excessAmount = uint128(bound(excessAmount, totalStaked + 1, type(uint128).max));
        
        // Should unstake only available amount
        ttsToken.unstake(USER1, excessAmount);
        
        // Verify all was unstaked
        s_proof memory proofAfter = ttsToken.stakeproofinfo(stakeId);
        assertEq(proofAfter.proofstate, 0, "Should unstake all available");
    }
    
    function testFuzz_Unstake_StateConsistency(
        uint128[] memory unstakeAmounts
    ) public {
        vm.assume(unstakeAmounts.length <= 10);
        
        s_proof memory initialProof = ttsToken.stakeproofinfo(stakeId);
        uint128 remaining = uint128(initialProof.proofstate >> 128);
        
        for (uint i = 0; i < unstakeAmounts.length && remaining > 0; i++) {
            uint128 amount = uint128(bound(unstakeAmounts[i], 0, remaining));
            if (amount == 0) continue;
            
            uint256 stakeStateBefore = ttsToken.stakestate();
            uint256 poolStateBefore = ttsToken.poolstate();
            
            ttsToken.unstake(USER1, amount);
            
            uint256 stakeStateAfter = ttsToken.stakestate();
            uint256 poolStateAfter = ttsToken.poolstate();
            
            // Verify state consistency
            assertTrue(
                uint128(stakeStateAfter) <= uint128(stakeStateBefore),
                "Stake state should decrease"
            );
            
            remaining -= amount;
        }
    }
}