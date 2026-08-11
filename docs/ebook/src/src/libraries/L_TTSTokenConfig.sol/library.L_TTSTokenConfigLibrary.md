# L_TTSTokenConfigLibrary
**Title:**
TTS Token Configuration Library

A library for handling TTS token configurations


## Functions
### ismain

Checks if the given configuration represents a main item

Uses assembly to perform a bitwise right shift operation


```solidity
function ismain(uint256 config) internal pure returns (bool a);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The configuration value to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`a`|`bool`|True if the configuration represents a main item, false otherwise|


### getratio

Calculates the ratio amount based on configuration.

Extracts the lower 16 bits (0xffff) of config as a basis point ratio (dividend/10000) and applies it to amount.


```solidity
function getratio(uint256 config, uint128 amount) internal pure returns (uint128 b);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The configuration value containing the ratio in the lowest 16 bits.|
|`amount`|`uint128`|The amount to apply the ratio to.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`b`|`uint128`|The calculated amount.|


### setratio

Updates the ratio configuration.

Replaces the lower 16 bits of `config` with the lower 16 bits of `ttsconfig`.
This effectively updates the stored ratio while preserving other configuration bits.


```solidity
function setratio(uint256 config, uint256 ttsconfig) internal pure returns (uint256 b);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The original configuration value.|
|`ttsconfig`|`uint256`|The new configuration value containing the new ratio in its lower 16 bits.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`b`|`uint256`|The updated configuration value.|


