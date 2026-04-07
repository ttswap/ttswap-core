# IERC20Permit


*Interface for token permits for ERC-721*


## Functions
### permit

ERC165 bytes to add to interface array - set in parent contract
_INTERFACE_ID_ERC4494 = 0x5604e225


```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external;
```

### nonces

Returns the nonce of an NFT - useful for creating permits


```solidity
function nonces(uint256 tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|the index of the NFT to get the nonce of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the uint256 representation of the nonce|


### DOMAIN_SEPARATOR

Returns the domain separator used in the encoding of the signature for permits, as defined by EIP-712


```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|the bytes32 domain separator|


