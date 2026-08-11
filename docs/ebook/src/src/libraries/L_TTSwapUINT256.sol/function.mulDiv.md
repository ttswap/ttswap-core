# mulDiv
Performs a multiplication followed by a division (full precision)

Optimized to prevent intermediate overflow during multiplication


```solidity
function mulDiv(uint256 config, uint256 amount, uint256 divisor) pure returns (uint128 a);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The multiplicand|
|`amount`|`uint256`|The multiplier|
|`divisor`|`uint256`|The divisor|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint128`|The result as a uint128|


