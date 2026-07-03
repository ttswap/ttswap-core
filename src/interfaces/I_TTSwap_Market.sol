// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {T_GoodKey} from "../type/T_GoodKey.sol";

/// @title I_TTSwap_Market
/// @notice Public API for the TTSwap on-chain market (v2.0.0).
/// @dev **Core concepts**
///      - **Good**: one token pool (`T_GoodKey` → `goodId`) with virtual AMM state and fee config.
///      - **Proof**: one user's LP position in a good; id = `keccak256(owner, goodId)`.
///      - **buyGood**: exact-input swap — specify input token qty + minimum gross output.
///      - **payGood**: exact-output swap / same-token pay — specify max input + target output.
///
/// @dev **Good quantity fields** (see `L_GoodConfig` glossary):
///      `currentState.amount0` = investQty; `currentState.amount1` = Q;
///      `goodConfig.amount1()` = leverage virtualQty only; `investState.amount1` = V.
///
/// @dev **Packed return / state words** (`TTSwapUINT256`): high 128 bits = `amount0`, low 128 bits = `amount1`.
///      Swap legs return `(fee, quantityOrValue)`; see `L_TTSwapUINT256.sol` for field semantics per context.
///
/// @dev **Meta-transactions**
///      Only `buyGood` and `payGood` verify EIP-712 when `msg.sender != _trader`.
///      Every other function that includes `bytes calldata signature` keeps it for ABI compatibility only;
///      the implementation requires `_trader == msg.sender` via `_checkTrader`.
interface I_TTSwap_Market {
    // ─────────────────────────── Events ───────────────────────────

    /// @notice Good owner updated fee/power region of `goodConfig` (owner-writable bits).
    event e_updateGoodConfig(
        uint256 indexed _goodid,
        uint256 _goodConfig,
        address _trader
    );

    /// @notice Market manager or admin updated `goodConfig` (manager/admin bit regions).
    event e_modifyGoodConfig(
        uint256 indexed _goodid,
        uint256 _goodconfig,
        address _trader
    );

    /// @notice Good ownership transferred by market manager.
    /// @param goodid Good id.
    /// @param to New owner.
    event e_changegoodowner(uint256 goodid, address to, address _trader);

    /// @notice Commission balances withdrawn for one or more goods.
    /// @param _goodid Good ids processed (max 100 per call).
    /// @param _commisionamount Token amount sent per good (parallel array).
    event e_collectcommission(
        uint256[] _goodid,
        uint256[] _commisionamount,
        address _trader
    );

    /// @notice Donor topped up pool reserves without minting shares (welfare).
    event e_goodWelfare(uint256 indexed goodid, uint128 welfare, address _trader);

    /// @notice Liquidity added to an existing good (`investGood`).
    /// @param _proofNo Proof id for `(msg.sender, _goodid)`.
    /// @param _goodid Target good id.
    /// @param _construct TTS stake receipt from `TTS_CONTRACT.stake` (0 if good not promised).
    /// @param _value Packed `(virtualInvestValue, actualInvestValue)` after leverage normalization.
    /// @param _invest Packed `(investFeeQty, virtualInvestQty)` credited to the pool.
    event e_investGood(
        uint256 indexed _proofNo,
        uint256 indexed _goodid,
        uint256 _construct,
        uint256 _value,
        uint256 _invest,
        address _trader
    );

    /// @notice New good pool created (`initGood`).
    /// @param _proofNo Creator's initial proof id.
    /// @param _goodid New good id.
    /// @param _goodinfo Packed `(ercType << 160) | tokenAddress` from `T_GoodKey.composedata()`.
    /// @param _good_id ERC-1155/6909 id field (0 for ERC-20 / native).
    /// @param _normalinitial Packed init: amount0 = declared value, amount1 = deposited quantity.
    event e_initGood(
        uint256 indexed _proofNo,
        uint256 indexed _goodid,
        uint256 _goodinfo,
        uint256 _good_id,
        uint256 _normalinitial,
        address _trader
    );

    /// @notice Exact-input swap completed (`buyGood`).
    /// @param sellgood Input good id (tokens sold in).
    /// @param forgood Output good id (tokens bought out).
    /// @param swapvalue Input token quantity moved on the sell side (good1change.amount1).
    /// @param good1change Packed `(sellFee, inputQty)` on the input good.
    /// @param good2change Packed `(buyFee, grossOutputQty)` on the output good (before relayer fee).
    /// @param external_info Opaque metadata; low 64 bits may encode deadline for meta-tx.
    event e_buyGood(
        uint256 indexed sellgood,
        uint256 indexed forgood,
        uint256 swapvalue,
        uint256 good1change,
        uint256 good2change,
        address _trader,
        uint256 external_info
    );

