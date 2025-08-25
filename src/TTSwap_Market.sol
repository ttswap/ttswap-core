// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {I_TTSwap_Market, S_ProofState, S_GoodState, S_ProofKey, S_GoodTmpState} from "./interfaces/I_TTSwap_Market.sol";
import {L_Good} from "./libraries/L_Good.sol";
import {L_Transient} from "./libraries/L_Transient.sol";
import {TTSwapError} from "./libraries/L_Error.sol";
import {L_Proof, L_ProofIdLibrary} from "./libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "./libraries/L_GoodConfig.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
import {L_CurrencyLibrary} from "./libraries/L_Currency.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, add, sub, addsub, subadd, lowerprice} from "./libraries/L_TTSwapUINT256.sol";
import {IMulticall_v4} from "./interfaces/IMulticall_v4.sol";
import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
/**
 * @title TTSwap_Market
 * @dev Core market contract for TTSwap protocol that manages goods trading, investing, and staking operations
 * @notice This contract implements a decentralized market system with the following key features:
 * - Meta good, value goods, and normal goods management
 * - Automated market making (AMM) with configurable fees
 * - Investment and disinvestment mechanisms
 * - Commission distribution system
 * - ETH or WETH staking integration
 */
contract TTSwap_Market is I_TTSwap_Market, IMulticall_v4 {
    using L_GoodConfigLibrary for uint256;
    using L_UserConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;
    using L_Good for S_GoodState;
    using L_Proof for S_ProofState;
    using L_CurrencyLibrary for address;

    /**
     * @dev Address of the official TTS token contract
     * @notice Handles:
     * - Minting rewards for market participation
     * - Staking operations and rewards
     * - Referral tracking and rewards
     * - Governance token functionality
     */
    I_TTSwap_Token private immutable officialTokenContract;
    address internal securitykeeper;

    /**
     * @dev Mapping of good addresses to their state information
     * @notice Stores the complete state of each good including:
     * - Current trading state(current value & current quantitys)
     * - Investment state (current invest value & current invest quantitys)
     * - Fee collection state (current total fee & current total construnct fee)
     * - Owner information
     * - Configuration parameters
     */
    mapping(address goodid => S_GoodState) private goods;
    /**
     * @dev Mapping of proof IDs to their state information
     * @notice Records all investment proofs in the system:
     * - Investment amounts and timestamps
     * - Associated goods (normal and value)
     * - Fee calculations and distributions
     * - Profit/loss tracking and performance metrics
     */
    mapping(uint256 proofid => S_ProofState) private proofs;

    /**
     * @dev Constructor for TTSwap_Market
     * @param _officialTokenContract The address of the official token contract
     */
    constructor(
        I_TTSwap_Token _officialTokenContract,
        address _securitykeeper
    ) {
        officialTokenContract = _officialTokenContract;
        securitykeeper = _securitykeeper;
    }

    /// onlydao admin can execute
    modifier onlyMarketadmin() {
        if (!officialTokenContract.userConfig(msg.sender).isMarketAdmin())
            revert TTSwapError(1);
        _;
    }

    /// onlydao manager can execute
    modifier onlyMarketor() {
        if (!officialTokenContract.userConfig(msg.sender).isMarketManager())
            revert TTSwapError(2);
        _;
    }

    /// run when eth token
    modifier msgValue() {
        L_Transient.checkbefore();
        _;
        L_Transient.checkafter();
    }

    /// @notice This will revert if the contract is locked
    modifier noReentrant() {
        if (L_Transient.get() != address(0)) revert TTSwapError(3);
        L_Transient.set(msg.sender);
        _;
        L_Transient.set(address(0));
    }

    /// @notice Enables calling multiple methods in a single call to the contract
    /// @inheritdoc IMulticall_v4
    function multicall(
        bytes[] calldata data
    ) external payable msgValue returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                // bubble up the revert reason
                assembly {
                    revert(add(result, 0x20), mload(result))
                }
            }

            results[i] = result;
        }
    }

    /**
     * @dev Initializes a meta good with initial liquidity
     * @param _erc20address The address of the ERC20 token to be used as the meta good
     * @param _initial The initial liquidity amounts:
     *        - amount0: Initial token amount
     *        - amount1: Initial value backing
     * @param _goodConfig Configuration parameters for the good:
     *        - Fee rates (trading, investment)
     *        - Trading limits (min/max amounts)
     *        - Special flags (staking enabled, emergency pause)
     * @param data Additional data for token transfer
     * @return bool Success status of the initialization
     * @notice This function:
     * - Creates a new meta good with specified parameters
     * - Sets up initial liquidity pool
     * - Mints corresponding tokens to the creator
     * - Initializes proof tracking
     * - Emits initialization events
     * @custom:security Only callable by DAO admin
     * @custom:security Requires reentrancy protection
     */
    /// @inheritdoc I_TTSwap_Market

    function initMetaGood(
        address _erc20address,
        uint256 _initial,
        uint256 _goodConfig,
        bytes calldata data
    ) external payable onlyMarketadmin msgValue returns (bool) {
        if (!_goodConfig.isvaluegood()) revert TTSwapError(4);
        if (goods[_erc20address].owner != address(0)) revert TTSwapError(5);
        _erc20address.transferFrom(msg.sender, _initial.amount1(), data);
        goods[_erc20address].init(_initial, _goodConfig);
        /// update good to value good
        goods[_erc20address].modifyGoodConfig(5933383808 << 223); //2**32+6*2**28+ 1*2**24+ 5*2**21+8*2**16+8*2**11+2*2**6
        uint256 proofid = S_ProofKey(msg.sender, _erc20address, address(0))
            .toId();
        proofs[proofid].updateInvest(
            _erc20address,
            address(0),
            toTTSwapUINT256(_initial.amount0(), _initial.amount0()),
            toTTSwapUINT256(_initial.amount0(), _initial.amount1()),
            0
        );
        uint128 construct = L_Proof.stake(
            officialTokenContract,
            msg.sender,
            _initial.amount0()
        );
        emit e_initMetaGood(
            proofid,
            _erc20address,
            construct,
            _goodConfig,
            _initial
        );
        return true;
    }

    /**
     * @dev Initializes a good
     * @param _valuegood The value good ID
     * @param _initial The initial balance,amount0 is the amount of the normal good,amount1 is the amount of the value good
     * @param _erc20address The address of the ERC20 token
     * @param _goodConfig The good configuration
     * @return bool Returns true if successful
     */
    /// @inheritdoc I_TTSwap_Market
    function initGood(
        address _valuegood,
        uint256 _initial,
        address _erc20address,
        uint256 _goodConfig,
        bytes calldata _normaldata,
        bytes calldata _valuedata
    ) external payable override noReentrant msgValue returns (bool) {
        if (!goods[_valuegood].goodConfig.isvaluegood()) {
            revert TTSwapError(6);
        }
        if (goods[_erc20address].owner != address(0)) revert TTSwapError(5);
        _erc20address.transferFrom(msg.sender, _initial.amount0(), _normaldata);
        _valuegood.transferFrom(msg.sender, _initial.amount1(), _valuedata);
        L_Good.S_GoodInvestReturn memory investResult;
        goods[_valuegood].investGood(_initial.amount1(), investResult, 1);
        goods[_erc20address].init(
            toTTSwapUINT256(investResult.investValue, _initial.amount0()),
            _goodConfig
        );
        uint256 proofId = S_ProofKey(msg.sender, _erc20address, _valuegood)
            .toId();

        proofs[proofId] = S_ProofState(
            _erc20address,
            _valuegood,
            toTTSwapUINT256(
                investResult.investValue,
                investResult.investValue
            ),
            toTTSwapUINT256(_initial.amount0(),_initial.amount0()),
            toTTSwapUINT256(
                investResult.investShare,investResult.investQuantity
            )
        );

        emit e_initGood(
            proofId,
            _erc20address,
            _valuegood,
            _goodConfig,
            L_Proof.stake(
                officialTokenContract,
                msg.sender,
                investResult.investValue * 2
            ),
            toTTSwapUINT256(_initial.amount0(), investResult.investValue),
            toTTSwapUINT256(
                investResult.investFeeQuantity,
                investResult.investQuantity
            )
        );
        return true;
    }
    /**
     * @dev Executes a buy order between two goods
     * @param _goodid1 The address of the input good
     * @param _goodid2 The address of the output good
     * @param _swapQuantity The amount of _goodid1 to swap
     * @param _tradetimes The number of trading iterations:
     *        - < 100: Normal trading with price impact
     *        - >= 100: Direct trading with fixed price
     * @param _recipent The address to receive referral rewards
     * @param data Additional data for token transfer
     * @return good1change The amount of _goodid1 used:
     *         - amount0: Trading fees
     *         - amount1: Actual swap amount
     * @return good2change The amount of _goodid2 received:
     *         - amount0: Trading fees
     *         - amount1: Actual received amount
     * @notice This function:
     * - Calculates optimal swap amounts using AMM formulas
     * - Applies trading fees and updates fee states
     * - Updates good states and reserves
     * - Handles referral rewards and distributions
     * - Emits trade events with detailed information
     * @custom:security Protected by reentrancy guard
     * @custom:security Validates input parameters and state
     */
    /// @inheritdoc I_TTSwap_Market

    function buyGood(
        address _goodid1,
        address _goodid2,
        uint256 _swapQuantity,
        uint128 _side,
        address _recipent,
        bytes calldata data
    )
        external
        payable
        noReentrant
        msgValue
        returns (uint256 good1change, uint256 good2change)
    {
        if (_swapQuantity == 0) revert TTSwapError(7);
        if (_side > 1) revert TTSwapError(8);
        if (_goodid1 == _goodid2) revert TTSwapError(9);
        if (goods[_goodid1].goodConfig.isFreeze()) revert TTSwapError(10);
        if (goods[_goodid2].goodConfig.isFreeze()) revert TTSwapError(11);
        if (goods[_goodid1].currentState == 0) revert TTSwapError(12);
        if (goods[_goodid2].currentState == 0) revert TTSwapError(13);
        if (
            goods[_goodid1].investState.amount1() + _swapQuantity.amount1() >
            goods[_goodid1].investState.amount1() * 2
        ) revert TTSwapError(33);
        if (_side == 1) {
            if (_recipent != address(0) && _recipent != msg.sender) {
                officialTokenContract.setReferral(msg.sender, _recipent);
            }
            L_Good.swapCache memory swapcache = L_Good.swapCache({
                remainQuantity: _swapQuantity.amount0(),
                outputQuantity: 0,
                feeQuantity: 0,
                swapvalue: 0,
                good1value:goods[_goodid1].investState.amount1(),
                good2value:goods[_goodid2].investState.amount1(),
                good1currentState: goods[_goodid1].currentState,
                good1config: goods[_goodid1].goodConfig,
                good2currentState: goods[_goodid2].currentState,
                good2config: goods[_goodid2].goodConfig
            });

            L_Good.swapCompute1(swapcache);

            if (swapcache.swapvalue < 1_000_000) revert TTSwapError(14);
            if (
                swapcache.outputQuantity < _swapQuantity.amount1() &&
                _swapQuantity.amount1() > 0
            ) revert TTSwapError(15);
            if (
                swapcache.good2currentState.amount1() <=
                (swapcache.good2config.amount1() * 11) / 10
            ) revert TTSwapError(16);

            good1change = toTTSwapUINT256(
                swapcache.feeQuantity,
                _swapQuantity.amount0()
            );
            _side = swapcache.good2config.getBuyFee(swapcache.outputQuantity);
            good2change = toTTSwapUINT256(
                _side,
                swapcache.outputQuantity - _side
            );
            goods[_goodid1].swapCommit(
                swapcache.good1currentState
            );
            goods[_goodid2].swapCommit(
                swapcache.good2currentState
            );
            _goodid1.transferFrom(msg.sender, good1change.amount1(), data);
            _goodid2.safeTransfer(msg.sender, good2change.amount1());
            emit e_buyGood(
                _goodid1,
                _goodid2,
                swapcache.swapvalue,
                good1change,
                good2change
            );
        } else {
            if (_recipent == address(0)) revert TTSwapError(32);
            L_Good.swapCache memory swapcache = L_Good.swapCache({
                remainQuantity: _swapQuantity.amount1(),
                outputQuantity: 0,
                feeQuantity: 0,
                swapvalue: 0,
                good1value:goods[_goodid1].investState.amount1(),
                good2value:goods[_goodid2].investState.amount1(),
                good1currentState: goods[_goodid1].currentState,
                good1config: goods[_goodid1].goodConfig,
                good2currentState: goods[_goodid2].currentState,
                good2config: goods[_goodid2].goodConfig
            });
            L_Good.swapCompute2(swapcache);
            _side = swapcache.good1config.getSellFee(swapcache.outputQuantity);
            good1change = toTTSwapUINT256(
                _side,
                swapcache.outputQuantity + _side
            );
            if (swapcache.swapvalue < 1_000_000) revert TTSwapError(14);
            if (
                good1change.amount1() > _swapQuantity.amount0() &&
                _swapQuantity.amount0() > 0
            ) revert TTSwapError(15);
            if (
                swapcache.good2currentState.amount1() <=
                (swapcache.good2config.amount1() * 11) / 10
            ) revert TTSwapError(16);
            swapcache.good1currentState=add(
                swapcache.good1currentState,
                toTTSwapUINT256(_side, 0)
            );
            good2change = toTTSwapUINT256(
                swapcache.feeQuantity,
                _swapQuantity.amount1()
            );
            _goodid1.transferFrom(msg.sender, good1change.amount1(), data);
            goods[_goodid1].swapCommit(
                swapcache.good1currentState
            );
            goods[_goodid2].swapCommit(
                swapcache.good2currentState
            );
            _goodid2.safeTransfer(_recipent, _swapQuantity.amount1());
            emit e_buyGood(
                _goodid1,
                _goodid2,
                uint256(swapcache.swapvalue) * 2 ** 128,
                good1change,
                good2change
            );
        }
    }
    /**
     * @dev Simulates a buy order between two goods to check expected amounts
     * @param _goodid1 The address of the input good
     * @param _goodid2 The address of the output good
     * @param _swapQuantity The amount of _goodid1 to swap
     * @param _tradetimes The number of trading iterations:
     *        - < 100: user sell _goodid1 for _goodid2
     *        - >= 100: user pay _goodid1 use _goodid2
     * @return good1change The expected amount of _goodid1 to be used:
     *         - amount0: Expected trading fees
     *         - amount1: Expected swap amount
     * @return good2change The expected amount of _goodid2 to be received:
     *         - amount0: Expected trading fees
     *         - amount1: Expected received amount
     * @notice This function:
     * - Simulates the buyGood operation without executing it
     * - Uses the same AMM formulas as buyGood
     * - Validates input parameters and market state
     * - Returns expected amounts including fees
     * - Useful for frontend price quotes and transaction previews
     * @custom:security View function, does not modify state
     * @custom:security Reverts if:
     * - Either good is not initialized
     * - Swap quantity is zero
     * - Same good is used for both input and output
     * - Trade times exceeds 200
     * - Insufficient liquidity for the swap
     */
    /// @inheritdoc I_TTSwap_Market

    function buyGoodCheck(
        address _goodid1,
        address _goodid2,
        uint256 _swapQuantity,
        bool side
    ) external view returns (uint256 good1change, uint256 good2change) {
        if (
            goods[_goodid1].currentState == 0 ||
            goods[_goodid2].currentState == 0 ||
            _swapQuantity == 0 ||
            _goodid1 == _goodid2
        ) revert TTSwapError(35);
        if (side) {
            L_Good.swapCache memory swapcache = L_Good.swapCache({
                remainQuantity: _swapQuantity.amount0(),
                outputQuantity: 0,
                feeQuantity: 0,
                swapvalue: 0,
                good1value:goods[_goodid1].investState.amount1(),
                good2value:goods[_goodid2].investState.amount1(),
                good1currentState: goods[_goodid1].currentState,
                good1config: goods[_goodid1].goodConfig,
                good2currentState: goods[_goodid2].currentState,
                good2config: goods[_goodid2].goodConfig
            });

            L_Good.swapCompute1(swapcache);

            if (swapcache.swapvalue < 1_000_000) revert TTSwapError(14);
            if (
                swapcache.outputQuantity < _swapQuantity.amount1() &&
                _swapQuantity.amount1() > 0
            ) revert TTSwapError(15);
            if (
                swapcache.good2currentState.amount1() <=
                (swapcache.good2config.amount1() * 11) / 10
            ) revert TTSwapError(16);

            good1change = toTTSwapUINT256(
                swapcache.feeQuantity,
                _swapQuantity.amount0()
            );

            good2change = toTTSwapUINT256(
                swapcache.good2config.getBuyFee(swapcache.outputQuantity),
                swapcache.outputQuantity -
                    swapcache.good2config.getBuyFee(swapcache.outputQuantity)
            );
        } else {
            L_Good.swapCache memory swapcache = L_Good.swapCache({
                remainQuantity: _swapQuantity.amount1(),
                outputQuantity: 0,
                feeQuantity: 0,
                swapvalue: 0,
                good1value:goods[_goodid1].investState.amount1(),
                good2value:goods[_goodid2].investState.amount1(),
                good1currentState: goods[_goodid1].currentState,
                good1config: goods[_goodid1].goodConfig,
                good2currentState: goods[_goodid2].currentState,
                good2config: goods[_goodid2].goodConfig
            });
            L_Good.swapCompute2(swapcache);
            if (swapcache.swapvalue < 1_000_000) revert TTSwapError(14);
            if (
                good1change.amount1() > _swapQuantity.amount0() &&
                _swapQuantity.amount0() > 0
            ) revert TTSwapError(15);
            if (
                swapcache.good2currentState.amount1() <=
                (swapcache.good2config.amount1() * 11) / 10
            ) revert TTSwapError(16);
            good1change = toTTSwapUINT256(
                swapcache.feeQuantity,
                swapcache.outputQuantity
            );
            good2change = toTTSwapUINT256(
                swapcache.feeQuantity,
                _swapQuantity.amount1()
            );
        }
    }

    /**
     * @dev Invests in a good with optional value good backing
     * @param _togood The address of the good to invest in
     * @param _valuegood The address of the value good (can be address(0))
     * @param _quantity The amount to invest _togood
     * @param data1 Additional data for _togood transfer
     * @param data2 Additional data for _valuegood transfer
     * @return bool Success status of the investment
     * @notice This function:
     * - Processes investment in the target good
     * - Optionally processes value good investment
     * - Updates proof state
     * - Mints corresponding tokens
     * - Calculates and distributes fees
     */
    /// @inheritdoc I_TTSwap_Market
    function investGood(
        address _togood,
        address _valuegood,
        uint128 _quantity,
        bytes calldata data1,
        bytes calldata data2
    ) external payable override noReentrant msgValue returns (bool) {
        L_Good.S_GoodInvestReturn memory normalInvest_;
        L_Good.S_GoodInvestReturn memory valueInvest_;
        if (_togood == _valuegood) revert TTSwapError(9);
        if (goods[_togood].goodConfig.isFreeze()) revert TTSwapError(10);
        if (
            !(goods[_togood].goodConfig.isvaluegood() ||
                goods[_valuegood].goodConfig.isvaluegood())
        ) revert TTSwapError(17);
        if (goods[_togood].currentState.amount1() + _quantity >= 2 ** 109)
            revert TTSwapError(18);

        uint128 enpower = goods[_togood].goodConfig.getPower();
        if (_valuegood != address(0)) {
            enpower = enpower < goods[_valuegood].goodConfig.getPower()
                ? enpower
                : goods[_valuegood].goodConfig.getPower();
        }

        _togood.transferFrom(msg.sender, _quantity, data1);
        _quantity = enpower * _quantity; 
        (normalInvest_.goodShares,normalInvest_.goodValues)=goods[_togood].investState.amount01();
        (normalInvest_.goodInvestQuantity,normalInvest_.goodCurrentQuantity)=goods[_togood].currentState.amount01();
        goods[_togood].investGood(_quantity, normalInvest_, enpower);

        if (_valuegood != address(0)) {
            if (goods[_valuegood].goodConfig.isFreeze()) revert TTSwapError(10);
            (valueInvest_.goodShares,valueInvest_.goodValues)=goods[_valuegood].investState.amount01();
             (valueInvest_.goodInvestQuantity,valueInvest_.goodCurrentQuantity)=goods[_valuegood].currentState.amount01();
            valueInvest_.investQuantity = toTTSwapUINT256(valueInvest_.goodCurrentQuantity,valueInvest_.goodValues).getamount0fromamount1(normalInvest_.investValue);
            valueInvest_.investQuantity=goods[_valuegood]
                .goodConfig
                .getInvestFullFee(valueInvest_.investQuantity);
            goods[_valuegood].investGood(
                valueInvest_.investQuantity,
                valueInvest_,
                enpower
            );
            _valuegood.transferFrom(
                msg.sender,
                valueInvest_.investQuantity/enpower+valueInvest_.investFeeQuantity,
                data2
            );
        }

        uint256 proofNo = S_ProofKey(msg.sender, _togood, _valuegood).toId();
         uint128 investvalue = normalInvest_.investValue;

        investvalue = (normalInvest_.investValue / enpower);
        proofs[proofNo].updateInvest(
            _togood,
            _valuegood,
            toTTSwapUINT256(normalInvest_.investValue, investvalue),
            toTTSwapUINT256(
                normalInvest_.investShare,
                normalInvest_.investQuantity
            ),
            toTTSwapUINT256(
                valueInvest_.investShare,
                valueInvest_.investQuantity
            )
        );
        emit e_investGood(
            proofNo,
            _togood,
            _valuegood,
            toTTSwapUINT256(normalInvest_.investValue, investvalue),
            toTTSwapUINT256(
                normalInvest_.investFeeQuantity,
                normalInvest_.investQuantity
            ),
            toTTSwapUINT256(
                valueInvest_.investFeeQuantity,
                valueInvest_.investQuantity
            )
        );
        investvalue = _valuegood == address(0) ? investvalue : investvalue * 2;
        L_Proof.stake(officialTokenContract, msg.sender, investvalue);
        return true;
    }

    /**
     * @dev Disinvests from a proof by withdrawing invested tokens and collecting profits
     * @param _proofid The ID of the proof to disinvest from
     * @param _goodQuantity The amount of normal good tokens to disinvest
     * @param _gate The address to receive gate rewards (falls back to DAO admin if banned)
     * @return uint128 The profit amount from normal good disinvestment
     * @return uint128 The profit amount from value good disinvestment (if applicable)
     * @notice This function:
     * - Validates proof ownership and state
     * - Processes disinvestment for both normal and value goods
     * - Handles commission distribution and fee collection
     * - Updates proof state and burns tokens
     * - Distributes rewards to gate and referrer
     * - Unstakes TTS tokens
     * @custom:security Protected by noReentrant modifier
     * @custom:security Reverts if:
     * - Proof ID does not match sender's proof
     * - Invalid proof state
     * - Insufficient balance for disinvestment
     */
    /// @inheritdoc I_TTSwap_Market
    function disinvestProof(
        uint256 _proofid,
        uint128 _goodshares,
        address _gate
    ) external override noReentrant returns (uint128, uint128) {
        if (
            S_ProofKey(
                msg.sender,
                proofs[_proofid].currentgood,
                proofs[_proofid].valuegood
            ).toId() != _proofid
        ) {
            revert TTSwapError(19);
        }
        L_Good.S_GoodDisinvestReturn memory disinvestNormalResult1_;
        L_Good.S_GoodDisinvestReturn memory disinvestValueResult2_;
        address normalgood = proofs[_proofid].currentgood;
        address valuegood = proofs[_proofid].valuegood;
        uint256 divestvalue;
        address referal = I_TTSwap_Token(officialTokenContract).getreferral(
            msg.sender
        );
        _gate = officialTokenContract.userConfig(_gate).isBan()
            ? address(0)
            : _gate;
        referal = _gate == referal ? address(0) : referal;
        referal = officialTokenContract.userConfig(referal).isBan()
            ? address(0)
            : referal;
        (disinvestNormalResult1_, disinvestValueResult2_, divestvalue) = goods[
            normalgood
        ].disinvestGood(
                goods[valuegood],
                proofs[_proofid],
                L_Good.S_GoodDisinvestParam(_goodshares, _gate, referal)
            );

        uint256 tranferamount = goods[normalgood].commission[msg.sender];

        if (tranferamount > 1) {
            goods[normalgood].commission[msg.sender] = 1;
            normalgood.safeTransfer(msg.sender, tranferamount - 1);
        }
        if (goods[normalgood].goodConfig.isFreeze()) revert TTSwapError(10);
        if (valuegood != address(0)) {
            if (goods[valuegood].goodConfig.isFreeze()) revert TTSwapError(10);
            tranferamount = goods[valuegood].commission[msg.sender];
            if (tranferamount > 1) {
                goods[valuegood].commission[msg.sender] = 1;
                valuegood.safeTransfer(msg.sender, tranferamount - 1);
            }
        }
        L_Proof.unstake(
            officialTokenContract,
            msg.sender,
            divestvalue.amount0()
        );

        emit e_disinvestProof(
            _proofid,
            normalgood,
            valuegood,
            _gate,
            divestvalue,
            toTTSwapUINT256(
                disinvestNormalResult1_.profit,
                disinvestNormalResult1_.vitualDisinvestQuantity
            ),
            toTTSwapUINT256(
                disinvestNormalResult1_.actual_fee,
                disinvestNormalResult1_.actualDisinvestQuantity
            ),
            toTTSwapUINT256(
                disinvestValueResult2_.profit,
                disinvestValueResult2_.vitualDisinvestQuantity
            ),
            toTTSwapUINT256(
                disinvestValueResult2_.actual_fee,
                disinvestValueResult2_.actualDisinvestQuantity
            )
        );
        return (disinvestNormalResult1_.profit, disinvestValueResult2_.profit);
    }

    /**
     * @dev Compares the current trading states of two goods to determine if the first good is in a higher iteration
     * @param good1 The address of the first good to compare
     * @param good2 The address of the second good to compare
     * @param compareprice the price of use good2 for good1
     * @return bool Returns true if good1's current state is higher than good2's, false otherwise
     * @notice This function:
     * - Compares the current trading iterations (states) of two goods
     * - Used to determine the trading order and eligibility for operations
     * - Essential for maintaining trading synchronization between goods
     * - Returns false if either good is not registered (state = 0)
     * @custom:security This is a view function with no state modifications
     * @custom:security Returns false for unregistered goods to prevent invalid operations
     */
    /// @inheritdoc I_TTSwap_Market
    function ishigher(
        address goodid,
        address valuegood,
        uint256 compareprice
    ) external view override returns (bool) {
        return
            lowerprice(
                goods[goodid].currentState,
                goods[valuegood].currentState,
                compareprice
            );
    }

    /**
     * @dev Retrieves the current state of two goods in a single call
     * @param good1 The address of the first good to query
     * @param good2 The address of the second good to query
     * @return good1correntstate The current state of the first good, representing its latest trading iteration
     * @return good2correntstate The current state of the second good, representing its latest trading iteration
     * @notice This function is a view function that:
     * - Returns the current trading iteration (state) for both goods
     * - Useful for checking the latest trading status of a pair of goods
     * - Can be used to verify if goods are in sync for trading operations
     * @custom:security This is a view function with no state modifications
     * @custom:security Returns 0 if either good address is not registered
     */
    /// @inheritdoc I_TTSwap_Market
    function getRecentGoodState(
        address good1,
        address good2
    )
        external
        view
        override
        returns (uint256 good1currentstate, uint256 good2currentstate)
    {
        return (goods[good1].currentState, goods[good2].currentState);
    }

    /// @inheritdoc I_TTSwap_Market
    function getProofState(
        uint256 proofid
    ) external view override returns (S_ProofState memory) {
        return proofs[proofid];
    }

    /// @inheritdoc I_TTSwap_Market
    function getGoodState(
        address goodkey
    ) external view override returns (S_GoodTmpState memory) {
        return
            S_GoodTmpState(
                goods[goodkey].goodConfig,
                goods[goodkey].owner,
                goods[goodkey].currentState,
                goods[goodkey].investState
            );
    }

    /// @inheritdoc I_TTSwap_Market
    function updateGoodConfig(
        address _goodid,
        uint256 _goodConfig
    ) external override returns (bool) {
        if (msg.sender != goods[_goodid].owner) revert TTSwapError(20);
        goods[_goodid].updateGoodConfig(_goodConfig);
        emit e_updateGoodConfig(_goodid, _goodConfig);
        return true;
    }

    /// @inheritdoc I_TTSwap_Market
    function modifyGoodConfig(
        address _goodid,
        uint256 _goodConfig
    ) external override onlyMarketor returns (bool) {
        goods[_goodid].modifyGoodConfig(_goodConfig);
        emit e_modifyGoodConfig(_goodid, _goodConfig);
        return true;
    }

    /// @inheritdoc I_TTSwap_Market
    function changeGoodOwner(
        address _goodid,
        address _to
    ) external override onlyMarketor {
        goods[_goodid].owner = _to;
        emit e_changegoodowner(_goodid, _to);
    }
    /// @inheritdoc I_TTSwap_Market

    function collectCommission(
        address[] memory _goodid
    ) external override noReentrant {
        address recipent = officialTokenContract
            .userConfig(msg.sender)
            .isDAOAdmin()
            ? address(0)
            : msg.sender;
        if (_goodid.length > 100) revert TTSwapError(21);
        uint256[] memory commissionamount = new uint256[](_goodid.length);
        for (uint256 i = 0; i < _goodid.length; i++) {
            commissionamount[i] = goods[_goodid[i]].commission[recipent];
            if (commissionamount[i] < 2) {
                commissionamount[i] = 0;
                continue;
            } else {
                commissionamount[i] = commissionamount[i] - 1;
                goods[_goodid[i]].commission[recipent] = 1;
                _goodid[i].safeTransfer(msg.sender, commissionamount[i]);
            }
        }
        emit e_collectcommission(_goodid, commissionamount);
    }

    /**
     * @dev Queries commission amounts for multiple goods for a specific recipient
     * @param _goodid Array of good addresses to query commission for
     * @param _recipent The address to check commission amounts for
     * @return feeamount Array of commission amounts corresponding to each good
     * @notice This function:
     * - Returns commission amounts for up to 100 goods in a single call
     * - Each amount represents the commission available for the recipient
     * - Returns 0 for goods where no commission is available
     * - Maintains gas efficiency by using a fixed array size
     * @custom:security Reverts if more than 100 goods are queried
     * @custom:security View function, does not modify state
     */
    /// @inheritdoc I_TTSwap_Market
    function queryCommission(
        address[] memory _goodid,
        address _recipent
    ) external view override returns (uint256[] memory) {
        if (_goodid.length >= 100) revert TTSwapError(21);
        uint256[] memory feeamount = new uint256[](_goodid.length);
        for (uint256 i = 0; i < _goodid.length; i++) {
            feeamount[i] = goods[_goodid[i]].commission[_recipent];
        }
        return feeamount;
    }

    /**
     * @dev Adds welfare funds to a good's fee pool
     * @param goodid The address of the good to receive welfare
     * @param welfare The amount of tokens to add as welfare
     * @param data Additional data for token transfer
     * @notice This function:
     * - Allows anyone to contribute additional funds to a good's fee pool
     * - Increases the good's feeQuantityState by the welfare amount
     * - Transfers tokens from the sender to the good
     * - Emits an event with the welfare contribution details
     * @custom:security Protected by noReentrant modifier
     * @custom:security Checks for overflow in feeQuantityState
     */
    /// @inheritdoc I_TTSwap_Market
    function goodWelfare(
        address goodid,
        uint128 welfare,
        bytes calldata data
    ) external payable override noReentrant msgValue {
        if (goods[goodid].currentState.amount0() + welfare >= 2 ** 109) {
            revert TTSwapError(18);
        }
        goodid.transferFrom(msg.sender, welfare, data);
        goods[goodid].currentState = add(
            goods[goodid].currentState,
            toTTSwapUINT256(uint128(welfare), 0)
        );
        emit e_goodWelfare(goodid, welfare);
    }

    function removeSecurityKeeper() external onlyMarketadmin {
        if (securitykeeper != msg.sender) revert TTSwapError(22);
        securitykeeper = address(0);
    }

    function securityKeeper(address erc20) external onlyMarketadmin {
        uint256 amount = erc20.balanceof(address(this));
        erc20.safeTransfer(msg.sender, amount);
    }
}
