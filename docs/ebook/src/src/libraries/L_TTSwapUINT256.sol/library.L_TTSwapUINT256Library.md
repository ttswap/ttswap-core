# L_TTSwapUINT256Library
A library for operations on T_BalanceUINT256


## Functions
### amount0

Extracts the first 128-bit amount from a T_BalanceUINT256


```solidity
function amount0(uint256 balanceDelta) internal pure returns (uint128 _amount0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceDelta`|`uint256`|The T_BalanceUINT256 to extract from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amount0`|`uint128`|The extracted first 128-bit amount|


### amount1

Extracts the second 128-bit amount from a T_BalanceUINT256


```solidity
function amount1(uint256 balanceDelta) internal pure returns (uint128 _amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceDelta`|`uint256`|The T_BalanceUINT256 to extract from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amount1`|`uint128`|The extracted second 128-bit amount|


### amount01

Extracts the first and second 128-bit amounts from a T_BalanceUINT256


```solidity
function amount01(uint256 balanceDelta) internal pure returns (uint128 _amount0, uint128 _amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceDelta`|`uint256`|The T_BalanceUINT256 to extract from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amount0`|`uint128`|The extracted first 128-bit amount|
|`_amount1`|`uint128`|The extracted second 128-bit amount|


### getamount0fromamount1

Calculates amount0 based on a given amount1 and the ratio in balanceDelta


```solidity
function getamount0fromamount1(uint256 balanceDelta, uint128 amount1delta) internal pure returns (uint128 _amount0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceDelta`|`uint256`|The T_BalanceUINT256 containing the ratio|
|`amount1delta`|`uint128`|The amount1 to base the calculation on|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amount0`|`uint128`|The calculated amount0|


### getamount1fromamount0

Calculates amount1 based on a given amount0 and the ratio in balanceDelta


```solidity
function getamount1fromamount0(uint256 balanceDelta, uint128 amount0delta) internal pure returns (uint128 _amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceDelta`|`uint256`|The T_BalanceUINT256 containing the ratio|
|`amount0delta`|`uint128`|The amount0 to base the calculation on|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amount1`|`uint128`|The calculated amount1|


