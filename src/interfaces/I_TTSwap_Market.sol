// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {T_GoodKey} from "../type/T_GoodKey.sol";

/// @title Market Management Interface
/// @notice Defines the interface for managing market operations
///  Only `buyGood` and `payGood` verify EIP-712 when `msg.sender != _trader`. On every other function
/// that includes `bytes calldata signature`, that parameter is **unused** (reserved for ABI / future relayer); callers must
/// pass `_trader == msg.sender` where the implementation enforces `_checkTrader`.
interface I_TTSwap_Market {
    /// @notice Emitted when a good's configuration is updated
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    event e_updateGoodConfig(
        uint256 indexed _goodid,
        uint256 _goodConfig,
        address _trader
    );

    /// @notice Emitted when a good's configuration is modified by market admin
    /// @param _goodid The ID of the good
    /// @param _goodconfig The new configuration
    event e_modifyGoodConfig(
        uint256 indexed _goodid,
        uint256 _goodconfig,
        address _trader
    );

    /// @notice Emitted when a good's owner is changed
    /// @param goodid The ID of the good
    /// @param to The new owner's address
    event e_changegoodowner(uint256 goodid, address to, address _trader);

    /// @notice Emitted when market commission is collected
    /// @param _goodid Array of good IDs
    /// @param _commisionamount Array of commission amounts
    event e_collectcommission(
        uint256[] _goodid,
        uint256[] _commisionamount,
        address _trader
    );

    /// @notice Emitted when welfare is delivered to investors
    /// @param goodid The ID of the good
    /// @param welfare The amount of welfare
    event e_goodWelfare(uint256 indexed goodid, uint128 welfare, address _trader);

    /// @notice Emitted when a one token is invested or created
    /// @dev The decimal precision of _initial.amount0() defaults to 6
    /// @param _proofNo The ID of the investment proof
    /// @param _goodid A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct
    /// @param _construct The stake construct of mint tts token
    /// @param _invest Market initialization parameters: amount0 is the value, amount1 is the quantity
    /// for verison <1.15.0
    event e_investGood(
        uint256 indexed _proofNo,
        uint256 indexed _goodid,
        uint256 _construct,
        uint256 _value,
        uint256 _invest,
        address _trader
    );

    /// @notice Emitted when a good is created and initialized
    /// @param _proofNo The ID of the investment proof
    /// @param _goodid The ID of the good
    /// @param _normalinitial Normal good initialization parameters: amount0 is the quantity, amount1 is the value
    /// for verison <1.15.0
    event e_initGood(
        uint256 indexed _proofNo,
        uint256 indexed _goodid,
        uint256 _goodinfo,
        uint256 _good_id,
        uint256 _normalinitial,
        address _trader
    );

    /// @notice Emitted when a user buys a good
    /// @param sellgood The ID of the good being sold
    /// @param forgood The ID of the good being bought
    /// @param swapvalue The trade value
    /// @param good1change The status of the sold good (amount0: fee, amount1: quantity)
    /// @param good2change The status of the bought good (amount0: fee, amount1: quantity)
    /// @param external_info External business metadata (e.g., payment order id or other extra info).
    event e_buyGood(
        uint256 indexed sellgood,
        uint256 indexed forgood,
        uint256 swapvalue,
        uint256 good1change,
        uint256 good2change,
        address _trader,
        uint256 external_info
    );
    // /// @notice Emitted when a user makes a payment using goods
    // /// @param sellgood The ID of the good being sold/used for payment
    // /// @param forgood The ID of the good being received
    // /// @param swapvalue The trade value
    // /// @param good1change The status of the sold good (amount0: fee, amount1: quantity)
    // /// @param good2change The status of the received good (amount0: fee, amount1: quantity)
    // /// @param _trader The address of the trader initiating the payment
    // /// @param external_info The hash of the transaction data for verification
    // event e_payGood(
    //     uint256 indexed sellgood,
    //     uint256 indexed forgood,
    //     uint256 swapvalue,
    //     uint256 good1change,
    //     uint256 good2change,
    //     address _trader,
    //     address _recipient,
    //     uint256 external_info
    // );



    /// @notice Emitted when a user disinvests from  good
    /// @param _proofNo The ID of the investment proof
    /// @param _normalGoodNo The ID of the normal good
    /// @param _gate The gate of User
    /// @param _value amount0: virtual disinvest value,amount1: actual disinvest value
    /// @param _normalprofit amount0:normalgood profit,amount1:normalgood disvest virtual quantity
    /// @param _normaldisvest The disinvestment details of the normal good (amount0: actual fee, amount1: actual disinvest quantity)
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

    event e_getPromiseProof(uint256 indexed _goodid, uint256 _proofid);
    function nonces(address _trader) external view returns (uint256);

