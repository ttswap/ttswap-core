// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {L_Proof} from "./L_Proof.sol";
import {TTSwapError} from "./L_Error.sol";
import {L_GoodConfigLibrary} from "./L_GoodConfig.sol";
import {T_GoodKey} from "../type/T_GoodKey.sol";
import {S_GoodState, S_ProofState} from "../interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    toUint128,
    add,
    sub,
    addsub,
    MAX_GOOD_STATE_LEG
} from "./L_TTSwapUINT256.sol";
uint128 constant MIN_INVEST_VALUE = 1_000_000_000_000;
/**
 * @title L_Good Library
 * @author ttswap.exchange@gmail.com
 * @notice Core AMM + LP accounting for a single "good" (one token pool).
 * @dev Each good stores:
 *      - `currentState.amount0` (`investQty`): actual token units deposited / principal.
 *      - `currentState.amount1` (`Q`): total virtual pool depth (actual + leverage virtual).
 *      - `goodConfig.amount1()` (`virtualQty`): leverage-only virtual excess (not including actual).
 *      - `investState`: (totalShares, `V` market value) — LP shares and pricing anchor.
 *      - `goodConfig` high bits: packed fees, safe lines, flags (see `L_GoodConfig`).
 *
 * @dev **Example (3× invest, 1 token, ignore fees)**
 *      After invest: `investQty=1`, `virtualQty=2`, `Q=3` because `Q = investQty + virtualQty`.
 *
 * @dev **Pricing model**
 *      Pool price ≈ `investState.amount1 / currentState.amount1` (`V / Q`).
 *      Swaps move value between two goods by:
 *      1. Input good: user sells tokens → pool virtual qty rises → value exported (`buyGoodInput` / `payGoodInput`)
 *      2. Output good: value imported → virtual qty falls → tokens sent to user (`buyGoodOutput` / `payGoodOutput`)
 *
 *      Large trades are chunked in 1% steps of pool depth to approximate a bonding curve and stay within safe-line bounds.
 */