    /// @notice Exact-output payment completed (`payGood`).
    /// @param sellgood Input / pay-token good id.
    /// @param forgood Output good id (0 when same-token direct pay path).
    /// @param swapvalue Gross output quantity targeted on cross-good path.
    /// @param good1change Packed input-side fee and quantities.
    /// @param good2change Packed output-side fee and quantities.
    /// @param _recipient Final token recipient.
    /// @param external_info Business metadata; low 64 bits = deadline on signed pay path.
    event e_payGood(
        uint256 indexed sellgood,
        uint256 indexed forgood,
        uint256 swapvalue,
        uint256 good1change,
        uint256 good2change,
        address _trader,
        address _recipient,
        uint256 external_info
    );

    /// @notice LP shares burned and proceeds distributed (`disinvestProof`).
    /// @param _proofNo Proof id.
    /// @param _normalGoodNo Good id being exited.
    /// @param _gate Gate address used for fee routing (may be zeroed if banned).
    /// @param _value Packed disinvest value snapshot from proof ratios.
    /// @param _normalprofit Packed `(profit, virtualDisinvestQty)`.
    /// @param _normaldisvest Packed `(disinvestFee, actualDisinvestQty)`.
    /// @param _TTSValue TTS unstaked on this withdrawal.
    event e_disinvestProof(
        uint256 indexed _proofNo,
        uint256 _normalGoodNo,
        address _gate,
        uint256 _value,
        uint256 _normalprofit,
        uint256 _normaldisvest,
        uint256 _TTSValue,
        address _trader
    );

    /// @notice Emitted when a promised-good owner signals a claimable proof (`refreshPromise`).
    event e_getPromiseProof(uint256 indexed _goodid, uint256 _proofid);

    // ─────────────────────────── Nonces ───────────────────────────

    /// @notice EIP-712 nonce for `_trader` on signed `buyGood` / `payGood`; increment via `cancelNonce`.
    function nonces(address _trader) external view returns (uint256);

    // ─────────────────────────── Lifecycle ───────────────────────────

    /// @notice Create a new good (token pool) at a user-declared initial price.
    /// @param _goodKey Token identifier (ERC-20 or native `address(1)`).
    /// @param _initial amount0 = declared total value, amount1 = token quantity deposited.
    /// @param _normaldata Transfer auth: empty + `msg.value` for native; approve/permit data for ERC-20.
    /// @param _trader Must equal `msg.sender`.
    /// @param _signature Unused (ABI placeholder).
    function initGood(
        T_GoodKey memory _goodKey,
        uint256 _initial,
        bytes memory _normaldata,
        address _trader,
        bytes calldata _signature
    ) external payable returns (bool);

    /// @notice Add single-token liquidity to an existing good.
    /// @dev Deposits `_invest.amount1` tokens; virtual shares scale by pool leverage (`getInvestPower`).
    ///      Reverts: 10 frozen, 12 missing good, 18 overflow, 38 value dust, 46 run-block replay.
    /// @param _goodKey Good to invest in.
    /// @param _invest amount1 = token quantity to deposit (amount0 unused on input).
    /// @param _gooddata Encoded transfer (approve / EIP-2612 / Permit2).
    /// @param signature Unused (ABI placeholder).
    /// @param _trader Must equal `msg.sender`.
    function investGood(
        T_GoodKey memory _goodKey,
        uint256 _invest,
        bytes calldata _gooddata,
        bytes calldata signature,
        address _trader
    ) external payable returns (bool);

    // ─────────────────────────── Trading ───────────────────────────

