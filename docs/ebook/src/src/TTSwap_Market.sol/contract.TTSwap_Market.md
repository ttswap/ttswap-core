# TTSwap_Market
**Inherits:**
[I_TTSwap_Market](/src/interfaces/I_TTSwap_Market.sol/interface.I_TTSwap_Market.md), [IMulticall_v4](/src/interfaces/IMulticall_v4.sol/interface.IMulticall_v4.md)

**Author:**
ttswap.exchange@gmail.com

This contract implements a decentralized market system with the following key features:
- Meta good, value goods, and normal goods management
- Automated market making (AMM) with configurable fees
- Investment and disinvestment mechanisms
- Commission distribution system

*Core market contract for TTSwap protocol that manages goods trading, investing, and staking operations*


## State Variables
### TTS_CONTRACT
Handles:
- Minting rewards for market participation
- Staking operations and rewards
- Referral tracking and rewards
- Governance token functionality

*Address of the official TTS token contract*


```solidity
I_TTSwap_Token private immutable TTS_CONTRACT;
```


### securitykeeper
Address of the security keeper

*The address of the security keeper*

**Notes:**
- security: The address of the security keeper when deploy market contract

- security: The address of the security keeper will be removed by market admin when contract run safety


```solidity
address internal securitykeeper;
```


### goods
Stores the complete state of each good including:
- Current trading state(invest quantity & current quantity)
- Investment state (invest shares & invest value)
- Owner information
- Configuration parameters

*Mapping of good addresses to their state information*


```solidity
mapping(address goodid => S_GoodState) private goods;
```


### proofs
Records all investment proofs in the system:
shares amount0:normal good shares amount1:value good shares
state amount0:total value : amount1:total actual value
invest amount0:normal good virtual quantity amount1:normal good actual quantity
valueinvest amount0:value good virtual quantity amount1:value good actual quantity

*Mapping of proof IDs to their state information*


```solidity
mapping(uint256 proofid => S_ProofState) private proofs;
```


## Functions
### constructor

*Constructor for TTSwap_Market*


```solidity
constructor(I_TTSwap_Token _TTS_Contract, address _securitykeeper);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TTS_Contract`|`I_TTSwap_Token`|The address of the official token contract|
|`_securitykeeper`|`address`|The address of the security keeper|


### onlyMarketadmin

only market admin can execute


```solidity
modifier onlyMarketadmin();
```

### onlyMarketor

only market manager can execute


```solidity
modifier onlyMarketor();
```

### msgValue

run when eth token transfer to market contract


```solidity
modifier msgValue();
```

### noReentrant

This will revert if the contract is locked


```solidity
modifier noReentrant();
```

### multicall

Enables calling multiple methods in a single call to the contract

*The `msg.value` is passed onto all subcalls, even if a previous subcall has consumed the ether.
Subcalls can instead use `address(this).value` to see the available ETH, and consume it using {value: x}.*


```solidity
function multicall(bytes[] calldata data) external payable msgValue returns (bytes[] memory results);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes[]`|The encoded function data for each of the calls to make to this contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`results`|`bytes[]`|The results from each of the calls passed in via data|


### initMetaGood

This function:
- Creates a new meta good with specified parameters
- Sets up initial liquidity pool
- Mints corresponding tokens to the market creator
- Initializes proof tracking
- Emits initialization events

*Initializes a meta good with initial liquidity*

**Note:**
security: Only callable by market admin


```solidity
function initMetaGood(address _erc20address, uint256 _initial, uint256 _goodConfig, bytes calldata data)
    external
    payable
    onlyMarketadmin
    msgValue
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_erc20address`|`address`|The address of the ERC20 token to be used as the meta good|
|`_initial`|`uint256`|The initial liquidity amounts: - amount0: Initial token value - amount1: Initial token amount|
|`_goodConfig`|`uint256`|Configuration parameters for the good: - Fee rates (trading, investment) - Trading limits (min/max amounts) - Special flags ( emergency pause)|
|`data`|`bytes`|Additional data for token transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Success status of the initialization|


### initGood

Initialize a normal good in the market

*Initializes a good*


```solidity
function initGood(
    address _valuegood,
    uint256 _initial,
    address _erc20address,
    uint256 _goodConfig,
    bytes calldata _normaldata,
    bytes calldata _valuedata
) external payable override noReentrant msgValue returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_valuegood`|`address`|The value good ID|
|`_initial`|`uint256`|The initial balance,amount0 is the amount of the normal good,amount1 is the amount of the value good|
|`_erc20address`|`address`|The address of the ERC20 token|
|`_goodConfig`|`uint256`|The good configuration|
|`_normaldata`|`bytes`|The data of the normal good|
|`_valuedata`|`bytes`|The data of the value good|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Returns true if successful|