    /// @notice Initialize a new good with single-token deposit at a user-specified price
    /// @param _goodKey The address of the ERC20 token representing the new good
    /// @param _initial amount0: user-specified total value, amount1: token quantity to deposit
    /// @param _normaldata The data for transferring the normal good (Permit/Transfer)
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param _signature Reserved for ABI compatibility; **not verified** here.
    function initGood(
        T_GoodKey memory _goodKey,
        uint256 _initial,
        bytes memory _normaldata,
        address _trader,
        bytes calldata _signature
    ) external payable returns (bool);

    /// @notice Add single-token liquidity to an existing good without pairing a value good.
    /// @dev The caller deposits only the target token; its credited value is derived from
    ///      the current pool price and scaled by the leverage factor (`enpower`).
    ///      Flow: checkInvest (price guard) → transfer tokens in → compute virtual shares
    ///      → update good state → update/create proof → stake value to TTS.
    ///      Reverts with TTSwapError(47) if the deposit price exceeds the current pool price,
    ///      TTSwapError(38) if the resulting investment value is below the dust threshold.
    /// @param _goodid  Address of the ERC-20 token (good) to invest in.
    /// @param _invest  Packed uint256 — amount0: credited value per unit, amount1: token quantity to deposit.
    /// @param _gooddata  Encoded transfer authorisation (plain approve / EIP-2612 / Permit2).
    /// @param signature Reserved for ABI compatibility; **not verified** here (C-01 scheme B).
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @return bool  True on success.
    function investGood(
        T_GoodKey memory _goodid,
        uint256 _invest,
        bytes calldata _gooddata,
        bytes calldata signature,
        address _trader
    ) external payable returns (bool);

    /**
     * @dev Buys a good
     * @param _goodKey1 The ID of the first good
     * @param _goodKey2 The ID of the second good
     * @param _swapQuantity The amount of _goodid1 to swap
     *        - amount0: The quantity of the input good
     *        - amount1: The minimum gross quantity of the output good before any relayer execution fee
     * @param _referral when side is buy, _referral is the referral address when side is sell, _referral is the address to receive the fee
     * @param data Encoded transfer authorization for the input token (Permit/Transfer).
     * @param _trader The trader; `msg.sender` may be a relayer distinct from `_trader` when `signature` is valid.
     * @param signature EIP-712 signature over the buy payload; **verified** when `msg.sender != _trader`.
     * @param external_info External business metadata (e.g., payment order id or other extra info).
     * @return good1change amount0() good1tradefee,good1tradeamount
     * @return good2change amount0() good1tradefee,good2tradeamount
     */
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

    // /**
    //  * @notice Pays a fixed gross output amount using inverse pricing.
    //  * @param _goodKey1 Input good id (payer side).
    //  * @param _goodKey2 Output good id (recipient side).
    //  * @param _swapQuantity Packed swap params:
    //  *        - amount0: max input limit.
    //  *        - amount1: target gross output amount before any relayer execution fee.
    //  * @param _recipient Address receiving output good. In relayer mode, net delivery may be lower because execution fee is deducted from gross output.
    //  * @param data Additional transfer data for input token (Permit/Transfer).
    //  * @param _trader The trader; `msg.sender` may be a relayer distinct from `_trader` when `signature` is valid.
    //  * @param signature EIP-712 signature over the pay payload; **verified** when `msg.sender != _trader`.
    //  * @param external_info External business metadata (e.g., payment order id or other extra info).
    //  * @return good1change Packed input-side change.
    //  * @return good2change Packed output-side change.
    //  */
    // function payGood(
    //     T_GoodKey memory _goodKey1,
    //     T_GoodKey memory _goodKey2,
    //     uint256 _swapQuantity,
    //     address _recipient,
    //     bytes calldata data,
    //     address _trader,
    //     bytes calldata signature,
    //     uint256 external_info
    // ) external payable returns (uint256 good1change, uint256 good2change);

    /// @notice Disinvest from a normal good
    /// @param _proofid ID of the investment proof
    /// @param _goodQuantity Quantity to disinvest
    /// @param _gate Address of the gate
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return reward1 status
    function disinvestProof(
        uint256 _proofid,
        uint128 _goodQuantity,
        address _gate,
        address _trader,
        bytes calldata signature
    ) external returns (uint128 reward1);

    /// @notice Check if the price of a good is higher than a comparison price
    /// @param goodid ID of the good to check
    /// @param valuegood ID of the value good
    /// @param compareprice Price to compare against
    /// @return Whether the good's price is higher
    function ishigher(
        uint256 goodid,
        uint256 valuegood,
        uint256 compareprice
    ) external view returns (bool);

    /// @notice Signal for claimable proof on applied goods; **only** `msg.sender` as proof owner (no relayer, no EIP-712). See C-01 / M-08.
    function refreshPromise(uint256 _proofid) external;

    /// @notice Retrieves the current state of a proof
    /// @param proofid The ID of the proof to query
    /// @return proofstate The current state of the proof,
    ///  currentgood The current good associated with the proof
    ///  valuegood The value good associated with the proof
    ///  shares normal good shares, value good shares
    ///  state Total value, Total actual value
    ///  invest normal good virtual quantity, normal good actual quantity
    ///  valueinvest value good virtual quantity, value good actual quantity
    function getProofState(
        uint256 proofid
    ) external view returns (S_ProofState memory);

