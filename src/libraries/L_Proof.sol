// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {sub, add, L_TTSwapUINT256Library} from "./L_TTSwapUINT256.sol";
import {I_TTSwap_Token} from "../interfaces/I_TTSwap_Token.sol";
import {S_ProofState, S_ProofKey} from "../interfaces/I_TTSwap_Market.sol";

/**
 * @title L_Proof Library
 * @notice Tracks a user's liquidity position in one good as an "investment proof" (NFT-like id).
 * @dev Proof id = `keccak256(abi.encode(S_ProofKey))` where key is `(owner, currentgood)`.
 *
 * @dev **Proof state fields** (`S_ProofState`) — per-position snapshots, not global pool fields:
 * - `currentgood`: good id this proof is bound to
 * - `shares.amount0`: LP shares; `shares.amount1`: TTS stake value
 * - `state.amount0`: virtual value at proof ratios; `state.amount1`: actual value at proof ratios
 * - `invest.amount0`: virtual qty at proof time (`Q` leg); `invest.amount1`: actual qty deposited (`investQty` leg)
 *
 * @dev Distinct from on-pool `goodConfig.amount1()` (`virtualQty` tracker) and `currentState` (`investQty`, `Q`).
 */
library L_Proof {
    using L_TTSwapUINT256Library for uint256;

    /// @notice Adds a new deposit (or increases position) on an existing proof.
    /// @dev On first deposit (`invest.amount1 == 0`), sets `currentgood`.
    /// @param _shares `(newShares, ttsStakeValue)` to add.
    /// @param _state `(virtualValue, actualValue)` increment.
    /// @param _invest `(virtualQty, actualQty)` increment.
    function updateInvest(
        S_ProofState storage _self,
        uint256 _currenctgood,
        uint256 _shares,
        uint256 _state,
        uint256 _invest
    ) internal {
        if (_self.invest.amount1() == 0) _self.currentgood = _currenctgood;
        _self.shares = add(_self.shares, _shares);
        _self.state = add(_self.state, _state);
        _self.invest = add(_self.invest, _invest);
    }

    /// @notice Reduces proof balances after a partial or full disinvest.
    /// @dev Called from `L_Good.disinvestGood` after pool state is updated.
    function burnProof(
        S_ProofState storage _self,
        uint256 _shares,
        uint256 _state,
        uint256 _invest
    ) internal {
        _self.invest = sub(_self.invest, _invest);
        _self.state = sub(_self.state, _state);
        _self.shares = sub(_self.shares, _shares);
    }

    /// @notice Stakes proof value into the TTS governance token (called on invest).
    /// @return Amount recorded by the token contract (may net construction fee).
    function stake(
        I_TTSwap_Token contractaddress,
        address to,
        uint128 proofvalue
    ) internal returns (uint128) {
        return contractaddress.stake(to, proofvalue);
    }

    /// @notice Unstakes TTS when LP withdraws and proof TTS value is released.
    function unstake(
        I_TTSwap_Token contractaddress,
        address from,
        uint128 divestvalue
    ) internal {
        contractaddress.unstake(from, divestvalue);
    }
}

/// @title L_ProofIdLibrary
/// @notice Deterministic proof id from `(owner, goodId)` — one proof per user per good.
library L_ProofIdLibrary {
    /// @dev `keccak256` over 64 bytes of `S_ProofKey` (owner + currentgood).
    function toId(
        S_ProofKey memory proofKey
    ) internal pure returns (uint256 poolId) {
        assembly {
            poolId := keccak256(proofKey, 0x40)
        }
    }
}
