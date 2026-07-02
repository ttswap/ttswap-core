# L_UserConfigLibrary
**Title:**
User Configuration Library

Library for managing user permissions and roles within the TTSwap system.

Uses bitwise operations on a `uint256` to store boolean flags and addresses efficiently.
Permission Layout (Bit Index):
- 255: DAO Admin
- 254: Token Admin
- 253: Token Manager
- 252: Market Admin
- 251: Market Manager
- 250: Can Call Mint TTS (Contract Role)
- 249: Stake Admin
- 248: Stake Manager
- 160: Ban Status
- [0-159]: Referral Address (160 bits)


## Functions
### isDAOAdmin

Checks if the user has DAO Admin privileges.


```solidity
function isDAOAdmin(uint256 config) internal pure returns (bool a);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The user's configuration value.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`a`|`bool`|True if DAO Admin, false otherwise.|


### setDAOAdmin

Sets or unsets DAO Admin privileges.


```solidity
function setDAOAdmin(uint256 config, bool a) internal pure returns (uint256 e);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`uint256`|The current configuration value.|
|`a`|`bool`|The new boolean status.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`e`|`uint256`|The updated configuration value.|


### isTokenAdmin

Checks if the user has Token Admin privileges.


```solidity
function isTokenAdmin(uint256 config) internal pure returns (bool a);
```

### setTokenAdmin

Sets or unsets Token Admin privileges.


```solidity
function setTokenAdmin(uint256 config, bool a) internal pure returns (uint256 e);
```

### isTokenManager

Checks if the user has Token Manager privileges.


```solidity
function isTokenManager(uint256 config) internal pure returns (bool a);
```

### setTokenManager

Sets or unsets Token Manager privileges.


```solidity
function setTokenManager(uint256 config, bool a) internal pure returns (uint256 e);
```

### isMarketAdmin

Checks if the user has Market Admin privileges.


```solidity
function isMarketAdmin(uint256 config) internal pure returns (bool a);
```

### setMarketAdmin

Sets or unsets Market Admin privileges.


```solidity
function setMarketAdmin(uint256 config, bool a) internal pure returns (uint256 e);
```

### isMarketManager

Checks if the user has Market Manager privileges.


```solidity
function isMarketManager(uint256 config) internal pure returns (bool a);
```

### setMarketManager

Sets or unsets Market Manager privileges.


```solidity
function setMarketManager(uint256 config, bool a) internal pure returns (uint256 e);
```

### isCallMintTTS

Checks if the user (contract) is authorized to call mint functions.


```solidity
function isCallMintTTS(uint256 config) internal pure returns (bool a);
```

### setCallMintTTS

Sets or unsets mint calling authorization.


```solidity
function setCallMintTTS(uint256 config, bool a) internal pure returns (uint256 e);
```

### isStakeAdmin

Checks if the user has Stake Admin privileges.


```solidity
function isStakeAdmin(uint256 config) internal pure returns (bool a);
```

### setStakeAdmin

Sets or unsets Stake Admin privileges.


```solidity
function setStakeAdmin(uint256 config, bool a) internal pure returns (uint256 e);
```

### isStakeManager

Checks if the user has Stake Manager privileges.


```solidity
function isStakeManager(uint256 config) internal pure returns (bool a);
```

### setStakeManager

Sets or unsets Stake Manager privileges.


```solidity
function setStakeManager(uint256 config, bool a) internal pure returns (uint256 e);
```

### isBan

Checks if the user is banned.


```solidity
function isBan(uint256 config) internal pure returns (bool a);
```

### setBan

Sets or unsets the ban status.


```solidity
function setBan(uint256 config, bool a) internal pure returns (uint256 e);
```

### referral

Retrieves the referral address associated with the user.

Returns the lower 160 bits cast as an address.


```solidity
function referral(uint256 config) internal pure returns (address a);
```

### setReferral

Sets the referral address for the user.

Clears the lower 160 bits and ORs them with the new address.


```solidity
function setReferral(uint256 config, address a) internal pure returns (uint256 e);
```