    /// @notice Exact-input swap: sell `_goodKey1`, buy `_goodKey2`.
    /// @dev Flow: `buyGoodInput` on good1 → `buyGoodOutput` on good2 → token transfers.
    ///      When `msg.sender != _trader`, `signature` must be valid EIP-712 over the typed payload + `nonces[_trader]`.
    /// @param _goodKey1 Input (sell) good.
    /// @param _goodKey2 Output (buy) good.
    /// @param _swapQuantity amount0 = exact input token qty; amount1 = min gross output (slippage, 0 = no check).
    /// @param _referral Referral recipient when `!= _trader` and `!= 0` (registered via TTS token); else ignored.
    /// @param data Input-token transfer authorization for the relayer path.
    /// @param _trader Signer / economic actor.
    /// @param signature EIP-712 signature; required when caller is a relayer.
    /// @param external_info App metadata; low 64 bits = unix deadline (reverts 49 if expired).
    /// @return good1change `(sellFee, exportedValue)` on input good.
    /// @return good2change `(buyFee, netOutputQty)` on output good (relayer fee deducted off-chain transfer).
    function buyGood(
        T_GoodKey memory _goodKey1,
        T_GoodKey memory _goodKey2,
        uint256 _swapQuantity,
        address _referral,
        bytes calldata data,
        address _trader,
        bytes calldata signature,
        uint256 external_info
    ) external payable returns (uint256 good1change, uint256 good2change);

    /// @notice Exact-output swap or same-token payment.
    /// @dev Cross-good: `payGoodOutput` on good2 → `payGoodInput` on good1.
    ///      Same good: direct transfer without AMM (good2 event field = 0).
    /// @param _goodKey1 Pay-token / input good.
    /// @param _goodKey2 Output good (may equal good1 for direct pay).
    /// @param _swapQuantity amount0 = max input (slippage cap); amount1 = target gross output qty.
    /// @param _recipient Must be non-zero; receives output tokens (net of relayer fee when applicable).
    /// @param data Input-token transfer authorization.
    /// @param _trader Signer / payer.
    /// @param signature EIP-712 signature when `msg.sender != _trader`.
    /// @param external_info App metadata; low 64 bits = deadline (reverts 53 if expired).
    /// @return good1change Input-side packed change (fees + quantities).
    /// @return good2change Output-side packed change.
    function payGood(
        T_GoodKey memory _goodKey1,
        T_GoodKey memory _goodKey2,
        uint256 _swapQuantity,
        address _recipient,
        bytes calldata data,
        address _trader,
        bytes calldata signature,
        uint256 external_info
    ) external payable returns (uint256 good1change, uint256 good2change);

    /// @notice Withdraw LP shares (partial allowed per `getDisinvestChips`).
    /// @param _proofid Proof id for `(msg.sender, good)`.
    /// @param _goodQuantity Share amount to burn (not token amount).
    /// @param _gate Gate address for operator/gate fee split.
    /// @param _trader Must equal `msg.sender`.
    /// @param signature Unused (ABI placeholder).
    /// @return reward1 Profit credited to user after disinvest fee (normal-good leg).
    function disinvestProof(
        uint256 _proofid,
        uint128 _goodQuantity,
        address _gate,
        address _trader,
        bytes calldata signature
    ) external returns (uint128 reward1);

    // ─────────────────────────── Views ───────────────────────────

    /// @notice Compare implied prices of two goods using `lowerprice` (512-bit safe).
    /// @param goodid First good id.
    /// @param valuegood Second good id (reference / value side).
    /// @param compareprice Packed ratio threshold `(num, den)`.
    /// @return True when goodid's price is higher than valuegood under the compare ratio.
    function ishigher(
        uint256 goodid,
        uint256 valuegood,
        uint256 compareprice
    ) external view returns (bool);

    /// @notice Owner-only signal for promised goods; emits `e_getPromiseProof` when eligible.
    /// @dev No EIP-712, no relayer — `msg.sender` must own the proof.
    function refreshPromise(uint256 _proofid) external;

    /// @notice Full on-chain proof snapshot for indexing / UI.
    /// @return proofstate `S_ProofState` — see `L_Proof` for field meanings (position snapshots).
    function getProofState(
        uint256 proofid
    ) external view returns (S_ProofState memory);

    /// @notice Lightweight good snapshot (no commission mappings).
    function getGoodState(
        uint256 good
    ) external view returns (S_GoodTmpState memory);

    /// @notice Packed `(V, Q)` price snapshot for two goods in one call.
    /// @return good1currentstate `(V, Q)` for good1 — see `L_Good.getGoodState`.
    /// @return good2currentstate `(V, Q)` for good2.
    function getRecentGoodState(
        uint256 good1,
        uint256 good2
    )
        external
        view
        returns (uint256 good1currentstate, uint256 good2currentstate);

