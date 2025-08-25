// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {L_Proof} from "./L_Proof.sol";
import {TTSwapError} from "./L_Error.sol";
import {L_GoodConfigLibrary} from "./L_GoodConfig.sol";

import {S_GoodState, S_ProofState} from "../interfaces/I_TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, toUint128, add, sub, addsub, subadd, lowerprice} from "./L_TTSwapUINT256.sol";

/**
 * @title L_Good Library
 * @dev A library for managing goods in a decentralized marketplace
 * @notice This library provides functions for investing, disinvesting, swapping, and fee management for goods
 */
library L_Good {
    using L_GoodConfigLibrary for uint256;
    using L_TTSwapUINT256Library for uint256;
    using L_Proof for S_ProofState;

    /**
     * @notice Update the good configuration
     * @dev Preserves the top 33 bits of the existing config and updates the rest
     * @param _self Storage pointer to the good state
     * @param _goodConfig New configuration value to be applied
     */
    function updateGoodConfig(
        S_GoodState storage _self,
        uint256 _goodConfig
    ) internal {
        if (_self.goodConfig.getLimitPower() < _goodConfig.getPower())
            revert TTSwapError(23);
        // Clear the top 33 bits of the new config
        assembly {
            _goodConfig := shl(33, shr(33, _goodConfig))
            _goodConfig := shl(128, shr(128, _goodConfig))
        }
        uint256 a = (_self.goodConfig >> 223) << 223;
        uint256 b = (_self.goodConfig << 128) >> 128;
        // Preserve the top 33 bits of the existing config and add the new config
        _self.goodConfig = a + b + _goodConfig;
    }

    /**
     * @notice Modify the good configuration
     * @dev This function modifies the good configuration by preserving the top 33 bits and updating the rest
     * @param _self Storage pointer to the good state
     * @param _goodconfig The new configuration value to be applied
     */
    function modifyGoodConfig(
        S_GoodState storage _self,
        uint256 _goodconfig
    ) internal {
        if (!_goodconfig.checkGoodConfig()) revert TTSwapError(24);
        _goodconfig = (_goodconfig >> 223) << 223;
        _goodconfig = _goodconfig + (_self.goodConfig % (2 ** 223));
        _self.goodConfig = _goodconfig;
    }

    /**
     * @notice Initialize the good state
     * @dev Sets up the initial state, configuration, and owner of the good
     * @param self Storage pointer to the good state
     * @param _init Initial balance state
     * @param _goodConfig Configuration of the good
     */
    function init(
        S_GoodState storage self,
        uint256 _init,
        uint256 _goodConfig
    ) internal {
        self.currentState = toTTSwapUINT256(0, _init.amount1());
        self.investState = toTTSwapUINT256(_init.amount0(), _init.amount0());
        _goodConfig = (_goodConfig << 33) >> 33;
        _goodConfig = (_goodConfig >> 128) << 128;
        _goodConfig = _goodConfig + (1638416512 << 223); //1638416512 6*2**28+ 1*2**24+ 5*2**21+8*2**16+8*2**11+2*2**6
        if (_goodConfig.getPower() > 1) revert TTSwapError(25);
        self.goodConfig = _goodConfig;
        self.owner = msg.sender;
    }

    /**
     * @dev Struct to cache swap-related data
     */
    struct swapCache {
        uint128 remainQuantity; // Remaining quantity to be swapped
        uint128 outputQuantity; // Quantity received from the swap
        uint128 feeQuantity; // Fee amount for the swap
        uint128 swapvalue; // Total value of the swap
        uint128 good1value;
        uint128 good2value;
        uint256 good1currentState; // Current state of the first good
        uint256 good1config; // Configuration of the first good
        uint256 good2currentState; // Current state of the second good
        uint256 good2config; // Configuration of the second good
    }

    /**
     * @notice Compute the swap result from good1 to good2
     * @dev Implements a complex swap algorithm considering price limits, fees, and minimum swap amounts
     * @param _stepCache A cache structure containing swap state and configurations
     */
    function swapCompute1(swapCache memory _stepCache) internal pure {
        // Check if the current price is lower than the limit price, if not, return immediately
        _stepCache.feeQuantity = _stepCache.good1config.getSellFee(
            _stepCache.remainQuantity
        );
        _stepCache.remainQuantity =
            _stepCache.remainQuantity -
            _stepCache.feeQuantity;
        uint256 a = uint256(_stepCache.good1value) *
            uint256(_stepCache.remainQuantity) *
            2;
        uint256 b = uint256(_stepCache.good1currentState.amount1()) *
            2 +
            uint256(_stepCache.remainQuantity);
        // Calculate and deduct the sell fee
        _stepCache.swapvalue = toUint128(a / b);
        a =
            uint256(_stepCache.good2currentState.amount1()) *
            uint256(_stepCache.swapvalue) *
            2;
        b = uint256(_stepCache.good2value) * 2 + uint256(_stepCache.swapvalue);
        _stepCache.outputQuantity = toUint128(a / b);
        _stepCache.good1currentState = add(
            _stepCache.good1currentState,
            toTTSwapUINT256(_stepCache.feeQuantity, _stepCache.remainQuantity)
        );
        _stepCache.good2currentState = addsub(
            _stepCache.good2currentState,
            toTTSwapUINT256(
                _stepCache.good2config.getBuyFee(_stepCache.outputQuantity),
                _stepCache.outputQuantity
            )
        );
    }

    /**
     * @notice Compute the swap result from good1 to good2
     * @dev Implements a complex swap algorithm considering price limits, fees, and minimum swap amounts
     * @param _stepCache A cache structure containing swap state and configurations
     */
    function swapCompute2(swapCache memory _stepCache) internal pure {
        // Check if the current price is lower than the limit price, if not, return immediately
        _stepCache.feeQuantity = _stepCache.good1config.getSellFee(
            _stepCache.remainQuantity
        );
        _stepCache.remainQuantity =
            _stepCache.remainQuantity +
            _stepCache.feeQuantity;

        uint256 a = uint256(_stepCache.good1currentState.amount1()) *
            uint256(_stepCache.good2currentState.amount0()) *
            uint256(_stepCache.remainQuantity) *
            2;
        uint256 b = uint256(_stepCache.good1currentState.amount0()) *
            uint256(_stepCache.good2currentState.amount1()) *
            2 -
            uint256(_stepCache.good1currentState.amount0()) *
            uint256(_stepCache.remainQuantity) -
            uint256(_stepCache.good2currentState.amount0()) *
            uint256(_stepCache.remainQuantity);
        _stepCache.outputQuantity = toUint128(a / b);
        _stepCache.swapvalue = toTTSwapUINT256(
            _stepCache.good1currentState.amount0(),
            _stepCache.good1currentState.amount1() + _stepCache.outputQuantity
        ).getamount0fromamount1(_stepCache.outputQuantity);

        _stepCache.good1currentState = add(
            _stepCache.good1currentState,
            toTTSwapUINT256(0, _stepCache.outputQuantity)
        );
        _stepCache.good2currentState = addsub(
            _stepCache.good2currentState,
            toTTSwapUINT256(_stepCache.feeQuantity, _stepCache.remainQuantity)
        );
    }

    /**
     * @notice Commit the result of a swap operation to the good's state
     * @dev Updates the current state and fee state of the good after a swap
     * @param _self Storage pointer to the good state
     * @param _swapstate The new state of the good after the swap
     */
    function swapCommit(
        S_GoodState storage _self,
        uint256 _swapstate
    ) internal {
        _self.currentState = _swapstate;
    }

    /**
     * @notice Struct to hold the return values of an investment operation
     * @dev Used to store and return the results of investing in a good
     */
    struct S_GoodInvestReturn {
        uint128 investFeeQuantity; // The actual fee amount charged for the investment
        uint128 investShare; // The construction fee amount (if applicable)
        uint128 investValue; // The actual value invested after fees
        uint128 investQuantity; // The actual quantity of goods received for the investment
        uint128 goodShares;
        uint128 goodValues;
        uint128 goodInvestQuantity;
        uint128 goodCurrentQuantity;
    }

    /**
     * @notice Invest in a good
     * @dev Calculates fees, updates states, and returns investment results
     * @param _self Storage pointer to the good state
     * @param _invest Amount to invest
     */
    function investGood(
        S_GoodState storage _self,
        uint128 _invest,
        S_GoodInvestReturn memory investResult_,
        uint128 enpower
    ) internal {
        // Calculate the investment fee
        investResult_.investFeeQuantity = _self.goodConfig.getInvestFee(
            _invest
        );
        // Calculate the actual investment quantity after deducting the fee
        investResult_.investQuantity =
            _invest -
            investResult_.investFeeQuantity;

        // Calculate the actual investment value based on the current state
        investResult_.investValue = toTTSwapUINT256(
            investResult_.goodValues,
            investResult_.goodCurrentQuantity
        ).getamount0fromamount1(investResult_.investQuantity);

        // Update the current state with the new investment
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(_invest, investResult_.investQuantity)
        );
        investResult_.investShare = toTTSwapUINT256(
            investResult_.goodShares,
            investResult_.goodInvestQuantity
        ).getamount0fromamount1(investResult_.investQuantity);
        // Update the invest state with the new investment
        _self.investState = add(
            _self.investState,
            toTTSwapUINT256(
                investResult_.investShare,
                investResult_.investValue
            )
        );
        _self.goodConfig = add(
            _self.goodConfig,
            toTTSwapUINT256(
                0,
                investResult_.investQuantity -
                    investResult_.investQuantity /
                    enpower
            )
        );
    }
    /**
     * @notice Struct to hold the return values of a disinvestment operation
     * @dev Used to store and return the results of disinvesting from a good
     */

    struct S_GoodDisinvestReturn {
        uint128 profit; // The profit earned from disinvestment
        uint128 actual_fee; // The actual fee charged for disinvestment
        uint128 vitualDisinvestQuantity; // The vitual quantity of goods disinvested
        uint128 actualDisinvestQuantity;
    }

    /**
     * @notice Struct to hold the parameters for a disinvestment operation
     * @dev Used to pass multiple parameters to the disinvestGood function
     */
    struct S_GoodDisinvestParam {
        uint128 _goodshares; // The shares of goods to disinvest
        address _gater; // The address of the gater (if applicable)
        address _referral; // The address of the referrer (if applicable)
    }

    /**
     * @notice Disinvest from a good and potentially its associated value good
     * @dev This function handles the complex process of disinvesting from a good, including fee calculations and state updates
     * @param _self Storage pointer to the main good state
     * @param _valueGoodState Storage pointer to the value good state (if applicable)
     * @param _investProof Storage pointer to the investment proof state
     * @param _params Struct containing disinvestment parameters
     * @return normalGoodResult1_ Struct containing disinvestment results for the main good
     * @return valueGoodResult2_ Struct containing disinvestment results for the value good (if applicable)
     * @return disinvestvalue The total value being disinvested
     */
    function disinvestGood(
        S_GoodState storage _self,
        S_GoodState storage _valueGoodState,
        S_ProofState storage _investProof,
        S_GoodDisinvestParam memory _params
    )
        internal
        returns (
            S_GoodDisinvestReturn memory normalGoodResult1_,
            S_GoodDisinvestReturn memory valueGoodResult2_,
            uint256 disinvestvalue
        )
    {
        // Calculate the disinvestment value based on the investment proof and requested quantity

        disinvestvalue = toTTSwapUINT256(
            _investProof.state.amount1(),
            _investProof.invest.amount1()
        ).getamount0fromamount1(_params._goodshares);

        normalGoodResult1_ = S_GoodDisinvestReturn(
            0,
            _params._goodshares, //divest shares
            _investProof.invest.getamount1fromamount0(_params._goodshares),
            0
        );
        uint128 actualvalue = _investProof.state.getamount1fromamount0(
            disinvestvalue.amount1()
        );

        // Ensure disinvestment conditions are met
        if (
            disinvestvalue >
            _self.goodConfig.getDisinvestChips(_self.investState.amount1())
        ) {
            revert TTSwapError(26);
        }
        if (
            normalGoodResult1_.vitualDisinvestQuantity >
            _self.goodConfig.getDisinvestChips(_self.currentState.amount1())
        ) revert TTSwapError(27);
        normalGoodResult1_.actualDisinvestQuantity = _investProof
            .state
            .getamount1fromamount0(normalGoodResult1_.vitualDisinvestQuantity);
        normalGoodResult1_.actual_fee = _self.goodConfig.getDisinvestFee(
            normalGoodResult1_.vitualDisinvestQuantity
        );
        normalGoodResult1_.profit = toTTSwapUINT256(
            _self.currentState.amount0(),
            _self.investState.amount1()
        ).getamount0fromamount1(_params._goodshares);
        if (normalGoodResult1_.profit > normalGoodResult1_.actual_fee)
            revert TTSwapError(34);
        // Update main good states
        _self.currentState = sub(
            _self.currentState,
            toTTSwapUINT256(
                normalGoodResult1_.vitualDisinvestQuantity,
                normalGoodResult1_.vitualDisinvestQuantity
            )
        );

        _self.investState = sub(
            _self.investState,
            toTTSwapUINT256(_params._goodshares, disinvestvalue.amount1())
        );
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(normalGoodResult1_.actual_fee, 0)
        );
        _self.goodConfig = sub(
            _self.goodConfig,
            normalGoodResult1_.vitualDisinvestQuantity -
                normalGoodResult1_.actualDisinvestQuantity
        );

        // Calculate final profit and fee for main good
        normalGoodResult1_.profit =
            normalGoodResult1_.profit -
            normalGoodResult1_.actualDisinvestQuantity;

        // Allocate fees for main good
        allocateFee(
            _self,
            normalGoodResult1_.profit,
            _params._gater,
            _params._referral,
            normalGoodResult1_.actualDisinvestQuantity -
                normalGoodResult1_.actual_fee
        );

        // Handle value good disinvestment if applicable
        if (_investProof.valuegood != address(0)) {
            // Calculate disinvestment results for value good
            valueGoodResult2_ = S_GoodDisinvestReturn(
                0,
                toTTSwapUINT256(
                    _investProof.valueinvest.amount0(),
                    _investProof.invest.amount0()
                ).getamount0fromamount1(_params._goodshares), //divest shares
                0,
                0
            );
            valueGoodResult2_.vitualDisinvestQuantity = _investProof
                .valueinvest
                .getamount1fromamount0(valueGoodResult2_.actual_fee);

            // Ensure value good disinvestment conditions are met
            if (
                disinvestvalue >
                _valueGoodState.goodConfig.getDisinvestChips(
                    _valueGoodState.currentState.amount0()
                )
            ) revert TTSwapError(28);
            if (
                valueGoodResult2_.vitualDisinvestQuantity >
                _valueGoodState.goodConfig.getDisinvestChips(
                    _valueGoodState.currentState.amount1()
                )
            ) revert TTSwapError(29);

            valueGoodResult2_.actualDisinvestQuantity = _investProof
                .state
                .getamount1fromamount0(
                    valueGoodResult2_.vitualDisinvestQuantity
                );
            valueGoodResult2_.profit = toTTSwapUINT256(
                _valueGoodState.currentState.amount0(),
                _valueGoodState.investState.amount0()
            ).getamount0fromamount1(_params._goodshares);
            if (normalGoodResult1_.profit > normalGoodResult1_.actual_fee)
                revert TTSwapError(34);

            // Update value good states
            _valueGoodState.currentState = sub(
                _valueGoodState.currentState,
                toTTSwapUINT256(
                    valueGoodResult2_.vitualDisinvestQuantity,
                    valueGoodResult2_.vitualDisinvestQuantity
                )
            );

            _valueGoodState.investState = sub(
                _valueGoodState.investState,
                toTTSwapUINT256(
                    valueGoodResult2_.actual_fee,
                    disinvestvalue.amount1()
                )
            );
            valueGoodResult2_.actual_fee = _valueGoodState
                .goodConfig
                .getDisinvestFee(valueGoodResult2_.vitualDisinvestQuantity);
                
            _valueGoodState.currentState = add(
                _valueGoodState.currentState,
                toTTSwapUINT256(valueGoodResult2_.actual_fee, 0)
            );
            _valueGoodState.goodConfig = sub(
                _valueGoodState.goodConfig,
                valueGoodResult2_.vitualDisinvestQuantity -
                    valueGoodResult2_.actualDisinvestQuantity
            );

            valueGoodResult2_.profit =
                valueGoodResult2_.profit -
                valueGoodResult2_.actualDisinvestQuantity;

            allocateFee(
                _valueGoodState,
                valueGoodResult2_.profit,
                _params._gater,
                _params._referral,
                valueGoodResult2_.actualDisinvestQuantity -
                    valueGoodResult2_.actual_fee
            );
        }

        disinvestvalue = toTTSwapUINT256(disinvestvalue.amount1(), actualvalue);
        // Burn the investment proof
        _investProof.burnProof(disinvestvalue);
    }

    /**
     * @notice Allocate fees to various parties
     * @dev This function handles the allocation of fees to the market creator, gater, referrer, and liquidity providers
     * @param _self Storage pointer to the good state
     * @param _profit The total profit to be allocated
     * @param _gater The address of the gater (if applicable)
     * @param _referral The address of the referrer (if applicable)
     * @param _divestQuantity The quantity of goods being divested (if applicable)
     */
    function allocateFee(
        S_GoodState storage _self,
        uint128 _profit,
        address _gater,
        address _referral,
        uint128 _divestQuantity
    ) private {
        uint256 _goodconfig = _self.goodConfig;
        // Calculate platform fee and deduct it from the profit
        uint128 marketfee = _goodconfig.getPlatformFee128(_profit);
        _profit -= marketfee;

        // Calculate individual fees based on market configuration
        uint128 liquidFee = _goodconfig.getLiquidFee(_profit);
        uint128 sellerFee = _goodconfig.getOperatorFee(_profit);
        uint128 gaterFee = _goodconfig.getGateFee(_profit);
        uint128 referFee = _goodconfig.getReferFee(_profit);
        uint128 customerFee = _goodconfig.getCustomerFee(_profit);

        if (_referral == address(0)) {
            // If no referrer, distribute fees differently
            _self.commission[msg.sender] += (liquidFee + _divestQuantity);
            _self.commission[_gater] += sellerFee + customerFee;
            _self.commission[address(0)] += (_profit -
                liquidFee -
                sellerFee -
                customerFee +
                marketfee);
        } else {
            // If referrer exists, distribute fees according to roles
            if (_self.owner != address(0)) {
                _self.commission[_self.owner] += sellerFee;
            } else {
                marketfee += sellerFee;
            }

            if (_gater != address(0)) {
                _self.commission[_gater] += gaterFee;
            } else {
                marketfee += gaterFee;
            }

            if (_referral != address(0)) {
                _self.commission[_referral] += referFee;
            } else {
                marketfee += referFee;
            }
            _self.commission[address(0)] += marketfee;
            _self.commission[msg.sender] = (liquidFee +
                customerFee +
                _divestQuantity);
        }
    }

    /**
     * @notice fill good
     * @dev Preserves the top 33 bits of the existing config and updates the rest
     * @param _self Storage pointer to the good state
     * @param _fee New configuration value to be applied
     */
    function fillFee(S_GoodState storage _self, uint256 _fee) internal {
        unchecked {
            _self.currentState = _self.currentState + (_fee << 128);
        }
    }
}