library L_Good {
    using L_GoodConfigLibrary for uint256;
    using L_TTSwapUINT256Library for uint256;
    using L_Proof for S_ProofState;

    function toGoodKey(
        S_GoodState storage _self
    ) internal view returns (T_GoodKey memory) {
        return
            T_GoodKey({
                ercType: _self.erctype,
                contractAddress: _self.contractAddress,
                id: _self.id
            });
    }

    /**
     * @notice Update the good configuration only goodowner
     * @dev enpower,disinvest chips,invest fee,disinvest fee,buy fee,sell fee
     * @param _self Storage pointer to the good state
     * @param _goodConfig New configuration value to be applied
     */
    function updateConfigbyGoodOwner(
        S_GoodState storage _self,
        uint256 _goodConfig
    ) internal {
        if (_self.goodConfig.getLimitPower() < _goodConfig.getPower())
            revert TTSwapError(23);
        _self.goodConfig = _self.goodConfig.updateGoodOwnerConfig(_goodConfig);
    }

    /**
     * @notice Modify the good configuration
     * @dev This function modifies the good configuration by preserving the top 33 bits and updating the rest
     * @param _self Storage pointer to the good state
     * @param _goodconfig The new configuration value to be applied
     */
    function updateConfigbyManager(
        S_GoodState storage _self,
        uint256 _goodconfig
    ) internal {
        if (!_goodconfig.checkGoodConfig()) revert TTSwapError(24);
        _self.goodConfig = _self.goodConfig.updateManagerConfig(_goodconfig);
    }

    /**
     * @notice Modify the good configuration
     * @dev This function modifies the good configuration by preserving the top 33 bits and updating the rest
     * @param _self Storage pointer to the good state
     * @param _goodconfig The new configuration value to be applied
     */
    function updateConfigbyAdmin(
        S_GoodState storage _self,
        uint256 _goodconfig
    ) internal {
        _self.goodConfig = _self.goodConfig.updateAdminConfig(_goodconfig);
    }

    /// @notice Locks a good by setting `isFreeze` (bit 246).
    /// @param _self Storage pointer to the good state.
    function lockGood(S_GoodState storage _self) internal {
        _self.goodConfig = _self.goodConfig.setFreeze(true);
    }
    /// @notice First-time pool setup after tokens are received.
    /// @dev No leverage at init: `investQty = Q = deposit`, `goodConfig.amount1()` (`virtualQty`) stays 0.
    ///      `investState` seeds shares and declared value from `_initial`.
    function init(
        S_GoodState storage self,
        uint256 _init,
        T_GoodKey memory _goodKey
    ) internal {
        self.currentState = toTTSwapUINT256(_init.amount1(), _init.amount1());
        self.investState = toTTSwapUINT256(_init.amount1(), _init.amount0());
        self.goodConfig = L_GoodConfigLibrary.setInitialConfig();
        self.erctype = _goodKey.ercType;
        self.contractAddress = _goodKey.contractAddress;
        if (_goodKey.id != 0) {
            self.id = _goodKey.id;
        }
        self.owner = msg.sender;
    }

    /// @dev Scratch space for iterative swap simulation (memory-only, not persisted).
    /// @param swap_fee Fee charged on this leg of the swap (sell or buy fee depending on direction).
    /// @param remain Value or quantity still to process in the chunking loop.
    /// @param get Accumulated output (value on input leg, quantity on output leg).
    /// @param current_quantity Pool virtual quantity at the current simulation step.
    /// @param current_value Pool total value (V) at the current simulation step.
    struct S_SwapTemp {
        uint128 swap_fee;
        uint128 remain;
        uint128 get;
        uint128 current_quantity;
        uint128 current_value;
    }

    /// @notice Input leg of `buyGood`: user sells tokens **into** this pool (exact-input swap, side A).
    /// @dev Pool notation for swap loops:
    ///      `Q` = `currentState.amount1` (total virtual depth),
    ///      `V` = `investState.amount1` (pool value). Price ≈ V/Q.
    ///      Safe-line baseline uses `currentState.amount0 + goodConfig.amount1()` (= actual + leverage virtual).
    ///      Called by `TTSwap_Market.buyGood` **before** the output good runs `buyGoodOutput`.
    /// @param _swapParam Gross token quantity the user sends (sell fee is deducted inside).
    /// @return `(amount0, amount1)` = `(sellFee, exportedValue)` passed to the output good.
    function buyGoodInput(
        S_GoodState storage _self,
        uint128 _swapParam
    ) internal returns (uint256) {
        uint256 cfg = _self.goodConfig;
        (uint128 investQty, uint128 q0) = _self.currentState.amount01();
        // --- Phase 1: snapshot pool & charge sell fee on the user's deposit ---
        S_SwapTemp memory swapTemp = S_SwapTemp({
            swap_fee: cfg.getSellFee(_swapParam),
            remain: _swapParam,
            get: 0,
            current_quantity: q0,
            current_value: _self.investState.amount1()
        });
        // `remain` = net tokens that actually enter the curve (after sell fee stays in pool later).
        swapTemp.remain = swapTemp.remain - swapTemp.swap_fee;
        uint128 value;
        if (swapTemp.current_quantity < 10000) revert TTSwapError(56);

        // --- Phase 2: walk the bonding curve in ≤1% depth chunks ---
        // Formula (deposit / sell-in):  ΔV = 2·V·Δq / (2·Q + Δq)
        // Unchecked mul/div: uint128 legs; protocol caps near 2**109 so 2·a·b fits uint256.
        while (swapTemp.remain > 0) {
            if (swapTemp.remain >= swapTemp.current_quantity / 100) {
                _swapParam = swapTemp.current_quantity / 100;
                swapTemp.remain -= _swapParam;
            } else {
                _swapParam = swapTemp.remain;
                swapTemp.remain = 0;
            }
            unchecked {
                value = uint128(
                    (2 *
                        uint256(_swapParam) *
                        uint256(swapTemp.current_value)) /
                        (2 *
                            uint256(swapTemp.current_quantity) +
                            uint256(_swapParam))
                );
            }
            swapTemp.get += value;
            swapTemp.current_quantity += _swapParam;
        }

        // --- Phase 3: safe-line upper — baseline = investQty + virtualQty (actual + leverage virtual) ---
        if (
            swapTemp.current_quantity >
            cfg.getSafeLineUpper(investQty + cfg.amount1())
        ) {
            revert TTSwapError(55);
        }

        // --- Phase 4: persist state — raise virtual Q, credit sell fee to both amount0/amount1 legs ---
        _self.currentState = toTTSwapUINT256(
            investQty + swapTemp.swap_fee,
            swapTemp.current_quantity + swapTemp.swap_fee
        );

        return toTTSwapUINT256(swapTemp.swap_fee, swapTemp.get);
    }

    /// @notice Output leg of `buyGood`: convert imported value into tokens **out** of this pool (side B).
    /// @dev Receives `exportedValue` from `buyGoodInput` on the paired good.
    ///      Walks the curve in value chunks, then charges buy fee on the total token outflow.
    /// @param _swapParam Value imported from the input good (already net of input sell fee economics).
    /// @return `(amount0, amount1)` = `(buyFee, netOutputQuantity)` sent to the user.
    function buyGoodOutput(
        S_GoodState storage _self,
        uint128 _swapParam
    ) internal returns (uint256) {
        uint256 cfg = _self.goodConfig;
        (uint128 investQty, uint128 qBefore) = _self.currentState.amount01();
        S_SwapTemp memory swapTemp = S_SwapTemp({
            swap_fee: 0,
            remain: _swapParam,
            get: 0,
            current_quantity: qBefore,
            current_value: _self.investState.amount1()
        });
        uint128 quantity;

        // --- Phase 2: consume value in ≤1% of V chunks, withdraw tokens ---
        // Formula (withdraw / buy-out):  Δq = 2·Q·ΔV / (2·V + ΔV)
        while (swapTemp.remain > 0) {
            if (swapTemp.current_quantity < 10000) revert TTSwapError(56);
            if (swapTemp.remain >= swapTemp.current_value / 100) {
                _swapParam = swapTemp.current_value / 100;
                swapTemp.remain -= _swapParam;
            } else {
                _swapParam = swapTemp.remain;
                swapTemp.remain = 0;
            }
            unchecked {
                quantity = uint128(
                    (2 *
                        uint256(_swapParam) *
                        uint256(swapTemp.current_quantity)) /
                        (2 *
                            uint256(swapTemp.current_value) +
                            uint256(_swapParam))
                );
            }
            swapTemp.get += quantity;
            swapTemp.current_quantity -= quantity;
        }

        // --- Phase 3: safe-line lower guard (pool must retain minimum depth) ---
        if (
            swapTemp.current_quantity <
            cfg.getSafeLineLower128(investQty + cfg.amount1())
        ) {
            revert TTSwapError(56);
        }

        // --- Phase 4: buy fee on total outflow, then persist reduced Q + fee credit ---
        quantity = qBefore - swapTemp.current_quantity; // gross tokens leaving
        swapTemp.swap_fee = cfg.getBuyFee(quantity);
        quantity = quantity - swapTemp.swap_fee; // net to user
        _self.currentState = toTTSwapUINT256(
            investQty + swapTemp.swap_fee,
            swapTemp.current_quantity + swapTemp.swap_fee
        );

        return toTTSwapUINT256(swapTemp.swap_fee, quantity);
    }

    /// @notice Output leg of `payGood`: user wants exactly `_swapParam` **net** output tokens (exact-output, side B first).
    /// @dev Called **before** `payGoodInput` in `TTSwap_Market.payGood` (reverse order vs `buyGood`).
    ///      Gross pool withdrawal = desired output + buy fee. Returns how much **value** the input good must supply.
    /// @param _swapParam Target token quantity the recipient must receive (before relayer fee in market layer).
    /// @return `(amount0, amount1)` = `(buyFee, valueRequired)` for the input good's `payGoodInput`.
    function payGoodOutput(
        S_GoodState storage _self,
        uint128 _swapParam
    ) internal returns (uint256) {
        uint256 cfg = _self.goodConfig;
        (uint128 investQty, uint128 q0) = _self.currentState.amount01();
        // --- Phase 1: gross-up desired output by buy fee ---
        S_SwapTemp memory swapTemp = S_SwapTemp({
            swap_fee: cfg.getBuyFee(_swapParam),
            remain: _swapParam,
            get: 0,
            current_quantity: q0,
            current_value: _self.investState.amount1()
        });
        swapTemp.remain = swapTemp.remain + swapTemp.swap_fee;
        uint128 value;

        // --- Phase 2: remove tokens in ≤1% Q chunks ---
        // Formula (exact-out withdraw):  ΔV = 2·V·Δq / (2·Q − Δq)
        while (swapTemp.remain > 0) {
            if (swapTemp.current_quantity < 10000) revert TTSwapError(56);
            if (swapTemp.remain >= swapTemp.current_quantity / 100) {
                _swapParam = swapTemp.current_quantity / 100;
                swapTemp.remain -= _swapParam;
            } else {
                _swapParam = swapTemp.remain;
                swapTemp.remain = 0;
            }
            unchecked {
                value = uint128(
                    (2 *
                        uint256(_swapParam) *
                        uint256(swapTemp.current_value)) /
                        (2 *
                            uint256(swapTemp.current_quantity) -
                            uint256(_swapParam))
                );
            }
            value += 1;
            swapTemp.get += value;
            swapTemp.current_quantity -= _swapParam;
        }

        // --- Phase 3: safe-line lower guard ---
        if (
            swapTemp.current_quantity <
            cfg.getSafeLineLower128(investQty + cfg.amount1())
        ) {
            revert TTSwapError(56);
        }

        // --- Phase 4: persist shallower pool; buy fee credited to state; return value budget for input leg ---
        _self.currentState = toTTSwapUINT256(
            investQty + swapTemp.swap_fee,
            swapTemp.current_quantity + swapTemp.swap_fee
        );

        return toTTSwapUINT256(swapTemp.swap_fee, swapTemp.get);
    }

    /// @notice Input leg of `payGood`: absorb `valueRequired` from `payGoodOutput` and compute pay-token input (side A).
    /// @dev Mirror of `buyGoodInput` direction but driven by a **value budget** instead of a token budget.
    ///      Market checks `sellFee + netInput <= maxInput` (slippage on payer side).
    /// @param _swapParam Value to import (from `payGoodOutput.get` on the output good).
    /// @return `(amount0, amount1)` = `(sellFee, grossInputQuantity)` user must transfer in.
    function payGoodInput(
        S_GoodState storage _self,
        uint128 _swapParam
    ) internal returns (uint256) {
        uint256 cfg = _self.goodConfig;
        (uint128 investQty, uint128 qBefore) = _self.currentState.amount01();
        S_SwapTemp memory swapTemp = S_SwapTemp({
            swap_fee: 0,
            remain: _swapParam,
            get: 0,
            current_quantity: qBefore,
            current_value: _self.investState.amount1()
        });
        uint128 quantity;
        if (swapTemp.current_value < 10000) revert TTSwapError(56);

        // --- Phase 2: import value in ≤1% of V chunks ---
        // Formula (value-driven deposit):  Δq = 2·Q·ΔV / (2·V − ΔV)
        while (swapTemp.remain > 0) {
            if (swapTemp.remain >= swapTemp.current_value / 100) {
                _swapParam = swapTemp.current_value / 100;
                swapTemp.remain -= _swapParam;
            } else {
                _swapParam = swapTemp.remain;
                swapTemp.remain = 0;
            }
            unchecked {
                quantity = uint128(
                    (2 *
                        uint256(_swapParam) *
                        uint256(swapTemp.current_quantity)) /
                        (2 *
                            uint256(swapTemp.current_value) -
                            uint256(_swapParam))
                );
            }
            quantity += 1;
            swapTemp.get += quantity;
            swapTemp.current_quantity += quantity;
        }

        // --- Phase 3: safe-line upper guard ---
        if (
            swapTemp.current_quantity >
            cfg.getSafeLineUpper(investQty + cfg.amount1())
        ) {
            revert TTSwapError(55);
        }

        // --- Phase 4: sell fee on net tokens added; persist deeper pool ---
        quantity = swapTemp.current_quantity - qBefore; // net deposit into pool
        swapTemp.swap_fee = cfg.getSellFee(quantity);
        _self.currentState = toTTSwapUINT256(
            investQty + swapTemp.swap_fee,
            swapTemp.current_quantity + swapTemp.swap_fee
        );

        // `quantity` return is gross input (net + sell fee) — market adds amount0+amount1 for max-input check.
        return toTTSwapUINT256(swapTemp.swap_fee, quantity);
    }

    /// @notice Packs live pool price as `(V, Q)` = `(investState.amount1, currentState.amount1)`.
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
     * @notice Return struct for `investGood` — intermediate values before proof update.
     * @param investFeeQuantity Tokens retained as invest fee (stay in pool).
     * @param investShare New LP shares minted to the investor.
     * @param investValue Virtual value credited at pool price (before leverage normalization).
     * @param investQuantity Virtual quantity added (actual deposit × leverage / 100).
     * @param goodShares Cached total shares before update.
     * @param goodValues Cached total value before update.
     * @param goodInvestQuantity Cached `investQty` (`currentState.amount0`).
     * @param goodCurrentQuantity Cached total depth `Q` (`currentState.amount1`).
     */
    struct S_GoodInvestReturn {
        uint128 investFeeQuantity; // The actual fee amount charged for the investment
        uint128 investShare; // The construction fee amount (if applicable)
        uint128 investValue; // The actual value invested after fees
        uint128 investQuantity; // Virtual total credited to Q (actual × leverage%; e.g. 1 @ 3× → 3)
        uint128 goodShares;
        uint128 goodValues;
        uint128 goodInvestQuantity;
        uint128 goodCurrentQuantity;
    }
    /// @notice Mint LP shares and deepen the pool when a user deposits `_invest` tokens.
    /// @dev Steps:
    ///      1. Charge invest fee → reduce actual deposit.
    ///      2. Scale deposit by `enpower` (leverage) to virtual quantity.
    ///      3. Price virtual quantity at current pool ratio → `investValue`.
    ///      4. Mint shares proportional to virtual deposit vs existing shares.
    ///      5. Update `currentState`, `investState`, and config virtual-quantity tracker.
    /// @param enpower Leverage factor in percent (100 = 1x, 200 = 2x virtual liquidity).
    function investGood(
        S_GoodState storage _self,
        uint128 _invest,
        S_GoodInvestReturn memory investResult_,
        uint128 enpower
    ) internal {
        uint128 _investValue;

        // Calculate the invest virtual quantity
        // The user receives virtual shares magnified by the power/leverage factor.

        // calculate the fee quantity
        // Calculate investment fee based on the virtual quantity.
        investResult_.investFeeQuantity = _self.goodConfig.getInvestFee(
            _invest
        );
        _invest = _invest - investResult_.investFeeQuantity;
        // Virtual total credited to Q = actual * leverage% (e.g. 1 @ 300% → investQuantity = 3).
        investResult_.investQuantity = (_invest * enpower) / 100;
        _investValue = toTTSwapUINT256(
            investResult_.goodValues,
            investResult_.goodCurrentQuantity
        ).getamount0fromamount1(investResult_.investQuantity);
        // Calculate the actual investment value based from investQuantity on the current state
        // Determines the monetary value (virtual USD/ETH) of the new shares relative to the pool's total value.

        investResult_.investValue = _self.goodConfig.getInvestThreshold(
            _investValue
        );

        // Calculate the invest share based from investQuantity on the invest state
        // Mints shares proportional to the new virtual quantity vs the total existing virtual quantity.
        investResult_.investShare = toTTSwapUINT256(
            investResult_.goodShares,
            investResult_.goodInvestQuantity
        ).getamount0fromamount1(_invest);

        // Q / investQty legs after this deposit (fee credited to both legs).
        uint256 addInvestQty = uint256(_invest) +
            uint256(investResult_.investFeeQuantity);
        uint256 addQ = uint256(investResult_.investQuantity) +
            uint256(investResult_.investFeeQuantity);
        if (
            uint256(investResult_.goodInvestQuantity) + addInvestQty >
            MAX_GOOD_STATE_LEG ||
            uint256(investResult_.goodCurrentQuantity) + addQ >
            MAX_GOOD_STATE_LEG
        ) revert TTSwapError(18);
        if (investResult_.investShare == 0) revert TTSwapError(56);
        if (investResult_.investValue < MIN_INVEST_VALUE) revert TTSwapError(38);

        // currentState: investQty += actual (+fee on amount0 leg); Q += virtual total (+fee on amount1 leg).
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
        // goodConfig.amount1 (virtualQty) += leverage excess only: investQuantity - netActual.
        // Example: invest 1 @ 3× → virtualQty += 2; together with investQty=1 gives Q=3.
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
        uint128 virtualDisinvestQuantity; // Virtual qty divested from Q (includes leverage leg)
        uint128 actualDisinvestQuantity;
        uint128 disinvestTTSValue;
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
     * @param _investProof Storage pointer to the investment proof state
     * @param _params Struct containing disinvestment parameters
     * @return normalGoodResult1_ Struct containing disinvestment results for the main good
     * @return disinvestvalue The total value being disinvested
     */
    function disinvestGood(
        S_GoodState storage _self,
        S_ProofState storage _investProof,
        S_GoodDisinvestParam memory _params
    )
        internal
        returns (
            S_GoodDisinvestReturn memory normalGoodResult1_,
            uint256 disinvestvalue
        )
    {
        // Cache proof fields to avoid repeated SLOADs on the same storage slots
        uint128 proofShares0 = _investProof.shares.amount0();
        uint128 proofMintTTSValue = _investProof.shares.amount1();
        //amount0 :normal good virtual quantity of proof, amount1 :normal good actual quantity of proof
        uint128 proofInvest0 = _investProof.invest.amount0();
        uint128 proofInvest1 = _investProof.invest.amount1();
        //amount0 :total value of proof,amount1 :total actual value of proof
        uint128 proofState0 = _investProof.state.amount0();
        uint128 proofState1 = _investProof.state.amount1();

        if (_params._goodshares > proofShares0) {
            revert TTSwapError(41);
        }
        // Calculate the disinvestment value based on the investment proof and requested quantity
        // Determines the proportional share of the user's investment being withdrawn.
        normalGoodResult1_ = S_GoodDisinvestReturn(
            0,
            0,
            _params._goodshares, //divest shares
            toTTSwapUINT256(proofInvest0, proofShares0).getamount0fromamount1(
                _params._goodshares
            ), // Virtual quantity to divest (normal good)
            toTTSwapUINT256(proofInvest1, proofShares0).getamount0fromamount1(
                _params._goodshares
            ), // Actual quantity to divest (normal good)
            toTTSwapUINT256(proofMintTTSValue, proofShares0)
                .getamount0fromamount1(_params._goodshares) // Mint TTS value to divest (normal good)
        );
        // calculate the value from the proof (in terms of the value good) corresponding to the divested portion.
        // Uses proof-time value ratios to preserve value accounting across virtual/actual quantities.
        // amount0 :total value of proof in terms of the normal good,amount1 :total actual value of proof in terms of the normal good
        disinvestvalue = toTTSwapUINT256(
            toTTSwapUINT256(proofState0, proofShares0).getamount0fromamount1(
                _params._goodshares
            ),
            toTTSwapUINT256(proofState1, proofShares0).getamount0fromamount1(
                _params._goodshares
            )
        );

        // ensure the divested value and quantity are within valid ranges.
        // Check limits on how much value can be withdrawn at once to prevent manipulation.
        if (disinvestvalue.amount0() >
            _self.goodConfig.getDisinvestChips(_self.investState.amount1())) {
            revert TTSwapError(26);
        }
        if (disinvestvalue.amount1() < 1_000_000_000_000) {
            normalGoodResult1_ = S_GoodDisinvestReturn(
                0,
                0,
                _params._goodshares, //divest shares
                proofInvest0, // Virtual quantity to divest (normal good)
                proofInvest1, // Actual quantity to divest (normal good)
                proofMintTTSValue // Mint TTS value to divest (normal good)
            );
            disinvestvalue = toTTSwapUINT256(proofState0, proofState1);
        }
        if (
            normalGoodResult1_.virtualDisinvestQuantity >
            _self.goodConfig.getDisinvestChips(_self.currentState.amount1())
        ) revert TTSwapError(27);

        // Calculate the fee for disinvesting.
        normalGoodResult1_.actual_fee = _self.goodConfig.getDisinvestFee(
            normalGoodResult1_.virtualDisinvestQuantity
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
        _self.currentState = sub(
            _self.currentState,
            toTTSwapUINT256(
                normalGoodResult1_.profit,
                normalGoodResult1_.virtualDisinvestQuantity +
                    normalGoodResult1_.profit -
                    normalGoodResult1_.actualDisinvestQuantity
            )
        );

        // Reduce the global investment state (shares and value) by the amount being withdrawn.
        _self.investState = sub(
            _self.investState,
            toTTSwapUINT256(normalGoodResult1_.shares, disinvestvalue.amount0())
        );
        // Add the collected fee back into the pool reserves.
        if (normalGoodResult1_.actual_fee > 0) {
            _self.currentState = add(
                _self.currentState,
                toTTSwapUINT256(
                    normalGoodResult1_.actual_fee,
                    normalGoodResult1_.actual_fee
                )
            );
        }

        _self.goodConfig = sub(
            _self.goodConfig,
            // Remove leverage virtual excess: virtualDisinvestQty - actualDisinvestQty.
            normalGoodResult1_.virtualDisinvestQuantity -
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
        // Burn the investment proof
        _investProof.burnProof(
            toTTSwapUINT256(
                normalGoodResult1_.shares,
                normalGoodResult1_.disinvestTTSValue
            ),
            disinvestvalue,
            toTTSwapUINT256(
                normalGoodResult1_.virtualDisinvestQuantity,
                normalGoodResult1_.actualDisinvestQuantity
            )
        );
    }

    /**
     * @notice Allocate fees to various parties
     * @dev This function handles the allocation of fees to the market creator, gater, referrer, and liqidity providers
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
        mapping(address => uint256) storage commission = _self.commission;
        // Platform fee always taken from gross profit first.
        uint128 marketfee = _goodconfig.getPlatformFee128(_profit);
        _profit -= marketfee;
        uint128 liqidFee = _goodconfig.getLiquidFee(_profit);

        if (_referral == address(0)) {
            // No referrer: only compute fees needed for this branch.
            if (_gater == address(0)) {
                commission[address(0)] += (_profit - liqidFee + marketfee);
                commission[_sender] += (liqidFee + _divestQuantity);
            } else {
                uint128 sellerFee = _goodconfig.getOperatorFee(_profit);
                uint128 customerFee = _goodconfig.getCustomerFee(_profit);
                commission[_sender] += (liqidFee + _divestQuantity);
                commission[_gater] += sellerFee + customerFee;
                commission[address(0)] += (_profit +
                    marketfee -
                    liqidFee -
                    sellerFee -
                    customerFee);
            }
        } else {
            // Referrer path: full fee split.
            uint128 sellerFee = _goodconfig.getOperatorFee(_profit);
            uint128 gaterFee = _goodconfig.getGateFee(_profit);
            uint128 referFee = _goodconfig.getReferFee(_profit);
            uint128 customerFee = _goodconfig.getCustomerFee(_profit);
            address owner = _self.owner;

            if (owner != address(0)) {
                commission[owner] += sellerFee;
            } else {
                marketfee += sellerFee;
            }

            if (_gater != address(0)) {
                commission[_gater] += gaterFee;
            } else {
                marketfee += gaterFee;
            }

            commission[_referral] += referFee;
            commission[address(0)] += marketfee;
            commission[_sender] += (liqidFee + customerFee + _divestQuantity);
        }
    }

    function getBalanceLimit(
        S_GoodState storage _self
    ) internal view returns (uint256) {
        uint256 cfg = _self.goodConfig;
        return
            uint256(
                cfg.getSafeLineLower128(
                    _self.currentState.amount1() - cfg.amount1()
                )
            );
    }
}