    /// @notice Accrued commission balances per good for `_recipient` (max 100 ids).
    /// @dev `address(0)` recipient reads protocol/platform commission slot.
    function queryCommission(
        uint256[] calldata _goodid,
        address _recipient
    ) external view returns (uint256[] memory);

    // ─────────────────────────── Admin / config ───────────────────────────

    /// @notice Good owner patches owner-writable config bits (fees, power, chips).
    function modifyGoodByGoodOwner(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @notice Market manager patches manager-writable bits (fee split, safe lines, flags).
    function modifyGoodByManager(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @notice Market admin patches admin bits (value-good flag, ERC type).
    function modifyGoodByAdmin(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @notice Freeze trading on a good (manager or good owner).
    function lockGood(
        uint256 _goodid,
        address _trader,
        bytes calldata signature
    ) external;

    /// @notice Transfer good ownership (market manager only).
    function changeGoodOwner(
        uint256 _goodid,
        address _to,
        address _trader,
        bytes calldata signature
    ) external;

    /// @notice Pull accrued commission for up to 100 goods to `msg.sender`.
    /// @dev Market admin collects platform slot (`recipient == address(0)` internally).
    function collectCommission(
        uint256[] calldata _goodid,
        address _trader,
        bytes calldata signature
    ) external;

    /// @notice Donate tokens to a pool's depth without minting shares (LP welfare).
    /// @param data1 Transfer authorization for the donated tokens.
    function goodWelfare(
        uint256 goodid,
        uint128 welfare,
        bytes calldata data1,
        address _trader,
        bytes calldata signature
    ) external payable;

    /// @notice Invalidate pending signed `buyGood` / `payGood` intents by bumping caller nonce.
    function cancelNonce() external;
}

// ─────────────────────────── Storage layouts ───────────────────────────

/// @notice LP position snapshot returned by `getProofState`.
/// @dev Packed fields use `TTSwapUINT256` encoding (amount0 high, amount1 low).
///      Not the same as global `goodConfig.amount1()` / `currentState` — these are per-proof snapshots.
/// @param currentgood Good id this proof is bound to.
/// @param shares amount0 = LP shares; amount1 = TTS stake value linked to proof.
/// @param state amount0 = virtual value; amount1 = actual value at proof ratios.
/// @param invest amount0 = virtual qty (`Q` leg at invest); amount1 = actual qty deposited (`investQty` leg).
struct S_ProofState {
    uint256 currentgood;
    uint256 shares;
    uint256 state;
    uint256 invest;
}

/// @notice Full good state in storage (includes mappings; not returned verbatim to callers).
/// @param goodConfig High bits = fee config; low 128 bits (`amount1()`) = leverage `virtualQty` only.
/// @param currentState amount0 = `investQty` (actual tokens); amount1 = `Q` (total virtual depth for AMM).
/// @param investState amount0 = total LP shares; amount1 = `V` (pool value, `price ≈ V/Q`).
/// @param commission Per-address accrued fee balances (1-unit sentinel after first collect).
struct S_GoodState {
    uint256 goodConfig;
    uint88 reserverd1; // commission config (reserved)
    uint8 erctype;
    address contractAddress;
    uint96 reserved2;
    address owner;
    uint256 id;
    address hookAddress;
    uint256 currentState;
    uint256 investState;
    uint256 extendsState1;
    uint256 extendsState2;
    uint256 extendsState3;
    uint256 extendsState4;
    uint256 extendsState5;
    uint256 extendsState6;
    uint256 extendsState7;
    uint256 extendsState8;
    uint256 extendsState9;
    mapping(address => uint256) commission;
    mapping(address => uint256) extendmapping1;
    mapping(address => uint256) extendmapping2;
    mapping(address => uint256) extendmapping3;
    mapping(address => uint256) extendmapping4;
    mapping(address => uint256) extendmapping5;
}

/// @notice Good snapshot returned by `getGoodState` (no mappings).
/// @dev Read `goodConfig.amount1()` for leverage `virtualQty`; `investState.amount1()` for `V`.
struct S_GoodTmpState {
    uint256 goodConfig;
    address owner;
    uint256 currentState;
    uint256 investState;
}

/// @notice Proof id derivation input: `proofId = keccak256(abi.encodePacked(owner, currentgood))` (64 bytes in memory).
struct S_ProofKey {
    address owner;
    uint256 currentgood;
}
