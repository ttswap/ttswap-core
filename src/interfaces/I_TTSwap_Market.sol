// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {toTTSwapUINT256, addsub, subadd} from "../libraries/L_TTSwapUINT256.sol";

/// @title Market Management Interface
/// @notice Defines the interface for managing market operations
interface I_TTSwap_Market {
   
    /// @notice Emitted when a good's configuration is updated
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    event e_updateGoodConfig(address _goodid, uint256 _goodConfig);

    /// @notice Emitted when a good's configuration is modified by market admin
    /// @param _goodid The ID of the good
    /// @param _goodconfig The new configuration
    event e_modifyGoodConfig(address _goodid, uint256 _goodconfig);

    /// @notice Emitted when a good's owner is changed
    /// @param goodid The ID of the good
    /// @param to The new owner's address
    event e_changegoodowner(address goodid, address to);

    /// @notice Emitted when market commission is collected
    /// @param _gooid Array of good IDs
    /// @param _commisionamount Array of commission amounts
    event e_collectcommission(address[] _gooid, uint256[] _commisionamount);

    /// @notice Emitted when welfare is delivered to investors
    /// @param goodid The ID of the good
    /// @param welfare The amount of welfare
    event e_goodWelfare(address goodid, uint128 welfare);

    /// @notice Emitted when protocol fee is collected
    /// @param goodid The ID of the good
    /// @param feeamount The amount of fee collected
    event e_collectProtocolFee(address goodid, uint256 feeamount);


    /// @notice Emitted when a meta good is created and initialized
    /// @dev The decimal precision of _initial.amount0() defaults to 6
    /// @param _proofNo The ID of the investment proof
    /// @param _goodid A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct
    /// @param _construct A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct
    /// @param _goodConfig The configuration of the meta good (refer to the whitepaper for details)
    /// @param _initial Market initialization parameters: amount0 is the value, amount1 is the quantity
    event e_initMetaGood(uint256 _proofNo, address _goodid, uint256 _construct, uint256 _goodConfig, uint256 _initial);

    /// @notice Emitted when a good is created and initialized
    /// @param _proofNo The ID of the investment proof
    /// @param _goodid A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct
    /// @param _construct A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct
    /// @param _valuegoodNo The ID of the good
    /// @param _goodConfig The configuration of the meta good (refer to the whitepaper for details)
    /// @param _normalinitial Normal good initialization parameters: amount0 is the quantity, amount1 is the value
    /// @param _value Value good initialization parameters: amount0 is the investment fee, amount1 is the investment quantity
    event e_initGood(
        uint256 _proofNo,
        address _goodid,
        address _valuegoodNo,
        uint256 _goodConfig,
        uint256 _construct,
        uint256 _normalinitial,
        uint256 _value
    );

    /// @notice Emitted when a user buys a good
    /// @param sellgood The ID of the good being sold
    /// @param forgood The ID of the good being bought
    /// @param swapvalue The trade value
    /// @param good1change The status of the sold good (amount0: fee, amount1: quantity)
    /// @param good2change The status of the bought good (amount0: fee, amount1: quantity)
    event e_buyGood(
        address indexed sellgood, address indexed forgood, uint256 swapvalue, uint256 good1change, uint256 good2change
    );

    /// @notice Emitted when a user invests in a normal good
    /// @param _proofNo The ID of the investment proof
    /// @param _normalgoodid Packed data: first 128 bits for good's ID, last 128 bits for stake construct
    /// @param _valueGoodNo The ID of the value good
    /// @param _value Investment value (amount0: invest value, amount1: restake construct)
    /// @param _invest Normal good investment details (amount0: actual fee, amount1: actual invest quantity)
    /// @param _valueinvest Value good investment details (amount0: actual fee, amount1: actual invest quantity)
    event e_investGood(
        uint256 indexed _proofNo,
        address _normalgoodid,
        address _valueGoodNo,
        uint256 _value,
        uint256 _invest,
        uint256 _valueinvest
    );

