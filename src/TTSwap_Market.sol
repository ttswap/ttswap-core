// SPDX-License-Identifier: BUSL-1.1
// version 2.0.0
pragma solidity 0.8.29;

import {
    I_TTSwap_Market,
    S_ProofState,
    S_GoodState,
    S_ProofKey,
    S_GoodTmpState
} from "./interfaces/I_TTSwap_Market.sol";

import {IMulticall_v4} from "./interfaces/IMulticall_v4.sol";
import {L_Good} from "./libraries/L_Good.sol";
import {L_Transient} from "./libraries/L_Transient.sol";
import {TTSwapError} from "./libraries/L_Error.sol";
import {L_Proof, L_ProofIdLibrary} from "./libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "./libraries/L_GoodConfig.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";

import {T_GoodKey, T_GoodKeyLibrary} from "./type/T_GoodKey.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    add,
    lowerprice
} from "./libraries/L_TTSwapUINT256.sol";

import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
import {L_SignatureVerification} from "./libraries/L_SignatureVerification.sol";

/**
 * @title TTSwap_Market
 * @author ttswap.exchange@gmail.com
 * @notice Core on-chain market: create goods, provide liquidity, swap, pay, and withdraw.
 * @dev **Mental model for integrators**
 *      - A **good** = one token pool with its own virtual AMM state and fee config.
 *      - A **proof** = one user's LP position in a good (id = hash of owner + good).
 *      - **buyGood** = exact-input swap (you specify how much you sell; min output is slippage guard).
 *      - **payGood** = exact-output swap or same-token transfer (you specify how much recipient gets).
 *      - **Value good** flag (config bit 255) marks pricing/reference tokens (e.g. stablecoin side).
 *
 * @dev **Good quantity fields** (see `L_GoodConfig` glossary):
 *      `currentState.amount0` = investQty; `currentState.amount1` = Q;
 *      `goodConfig.amount1()` = leverage virtualQty only; `investState.amount1` = V.
 *
 * @dev **Meta-transactions**
 *      Only `buyGood` and `payGood` verify EIP-712 when `msg.sender != _trader`.
 *      All other functions with a `signature` argument keep it for ABI compatibility only;
 *      they require `_trader == msg.sender` via `_checkTrader`.
 *
 * @dev **Security modifiers**
 *      - `guardedEntry`: reentrancy lock (standalone 0→2, or 1→2 inside multicall).
 *      - `msgValue`: transient native-ETH budget for the whole call tree.
 *      - `multicallEntry`: arms lock level 1 so batched delegatecalls share one ETH budget.
 *
 * website  http://www.ttswap.io
 * twitter  https://x.com/ttswapfinance
 * telegram https://t.me/ttswapfinance
 * discord  https://discord.gg/XygqnmQgX3
 */
