// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {L_Proof} from "./L_Proof.sol";
import {TTSwapError} from "./L_Error.sol";
import {L_GoodConfigLibrary} from "./L_GoodConfig.sol";

import {S_GoodState, S_ProofState} from "../interfaces/I_TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, toUint128, add, sub} from "./L_TTSwapUINT256.sol";

/**
 * @title L_Good Library
 * @dev A library for managing goods in a decentralized marketplace
 * @notice This library provides functions for investing, disinvesting, swapping, and fee management for goods
 */
library L_Good {
    using L_GoodConfigLibrary for uint256;
    using L_TTSwapUINT256Library for uint256;
    using L_Proof for S_ProofState;
    //(2**256-1)-(2**223-1)+(2**177-1)
    uint256 internal constant feeConfigMask =0xffffffff800000000001ffffffffffffffffffffffffffffffffffffffffffff;
//        0xffffffff800000000000000000000000ffffffffffffffffffffffffffffffff;
    //2**223-1
    uint256 internal constant commissionConfigMask =
        0x3fffffff80000000000000000000000000000000000000000000000000000000;

    uint256 internal constant coreConfigMask =
        0xc000000000000000000000000000000000000000000000000000000000000000;
    //1638416512<<223  (6*2**28+ 1*2**24+ 5*2**21+8*2**16+8*2**11+2*2**6)<<223
    uint256 internal constant initialConfig =
        0x30d4204000000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Update the good configuration only goodowner
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
        uint256 tmpconfig = _self.goodConfig;
        assembly {
            _goodConfig := and(not(feeConfigMask), _goodConfig)
            tmpconfig := add(and(tmpconfig, feeConfigMask), _goodConfig)
        }
        _self.goodConfig = tmpconfig;


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
        uint256 tmpconfig = _self.goodConfig;
        assembly {
            _goodconfig := and(commissionConfigMask, _goodconfig)
            tmpconfig := add(
                and(not(commissionConfigMask), tmpconfig),
                _goodconfig
            )
        }
        _self.goodConfig = tmpconfig;
     

    }

    function modifyGoodCoreConfig(
        S_GoodState storage _self,
        uint256 _goodconfig
    ) internal {
        uint256 tmpconfig = _self.goodConfig;
        assembly {
            _goodconfig := and(coreConfigMask, _goodconfig)
            tmpconfig := add(and(not(coreConfigMask), tmpconfig), _goodconfig)
        }
        _self.goodConfig = tmpconfig;
    }

    function lockGood(S_GoodState storage _self) internal {
         uint256 tmpconfig = _self.goodConfig;
         uint256 lockConfig = 0x4000000000000000000000000000000000000000000000000000000000000000;
        assembly {
            tmpconfig := add(and(tmpconfig, not(lockConfig)),lockConfig)
        }
        _self.goodConfig = tmpconfig;
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
        self.currentState = toTTSwapUINT256(_init.amount1(), _init.amount1());
        self.investState = toTTSwapUINT256(_init.amount1(), _init.amount0());
        assembly {
            _goodConfig := and(not(feeConfigMask), _goodConfig)
            _goodConfig := add(_goodConfig, initialConfig)
        }
        if (_goodConfig.getPower() > 1) revert TTSwapError(25);
        self.goodConfig = _goodConfig;
        self.owner = msg.sender;
    }

    /**
     * @dev Struct to cache swap-related data for AMM calculations.
     * @param remainQuantity The remaining input quantity to be swapped after fees.
     * @param outputQuantity The calculated output quantity received from the swap.
     * @param feeQuantity The calculated fee amount deducted from the input.
     * @param swapvalue The calculated effective swap price/value.
     * @param good1value The investment value/price of the input good.
     * @param good2value The investment value/price of the output good.
     * @param good1currentState The current state (liquidity/reserves) of the input good.
     * @param good1config The configuration of the input good.
     * @param good2currentState The current state (liquidity/reserves) of the output good.
     * @param good2config The configuration of the output good.
     */
    struct swapCache {
        uint128 remainQuantity;
        uint128 outputQuantity;
        uint128 feeQuantity;
        uint128 swapvalue;
        uint128 good1value;
        uint128 good2value;
        uint256 good1currentState;
        uint256 good1config;
        uint256 good2currentState;
        uint256 good2config;
    }

    /**
     * @notice Compute the swap result from good1 (input) to good2 (output).
     * @dev Implements the AMM swap logic for selling good1 for good2.
     * The formula considers price impact based on the ratio of input value to pool reserves.
     * 
     * Formula derivation:
     * Δv = (Va * Δa) / (Qa + Δa/2)
     * Δb = (Qb * Δv) / (Vb + Δv/2)
     * 
     * Where:
     * - Va: Value of input good
     * - Vb: Value of output good
     * - Qa: Current quantity of input good
     * - Qb: Current quantity of output good
     * - Δa: Input amount (after fees)
     * - Δb: Output amount
     * - Δv: Virtual swap value
     * 
     * @param _stepCache A cache structure containing swap state and configurations. Modified in place.
     */
    function swapCompute1(swapCache memory _stepCache) internal pure {
        // compute Token1 fee quantity
        _stepCache.feeQuantity = _stepCache.good1config.getSellFee(
            _stepCache.remainQuantity
        );
        // minus fee quantity
        _stepCache.remainQuantity =
            _stepCache.remainQuantity -
            _stepCache.feeQuantity;
        //  Δv=(Va*Δa)/(Qa+Δa/2)
        //  =(2*Va*Δa)/(2*Qa+Δa)
        // Calculate the virtual swap value based on the input amount and current pool reserves.
        // This value represents the "economic weight" of the input in terms of the output good's pricing model.
        uint256 a = uint256(_stepCache.good1value) *
            uint256(_stepCache.remainQuantity) *
            2;
        uint256 b = uint256(_stepCache.good1currentState.amount1()) *
            2 +
            uint256(_stepCache.remainQuantity);
        // Calculate swap value
        _stepCache.swapvalue = toUint128(a / b);
        // calclulate Token2 output quantity
        //  Δb=(Qb*Δv)/(Vb+Δv/2)
        //  =(2*Qb*Δv)/(2*Vb+Δv)
        // Calculate the output amount of Token2 using the derived virtual swap value.
        a =
            uint256(_stepCache.good2currentState.amount1()) *
            uint256(_stepCache.swapvalue) *
            2;
        b = uint256(_stepCache.good2value) * 2 + uint256(_stepCache.swapvalue);
        _stepCache.outputQuantity = toUint128(a / b);
        _stepCache.good2currentState = sub(
            _stepCache.good2currentState,
            toTTSwapUINT256(0, _stepCache.outputQuantity)
        );
    }

    /**
     * @notice Compute the swap result from good2 (input) to good1 (output).
     * @dev Implements the AMM swap logic for buying good1 with good2.
     * This is the inverse operation of swapCompute1, calculating how much good1 can be bought.
     * 
     * Formula derivation (inverse of swapCompute1):
     * Δb = (2*Qb*Va*Δa)/(2*Vb*Qa+Vb*Δa+Va*Δa)
     * Solving for Δa (outputQuantity) given Δb (remainQuantity of good2).
     * 
     * @param _stepCache A cache structure containing swap state and configurations. Modified in place.
     */
    function swapCompute2(swapCache memory _stepCache) internal pure {
        // compute Token2 fee quantity
        _stepCache.feeQuantity = _stepCache.good2config.getBuyFee(
            _stepCache.remainQuantity
        );
        // plus fee quantity
        _stepCache.remainQuantity =
            _stepCache.remainQuantity +
            _stepCache.feeQuantity;
        // according to the swapCompute1
        // Δb=(2*Qb*Va*Δa)/(2*Vb*Qa+Vb*Δa+Va*Δa)
        // Δa=(2*Δb*Vb*Qa)/(2*Qb*Va-Δb*Vb-Δb*Va)
        // Calculate the numerator for determining the input quantity (Δa).
        // Based on the target output (Δb), current reserves, and token values.
        uint256 a = uint256(_stepCache.good1currentState.amount1()) *
            uint256(_stepCache.good2value) *
            uint256(_stepCache.remainQuantity) *
            2;
        // Calculate the denominator for determining the input quantity (Δa).
        // This involves subtraction, so we must ensure the result is positive (handled by requirement checks in caller).
        uint256 b = uint256(_stepCache.good1value) *
            uint256(_stepCache.good2currentState.amount1()) *
            2 -
            uint256(_stepCache.good1value) *
            uint256(_stepCache.remainQuantity) -
            uint256(_stepCache.good2value) *
            uint256(_stepCache.remainQuantity);
        require(b > 1000, "b is 0");
        // calclulate Token1 output quantity
        // Perform the division to find the exact input amount required.
        _stepCache.outputQuantity = toUint128(a / b);

        // Δv=(Va*Δa)/(Qa+Δa/2)
        // Calculate the virtual swap value using the newly computed input amount.
        // This ensures the pricing is consistent with the forward swap direction.
        _stepCache.swapvalue = toTTSwapUINT256(
            _stepCache.good1value,
            _stepCache.good1currentState.amount1() +
                _stepCache.outputQuantity /
                2
        ).getamount0fromamount1(_stepCache.outputQuantity);

        // add input quantity to token1 pool
        _stepCache.good1currentState = add(
            _stepCache.good1currentState,
            toTTSwapUINT256(0, _stepCache.outputQuantity)
        );
        // minus output quantity from token2 pool
        _stepCache.good2currentState = sub(
            _stepCache.good2currentState,
            toTTSwapUINT256(0, _stepCache.remainQuantity)
        );
        // add fee quantity to token2 pool
        _stepCache.good2currentState = add(
            _stepCache.good2currentState,
            toTTSwapUINT256(_stepCache.feeQuantity, _stepCache.feeQuantity)
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
     * @param _invest Amount to invest actual quantity
     */
    function investGood(
        S_GoodState storage _self,
        uint128 _invest,
        S_GoodInvestReturn memory investResult_,
        uint128 enpower
    ) internal {
        // Calculate the invest virtual quantity
        // The user receives virtual shares magnified by the power/leverage factor.
        investResult_.investQuantity = _invest * enpower;
        // calculate the fee quantity
        // Calculate investment fee based on the virtual quantity.
        investResult_.investFeeQuantity = _self.goodConfig.getInvestFee(
            investResult_.investQuantity
        );
        // before inpower,minus the fee quantity
        // Deduct the fee from the *actual* invest amount, then re-apply leverage to get the final virtual quantity.
        investResult_.investQuantity =
            (_invest - investResult_.investFeeQuantity) *
            enpower;

        // Calculate the actual investment value based from investQuantity on the current state
        // Determines the monetary value (virtual USD/ETH) of the new shares relative to the pool's total value.
        investResult_.investValue = toTTSwapUINT256(
            investResult_.goodValues,
            investResult_.goodCurrentQuantity
        ).getamount0fromamount1(investResult_.investQuantity);

        // Calculate the invest share based from investQuantity on the invest state
        // Mints shares proportional to the new virtual quantity vs the total existing virtual quantity.
        investResult_.investShare = toTTSwapUINT256(
            investResult_.goodShares,
            investResult_.goodInvestQuantity
        ).getamount0fromamount1(investResult_.investQuantity);

        // add invest quantity to token1 pool
        // Update the pool's total virtual quantity.
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(
                investResult_.investQuantity,
                investResult_.investQuantity
            )
        );
        // add fee quantity to token1 pool
        // Add the fee (in actual tokens) to the pool reserves.
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(
                investResult_.investFeeQuantity,
                investResult_.investFeeQuantity
            )
        );
        // Update the invest state with the new investment
        // Add newly minted shares and the calculated value to the global investment state.
        _self.investState = add(
            _self.investState,
            toTTSwapUINT256(
                investResult_.investShare,
                investResult_.investValue
            )
        );
        // add invest true virtual quantity to good config
        // Updates a tracking counter in the config (likely for fee/limit calculations), accounting for the leverage.
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
        uint128 shares;
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
        address _sender; // The address of the sender
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
        // Determines the proportional share of the user's investment being withdrawn.
        normalGoodResult1_ = S_GoodDisinvestReturn(
            0,
            0,
            _params._goodshares, //divest shares
            toTTSwapUINT256(
                _investProof.invest.amount0(),
                _investProof.shares.amount0()
            ).getamount0fromamount1(_params._goodshares), // Virtual quantity to divest (normal good)
            toTTSwapUINT256(
                _investProof.invest.amount1(),
                _investProof.shares.amount0()
            ).getamount0fromamount1(_params._goodshares)  // Actual quantity to divest (normal good)
        );
        // Calculate the total value (in terms of the value good) corresponding to the divested portion.
        disinvestvalue = toTTSwapUINT256(
            toTTSwapUINT256(
                _investProof.state.amount0(),
                _investProof.invest.amount0()
            ).getamount0fromamount1(normalGoodResult1_.vitualDisinvestQuantity),
            toTTSwapUINT256(
                _investProof.state.amount1(),
                _investProof.invest.amount0()
            ).getamount0fromamount1(normalGoodResult1_.vitualDisinvestQuantity)
        );
        if(_params._goodshares>_investProof.shares.amount0() ){
            revert TTSwapError(41);
        }
        // Ensure disinvestment conditions are met
        // Check limits on how much value can be withdrawn at once to prevent manipulation.
        if (
            disinvestvalue.amount0() >
            _self.goodConfig.getDisinvestChips(_self.investState.amount1() )||disinvestvalue.amount0()<10000)
         {
            revert TTSwapError(26);
        }
        if (
            normalGoodResult1_.vitualDisinvestQuantity >
            _self.goodConfig.getDisinvestChips(_self.currentState.amount1())
        ) revert TTSwapError(27);

        // Calculate the fee for disinvesting.
        normalGoodResult1_.actual_fee = _self.goodConfig.getDisinvestFee(
            normalGoodResult1_.vitualDisinvestQuantity
        );
        // Calculate the current value of the user's shares based on the *current* state of the pool.
        // This includes any profits or losses accumulated since investment.
        normalGoodResult1_.profit = toTTSwapUINT256(
            _self.currentState.amount0(),
            _self.investState.amount0()
        ).getamount0fromamount1(_params._goodshares);

        if (normalGoodResult1_.profit < normalGoodResult1_.actual_fee)
            revert TTSwapError(34);
        // Update main good states
        // Remove the profit/withdrawn amount from the pool's reserves.
        _self.currentState = sub(
            _self.currentState,
            toTTSwapUINT256(
                normalGoodResult1_.profit,
                normalGoodResult1_.profit
            )
        );

        // Reduce the global investment state (shares and value) by the amount being withdrawn.
        _self.investState = sub(
            _self.investState,
            toTTSwapUINT256(normalGoodResult1_.shares, disinvestvalue.amount0())
        );
        // Add the collected fee back into the pool reserves.
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(
                normalGoodResult1_.actual_fee,
                normalGoodResult1_.actual_fee
            )
        );

        _self.goodConfig = sub(
            _self.goodConfig,
            normalGoodResult1_.vitualDisinvestQuantity -
                normalGoodResult1_.actualDisinvestQuantity
        );

        // Calculate final profit and fee for main good
        // Net profit = Gross withdrawn value - Initial invested virtual quantity.
        // (This calculation assumes profit is the excess value above the principal).
        normalGoodResult1_.profit =
            normalGoodResult1_.profit -
            normalGoodResult1_.vitualDisinvestQuantity;

        // Allocate fees for main good
        allocateFee(
            _self,
            normalGoodResult1_.profit,
            _params._gater,
            _params._referral,
            normalGoodResult1_.actualDisinvestQuantity -
                normalGoodResult1_.actual_fee,
                _params._sender
        );
        // Handle value good disinvestment if applicable
        if (_investProof.valuegood != address(0)) {
            // Calculate disinvestment results for value good
            valueGoodResult2_ = S_GoodDisinvestReturn(
                0,
                0,
                toTTSwapUINT256(
                    _investProof.shares.amount1(),
                    _investProof.shares.amount0()
                ).getamount0fromamount1(_params._goodshares), //divest shares
                toTTSwapUINT256(
                    _investProof.valueinvest.amount0(),
                    _investProof.shares.amount0()
                ).getamount0fromamount1(_params._goodshares),
                toTTSwapUINT256(
                    _investProof.valueinvest.amount1(),
                    _investProof.shares.amount0()
                ).getamount0fromamount1(_params._goodshares)
            );
            // Ensure value good disinvestment conditions are met
            if (
                disinvestvalue.amount0() >
                _valueGoodState.goodConfig.getDisinvestChips(
                    _valueGoodState.investState.amount1()
                )
            ) revert TTSwapError(28);
            if (
                valueGoodResult2_.vitualDisinvestQuantity >
                _valueGoodState.goodConfig.getDisinvestChips(
                    _valueGoodState.currentState.amount1()
                )
            ) revert TTSwapError(29);

            valueGoodResult2_.profit = toTTSwapUINT256(
                _valueGoodState.currentState.amount0(),
                _valueGoodState.investState.amount0()
            ).getamount0fromamount1(valueGoodResult2_.shares);
            valueGoodResult2_.actual_fee = _valueGoodState
                .goodConfig
                .getDisinvestFee(valueGoodResult2_.vitualDisinvestQuantity);
            if (valueGoodResult2_.profit < valueGoodResult2_.actual_fee)
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
                    valueGoodResult2_.shares,
                    disinvestvalue.amount1()
                )
            );

            _valueGoodState.currentState = add(
                _valueGoodState.currentState,
                toTTSwapUINT256(
                    valueGoodResult2_.actual_fee,
                    valueGoodResult2_.actual_fee
                )
            );
            _valueGoodState.goodConfig = sub(
                _valueGoodState.goodConfig,
                valueGoodResult2_.vitualDisinvestQuantity -
                    valueGoodResult2_.actualDisinvestQuantity
            );

            valueGoodResult2_.profit =
                valueGoodResult2_.profit -
                valueGoodResult2_.vitualDisinvestQuantity;

            allocateFee(
                _valueGoodState,
                valueGoodResult2_.profit,
                _params._gater,
                _params._referral,
                valueGoodResult2_.actualDisinvestQuantity -
                    valueGoodResult2_.actual_fee,  
                _params._sender
            );
        }

        // Burn the investment proof
        _investProof.burnProof(
            toTTSwapUINT256(
                normalGoodResult1_.shares,
                valueGoodResult2_.shares
            ),
            disinvestvalue,
            toTTSwapUINT256(
                normalGoodResult1_.vitualDisinvestQuantity,
                normalGoodResult1_.actualDisinvestQuantity
            ),
            toTTSwapUINT256(
                valueGoodResult2_.vitualDisinvestQuantity,
                valueGoodResult2_.actualDisinvestQuantity
            )
        );
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
        uint128 _divestQuantity,
        address _sender
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
            _self.commission[_sender] += (liquidFee + _divestQuantity);
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
            _self.commission[_sender] += (liquidFee +
                customerFee +
                _divestQuantity);
        }
    }
}