    /// @notice Retrieves the current state of a good
    /// @param good The address of the good to query
    /// @return goodstate The current state of the good,
    ///  goodConfig Configuration of the good, check goodconfig.sol or whitepaper for details
    ///  owner Creator of the good
    ///  currentState Present investQuantity, CurrentQuantity
    ///  investState Shares, value
    function getGoodState(
        uint256 good
    ) external view returns (S_GoodTmpState memory);

    /// @notice Updates a good's configuration
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    function modifyGoodByGoodOwner(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @notice Allows market admin to modify a good's attributes
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    function modifyGoodByManager(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    /// @return Success status
    function modifyGoodByAdmin(
        uint256 _goodid,
        uint256 _goodConfig,
        address _trader,
        bytes calldata signature
    ) external returns (bool);

    /// @param _goodid The good to lock
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    function lockGood(
        uint256 _goodid,
        address _trader,
        bytes calldata signature
    ) external;

    /// @notice Changes the owner of a good
    /// @param _goodid The ID of the good
    /// @param _to The new owner's address
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    function changeGoodOwner(
        uint256 _goodid,
        address _to,
        address _trader,
        bytes calldata signature
    ) external;

    /// @notice Collects commission for specified goods
    /// @param _goodid Array of good IDs
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    function collectCommission(
        uint256[] calldata _goodid,
        address _trader,
        bytes calldata signature
    ) external;

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
    function queryCommission(
        uint256[] calldata _goodid,
        address _recipient
    ) external returns (uint256[] memory);

    /// @notice Delivers welfare to investors
    /// @param goodid The ID of the good
    /// @param welfare The amount of welfare
    /// @param data1 Transfer data for the token
    /// @param _trader Must equal `msg.sender` (enforced by `_checkTrader`).
    /// @param signature Reserved for ABI compatibility; **not verified** here.
    function goodWelfare(
        uint256 goodid,
        uint128 welfare,
        bytes calldata data1,
        address _trader,
        bytes calldata signature
    ) external payable;

    /**
     * @notice Retrieves the current state of two goods in a single call
     * @dev Retrieves the current state of two goods in a single call
     * @param good1 The address of the first good to query
     * @param good2 The address of the second good to query
     * @return good1correntstate The current state of the first good, representing its latest trading iteration,amount0:good current value,amount1:good current quantity
     * @return good2correntstate The current state of the second good, representing its latest trading iteration,amount0:good current value,amount1:good current quantity
     */
    function getRecentGoodState(
        uint256 good1,
        uint256 good2
    )
        external
        view
        returns (uint256 good1correntstate, uint256 good2correntstate);

    /// @notice Allows users to proactively increment the nonce to invalidate previously signed offline代付 signatures
    function cancelNonce() external;
}

/**
 * @dev Represents the state of a proof.
 * @notice Fields:
 * - `currentgood`: The current good associated with the proof
 * - `shares`: amount0 = normal good shares, amount1 :mint tts value
 * - `state`: amount0 = total value, amount1 = total actual value
 * - `invest`: amount0 = normal good virtual quantity, amount1 = normal good actual quantity
 */
struct S_ProofState {
    uint256 currentgood;
    uint256 shares;
    uint256 state;
    uint256 invest;
}

/**
 * @dev Struct representing the state of a good.
 * @notice Fields:
 * - `goodConfig`: amount0 = configuration settings, amount1 = total virtual quantity
 * - `owner`: Creator of the good
 * - `currentState`: Present invest quantity and current quantity
 * - `investState`: Shares and value aggregates
 */
struct S_GoodState {
    uint256 goodConfig;
    uint88 reserverd1; //commission config
    uint8 erctype;
    address contractAddress;
    uint96 reserved2; //  contract type,asset type,contract saddress
    address owner;
    uint256 id;
    uint256 currentState; //amount0:Present actual invest quantity, amount1:Present current virtual quantity
    uint256 investState; //amount0:shares, amount1:value
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

/**
 * @dev Struct representing a temporary state of a good.
 * @notice Fields mirror `S_GoodState` but store lightweight snapshots:
 * - `goodConfig`: amount0 = configuration settings, amount1 = total virtual quantity
 * - `owner`: Creator of the good
 * - `currentState`: Present invest quantity and current quantity
 * - `investState`: Shares and value aggregates
 */
struct S_GoodTmpState {
    uint256 goodConfig;
    address owner;
    uint256 currentState;
    uint256 investState;
}

/**
 * @dev Struct representing a key of a proof.
 * @notice Fields:
 * - `owner`: The owner of the proof
 * - `currentgood`: The current good associated with the proof
 * - `valuegood`: The value good associated with the proof
 */
struct S_ProofKey {
    address owner;
    uint256 currentgood;
}
