// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {L_Proof} from "./L_Proof.sol";
import {TTSwapError} from "./L_Error.sol";
import {L_GoodConfigLibrary} from "./L_GoodConfig.sol";

import {S_GoodState, S_ProofState} from "../interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    toUint128,
    add,
    sub,
    addsub
} from "./L_TTSwapUINT256.sol";

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
    uint256 internal constant feeConfigMask =
        0xffffffff800000000001ffffffffffffffffffffffffffffffffffffffffffff;
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
            tmpconfig := add(and(tmpconfig, not(lockConfig)), lockConfig)
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
        if (_goodConfig.getPower() > 100) revert TTSwapError(25);
        self.goodConfig = _goodConfig;
        self.owner = msg.sender;
    }

    struct S_swapCache {
        uint128 current_quantity;
        uint128 current_value;
        uint128 invest_quantity;
        uint128 virtual_quantity;
        uint128 swap;
        uint128 swap_fee;
        uint128 K;
    }

    /*
     * @notice Swap quantity
     * @dev Swaps quantity of the good
     * @param _self Storage pointer to the good state
     * @param _swapQuantity The quantity to swap
     * @param side true: input, false: output
     * @return amount0 The fee of the swap
     * @return amount1 swapvalue The value of the swap
     */
    function good1Swap(
        S_GoodState storage _self,
        uint128 _swapParam,
        bool side // true: input, false: output
    ) internal returns (uint256) {
        uint128 swapTemp; //when side is true, swapTemp is the quantity of the swap, when side is false, swapTemp is the value of the swap
        S_swapCache memory quantityCache = S_swapCache({
            current_quantity: _self.currentState.amount1(),
            current_value: _self.investState.amount1(),
            invest_quantity: _self.currentState.amount0(),
            virtual_quantity: _self.goodConfig.amount1(),
            swap: _swapParam,
            swap_fee: 0,
            K: 0
        });
        if (side) {
            
           
            quantityCache.swap_fee = _self.goodConfig.getSellFee(_swapParam);
            quantityCache.swap = quantityCache.swap - quantityCache.swap_fee;
            // Whitepaper mapping (input side):
            // Q = current_quantity, V = current_value, R = Q - virtual_quantity, I = invest_quantity.
            // K_A is derived from R/I before and after the input, then used in the harmonic-mean formula.
            quantityCache.K = getGood1K(
                quantityCache.current_quantity,
                quantityCache.invest_quantity,
                quantityCache.virtual_quantity,
                quantityCache.swap,
                _self.goodConfig,
                side
            );

            // ΔV = (K_A * V_A * Δa) / (K_A * Q_A + Δa), scaled by 100 for fee precision.
            swapTemp = uint128(
                (uint256(quantityCache.K) *
                    uint256(quantityCache.swap) *
                    uint256(quantityCache.current_value)) /
                    (uint256(quantityCache.K) *
                        uint256(quantityCache.current_quantity) +
                        uint256(quantityCache.swap) *
                        100)
            );
            _self.currentState = add(
                _self.currentState,
                toTTSwapUINT256(quantityCache.swap_fee, _swapParam)
            );
        } else {
            // waiting for eip 7954
            // Output-side (exact-out for value): use K_B from value-shifted R_B.
            quantityCache.K = getGood2K(
                quantityCache.current_quantity,
                quantityCache.invest_quantity,
                quantityCache.virtual_quantity,
                _self.goodConfig,
                quantityCache.swap,
                _self.investState.amount1(),
                side
            );

            // Δb = (K_B * Q_B * ΔV) / (K_B * V_B - ΔV), scaled by 100 for fee precision.
            swapTemp = uint128(
                (uint256(quantityCache.K) *
                    uint256(quantityCache.swap) *
                    uint256(quantityCache.current_quantity)) /
                    (uint256(quantityCache.K) *
                        uint256(quantityCache.current_value) -
                        uint256(quantityCache.swap) *
                        100)
            );
            quantityCache.swap_fee = _self.goodConfig.getSellFee(swapTemp);
            _self.currentState = add(
                _self.currentState,
                toTTSwapUINT256(
                    quantityCache.swap_fee,
                    quantityCache.swap_fee + swapTemp
                )
            );
        }

        return toTTSwapUINT256(quantityCache.swap_fee, swapTemp);
    }

    /*
     * @notice Swap value
     * @dev Swaps value of the good
     * @param _self Storage pointer to the good state
     * @param _swapValue The value to swap
     * @param side true: input, false: output
     * @return amount0 The fee of the swap
     * @return amount1 swapquantity The quantity of the swap
     */
    function good2Swap(
        S_GoodState storage _self,
        uint128 _swapParam,
        bool side // true: input, false: output
    ) internal returns (uint256) {
        uint128 swapTemp;
        S_swapCache memory quantityCache = S_swapCache({
            current_quantity: _self.currentState.amount1(),
            current_value: _self.investState.amount1(),
            invest_quantity: _self.currentState.amount0(),
            virtual_quantity: _self.goodConfig.amount1(),
            swap: _swapParam,
            swap_fee: 0,
            K: 0
        });

        if (side) {
            // Input-side (exact-in for value): K_B uses value-shifted R_B to update depth.
            quantityCache.K = getGood2K(
                quantityCache.current_quantity,
                quantityCache.invest_quantity,
                quantityCache.virtual_quantity,
                _self.goodConfig,
                quantityCache.swap,
                _self.investState.amount1(),
                side
            );

            // Δb = (K_B * Q_B * ΔV) / (K_B * V_B + ΔV), scaled by 100 for fee precision.
            swapTemp = uint128(
                (uint256(quantityCache.K) *
                    uint256(quantityCache.swap) *
                    uint256(quantityCache.current_quantity)) /
                    (uint256(quantityCache.K) *
                        uint256(quantityCache.current_value) +
                        uint256(quantityCache.swap) *
                        100)
            );

            quantityCache.swap_fee = _self.goodConfig.getBuyFee(swapTemp);
            swapTemp = swapTemp - quantityCache.swap_fee;

            _self.currentState = addsub(
                _self.currentState,
                toTTSwapUINT256(quantityCache.swap_fee, swapTemp)
            );
        } else {
            quantityCache.swap_fee = _self.goodConfig.getBuyFee(
                quantityCache.swap
            );
            quantityCache.swap = quantityCache.swap + quantityCache.swap_fee;
            // Quantity-view exact-out: solve for ΔV using K_A derived from quantity shift.
            quantityCache.K = getGood1K(
                quantityCache.current_quantity,
                quantityCache.invest_quantity,
                quantityCache.virtual_quantity,
                quantityCache.swap,
                _self.goodConfig,
                side
            );
            // ΔV = (K_A * V_A * Δa) / (K_A * Q_A - Δa), scaled by 100 for fee precision.
            swapTemp = uint128(
                (uint256(quantityCache.K) *
                    uint256(quantityCache.swap) *
                    uint256(quantityCache.current_value)) /
                    (uint256(quantityCache.K) *
                        uint256(quantityCache.current_quantity) -
                        uint256(quantityCache.swap) *
                        100)
            );
            if (quantityCache.swap_fee > 0)
                _self.currentState = add(
                    _self.currentState,
                    toTTSwapUINT256(
                        quantityCache.swap_fee,
                        quantityCache.swap_fee
                    )
                );
            _self.currentState = sub(
                _self.currentState,
                toTTSwapUINT256(0, quantityCache.swap)
            );
        }

        return toTTSwapUINT256(quantityCache.swap_fee, swapTemp);
    }


    function getGoodState(
        S_GoodState storage _self
    ) internal view returns (uint256 currentstate) {
        return
            toTTSwapUINT256(
                _self.investState.amount1(),
                _self.currentState.amount1()
            );
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

        // calculate the fee quantity
        // Calculate investment fee based on the virtual quantity.
        investResult_.investFeeQuantity = _self.goodConfig.getInvestFee(
            _invest
        );
        _invest = _invest - investResult_.investFeeQuantity;
        // Virtual quantity = actual input * leverage (enpower in basis points).
        investResult_.investQuantity = (_invest * enpower) / 100;

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
        ).getamount0fromamount1(_invest);

        // add invest quantity to token1 pool
        // Update the pool's total virtual quantity.
        _self.currentState = add(
            _self.currentState,
            toTTSwapUINT256(
                _invest + investResult_.investFeeQuantity,
                investResult_.investQuantity + investResult_.investFeeQuantity
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
            toTTSwapUINT256(0, investResult_.investQuantity - _invest)
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
            ).getamount0fromamount1(_params._goodshares) // Actual quantity to divest (normal good)
        );
        // Calculate the total value (in terms of the value good) corresponding to the divested portion.
        // Uses proof-time value ratios to preserve value accounting across virtual/actual quantities.
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
        if (_params._goodshares > _investProof.shares.amount0()) {
            revert TTSwapError(41);
        }
        // Ensure disinvestment conditions are met
        // Check limits on how much value can be withdrawn at once to prevent manipulation.
        if (
            disinvestvalue.amount0() >
            _self.goodConfig.getDisinvestChips(_self.investState.amount1()) ||
            disinvestvalue.amount0() < 10000
        ) {
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
            normalGoodResult1_.actualDisinvestQuantity;

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
                .getDisinvestFee(valueGoodResult2_.actualDisinvestQuantity);
            if (valueGoodResult2_.profit < valueGoodResult2_.actual_fee)
                revert TTSwapError(34);

            // Update value good states
            _valueGoodState.currentState = sub(
                _valueGoodState.currentState,
                toTTSwapUINT256(
                    valueGoodResult2_.actualDisinvestQuantity,
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
            // No referrer path:
            // - sender receives LP share + divested principal
            // - gate receives operator + customer portions (if gate exists)
            // - remaining + platform fee accrues to protocol (address(0))
            // If no referrer, distribute fees differently
            _self.commission[_sender] += (liquidFee + _divestQuantity);
            _self.commission[_gater] += sellerFee + customerFee;
            _self.commission[address(0)] += (_profit -
                liquidFee -
                sellerFee -
                customerFee +
                marketfee);
        } else {
            // Referrer path:
            // - operator fee goes to owner (or protocol if owner is zero)
            // - gate fee goes to gate (or protocol if gate is zero)
            // - referral fee always to referrer
            // - sender receives LP share + customer fee + divested principal
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

            _self.commission[_referral] += referFee;

            _self.commission[address(0)] += marketfee;
            _self.commission[_sender] += (liquidFee +
                customerFee +
                _divestQuantity);
        }
    }

    function getInvestPower(
        S_GoodState storage _self
    ) internal view returns (uint128 limitpower_) {
        uint128 maxpower = _self.goodConfig.getPower();
        uint128 virtual_quantity = _self.goodConfig.amount1();
        uint128 current_quantity = _self.currentState.amount1() -
            virtual_quantity;
        uint128 invest_quantity = _self.currentState.amount0();
        if (current_quantity < invest_quantity) {
            limitpower_ = ((current_quantity * maxpower) / invest_quantity);
            limitpower_ = limitpower_ < 100 ? 100 : limitpower_;
        } else {
            limitpower_ = ((invest_quantity * maxpower) / current_quantity);
            limitpower_ = limitpower_ < 100 ? 100 : limitpower_;
        }
    }

    function getGood1K(
        uint128 current_quantity,
        uint128 invest_quantity,
        uint128 virtual_quantity,
        uint128 swap_quantity,
        uint256 good1config,
        bool side
    ) internal  pure returns (uint128 K) {
        uint128 maxpower = good1config.getPower();
        maxpower += 100;
        // R = Q - P (actual quantity), with P as virtual liquidity.
        current_quantity = current_quantity - virtual_quantity;
        // k1: depth factor at the start point based on R/I deviation.
        uint128 k1 = current_quantity <= invest_quantity
            ? ((current_quantity * maxpower) / invest_quantity)
            : ((invest_quantity * maxpower) / current_quantity);
        if (side) {
            current_quantity = current_quantity + swap_quantity;
        } else {
            current_quantity = current_quantity - swap_quantity;
        }
       
        // k2: depth factor at the end point after applying swap quantity.
        uint128 k2 = current_quantity < invest_quantity
            ? ((current_quantity * maxpower) / invest_quantity)
            : ((invest_quantity * maxpower) / current_quantity);
        
        // K = harmonic mean of k1 and k2 (whitepaper K_A).
        K = (k1 + k2) == 0 ? 1 : (k1 * k2 * 2) / (k1 + k2);
        K = K == 0 ? 1 : K;
    }

    function getGood2K(
        uint128 current_quantity,
        uint128 invest_quantity,
        uint128 virtual_quantity,
        uint256 good2config,
        uint128 swap_value,
        uint128 good2value,
        bool side
    ) internal pure returns (uint128 K) {
        uint128 maxpower = good2config.getPower();
        maxpower += 100;
        // R = Q - P (actual quantity), with P as virtual liquidity.
        current_quantity = current_quantity - virtual_quantity;
        uint128 k1 = current_quantity <= invest_quantity
            ? ((current_quantity * maxpower) / invest_quantity)
            : ((invest_quantity * maxpower) / current_quantity);
        
        uint128 real_quantity;
        if (side) {
            // Value decreases by swap_value on input, compute value-adjusted R' (tilde R).
            real_quantity = uint128(
                (uint256(current_quantity + virtual_quantity) *
                    uint256(good2value - swap_value)) / uint256(good2value)
            );
        } else {
            // Value increases by swap_value on output, compute value-adjusted R' (tilde R).
            real_quantity = uint128(
                (uint256(current_quantity + virtual_quantity) *
                    uint256(good2value + swap_value)) / uint256(good2value)
            );
        }
        real_quantity = real_quantity - virtual_quantity;

        // k2: depth factor at the value-shifted end point.
        uint128 k2 = real_quantity <= invest_quantity
            ? ((real_quantity * maxpower) / invest_quantity)
            : ((invest_quantity * maxpower) / real_quantity);
        // K = harmonic mean of k1 and k2 (whitepaper K_B).
        K = (k1 + k2) == 0 ? 1 : (k1 * k2 * 2) / (k1 + k2);
        K = K == 0 ? 1 : K;
    }
}
