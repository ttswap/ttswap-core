# lowerprice
Compares the prices of three T_BalanceUINT256 values using 512-bit arithmetic

Avoids overflow: three uint128 multiplied can reach 2^384, exceeding uint256.
Uses mulmod trick to compute full 512-bit products for safe comparison.


```solidity
function lowerprice(uint256 a, uint256 b, uint256 c) pure returns (bool result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|The first T_BalanceUINT256|
|`b`|`uint256`|The second T_BalanceUINT256|
|`c`|`uint256`|The third T_BalanceUINT256|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bool`|True if a0*b1*c1 > a1*b0*c0, false otherwise|


