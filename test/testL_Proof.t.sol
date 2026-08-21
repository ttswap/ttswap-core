// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_Proof, L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token} from "../src/interfaces/I_TTSwap_Token.sol";
import {toTTSwapUINT256, L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

contract TokenStakeMock {
    address public lastAddr;
    uint128 public lastValue;
    uint128 public stakeReturn;

    function setStakeReturn(uint128 v) external {
        stakeReturn = v;
    }

    function stake(address to, uint128 proofvalue) external returns (uint128) {
        lastAddr = to;
        lastValue = proofvalue;
        return stakeReturn;
    }

    function unstake(address from, uint128 divestvalue) external {
        lastAddr = from;
        lastValue = divestvalue;
    }
}

contract ProofHarness {
    using L_Proof for S_ProofState;
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    S_ProofState internal proof;

    function updateInvest(uint256 good, uint256 shares, uint256 state, uint256 invest) external {
        proof.updateInvest(good, shares, state, invest);
    }

    function burnProof(uint256 shares, uint256 state, uint256 invest) external {
        proof.burnProof(shares, state, invest);
    }

    function stake(address token, address to, uint128 value) external returns (uint128) {
        return L_Proof.stake(I_TTSwap_Token(token), to, value);
    }

    function unstake(address token, address from, uint128 value) external {
        L_Proof.unstake(I_TTSwap_Token(token), from, value);
    }

    function toId(address owner, uint256 good) external pure returns (uint256) {
        return S_ProofKey(owner, good).toId();
    }

    function sharesOf() external view returns (uint256) {
        return proof.shares;
    }

    function currentgood() external view returns (uint256) {
        return proof.currentgood;
    }
}

/// @notice `L_Proof` stake/unstake/id paths for the coverage profile.
contract testL_Proof is Test {
    using L_TTSwapUINT256Library for uint256;

    ProofHarness internal h;
    TokenStakeMock internal mock;

    function setUp() public {
        h = new ProofHarness();
        mock = new TokenStakeMock();
    }

    function testL_Proof_updateBurnAndToId() public {
        h.updateInvest(7, toTTSwapUINT256(100, 10), toTTSwapUINT256(50, 40), toTTSwapUINT256(30, 20));
        assertEq(h.currentgood(), 7);
        h.updateInvest(7, toTTSwapUINT256(5, 1), toTTSwapUINT256(2, 2), toTTSwapUINT256(1, 1));
        assertEq(h.sharesOf().amount0(), 105);
        h.burnProof(toTTSwapUINT256(5, 1), toTTSwapUINT256(2, 2), toTTSwapUINT256(1, 1));
        assertEq(h.sharesOf().amount0(), 100);
        assertGt(h.toId(address(this), 7), 0);
    }

    function testL_Proof_stakeUnstake() public {
        mock.setStakeReturn(42);
        assertEq(h.stake(address(mock), address(0xBEEF), 100), 42);
        assertEq(mock.lastAddr(), address(0xBEEF));
        assertEq(mock.lastValue(), 100);

        h.unstake(address(mock), address(0xCAFE), 9);
        assertEq(mock.lastAddr(), address(0xCAFE));
        assertEq(mock.lastValue(), 9);
    }
}