### buyGood

This function:
- Calculates optimal swap amounts using AMM formulas
- Applies trading fees and updates fee states
- Updates good states and reserves
- Handles referral rewards and distributions
- Emits trade events with detailed information

*Executes a buy order between two goods*

**Notes:**
- security: Protected by reentrancy guard

- security: Validates input parameters and state


```solidity
function buyGood(
    address _goodid1,
    address _goodid2,
    uint256 _swapQuantity,
    uint128 _side,
    address _recipent,
    bytes calldata data
) external payable noReentrant msgValue returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid1`|`address`|The address of the input good|
|`_goodid2`|`address`|The address of the output good|
|`_swapQuantity`|`uint256`|The amount of _goodid1 to swap - amount0: The quantity of the input good - amount1: The limit quantity of the output good|
|`_side`|`uint128`|0:for pay 1for buy|
|`_recipent`|`address`|The address to receive referral rewards|
|`data`|`bytes`|Additional data for token transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|The amount of _goodid1 used: - amount0: Trading fees - amount1: Actual swap amount|
|`good2change`|`uint256`|The amount of _goodid2 received: - amount0: Trading fees - amount1: Actual received amount|


### buyGoodCheck

This function:
- Simulates the buyGood operation without executing it
- Uses the same AMM formulas as buyGood
- Validates input parameters and market state
- Returns expected amounts including fees
- Useful for frontend price quotes and transaction previews

*Simulates a buy order between two goods to check expected amounts*

**Notes:**
- security: View function, does not modify state

- security: Reverts if:
- Either good is not initialized
- Swap quantity is zero
- Same good is used for both input and output
- Trade times exceeds 200
- Insufficient liquidity for the swap


```solidity
function buyGoodCheck(address _goodid1, address _goodid2, uint256 _swapQuantity, bool _side)
    external
    view
    returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid1`|`address`|The address of the input good|
|`_goodid2`|`address`|The address of the output good|
|`_swapQuantity`|`uint256`|The amount of _goodid1 to swap - amount0: The quantity of the input good - amount1: The limit quantity of the output good|
|`_side`|`bool`|1:for buy 0:for pay|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|The expected amount of _goodid1 to be used: - amount0: Expected trading fees - amount1: Expected swap amount|
|`good2change`|`uint256`|The expected amount of _goodid2 to be received: - amount0: Expected trading fees - amount1: Expected received amount|


### investGood

This function:
- Processes investment in the target good
- Optionally processes value good investment
- Updates proof state
- Mints corresponding tokens
- Calculates and distributes fees

*Invests in a good with optional value good backing*


```solidity
function investGood(address _togood, address _valuegood, uint128 _quantity, bytes calldata data1, bytes calldata data2)
    external
    payable
    override
    noReentrant
    msgValue
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_togood`|`address`|The address of the good to invest in|
|`_valuegood`|`address`|The address of the value good (can be address(0))|
|`_quantity`|`uint128`|The amount to invest _togood|
|`data1`|`bytes`|Additional data for _togood transfer|
|`data2`|`bytes`|Additional data for _valuegood transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Success status of the investment|


### disinvestProof

This function:
- Validates proof ownership and state
- Processes disinvestment for both normal and value goods
- Handles commission distribution and fee collection
- Updates proof state and burns tokens
- Distributes rewards to gate and referrer
- Unstakes TTS tokens

*Disinvests from a proof by withdrawing invested tokens and collecting profits*

**Notes:**
- security: Protected by noReentrant modifier

- security: Reverts if:
- Proof ID does not match sender's proof
- Invalid proof state
- Insufficient balance for disinvestment


```solidity
function disinvestProof(uint256 _proofid, uint128 _goodshares, address _gate)
    external
    override
    noReentrant
    returns (uint128, uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofid`|`uint256`|The ID of the proof to disinvest from|
|`_goodshares`|`uint128`||
|`_gate`|`address`|The address to receive gate rewards (falls back to DAO admin if banned)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|uint128 The profit amount from normal good disinvestment|
|`<none>`|`uint128`|uint128 The profit amount from value good disinvestment (if applicable)|


### ishigher