contract TTSwap_Market is I_TTSwap_Market, IMulticall_v4 {
    using L_GoodConfigLibrary for uint256;
    using L_UserConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;
    using L_Good for S_GoodState;
    using L_Proof for S_ProofState;
    using L_SignatureVerification for bytes;
    using T_GoodKeyLibrary for T_GoodKey;

    /// @dev Reserved storage slot for **proxy implementation pointer** (UUPS / transparent proxy layout).
    ///      Intentionally unused in logic-only builds; keeps layout aligned with deployed proxy. See audit M-06.
    address internal implementation;
    /// @notice TTS token contract — permissions, referral, stake/unstake hooks.
    I_TTSwap_Token internal immutable TTS_CONTRACT;

    /// @notice Per-trader nonce consumed by EIP-712 signed `buyGood` / `payGood` (also manually bumpable via `cancelNonce`).
    mapping(address _trader => uint256 nonce) public nonces;

    /// @dev Reserved flag for upgrade / admin flows in proxy deployments; placeholder in logic contract. See audit M-06.
    bool internal upgradeable;

    /// @dev All goods indexed by `T_GoodKey.toId()`.
    ///      Each stores pool depth, LP totals, owner, fees, and per-recipient commission balances.
    mapping(uint256 goodid => S_GoodState) private goods;

    /// @dev LP proofs indexed by `S_ProofKey.toId()` (hash of owner + good id).
    mapping(uint256 proofid => S_ProofState) private proofs;

    /// @dev Relayer execution fee denominator: fee in output-token units = poolPrice(executeFee).
    ///      `50_000_000_000` is the fixed amount0 side; amount1 is derived per output good price.
    uint128 internal constant executeFee = 50_000_000_000; // 5×10^10

    /// @notice EIP-712 domain version string.
    string internal constant Version = "2.0.0";

    /// @param _TTS_Contract Official TTSwap token (roles, referral, staking).
    constructor(I_TTSwap_Token _TTS_Contract) {
        TTS_CONTRACT = _TTS_Contract;
    }

    /// @dev Requires `TTS_CONTRACT.userConfig(msg.sender).isMarketAdmin()`.
    modifier onlyMarketadmin() {
        if (!TTS_CONTRACT.userConfig(msg.sender).isMarketAdmin())
            revert TTSwapError(1);
        _;
    }

    /// @dev Requires `TTS_CONTRACT.userConfig(msg.sender).isMarketManager()`.
    modifier onlyMarketor() {
        if (!TTS_CONTRACT.userConfig(msg.sender).isMarketManager())
            revert TTSwapError(2);
        _;
    }

    /// @dev Wraps native-ETH accounting (`L_Transient`) around the function body.
    ///      Use on any entrypoint that may move native goods or receive `msg.value`.
    modifier msgValue() {
        L_Transient.checkbefore();
        _;
        L_Transient.checkafter();
    }

    /// @notice Multicall entry: arms lock level 1 so guarded subcalls can promote 1→2.
    modifier multicallEntry() {
        uint256 lock = L_Transient.get();
        if (lock > 1) revert TTSwapError(3);
        L_Transient.set(1);
        _;
        L_Transient.set(lock);
    }

    /// @notice Guarded entry: works standalone (lock 0→2) and inside multicall (lock 1→2).
    /// Reverts on reentrancy (lock == 2). Restores previous lock level on exit.
    modifier guardedEntry() {
        uint256 lock = L_Transient.get();
        if (lock > 1) revert TTSwapError(3);
        L_Transient.set(2);
        _;
        L_Transient.set(lock);
    }

    /// @dev Direct-call only: `_trader` must be `msg.sender` (no relayer on this path).
    function _checkTrader(address _trader) private view {
        if (_trader != msg.sender || _trader == address(0))
            revert TTSwapError(39);
    }

    /// @dev Shared guard for swap / invest paths.
    /// @param freezeErr Error code when good is frozen (10 buy-side, 11 pay output, etc.).
    /// @param emptyErr Error code when good not initialized (12 / 13).
    /// @dev Also enforces **run-block** anti-replay: one state-changing touch per good per `block.number % 4095`.
    function _checkGoodActive(
        S_GoodState storage g,
        uint256 freezeErr,
        uint256 emptyErr
    ) private view {
        // Storage pointer avoids recomputing the mapping key hash twice
        if (g.goodConfig.isFreeze()) revert TTSwapError(freezeErr);
        if (g.currentState == 0) revert TTSwapError(emptyErr);
        if (g.goodConfig.getRunBlockConfig() == block.number % 4095)
            revert TTSwapError(46);
    }
    /// @notice Batch multiple market calls in one transaction (delegatecall into self).
    /// @dev Must be `payable` with `msgValue` + `multicallEntry` so native ETH budget is set once
    ///      at the outer boundary and not re-seeded on each subcall (see `L_Transient`).
    /// @inheritdoc IMulticall_v4
    function multicall(
        bytes[] calldata data
    ) external payable msgValue multicallEntry returns (bytes[] memory results) {
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

    /// @notice Create a new good (token pool) with a user-chosen initial price.
    /// @dev Deposits `_initial.amount1` tokens and declares `_initial.amount0` as total pool value.
    ///      Mints the first proof for `msg.sender` with 100% of initial shares.
    /// @param _goodKey Token identifier (ERC-20 or native sentinel `address(1)`).
    /// @param _initial amount0 = declared value, amount1 = token quantity deposited.
    /// @param _normaldata Encoded transfer path (approve / permit / Permit2) for ERC-20; empty for native with `msg.value`.
    /// @param _trader Must equal `msg.sender`.
    /// @param _signature Unused (ABI placeholder).
    function initGood(
        T_GoodKey memory _goodKey,
        uint256 _initial,
        bytes calldata _normaldata,
        address _trader,
        bytes calldata _signature
    ) external payable override guardedEntry msgValue returns (bool) {
        _checkTrader(_trader);
        // Minimum init size prevents dust pools and absurd self-pricing.
        if (_initial.amount1() < 500000 || _initial.amount1() > 2 ** 109)
            revert TTSwapError(36);
        if (
            _initial.amount0() > 2 ** 109 ||
            _initial.amount0() < 500_000_000_000_000
        ) revert TTSwapError(35);
        if (goods[_goodKey.toId()].owner != address(0)) revert TTSwapError(5);
        // Pull tokens (or debit native budget) into the market.
        _goodKey.transferFrom(
            msg.sender,
            msg.sender,
            _initial.amount1(),
            _normaldata
        );
        goods[_goodKey.toId()].init(_initial, _goodKey);

        // Creator receives proof id = hash(msg.sender, goodId).
        uint256 proofId = S_ProofKey(msg.sender, _goodKey.toId()).toId();

        // Seed proof with full initial shares and 1:1 virtual/actual quantities.
        proofs[proofId].updateInvest(
            _goodKey.toId(),
            toTTSwapUINT256(_initial.amount1(), 0),
            toTTSwapUINT256(_initial.amount0(), _initial.amount0()),
            toTTSwapUINT256(_initial.amount1(), _initial.amount1())
        );

        emit e_initGood(
            proofId,
            _goodKey.toId(),
            _goodKey.composedata(),
            _goodKey.id,
            _initial,
            _trader
        );
        return true;
    }

    /// @notice Add single-token liquidity to an existing good without pairing a value good.
    /// @dev The caller deposits only the target token; its credited value is derived from
    ///      the current pool price and scaled by the leverage factor (`enpower`).
    ///      Flow: isInvestBlocked (price guard) → transfer tokens in → compute virtual shares
    ///      → update good state → update/create proof → stake value to TTS.
    ///      Reverts with TTSwapError(47) if the deposit price exceeds the current pool price,
    ///      TTSwapError(38) if the resulting investment value is below the dust threshold.
    /// @param _goodKey  Address of the ERC-20 token (good) to invest in.
    /// @param _invest  Packed uint256 — amount0: credited value per unit, amount1: token quantity to deposit.
    /// @param _gooddata  Encoded transfer authorisation (plain approve / EIP-2612 / Permit2).
    /// @param signature Reserved for ABI compatibility; **not verified** here (C-01 scheme B). Do not rely on relayer semantics.
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`); receives the investment proof context in events.
    /// @return result  True on success.
    function investGood(
        T_GoodKey memory _goodKey,
        uint256 _invest,
        bytes calldata _gooddata,
        bytes calldata signature,
        address _trader
    ) external payable override guardedEntry msgValue returns (bool result) {
        _checkTrader(_trader);
        S_GoodState storage g = goods[_goodKey.toId()];
        _checkGoodActive(g, 10, 12);

        L_Good.S_GoodInvestReturn memory normalInvest_;

        // Calculate the power/leverage factor.
        // The power determines how much "virtual" liquidity is minted relative to the actual deposit.
        // It is capped by the lower power factor of the two goods in the pair.
        uint128 enpower = g.getInvestPower();

        // Transfer normal good tokens from investor to market.
        _goodKey.transferFrom(
            msg.sender,
            msg.sender,
            _invest.amount1(),
            _gooddata
        );

        // Retrieve current investment state of the normal good.
        (normalInvest_.goodShares, normalInvest_.goodValues) = goods[
            _goodKey.toId()
        ].investState.amount01();
        (
            normalInvest_.goodInvestQuantity,
            normalInvest_.goodCurrentQuantity
        ) = goods[_goodKey.toId()].currentState.amount01();

        // Process investment for normal good.
        // Calculates new shares and updates normal good's state.
        g.investGood(_invest.amount1(), normalInvest_, enpower);
        if (g.currentState.amount1() + _invest.amount1() > 2 ** 109)
            revert TTSwapError(18);
        if (normalInvest_.investValue < 1000000000000) revert TTSwapError(38);

        // Generate/Get proof ID.
        uint256 proofNo = S_ProofKey(msg.sender, _goodKey.toId()).toId();

        // Convert virtual value to actual value basis (scale down by leverage).
        uint128 investvalue = ((normalInvest_.investValue * 100) / enpower);

        // reset _invest to 0 & store the mint tts value
        _invest = 0;
        if (g.goodConfig.isPromised()) _invest = investvalue;
        // Update the investment proof with the new shares and amounts.
        proofs[proofNo].updateInvest(
            _goodKey.toId(),
            toTTSwapUINT256(normalInvest_.investShare, _invest.amount1()),
            toTTSwapUINT256(normalInvest_.investValue, investvalue),
            toTTSwapUINT256(
                normalInvest_.investQuantity,
                (normalInvest_.investQuantity * 100) / enpower //real quantity
            )
        );
        g.goodConfig = g.goodConfig.updateRunBlockConfig();
        emit e_investGood(
            proofNo,
            _goodKey.toId(),
            L_Proof.stake(TTS_CONTRACT, msg.sender, _invest.amount1()),
            toTTSwapUINT256(normalInvest_.investValue, investvalue),
            toTTSwapUINT256(
                normalInvest_.investFeeQuantity,
                normalInvest_.investQuantity
            ),
            _trader
        );

        return true;
    }

    /**
     * @dev Executes a swap (buy) between two goods.
     * @param _goodKey1 The address of the input good (selling).
     * @param _goodKey2 The address of the output good (buying).
     * @param _swapQuantity The swap details:
     *        - amount0: The input quantity of _goodid1.
     *        - amount1: The minimum gross output quantity of _goodid2 before any relayer execution fee.
     * @param _recipient The address to receive the bought goods (if different from trader).
     *                 Also used for referral tracking if different from trader.
     * @param data Additional data for the input token transfer (Permit/Transfer).
     * @param _trader The address of the trader initiating the swap (must match signer if signature used).
     * @param signature The EIP-712 signature authorizing the trade (if msg.sender != _trader).
     * @param external_info External business metadata (e.g., payment order id or other extra info).
     * @return good1change The state change of the input good:
     *         - amount0: Fee quantity deducted.
     *         - amount1: Actual input quantity swapped.
     * @return good2change The state change of the output good:
     *         - amount0: Fee quantity deducted.
     *         - amount1: Gross output quantity from the AMM before any relayer execution fee.
     * @notice This function calculates the swap amount based on the AMM formula, deducts fees,
     * updates reserves, and transfers tokens.
     * @custom:security Protected by reentrancy guard.
     * @custom:security Verifies EIP-712 signature if the caller is a relayer.
     * @custom:security Checks slippage tolerance against gross AMM output (`_swapQuantity.amount1()`).
     * @custom:security Validates that the pool has sufficient liquidity and is not frozen.
     */
    function buyGood(
        T_GoodKey memory _goodKey1,
        T_GoodKey memory _goodKey2,
        uint256 _swapQuantity,
        address _recipient,
        bytes calldata data,
        address _trader,
        bytes calldata signature,
        uint256 external_info
    )
        external
        payable
        override
        guardedEntry
        msgValue
        returns (uint256 good1change, uint256 good2change)
    {
        if (msg.sender != _trader)
            signature.verify(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "buyGood(address _trader,address referral,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,bytes data,uint256 external_info,uint256 nonce)"
                                ),
                                _trader,
                                _recipient,
                                _goodKey1.toId(),
                                _goodKey2.toId(),
                                _swapQuantity,
                                keccak256(data),
                                external_info,
                                nonces[_trader]++
                            )
                        )
                    )
                ),
                _trader
            );
        // Optional deadline in low 64 bits of external_info (unix timestamp).
        if (
            external_info.get64bit() != 0 &&
            block.timestamp > external_info.get64bit()
        ) revert TTSwapError(49);
        if (_goodKey1.toId() == _goodKey2.toId()) revert TTSwapError(9);
        S_GoodState storage g1 = goods[_goodKey1.toId()];
        S_GoodState storage g2 = goods[_goodKey2.toId()];
        _checkGoodActive(g1, 10, 12);
        _checkGoodActive(g2, 10, 12);
        // `_recipient != trader` registers referral on first use (via TTS token).
        if (_recipient != address(0) && _recipient != _trader) {
            TTS_CONTRACT.setReferral(_trader, _recipient);
        }
        // --- AMM core: input good exports value, output good converts value to tokens ---
        good1change = g1.buyGoodInput(_swapQuantity.amount0());
        good2change = g2.buyGoodOutput(good1change.amount1());

        // Dust and slippage checks (amount1 on swapQuantity = min gross output).
        if (good1change.amount1() < 1_00_000_000) revert TTSwapError(14);
        if (
            good2change.amount1() < _swapQuantity.amount1() &&
            _swapQuantity.amount1() > 0
        ) revert TTSwapError(15);
        // Pull input tokens from trader (permit data in `data` when relayer executes).
        _goodKey1.transferFrom(
            _trader,
            msg.sender,
            _swapQuantity.amount0(),
            data
        );

        // Deliver output: trader gets full gross; relayer deducts executeFee to commission ledger.
        if (msg.sender == _trader) {
            _goodKey2.safeTransfer(_trader, good2change.amount1());
        } else {
            uint128 feeQuantity = g2.getGoodState().getamount1fromamount0(
                executeFee
            );
            if (feeQuantity > good2change.amount1()) revert TTSwapError(50);
            g2.commission[msg.sender] += feeQuantity;
            if (_recipient == address(0)) _recipient = _trader;
            _goodKey2.safeTransfer(
                _recipient,
                (good2change.amount1() - feeQuantity)
            );
        }

        // Mark output good as used this block slot (anti-replay).
        g2.goodConfig = g2.goodConfig.updateRunBlockConfig();
        emit e_buyGood(
            _goodKey1.toId(),
            _goodKey2.toId(),
            good1change.amount1(),
            toTTSwapUINT256(
                good1change.amount0(),
                _swapQuantity.amount0() - good1change.amount0()
            ),
            toTTSwapUINT256(
                good2change.amount0(),
                good2change.amount1() + good2change.amount0()
            ),
            _trader,
            external_info
        );
    }

    /**
     * @dev Executes a payment or swap using specific output quantity (Pay).
     * @param _goodKey1 The address of the input good (paying with).
     * @param _goodKey2 The address of the output good (paying to).
     * @param _swapQuantity The swap details:
     *        - amount0: The maximum input quantity of _goodid1 (slippage protection).
     *        - amount1: The target gross output quantity of _goodid2 before any relayer execution fee.
     * @param _recipient The address to receive the payment (goods). In relayer mode, net delivery may be lower because execution fee is deducted from gross output.
     * @param data Additional data for the input token transfer (Permit/Transfer).
     * @param _trader The address of the trader initiating the payment (must match signer).
     * @param signature The EIP-712 signature authorizing the payment (if msg.sender != _trader).
     * @param external_info amount0: external business metadata (e.g. payment order id). amount1: deadline; if non-zero and `block.timestamp` exceeds it, reverts `TTSwapError(53)`.
     * @return good1change The state change of the input good:
     *         - amount0: Fee quantity deducted.
     *         - amount1: Actual input quantity used.
     * @return good2change The state change of the output good:
     *         - amount0: Fee quantity deducted.
     *         - amount1: Gross output quantity from the AMM / direct-pay path before any relayer execution fee.
     * @notice This function calculates the input amount needed to get a specific gross output amount (inverse swap).
     * If `_goodid1` == `_goodid2`, it performs a direct transfer path with relayer fee deduction semantics.
     * @custom:security Protected by reentrancy guard.
     * @custom:security Verifies EIP-712 signature if the caller is a relayer.
     * @custom:security Checks max input limit (`_swapQuantity.amount0()`).
     * @custom:security `external_info` is included in signature payload as business context metadata.
     */
    function payGood(
        T_GoodKey memory _goodKey1,
        T_GoodKey memory _goodKey2,
        uint256 _swapQuantity,
        address _recipient,
        bytes calldata data,
        address _trader,
        bytes calldata signature,
        uint256 external_info
    )
        external
        payable
        guardedEntry
        msgValue
        returns (uint256 good1change, uint256 good2change)
    {
        uint128 feeQuantity;
        _checkGoodActive(goods[_goodKey1.toId()], 10, 12);
        _checkGoodActive(goods[_goodKey2.toId()], 11, 13);
        if (_recipient == address(0)) revert TTSwapError(32);
        if (msg.sender != _trader)
            signature.verify(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "payGood(address _trader,address recipient,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,uint256 external_info,bytes data,uint256 nonce)"
                                ),
                                _trader,
                                _recipient,
                                _goodKey1.toId(),
                                _goodKey2.toId(),
                                _swapQuantity,
                                external_info,
                                keccak256(data),
                                nonces[_trader]++
                            )
                        )
                    )
                ),
                _trader
            );

        if (
            external_info.get64bit() != 0 &&
            block.timestamp > external_info.get64bit()
        ) revert TTSwapError(53);
        // Output good slot is consumed first in pay flow (recipient always receives from good2).
        goods[_goodKey2.toId()].goodConfig = goods[_goodKey2.toId()]
            .goodConfig
            .updateRunBlockConfig();
        if (_goodKey1.toId() != _goodKey2.toId()) {
            // Cross-good payment: fix output qty → derive input qty (inverse of buyGood order).
            good2change = goods[_goodKey2.toId()].payGoodOutput(
                _swapQuantity.amount1()
            );

            good1change = goods[_goodKey1.toId()].payGoodInput(
                good2change.amount1()
            );
            // amount0 on swapQuantity = max input (slippage cap).
            if (
                good1change.amount1() + good1change.amount0() >
                _swapQuantity.amount0()
            ) revert TTSwapError(15);
            _goodKey1.transferFrom(
                _trader,
                msg.sender,
                good1change.amount1() + good1change.amount0(),
                data
            );
            // Transfer output tokens. In relayer mode, recipient receives gross output minus execution fee.
            if (msg.sender == _trader) {
                _goodKey2.safeTransfer(_recipient, _swapQuantity.amount1());
            } else {
                // Commission logic for relayer.
                feeQuantity = goods[_goodKey2.toId()]
                    .getGoodState()
                    .getamount1fromamount0(executeFee);
                if (feeQuantity > _swapQuantity.amount1())
                    revert TTSwapError(50);
                goods[_goodKey2.toId()].commission[msg.sender] += feeQuantity;
                _goodKey2.safeTransfer(
                    _recipient,
                    _swapQuantity.amount1() - feeQuantity
                );
            }
            emit e_payGood(
                _goodKey1.toId(),
                _goodKey2.toId(),
                good2change.amount1(),
                toTTSwapUINT256(good1change.amount0(), good1change.amount1()),
                toTTSwapUINT256(
                    good2change.amount0(),
                    _swapQuantity.amount1() - good2change.amount0()
                ),
                _trader,
                _recipient,
                external_info
            );
        } else {
            // Same-token path: no AMM — direct transfer of `_swapQuantity.amount1` to `_recipient`.
            good1change = toTTSwapUINT256(
                goods[_goodKey1.toId()].currentState.amount1(),
                goods[_goodKey1.toId()].investState.amount1()
            );
            if (msg.sender == _trader) {
                _goodKey1.transferFrom(
                    _trader,
                    msg.sender,
                    _swapQuantity.amount1(),
                    data
                );
                _goodKey1.safeTransfer(_recipient, _swapQuantity.amount1());
                good2change = (good2change << 128);
            } else {
                // Relayer commission calculation.
                _goodKey1.transferFrom(
                    _trader,
                    msg.sender,
                    _swapQuantity.amount1(),
                    data
                );
                feeQuantity = good1change.getamount0fromamount1(executeFee);
                if (feeQuantity > _swapQuantity.amount1())
                    revert TTSwapError(50);
                good2change = _swapQuantity.amount1() - feeQuantity;
                goods[_goodKey1.toId()].commission[msg.sender] += feeQuantity;
                if (good2change > _swapQuantity.amount0())
                    revert TTSwapError(55);
                _goodKey1.safeTransfer(_recipient, good2change);
                good2change = (good2change << 128) + feeQuantity;
            }
            emit e_payGood(
                _goodKey1.toId(),
                0,
                good1change.getamount1fromamount0(_swapQuantity.amount1()),
                _swapQuantity,
                good2change,
                _trader,
                _recipient,
                external_info
            );
        }
    }

    /// @notice Withdraw LP shares: return principal + profit, split fees to gate/referral/platform.
    /// @param _proofid Proof id for `(msg.sender, good)`.
    /// @param _goodshares Share amount to burn (partial withdraw allowed per `getDisinvestChips`).
    /// @param _gate Gate address for operator/customer fee routing (zeroed if banned).
    /// @param _trader Must equal `msg.sender`.
    /// @param signature Unused (ABI placeholder).
    /// @return Profit credited to the user after fees (normal-good leg).
    /// @inheritdoc I_TTSwap_Market
    function disinvestProof(
        uint256 _proofid,
        uint128 _goodshares,
        address _gate,
        address _trader,
        bytes calldata signature
    ) external override guardedEntry returns (uint128) {
        _checkTrader(_trader);
        if (
            S_ProofKey(_trader, proofs[_proofid].currentgood).toId() != _proofid
        ) {
            revert TTSwapError(19);
        }

        L_Good.S_GoodDisinvestReturn memory disinvestNormalResult1_;

        uint256 normalgood = proofs[_proofid].currentgood;
        if (goods[normalgood].goodConfig.isFreeze()) revert TTSwapError(10);
        if (
            goods[normalgood].goodConfig.isPromised() &&
            goods[normalgood].owner == _trader
        ) {
            revert TTSwapError(40);
        }

        uint256 divestvalue;
        address referral = TTS_CONTRACT.getreferral(msg.sender);
        _gate = TTS_CONTRACT.userConfig(_gate).isBan() ? address(0) : _gate;
        referral = _gate == referral ? address(0) : referral;
        referral = TTS_CONTRACT.userConfig(referral).isBan()
            ? address(0)
            : referral;
        // Normalize payout routes:
        // - banned gate/referral are nulled
        // - gate == referral collapses referral to avoid double-counting

        // Disinvest uses proof-time shares to compute virtual/actual quantities,
        // then realizes profit/loss against current pool state and applies fee splits.
        // Calculate disinvestment details using the shared library.
        // This computes:
        // - The amount of normal/value goods to return to the user.
        // - The realized profit/loss.
        // - Any applicable fees (gate, referral, platform).
        // - Updates the state of both goods.
        (disinvestNormalResult1_, divestvalue) = goods[normalgood]
            .disinvestGood(
                proofs[_proofid],
                L_Good.S_GoodDisinvestParam(
                    _goodshares,
                    _gate,
                    referral,
                    msg.sender
                )
            );

        // Transfer accumulated commission/profit for normal good to the user.
        uint256 tranferamount = goods[normalgood].commission[msg.sender];

        if (tranferamount > 1) {
            goods[normalgood].commission[msg.sender] = 1;
            goods[normalgood].toGoodKey().safeTransfer(
                msg.sender,
                tranferamount - 1
            );
        }
        // Commission balances are kept with a 1-unit sentinel to avoid cold SSTORE.

        if (disinvestNormalResult1_.disinvestTTSValue > 0) {
            L_Proof.unstake(
                TTS_CONTRACT,
                msg.sender,
                disinvestNormalResult1_.disinvestTTSValue
            );
        }

        emit e_disinvestProof(
            _proofid,
            normalgood,
            _gate,
            divestvalue,
            toTTSwapUINT256(
                disinvestNormalResult1_.profit,
                disinvestNormalResult1_.virtualDisinvestQuantity
            ),
            toTTSwapUINT256(
                disinvestNormalResult1_.actual_fee,
                disinvestNormalResult1_.actualDisinvestQuantity
            ),
            disinvestNormalResult1_.disinvestTTSValue,
            _trader
        );
        return (disinvestNormalResult1_.profit);
    }

    /// @notice Emits `e_getPromiseProof` for applied goods when the caller is the good owner and proof matches `msg.sender`.
    /// @dev **C-01 / M-08**: No EIP-712 and **no relayer/meta-tx**; only the proof owner can call (enforced via `S_ProofKey(msg.sender, ...)`).
    ///      Integrators must not assume a signature or `_trader` parameter — caller MUST be `msg.sender`.
    /// @param _proofid Proof id derived from `(msg.sender, currentgood, valuegood)`.
    function refreshPromise(uint256 _proofid) external {
        // Cache proof storage pointer + fields: avoids 4+ repeated SLOAD on proofs[_proofid]
        S_ProofState storage proof = proofs[_proofid];
        uint256 currentgood = proof.currentgood;
        if (S_ProofKey(msg.sender, currentgood).toId() != _proofid) {
            revert TTSwapError(19);
        }
        S_GoodState storage g = goods[currentgood];
        if (g.goodConfig.isPromised() && g.owner == msg.sender) {
            // Emits a claimable-proof signal for applied goods (creator-owned).
            emit e_getPromiseProof(currentgood, _proofid);
        }
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
        uint256 goodid,
        uint256 valuegood,
        uint256 compareprice
    ) external view returns (bool) {
        return
            lowerprice(
                toTTSwapUINT256(
                    goods[goodid].investState.amount1(),
                    goods[goodid].currentState.amount1()
                ),
                toTTSwapUINT256(
                    goods[valuegood].investState.amount1(),
                    goods[valuegood].currentState.amount1()
                ),
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
        uint256 good1,
        uint256 good2
    )
        external
        view
        returns (uint256 good1currentstate, uint256 good2currentstate)
    {
        // return (goods[good1].currentState, goods[good2].currentState);
        return (goods[good1].getGoodState(), goods[good2].getGoodState());
    }

    /// @notice Retrieves the current state of a proof.
    /// @param proofid Proof id (`keccak256(owner, goodId)`).
    /// @return proofstate Snapshot — see `S_ProofState` / `L_Proof` (position-level, not pool `virtualQty`).
    /// @inheritdoc I_TTSwap_Market
    function getProofState(
        uint256 proofid
    ) external view returns (S_ProofState memory) {
        return proofs[proofid];
    }

    /// @notice Retrieves the current state of a good.
    /// @param good Good id.
    /// @return goodstate Snapshot:
    ///  - goodConfig: fee flags + `virtualQty` in low 128 bits (`config.amount1()`).
    ///  - currentState.amount0 = `investQty`; amount1 = `Q` (total virtual depth).
    ///  - investState.amount0 = shares; amount1 = `V` (pool value).
    /// @inheritdoc I_TTSwap_Market
    function getGoodState(
        uint256 good
    ) external view returns (S_GoodTmpState memory) {
        return
            S_GoodTmpState(
                goods[good].goodConfig,
                goods[good].owner,
                goods[good].currentState,
                goods[good].investState
            );
    }

    /// @notice Updates a good's configuration
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    /// @inheritdoc I_TTSwap_Market
    function modifyGoodByGoodOwner(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool) {
        _checkTrader(_trader);
        if (msg.sender != goods[_goodid].owner) revert TTSwapError(20);
        goods[_goodid].updateConfigbyGoodOwner(_goodConfig);
        emit e_updateGoodConfig(_goodid, goods[_goodid].goodConfig, _trader);
        return true;
    }

    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    /// @inheritdoc I_TTSwap_Market
    function modifyGoodByManager(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external onlyMarketor returns (bool) {
        _checkTrader(_trader);
        if (!_goodConfig.checkGoodConfig()) revert TTSwapError(24);
        goods[_goodid].updateConfigbyManager(_goodConfig);
        emit e_modifyGoodConfig(_goodid, goods[_goodid].goodConfig, _trader);
        return true;
    }

    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    /// @inheritdoc I_TTSwap_Market
    function modifyGoodByAdmin(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external override onlyMarketadmin returns (bool) {
        _checkTrader(_trader);
        goods[_goodid].updateConfigbyAdmin(_goodConfig);
        emit e_modifyGoodConfig(_goodid, goods[_goodid].goodConfig, _trader);
        return true;
    }

    /// @notice Locks a good when the caller is market manager or good owner.
    /// @param _goodid The good to lock.
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @inheritdoc I_TTSwap_Market
    function lockGood(
        uint256 _goodid,
        address _trader,
        bytes calldata signature
    ) external override {
        _checkTrader(_trader);
        if (
            !TTS_CONTRACT.userConfig(msg.sender).isMarketManager() &&
            goods[_goodid].owner != msg.sender
        ) revert TTSwapError(20);
        goods[_goodid].lockGood();
        emit e_updateGoodConfig(_goodid, goods[_goodid].goodConfig, _trader);
    }

    /// @notice Changes the owner of a good
    /// @param _goodid The ID of the good
    /// @param _to The new owner's address
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @inheritdoc I_TTSwap_Market
    function changeGoodOwner(
        uint256 _goodid,
        address _to,
        address _trader,
        bytes calldata signature
    ) external override onlyMarketor {
        if (_to == address(0)) revert TTSwapError(32);
        _checkTrader(_trader);
        goods[_goodid].owner = _to;
        emit e_changegoodowner(_goodid, _to, _trader);
    }

    /// @notice Collects commission for specified goods
    /// @param _goodid Array of good IDs
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @inheritdoc I_TTSwap_Market
    function collectCommission(
        uint256[] calldata _goodid,
        address _trader,
        bytes calldata signature
    ) external override guardedEntry {
        _checkTrader(_trader);
        address recipient = TTS_CONTRACT.userConfig(msg.sender).isMarketAdmin()
            ? address(0)
            : msg.sender;
        uint256 len = _goodid.length;
        if (len > 100) revert TTSwapError(21);
        uint256[] memory commissionamount = new uint256[](len);
        for (uint256 i = 0; i < len; ) {
            commissionamount[i] = goods[_goodid[i]].commission[recipient];
            if (commissionamount[i] > 1) {
                commissionamount[i] = commissionamount[i] - 1;
                goods[_goodid[i]].commission[recipient] = 1;
                goods[_goodid[i]].toGoodKey().safeTransfer(
                    msg.sender,
                    commissionamount[i]
                );
            }
            unchecked {
                ++i;
            }
        }
        emit e_collectcommission(_goodid, commissionamount, _trader);
    }

    /**
     * @dev Queries commission amounts for multiple goods for a specific recipient
     * @param _goodid Array of good addresses to query commission for
     * @param _recipient The address to check commission amounts for
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
        uint256[] calldata _goodid,
        address _recipient
    ) external view returns (uint256[] memory) {
        uint256 len = _goodid.length;
        if (len > 100) revert TTSwapError(21);
        uint256[] memory feeamount = new uint256[](len);
        for (uint256 i = 0; i < len; ) {
            feeamount[i] = goods[_goodid[i]].commission[_recipient];
            unchecked {
                ++i;
            }
        }
        return feeamount;
    }

    /**
     * @dev Adds welfare funds to a good's fee pool
     * @param goodid The address of the good to receive welfare
     * @param welfare The amount of tokens to add as welfare
     * @param data Additional data for token transfer
     * @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
     * @param signature Reserved for ABI compatibility; **not verified** here.
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
        uint256 goodid,
        uint128 welfare,
        bytes calldata data,
        address _trader,
        bytes calldata signature
    ) external payable guardedEntry msgValue {
        _checkTrader(_trader);
        if (goods[goodid].owner == address(0)) revert TTSwapError(12);
        uint256 cur = goods[goodid].currentState;
        if (
            cur.amount0() + welfare > 2 ** 109 ||
            cur.amount1() + welfare > 2 ** 109
        ) {
            revert TTSwapError(18);
        }
        // Welfare is a direct pool top-up:
        // - increases both investQty (`amount0`) and Q (`amount1`) equally (fee-like injection)
        // - raises LP net value without minting new shares
        goods[goodid].toGoodKey().transferFrom(
            msg.sender,
            msg.sender,
            welfare,
            data
        );
        goods[goodid].currentState = add(
            goods[goodid].currentState,
            toTTSwapUINT256(uint128(welfare), uint128(welfare))
        );
        emit e_goodWelfare(goodid, welfare, _trader);
    }

    /// @notice Returns the EIP-712 domain separator used by relayed entrypoints.
    /// @dev Always computed from the current execution context so proxy calls bind signatures
    ///      to the proxy address instead of the implementation address.
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("TTSwap_Market")),
                    keccak256(bytes(Version)),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// @notice Invalidate pending EIP-712 signatures by bumping the caller's nonce.
    function cancelNonce() external {
        nonces[msg.sender] = nonces[msg.sender] + 1;
    }
}
