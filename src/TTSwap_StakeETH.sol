// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title TTSwap_StakeETH
 * @notice This contract manages ETH staking and restaking operations, integrating with Rocket Pool and TTSwap market.
 * @dev Handles staking, unstaking, reward synchronization, and investment/divestment logic for ETH and rETH.
 *      Provides role-based access control for protocol creator and manager.
 */
import {TTSwapError} from "./libraries/L_Error.sol";
import {toTTSwapUINT256, L_TTSwapUINT256Library, add, sub, subadd, addsub, mulDiv} from "./libraries/L_TTSwapUINT256.sol";
import {L_Strings} from "./libraries/L_Strings.sol";
import {L_CurrencyLibrary} from "./libraries/L_Currency_Stake.sol";
import {L_Transient} from "./libraries/L_Transient_Stake.sol";
import {IRocketDepositPool} from "./interfaces/IRocketDepositPool.sol";
import {IRocketTokenRETH} from "./interfaces/IRocketTokenRETH.sol";
import {IRocketDAOProtocolSettingsDeposit} from "./interfaces/IRocketDAOProtocolSettingsDeposit.sol";
import {IRocketStorage} from "./interfaces/IRocketStorage.sol";
import {I_TTSwap_Market, S_ProofKey} from "./interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_StakeETH} from "./interfaces/I_TTSwap_StakeETH.sol";
import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {L_ProofIdLibrary} from "./libraries/L_Proof.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";