    /// @notice Emitted when a user disinvests from a normal good
    /// @param _proofNo The ID of the investment proof
    /// @param _normalGoodNo The ID of the normal good
    /// @param _valueGoodNo The ID of the value good
    /// @param _gate The gate of User
    /// @param _normalgood The disinvestment details of the normal good (amount0: actual fee, amount1: actual disinvest quantity)
    /// @param _valuegood The disinvestment details of the value good (amount0: actual fee, amount1: actual disinvest quantity)
    /// @param _profit The profit (amount0: normal good profit, amount1: value good profit)
    event e_disinvestProof(
        uint256 indexed _proofNo,
        address _normalGoodNo,
        address _valueGoodNo,
        address _gate,
        uint256 _value,
        uint256 _normalgood,
        uint256 _valuegood,
        uint256 _profit
    );

   
    /// @notice Initialize the first good in the market
    /// @param _erc20address The contract address of the good
    /// @param _initial Initial parameters for the good (amount0: value, amount1: quantity)
    /// @param _goodconfig Configuration of the good
    /// @param data Configuration of the good
    /// @return Success status
    function initMetaGood(address _erc20address, uint256 _initial, uint256 _goodconfig, bytes calldata data)
        external
        payable
        returns (bool);

    /// @notice Initialize a normal good in the market
    /// @param _valuegood The ID of the value good used to measure the normal good's value
    /// @param _initial Initial parameters (amount0: normal good quantity, amount1: value good quantity)
    /// @param _erc20address The contract address of the good
    /// @param _goodConfig Configuration of the good
    /// @param data1 Configuration of the good
    /// @param data2 Configuration of the good
    /// @return Success status
    function initGood(
        address _valuegood,
        uint256 _initial,
        address _erc20address,
        uint256 _goodConfig,
        bytes calldata data1,
        bytes calldata data2
    ) external payable returns (bool);

    /**
     * @dev Buys a good
     * @param _goodid1 The ID of the first good
     * @param _goodid2 The ID of the second good
     * @param _swapQuantity The quantity to swap
     * @param _tradetimes trade times
     * @param _referal The referral address
     * @return good1change amount0() good1tradefee,good1tradeamount
     * @return good2change amount0() good1tradefee,good2tradeamount
     */
    function buyGood(
        address _goodid1,
        address _goodid2,
        uint128 _swapQuantity,
        uint128 _tradetimes,
        address _referal,
        bytes calldata data
    ) external payable returns (uint256 good1change, uint256 good2change);

    /**
     * @dev check before buy good
     * @param _goodid1 The ID of the first good
     * @param _goodid2 The ID of the second good
     * @param _swapQuantity The quantity to swap
     * @param _tradetimes trade times
     * @return good1change amount0()good1tradeamount,good1tradefee
     * @return good2change amount0()good2tradeamount,good2tradefee
     */
    function buyGoodCheck(address _goodid1, address _goodid2, uint128 _swapQuantity, uint128 _tradetimes)
        external
        view
        returns (uint256 good1change, uint256 good2change);

    /// @notice Invest in a normal good
    /// @param _togood ID of the normal good to invest in
    /// @param _valuegood ID of the value good
    /// @param _quantity Quantity of normal good to invest
    /// @return Success status
    function investGood(
        address _togood,
        address _valuegood,
        uint128 _quantity,
        bytes calldata data1,
        bytes calldata data2
    ) external payable returns (bool);

    /// @notice Disinvest from a normal good
    /// @param _proofid ID of the investment proof
    /// @param _goodQuantity Quantity to disinvest
    /// @param _gate Address of the gate
    /// @return reward1 status
    /// @return reward2 status
    function disinvestProof(uint256 _proofid, uint128 _goodQuantity, address _gate)
        external
        returns (uint128 reward1, uint128 reward2);

