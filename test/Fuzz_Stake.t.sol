// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract Fuzz_Stake is BaseTest {
    
    function setUp() public override {
        super.setUp();
        
        // Set up necessary permissions
        vm.startPrank(ADMIN);
        ttsToken.setCallMintTTS(address(this), true); // Allow this test to call stake
        vm.stopPrank();
    }
    
    function testFuzz_Stake_ValidStaking(
        address staker,
        uint128 proofValue
    ) public {
        vm.assume(staker != address(0));
        proofValue = uint128(bound(proofValue, 1e6, 1e15));
        
        // Record state before
        uint256 stateStateBefore = ttsToken.stakestate();
        uint256 poolStateBefore = ttsToken.poolstate();
        
        // Stake
        uint128 construct = ttsToken.stake(staker, proofValue);
        
        // Verify state changes
        uint256 stateStateAfter = ttsToken.stakestate();
        uint256 poolStateAfter = ttsToken.poolstate();
        
        assertTrue(stateStateAfter > stateStateBefore, "Stake state should increase");
        
        // Pool state only increases if there was already some pool state (amount1 > 0)
        // When poolstate.amount1() == 0, netconstruct is 0, so poolstate doesn't increase
        if (uint128(poolStateBefore) > 0) {
            assertTrue(poolStateAfter > poolStateBefore, "Pool state should increase when pool has existing state");
        } else {
            // When pool is empty, construct should be 0 and pool state shouldn't change
            assertEq(construct, 0, "Construct should be 0 when pool is empty");
            assertEq(poolStateAfter, poolStateBefore, "Pool state should not change when pool is empty");
        }
        
        // Verify proof record
        uint256 stakeId = uint256(keccak256(abi.encode(staker, address(this))));
        s_proof memory proof = ttsToken.stakeproofinfo(stakeId);
        assertEq(proof.fromcontract, address(this), "Contract should match");
        assertTrue(proof.proofstate > 0, "Proof state should be set");
    }
    
    function testFuzz_Stake_MultipleStakes(
        address[] memory stakers,
        uint128[] memory amounts
    ) public {
        // Bound array sizes to reduce assume rejections
        uint256 arrayLength = bound(stakers.length, 1, 5); // Smaller range
        
        // Resize arrays to bounded length
        assembly {
            mstore(stakers, arrayLength)
            mstore(amounts, arrayLength)
        }
        
        uint256 totalStaked = 0;
        
        for (uint i = 0; i < arrayLength; i++) {
            // Use bound instead of assume for addresses
            address staker = address(uint160(bound(uint256(uint160(stakers[i])), 1, type(uint160).max)));
            
            uint128 amount = uint128(bound(amounts[i], 1e6, 1e10));
            totalStaked += amount;
            
            ttsToken.stake(staker, amount);
            
            // Verify individual stake
            uint256 stakeId = uint256(keccak256(abi.encode(staker, address(this))));
            s_proof memory proof = ttsToken.stakeproofinfo(stakeId);
            assertTrue(proof.proofstate > 0, "Each stake should be recorded");
        }
        
        // Verify total state
        uint256 finalStakeState = ttsToken.stakestate();
        assertTrue(uint128(finalStakeState) >= totalStaked, "Total stake should match");
    }
    
    function testFuzz_Stake_ConstructCalculation(
        uint128 proofValue,
        uint256 existingPoolState
    ) public {
        proofValue = uint128(bound(proofValue, 1e6, 1e15));
        
        // Calculate expected construct
        // construct = poolstate.amount1() == 0 ? 0 : mulDiv(poolstate.amount0(), proofvalue, stakestate.amount1())
        uint256 poolState = ttsToken.poolstate();
        uint256 stakeState = ttsToken.stakestate();
        
        uint128 expectedConstruct = uint128(poolState) == 0 ? 
            0 : 
            uint128((uint256(poolState >> 128) * proofValue) / uint128(stakeState));
        
        uint128 actualConstruct = ttsToken.stake(USER1, proofValue);
        
        // Allow for rounding
        assertApproxEqAbs(
            actualConstruct,
            expectedConstruct,
            100,
            "Construct calculation should match"
        );
    }
    
    function testFuzz_Stake_Authorization(
        address unauthorizedCaller
    ) public {
        vm.assume(unauthorizedCaller != address(this));
        vm.assume(unauthorizedCaller != ADMIN);
        
        // Remove permission first
        vm.prank(ADMIN);
        ttsToken.setCallMintTTS(unauthorizedCaller, false);
        
        // Try to stake without permission
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 71));
        ttsToken.stake(USER1, 1e10);
    }
    
    function testFuzz_Stake_FeeGeneration() public {
        // Fast forward time to trigger fee generation
        vm.warp(block.timestamp + 86401); // Move forward 1 day + 1 second
        
        uint256 poolStateBefore = ttsToken.poolstate();
        
        // Any stake should trigger fee update
        ttsToken.stake(USER1, 1e10);
        
        uint256 poolStateAfter = ttsToken.poolstate();
        
        // Pool should have increased due to daily fees
        assertTrue(
            poolStateAfter > poolStateBefore,
            "Pool should increase from fees"
        );
    }
}