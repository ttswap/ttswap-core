# I_TTSwap_Market
Defines the interface for managing market operations


## Functions
### initMetaGood

Initialize the first good in the market


```solidity
function initMetaGood(address _erc20address, uint256 _initial, uint256 _goodconfig, bytes calldata data)
    external
    payable
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_erc20address`|`address`|The contract address of the good|
|`_initial`|`uint256`|Initial parameters for the good (amount0: value, amount1: quantity)|
|`_goodconfig`|`uint256`|Configuration of the good|
|`data`|`bytes`|Configuration of the good|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### initGood

Initialize a normal good in the market


```solidity
function initGood(
    address _valuegood,
    uint256 _initial,
    address _erc20address,
    uint256 _goodConfig,
    bytes calldata data1,
    bytes calldata data2
) external payable returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_valuegood`|`address`|The ID of the value good used to measure the normal good's value|
|`_initial`|`uint256`|Initial parameters (amount0: normal good quantity, amount1: value good quantity)|
|`_erc20address`|`address`|The contract address of the good|
|`_goodConfig`|`uint256`|Configuration of the good|
|`data1`|`bytes`|Configuration of the good|
|`data2`|`bytes`|Configuration of the good|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### buyGood

*Buys a good*


```solidity
function buyGood(
    address _goodid1,
    address _goodid2,
    uint256 _swapQuantity,
    uint128 _side,
    address _referal,
    bytes calldata data
) external payable returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid1`|`address`|The ID of the first good|
|`_goodid2`|`address`|The ID of the second good|
|`_swapQuantity`|`uint256`|The amount of _goodid1 to swap - amount0: The quantity of the input good - amount1: The limit quantity of the output good|
|`_side`|`uint128`|tradeside,0:buy,1:sell|
|`_referal`|`address`|when side is buy, _referal is the referral address when side is sell, _referal is the address to receive the fee|
|`data`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|amount0() good1tradefee,good1tradeamount|
|`good2change`|`uint256`|amount0() good1tradefee,good2tradeamount|


### buyGoodCheck

*check before buy good*


```solidity
function buyGoodCheck(address _goodid1, address _goodid2, uint256 _swapQuantity, bool side)
    external
    view
    returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid1`|`address`|The ID of the first good|
|`_goodid2`|`address`|The ID of the second good|
|`_swapQuantity`|`uint256`|The amount of _goodid1 to swap - amount0: The quantity of the input good - amount1: The limit quantity of the output good|
|`side`|`bool`|trade side:true:buy,false:sell|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|amount0()good1tradeamount,good1tradefee|
|`good2change`|`uint256`|amount0()good2tradeamount,good2tradefee|


### investGood

Invest in a normal good


```solidity
function investGood(address _togood, address _valuegood, uint128 _quantity, bytes calldata data1, bytes calldata data2)
    external
    payable
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_togood`|`address`|ID of the normal good to invest in|
|`_valuegood`|`address`|ID of the value good|
|`_quantity`|`uint128`|Quantity of normal good to invest|
|`data1`|`bytes`||
|`data2`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### disinvestProof

Disinvest from a normal good


```solidity
function disinvestProof(uint256 _proofid, uint128 _goodQuantity, address _gate)
    external
    returns (uint128 reward1, uint128 reward2);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofid`|`uint256`|ID of the investment proof|
|`_goodQuantity`|`uint128`|Quantity to disinvest|
|`_gate`|`address`|Address of the gate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reward1`|`uint128`|status|
|`reward2`|`uint128`|status|


### ishigher

Check if the price of a good is higher than a comparison price


```solidity
function ishigher(address goodid, address valuegood, uint256 compareprice) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|ID of the good to check|
|`valuegood`|`address`|ID of the value good|
|`compareprice`|`uint256`|Price to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the good's price is higher|


### getProofState

Retrieves the current state of a proof


```solidity
function getProofState(uint256 proofid) external view returns (S_ProofState memory);
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
function getGoodState(address good) external view returns (S_GoodTmpState memory);
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
function updateGoodConfig(address _goodid, uint256 _goodConfig) external returns (bool);
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
function modifyGoodConfig(address _goodid, uint256 _goodConfig) external returns (bool);
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
function changeGoodOwner(address _goodid, address _to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_to`|`address`|The new owner's address|


### collectCommission

Collects commission for specified goods


```solidity
function collectCommission(address[] calldata _goodid) external;
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
function queryCommission(address[] calldata _goodid, address _recipent) external returns (uint256[] memory);
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

Delivers welfare to investors


```solidity
function goodWelfare(address goodid, uint128 welfare, bytes calldata data1) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|The ID of the good|
|`welfare`|`uint128`|The amount of welfare|
|`data1`|`bytes`||


### getRecentGoodState

Retrieves the current state of two goods in a single call

*Retrieves the current state of two goods in a single call*


```solidity
function getRecentGoodState(address good1, address good2)
    external
    view
    returns (uint256 good1correntstate, uint256 good2correntstate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`good1`|`address`|The address of the first good to query|
|`good2`|`address`|The address of the second good to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1correntstate`|`uint256`|The current state of the first good, representing its latest trading iteration,amount0:good current value,amount1:good current quantity|
|`good2correntstate`|`uint256`|The current state of the second good, representing its latest trading iteration,amount0:good current value,amount1:good current quantity|