This function:
- Compares the current trading iterations (states) of two goods
- Used to determine the trading order and eligibility for operations
- Essential for maintaining trading synchronization between goods
- Returns false if either good is not registered (state = 0)

*Compares the current trading states of two goods to determine if the first good is in a higher iteration*

**Notes:**
- security: This is a view function with no state modifications

- security: Returns false for unregistered goods to prevent invalid operations


```solidity
function ishigher(address goodid, address valuegood, uint256 compareprice) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|ID of the good to check|
|`valuegood`|`address`|ID of the value good|
|`compareprice`|`uint256`|the price of use good2 for good1|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Returns true if good1's current state is higher than good2's, false otherwise|


### getRecentGoodState

This function is a view function that:
- Returns the current trading iteration (state) for both goods
- Useful for checking the latest trading status of a pair of goods
- Can be used to verify if goods are in sync for trading operations

*Retrieves the current state of two goods in a single call*

**Notes:**
- security: This is a view function with no state modifications

- security: Returns 0 if either good address is not registered


```solidity
function getRecentGoodState(address good1, address good2)
    external
    view
    override
    returns (uint256 good1currentstate, uint256 good2currentstate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`good1`|`address`|The address of the first good to query|
|`good2`|`address`|The address of the second good to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1currentstate`|`uint256`|good1correntstate The current state of the first good, representing its latest trading iteration|
|`good2currentstate`|`uint256`|good2correntstate The current state of the second good, representing its latest trading iteration|


### getProofState

Retrieves the current state of a proof


```solidity
function getProofState(uint256 proofid) external view override returns (S_ProofState memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proofid`|`uint256`|The ID of the proof to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`S_ProofState`|proofstate The current state of the proof, currentgood The current good associated with the proof valuegood The value good associated with the proof shares normal good shares, value good shares state Total value, Total actual value invest normal good virtual quantity, normal good actual quantity valueinvest value good virtual quantity, value good actual quantity|


### getGoodState

Retrieves the current state of a good


```solidity
function getGoodState(address good) external view override returns (S_GoodTmpState memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`good`|`address`|The address of the good to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`S_GoodTmpState`|goodstate The current state of the good, goodConfig Configuration of the good, check goodconfig.sol or whitepaper for details owner Creator of the good currentState Present investQuantity, CurrentQuantity investState Shares, value|


### updateGoodConfig

Updates a good's configuration


```solidity
function updateGoodConfig(address _goodid, uint256 _goodConfig) external override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### modifyGoodConfig

Allows market admin to modify a good's attributes


```solidity
function modifyGoodConfig(address _goodid, uint256 _goodConfig) external override onlyMarketor returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### changeGoodOwner

Changes the owner of a good


```solidity
function changeGoodOwner(address _goodid, address _to) external override onlyMarketor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_to`|`address`|The new owner's address|


### collectCommission

Collects commission for specified goods


```solidity
function collectCommission(address[] calldata _goodid) external override noReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address[]`|Array of good IDs|


### queryCommission

This function:
- Returns commission amounts for up to 100 goods in a single call
- Each amount represents the commission available for the recipient
- Returns 0 for goods where no commission is available
- Maintains gas efficiency by using a fixed array size

*Queries commission amounts for multiple goods for a specific recipient*

**Notes:**
- security: Reverts if more than 100 goods are queried

- security: View function, does not modify state


```solidity
function queryCommission(address[] calldata _goodid, address _recipent)
    external
    view
    override
    returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address[]`|Array of good addresses to query commission for|
|`_recipent`|`address`|The address to check commission amounts for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|feeamount Array of commission amounts corresponding to each good|


### goodWelfare

This function:
- Allows anyone to contribute additional funds to a good's fee pool
- Increases the good's feeQuantityState by the welfare amount
- Transfers tokens from the sender to the good
- Emits an event with the welfare contribution details

*Adds welfare funds to a good's fee pool*

**Notes:**
- security: Protected by noReentrant modifier

- security: Checks for overflow in feeQuantityState


```solidity
function goodWelfare(address goodid, uint128 welfare, bytes calldata data)
    external
    payable
    override
    noReentrant
    msgValue;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|The address of the good to receive welfare|
|`welfare`|`uint128`|The amount of tokens to add as welfare|
|`data`|`bytes`|Additional data for token transfer|


### removeSecurityKeeper


```solidity
function removeSecurityKeeper() external onlyMarketadmin;
```

### securityKeeper


```solidity
function securityKeeper(address erc20) external noReentrant;
```

