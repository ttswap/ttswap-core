// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {toTTSwapUINT256, mulDiv, sub, add, L_TTSwapUINT256Library} from "./L_TTSwapUINT256.sol";
import {I_TTSwap_Token} from "../interfaces/I_TTSwap_Token.sol";
import {S_ProofState, S_ProofKey} from "../interfaces/I_TTSwap_Market.sol";

library L_Proof {
    using L_TTSwapUINT256Library for uint256;
    /**
     * @dev Represents the state of a proof
     * @member currentgood The current good  associated with the proof
     * @member valuegood The value good associated with the proof
     * @member state amount0 (first 128 bits) represents total value
     * @member invest amount0 (first 128 bits) represents invest normal good quantity, amount1 (last 128 bits) represents normal good constuct fee when investing
     * @member valueinvest amount0 (first 128 bits) represents invest value good quantity, amount1 (last 128 bits) represents value good constuct fee when investing
     */
    // struct S_ProofState {
    //     uint256 currentgood;
    //     uint256 valuegood;
    //     uint256 state;
    //     uint256 invest;
    //     uint256 valueinvest;
    // }

    /**
     * @dev Updates the investment state of a proof
     * @param _self The proof state to update
     * @param _currenctgood The current good value
     * @param _valuegood The value good
     * @param _shares amount0:normal shares amount1:value shares
     * @param _state amount0 (first 128 bits) represents total value
     * @param _invest amount0 (first 128 bits) represents invest normal good quantity, amount1 (last 128 bits) represents normal good constuct fee when investing
     * @param _valueinvest amount0 (first 128 bits) represents invest value good quantity, amount1 (last 128 bits) represents value good constuct fee when investing
     */
    function updateInvest(
        S_ProofState storage _self,
        address _currenctgood,
        address _valuegood,
        uint256 _shares,
        uint256 _state,
        uint256 _invest,
        uint256 _valueinvest
    ) internal {
        if (_self.invest.amount1() == 0) _self.currentgood = _currenctgood;
        _self.shares = add(_self.shares, _shares);
        _self.state = add(_self.state, _state);
        _self.invest = add(_self.invest, _invest);
        if (_valuegood != address(0)) {
            _self.valuegood = _valuegood;
            _self.valueinvest = add(_self.valueinvest, _valueinvest);
        }
    }

    /**
     * @dev Burns a portion of the proof
     * @param _self The proof state to update
     * @param _value The amount to burn
     */
    function burnProof(
        S_ProofState storage _self,
        uint256 _shares,
        uint256 _value,
        uint256 _invest,
        uint256 _valueinvest
    ) internal {
        // If there's a value good, calculate and burn the corresponding amount of value investment
        if (_self.valuegood != address(0)) {
            _self.valueinvest = sub(_self.valueinvest, _valueinvest);
        }

        // Subtract the calculated investment from the total investment
        _self.invest = sub(_self.invest, _invest);
        // Reduce the total state by the burned value
        _self.state = sub(_self.state, _value);
        _self.shares = sub(_self.shares, _shares);
    }

    /**
     * @dev Stakes a certain amount of proof value
     * @param contractaddress The address of the staking contract
     * @param to The address to stake for
     * @param proofvalue The amount of proof value to stake
     * @return The staked amount
     */
    function stake(
        I_TTSwap_Token contractaddress,
        address to,
        uint128 proofvalue
    ) internal returns (uint128) {
        return contractaddress.stake(to, proofvalue);
    }

    /**
     * @dev Unstakes a certain amount of proof value
     * @param contractaddress The address of the staking contract
     * @param from The address to unstake from
     * @param divestvalue The amount of proof value to unstake
     */
    function unstake(
        I_TTSwap_Token contractaddress,
        address from,
        uint128 divestvalue
    ) internal {
        contractaddress.unstake(from, divestvalue);
    }
}

library L_ProofIdLibrary {
    function toId(S_ProofKey memory proofKey) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(proofKey)));
    }
}