## Events
### e_updateGoodConfig
Emitted when a good's configuration is updated


```solidity
event e_updateGoodConfig(address _goodid, uint256 _goodConfig);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|

### e_modifyGoodConfig
Emitted when a good's configuration is modified by market admin


```solidity
event e_modifyGoodConfig(address _goodid, uint256 _goodconfig);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`address`|The ID of the good|
|`_goodconfig`|`uint256`|The new configuration|

### e_changegoodowner
Emitted when a good's owner is changed


```solidity
event e_changegoodowner(address goodid, address to);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|The ID of the good|
|`to`|`address`|The new owner's address|

### e_collectcommission
Emitted when market commission is collected


```solidity
event e_collectcommission(address[] _gooid, uint256[] _commisionamount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_gooid`|`address[]`|Array of good IDs|
|`_commisionamount`|`uint256[]`|Array of commission amounts|

### e_goodWelfare
Emitted when welfare is delivered to investors


```solidity
event e_goodWelfare(address goodid, uint128 welfare);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|The ID of the good|
|`welfare`|`uint128`|The amount of welfare|

### e_collectProtocolFee
Emitted when protocol fee is collected


```solidity
event e_collectProtocolFee(address goodid, uint256 feeamount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`address`|The ID of the good|
|`feeamount`|`uint256`|The amount of fee collected|

### e_initMetaGood
Emitted when a meta good is created and initialized

*The decimal precision of _initial.amount0() defaults to 6*


```solidity
event e_initMetaGood(uint256 _proofNo, address _goodid, uint256 _construct, uint256 _goodConfig, uint256 _initial);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|The ID of the investment proof|
|`_goodid`|`address`|A 256-bit value where the first 128 bits represent the good's ID and the last 128 bits represent the stake construct|
|`_construct`|`uint256`|The stake construct of mint tts token|
|`_goodConfig`|`uint256`|The configuration of the meta good (refer to the whitepaper for details)|
|`_initial`|`uint256`|Market initialization parameters: amount0 is the value, amount1 is the quantity|

### e_initGood
Emitted when a good is created and initialized


```solidity
event e_initGood(
    uint256 _proofNo,
    address _goodid,
    address _valuegoodNo,
    uint256 _goodConfig,
    uint256 _construct,
    uint256 _normalinitial,
    uint256 _value
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|The ID of the investment proof|
|`_goodid`|`address`|The ID of the good|
|`_valuegoodNo`|`address`|The ID of the good|
|`_goodConfig`|`uint256`|The configuration of the meta good (refer to the whitepaper for details)|
|`_construct`|`uint256`|The stake construct of mint tts token|
|`_normalinitial`|`uint256`|Normal good initialization parameters: amount0 is the quantity, amount1 is the value|
|`_value`|`uint256`|Value good initialization parameters: amount0 is the investment fee, amount1 is the investment quantity|

### e_buyGood
Emitted when a user buys a good


```solidity
event e_buyGood(
    address indexed sellgood, address indexed forgood, uint256 swapvalue, uint256 good1change, uint256 good2change
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sellgood`|`address`|The ID of the good being sold|
|`forgood`|`address`|The ID of the good being bought|
|`swapvalue`|`uint256`|The trade value|
|`good1change`|`uint256`|The status of the sold good (amount0: fee, amount1: quantity)|
|`good2change`|`uint256`|The status of the bought good (amount0: fee, amount1: quantity)|

### e_investGood
Emitted when a user invests in a normal good


```solidity
event e_investGood(
    uint256 indexed _proofNo,
    address _normalgoodid,
    address _valueGoodNo,
    uint256 _value,
    uint256 _invest,
    uint256 _valueinvest
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|The ID of the investment proof|
|`_normalgoodid`|`address`|Packed data: first 128 bits for good's ID, last 128 bits for stake construct|
|`_valueGoodNo`|`address`|The ID of the value good|
|`_value`|`uint256`|Investment value (amount0: virtual invest value, amount1: actual invest value)|
|`_invest`|`uint256`|Normal good investment details (amount0: actual fee, amount1: actual invest quantity)|
|`_valueinvest`|`uint256`|Value good investment details (amount0: actual fee, amount1: actual invest quantity)|

### e_disinvestProof
Emitted when a user disinvests from  good


```solidity
event e_disinvestProof(
    uint256 indexed _proofNo,
    address _normalGoodNo,
    address _valueGoodNo,
    address _gate,
    uint256 _value,
    uint256 _normalprofit,
    uint256 _normaldisvest,
    uint256 _valueprofit,
    uint256 _valuedisvest
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|The ID of the investment proof|
|`_normalGoodNo`|`address`|The ID of the normal good|
|`_valueGoodNo`|`address`|The ID of the value good|
|`_gate`|`address`|The gate of User|
|`_value`|`uint256`|amount0: virtual disinvest value,amount1: actual disinvest value|
|`_normalprofit`|`uint256`|amount0:normalgood profit,amount1:normalgood disvest virtual quantity|
|`_normaldisvest`|`uint256`|The disinvestment details of the normal good (amount0: actual fee, amount1: actual disinvest quantity)|
|`_valueprofit`|`uint256`|amount0:valuegood profit,amount1:valuegood disvest virtual quantity|
|`_valuedisvest`|`uint256`|The disinvestment details of the value good (amount0: actual fee, amount1: actual disinvest quantity)|