contract TTSwap_StakeETH is I_TTSwap_StakeETH {
    using L_TTSwapUINT256Library for uint256;
    using L_Strings for address;
    using L_CurrencyLibrary for address;
    using L_ProofIdLibrary for S_ProofKey;
    using L_UserConfigLibrary for uint256;

    /**
     * @notice Aggregated state for all staked tokens.
     * @dev amount0: total share, amount1: total ETH quantity
     */
    uint256 public override totalState;
    /**
     * @notice State for sETH pool (restakable ETH).
     * @dev amount0: share, amount1: quantity
     */
    uint256 public override sethState;
    /**
     * @notice State for swETH pool (non-restakable ETH).
     * @dev amount0: share, amount1: quantity
     */
    uint256 public override swethState;
    /**
     * @notice Total staked ETH and corresponding rETH received.
     * @dev amount0: staking amount, amount1: rETH amount received
     */
    uint256 public override totalStake;
    /**
     * @notice rETH staking state and rewards.
     * @dev amount0: rETH invested, amount1: reward
     */
    uint256 public override rethStaking;

    // Rocket Pool rETH token contract
    IRocketTokenRETH internal immutable ROCKET_TOKEN_RETH;
    // Rocket Pool storage contract
    IRocketStorage internal immutable rocketstorage;
    // TTSwap market contract
    I_TTSwap_Market internal immutable TTSWAP_MARKET;
    // TTSwap platform token contract
    I_TTSwap_Token internal immutable tts_token;
    // Special address representing the sETH pool (restakable ETH)
    address internal constant seth = address(2);

    /**
     * @notice Contract constructor, sets up protocol roles and external contract addresses.
     * @param _ttswap_market Address of the TTSwap market contract
     * @param _ttswap_token Address of the TTSwap platform token
     * @param _ROCKET_TOKEN_RETH Address of the Rocket Pool rETH token
     * @param _rocketstorage Address of the Rocket Pool storage contract
     */
    constructor(
        I_TTSwap_Market _ttswap_market,
        I_TTSwap_Token _ttswap_token,
        IRocketTokenRETH _ROCKET_TOKEN_RETH,
        IRocketStorage _rocketstorage
    ) {
        TTSWAP_MARKET = _ttswap_market;
        tts_token = _ttswap_token;
        rocketstorage = _rocketstorage;
        ROCKET_TOKEN_RETH = _ROCKET_TOKEN_RETH;
    }

    /**
     * @notice Restricts function access to the protocol creator only.
     */
    modifier onlyCreator() {
        if (!tts_token.userConfig(msg.sender).isStakeAdmin())
            revert TTSwapError(38);
        _;
    }

    /**
     * @notice Restricts function access to the protocol manager only.
     */
    modifier onlyManager() {
        if (!tts_token.userConfig(msg.sender).isStakeManager())
            revert TTSwapError(39);
        _;
    }

    /**
     * @notice Prevents reentrancy by using a transient storage lock.
     * @dev Reverts if the contract is already locked for the current call context.
     */
    modifier noReentrant() {
        if (L_Transient.get() != address(0)) revert TTSwapError(3);
        L_Transient.set(msg.sender);
        _;
        L_Transient.set(address(0));
    }

    /**
     * @notice Stake ETH or restakable tokens into the protocol.
     * @dev Only callable by the TTSwap market contract. Handles both sETH and swETH logic.
     * @param token The token address to stake (sETH or swETH)
     * @param _stakeamount The amount to stake
     */
    function stakeEth(
        address token,
        uint128 _stakeamount
    ) external payable override noReentrant {
        if ( address(TTSWAP_MARKET) != msg.sender) {
            revert TTSwapError(37);
        }
        token.transferFrom(address(TTSWAP_MARKET), address(this), _stakeamount);
        uint128 _stakeshare = totalState != 0
            ? totalState.getamount0fromamount1(_stakeamount)
            : _stakeamount;

        totalState = add(
            totalState,
            toTTSwapUINT256(_stakeshare, _stakeamount)
        );
        if (token == seth) {
            sethState = add(
                sethState,
                toTTSwapUINT256(_stakeshare, _stakeamount)
            );
            emit e_stakeSETH(
                totalStake,
                totalState,
                sethState,
                rethStaking,
                _stakeamount
            );
        } else {
            swethState = add(
                swethState,
                toTTSwapUINT256(_stakeshare, _stakeamount)
            );
            token.withdraw(_stakeamount);
            emit e_stakeSWETH(
                totalStake,
                totalState,
                swethState,
                rethStaking,
                _stakeamount
            );
        }
    }

    /**
     * @notice Unstake a specified amount of ETH or restakable tokens.
     * @dev Only callable by the TTSwap market contract. Handles both sETH and swETH logic.
     * @param token The token address to unstake (sETH or swETH)
     * @param amount The amount to unstake
     * @return reward The reward amount distributed to the user
     */
    function unstakeEthSome(
        address token,
        uint128 amount
    ) external override noReentrant returns (uint128 reward) {
        if ( address(TTSWAP_MARKET) != msg.sender) {
            revert TTSwapError(37);
        }
        internalReward();
        uint128 unstakeshare;
        if (token == seth) {
            unstakeshare = sethState.getamount0fromamount1(amount);
            reward = totalState.getamount1fromamount0(unstakeshare);
            sethState = sub(sethState, toTTSwapUINT256(unstakeshare, amount));
            totalState = sub(totalState, toTTSwapUINT256(unstakeshare, reward));
            token.safeTransfer(msg.sender, reward );
            emit e_unstakeSETH(
                totalStake,
                totalState,
                sethState,
                rethStaking,
                toTTSwapUINT256(reward-amount, amount)
            );
        } else {
            unstakeshare = swethState.getamount0fromamount1(amount);
            reward = totalState.getamount1fromamount0(unstakeshare);
            swethState = sub(swethState, toTTSwapUINT256(unstakeshare, amount));
            totalState = sub(totalState, toTTSwapUINT256(unstakeshare, reward));
            token.deposit( reward);

            token.safeTransfer(msg.sender,  reward);
            emit e_unstakeSWETH(
                totalStake,
                totalState,
                swethState,
                rethStaking,
                toTTSwapUINT256(reward-amount, amount)
            );
        }
    }

    /**
     * @notice Synchronize and claim staking rewards for a given token.
     * @dev Only callable by the TTSwap market contract. Handles both sETH and swETH logic.
     * @param token The token address to claim rewards for (sETH or swETH)
     * @return reward The reward amount distributed to the user
     */
    function syncReward(
        address token
    ) external override noReentrant returns (uint128 reward) {
        if ( address(TTSWAP_MARKET) != msg.sender) {
            revert TTSwapError(37);
        }
        internalReward();
        uint128 share;
        if (token == seth) {
            reward =
                totalState.getamount1fromamount0(sethState.amount0()) -
                sethState.amount1();
            share = totalState.getamount0fromamount1(reward);
            totalState = sub(totalState, toTTSwapUINT256(share, reward));
            sethState = sub(sethState, toTTSwapUINT256(share, 0));

            token.safeTransfer(msg.sender, reward);
            emit e_unstakeSETH(
                totalStake,
                totalState,
                sethState,
                rethStaking,
                toTTSwapUINT256(reward, 0)
            );
        } else {
            reward =
                totalState.getamount1fromamount0(swethState.amount0()) -
                swethState.amount1();

            share = totalState.getamount0fromamount1(reward);
            totalState = sub(totalState, toTTSwapUINT256(share, reward));
            swethState = sub(swethState, toTTSwapUINT256(share, 0));
            token.deposit(reward);

            token.safeTransfer(msg.sender, reward);
            emit e_unstakeSWETH(
                totalStake,
                totalState,
                swethState,
                rethStaking,
                toTTSwapUINT256(reward, 0)
            );
        }
    }

    /**
     * @notice Internal function to update rewards based on rETH and ETH balances.
     * @dev Updates totalStake, totalState, and rethStaking if new rewards are available.
     */
    function internalReward() internal {
        uint128 reth = uint128(
            IERC20(address(ROCKET_TOKEN_RETH)).balanceOf(address(this)) +
                rethStaking.amount0()
        );
        uint128 eth1 = uint128(ROCKET_TOKEN_RETH.getEthValue(reth));
        uint128 reward = eth1 >= totalStake.amount0()
            ? eth1 - totalStake.amount0()
            : 0;
        if (reward > 0) {
            totalStake = add(totalStake, toTTSwapUINT256(reward, 0));
            totalState = add(totalState, toTTSwapUINT256(0, reward));
            rethStaking = add(rethStaking, toTTSwapUINT256(0, reward));
        }
    }

    /**
     * @notice Stake ETH into Rocket Pool and receive rETH. Only callable by the manager.
     * @param stakeamount The amount of ETH to stake
     * @return rethAmount The amount of rETH received
     */
    function stakeRocketPoolETH(
        uint128 stakeamount
    ) external override onlyManager returns (uint128 rethAmount) {
        IRocketDAOProtocolSettingsDeposit ROCKET_DAO_SETTINGS_DEPOSIT = IRocketDAOProtocolSettingsDeposit(
                rocketstorage.getAddress(
                    keccak256(
                        abi.encodePacked(
                            "contract.address",
                            "rocketDAOProtocolSettingsDeposit"
                        )
                    )
                )
            );
        IRocketDepositPool ROCKET_DEPOSIT_POOL = IRocketDepositPool(
            rocketstorage.getAddress(
                keccak256(
                    abi.encodePacked("contract.address", "rocketDepositPool")
                )
            )
        );
        require(
            ROCKET_DAO_SETTINGS_DEPOSIT.getDepositEnabled(),
            "Rocket Pool deposits are currently disabled"
        );

        uint256 depositPoolBalance = ROCKET_DEPOSIT_POOL.getBalance();
        uint256 maxDepositPoolSize = ROCKET_DAO_SETTINGS_DEPOSIT
            .getMaximumDepositPoolSize();

        require(
            depositPoolBalance + stakeamount <= maxDepositPoolSize,
            "Deposit pool size exceeded"
        );

        rethAmount = uint128(ROCKET_TOKEN_RETH.getRethValue(stakeamount));
        address(ROCKET_DEPOSIT_POOL).deposit(stakeamount);

        totalStake = add(totalStake, toTTSwapUINT256(stakeamount, rethAmount));

        emit e_stakeRocketPoolETH(totalStake);
    }

    /**
     * @notice Unstake rETH from Rocket Pool and update protocol state. Only callable by the manager.
     * @param rethAmount The amount of rETH to unstake
     */
    function unstakeRocketPoolETH(
        uint128 rethAmount
    ) external override onlyManager {
        require(rethAmount > 0, "Amount must be greater than 0");
        uint128 ethAmount = totalStake.getamount0fromamount1(rethAmount);
        uint128 unstakeeth = uint128(ROCKET_TOKEN_RETH.getEthValue(rethAmount));
        require(
            IERC20(address(ROCKET_TOKEN_RETH)).balanceOf(address(this)) >=
                rethAmount,
            "Insufficient rETH balance"
        );
        uint128 reward = unstakeeth - ethAmount;
        ROCKET_TOKEN_RETH.burn(rethAmount);
        totalState = add(totalState, toTTSwapUINT256(0, unstakeeth));
        totalStake = sub(totalStake, toTTSwapUINT256(ethAmount, rethAmount));
        emit e_rocketpoolUnstaked(totalStake, totalState, reward);
    }

    /**
     * @notice Receive function to accept ETH transfers.
     * @dev Emits an event with the received ETH amount.
     */
    receive() external payable {
        emit e_Received(msg.value);
    }

    /**
     * @notice Invest rETH into the TTSwap market. Only callable by the manager.
     * @param _goodQuantity The amount of rETH to invest
     */
    function invest(uint128 _goodQuantity) external override onlyManager {
        uint256 proofid = S_ProofKey(
            address(this),
            address(ROCKET_TOKEN_RETH),
            address(0)
        ).toId();
        require(
            (_goodQuantity >=
                (
                    TTSWAP_MARKET.getProofState(proofid).invest.amount0() == 0
                        ? 0
                        : (TTSWAP_MARKET
                            .getProofState(proofid)
                            .invest
                            .amount0() * 2) / 10
                )) &&
                (_goodQuantity <=
                    (uint128(
                        IERC20(address(ROCKET_TOKEN_RETH)).balanceOf(
                            address(this)
                        )
                    ) * 8) /
                        10)
        );
        rethStaking = add(rethStaking, toTTSwapUINT256(_goodQuantity, 0));
        IERC20(address(ROCKET_TOKEN_RETH)).approve(
            address(TTSWAP_MARKET),
            _goodQuantity
        );
        TTSWAP_MARKET.investGood(
            address(ROCKET_TOKEN_RETH),
            address(0),
            _goodQuantity,
            "",
            ""
        );
        emit e_stakeeth_invest(rethStaking);
    }

    /**
     * @notice Divest rETH from the TTSwap market. Only callable by the manager.
     * @param _goodQuantity The amount of rETH to divest
     */
    function divest(uint128 _goodQuantity) external override onlyManager {
        uint256 proofid = S_ProofKey(
            address(this),
            address(ROCKET_TOKEN_RETH),
            address(0)
        ).toId();
        require(
            _goodQuantity <=
                TTSWAP_MARKET.getProofState(proofid).invest.amount0()
        );

        TTSWAP_MARKET.disinvestProof(proofid, _goodQuantity, address(0));

        rethStaking = subadd(rethStaking, toTTSwapUINT256(_goodQuantity, 0));
        emit e_stakeeth_devest(rethStaking);
    }

    /**
     * @notice Collect TTS token rewards and swap for rETH via the TTSwap market. Only callable by the manager.
     */
    function collectTTSReward() external override onlyManager {
        uint128 amount = uint128(
            IERC20(address(tts_token)).balanceOf(address(this))
        );
        if (amount > 0) {
            IERC20(address(tts_token)).approve(address(TTSWAP_MARKET), amount);
            (, uint256 getamount) = TTSWAP_MARKET.buyGood(
                address(tts_token),
                address(ROCKET_TOKEN_RETH),
                amount,
                1,
                address(0),
                ""
            );
            emit e_collecttts(toTTSwapUINT256(amount, getamount.amount1()));
        }
    }
}