    /// @notice Check if the price of a good is higher than a comparison price
    /// @param goodid ID of the good to check
    /// @param valuegood ID of the value good
    /// @param compareprice Price to compare against
    /// @return Whether the good's price is higher
    function ishigher(address goodid, address valuegood, uint256 compareprice) external view returns (bool);

    function getProofState(uint256 proofid) external view returns (S_ProofState memory);

    function getGoodState(address goodkey) external view returns (S_GoodTmpState memory);

    /// @notice Updates a good's configuration
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @return Success status
    function updateGoodConfig(address _goodid, uint256 _goodConfig) external returns (bool);

    /// @notice Allows market admin to modify a good's attributes
    /// @param _goodid The ID of the good
    /// @param _goodConfig The new configuration
    /// @return Success status
    function modifyGoodConfig(address _goodid, uint256 _goodConfig) external returns (bool);

    /// @notice Changes the owner of a good
    /// @param _goodid The ID of the good
    /// @param _to The new owner's address
    function changeGoodOwner(address _goodid, address _to) external;

    /// @notice Collects commission for specified goods
    /// @param _goodid Array of good IDs
    function collectCommission(address[] memory _goodid) external;

    /// @notice Queries commission for specified goods and recipient
    /// @param _goodid Array of good IDs
    /// @param _recipent The recipient's address
    /// @return Array of commission amounts
    function queryCommission(address[] memory _goodid, address _recipent) external returns (uint256[] memory);

    


    /// @notice Delivers welfare to investors
    /// @param goodid The ID of the good
    /// @param welfare The amount of welfare
    function goodWelfare(address goodid, uint128 welfare, bytes calldata data1) external payable;
    function unstakeETH(address token, uint128 amount) external;
    function stakeETH(address token, uint128 amount) external;
    function syncReward(address token) external;
    function changeReStakingContrat(address _target) external;
    function getRecentGoodState(address good1, address good2)
        external
        view
        returns (uint256 good1correntstate, uint256 good2correntstate);
}
/**
 * @dev Represents the state of a proof
 * @member currentgood The current good  associated with the proof
 * @member valuegood The value good associated with the proof
 * @member state amount0 (first 128 bits) represents total value
 * @member invest amount0 (first 128 bits) represents invest normal good quantity, amount1 (last 128 bits) represents normal good constuct fee when investing
 * @member valueinvest amount0 (first 128 bits) represents invest value good quantity, amount1 (last 128 bits) represents value good constuct fee when investing
 */

struct S_ProofState {
    address currentgood;
    address valuegood;
    uint256 state;
    uint256 invest;
    uint256 valueinvest;
}
/**
 * @dev Struct representing the state of a good
 */

struct S_GoodState {
    uint256 goodConfig; // Configuration of the good
    address owner; // Creator of the good
    uint256 currentState; // Current state: amount0 (first 128 bits) represents total value, amount1 (last 128 bits) represents quantity
    uint256 investState; // Investment state: amount0 represents total invested value, amount1 represents total invested quantity
    uint256 feeQuantityState; // Fee state: amount0 represents total fees (including construction fees), amount1 represents total construction fees
    uint256 extend1;
    uint256 extend2;
    uint256 extend3;
    uint256 extend4;
    uint256 extend5;    
    mapping(address => uint256) commission;
}
/**
 * @dev Struct representing a temporary state of a good
 */

struct S_GoodTmpState {
    uint256 goodConfig; // Configuration of the good
    address owner; // Creator of the good
    uint256 currentState; // Current state: amount0 (first 128 bits) represents total value, amount1 (last 128 bits) represents quantity
    uint256 investState; // Investment state: amount0 represents total invested value, amount1 represents total invested quantity
    uint256 feeQuantityState; // Fee state: amount0 represents total fees (including construction fees), amount1 represents total construction fees
}

struct S_ProofKey {
    address owner;
    address currentgood;
    address valuegood;
}

struct S_LoanProof {
    uint256 amount; //first 128 bit amount ,last 128 bit store feerate
}
