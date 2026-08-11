# T_GoodKeyLibrary
**Title:**
T_GoodKeyLibrary

Token transfers, balance reads, and id derivation for `T_GoodKey`.


## State Variables
### dai

```solidity
address constant dai = 0xCaFBbAd55eb09efe7bec8408Cff9932Be7D9A7fA
```


### _permit2

```solidity
address constant _permit2 = 0xa50eb0d081E986c280efF32dae089939Ea07bd22
```


### defaultvalue

```solidity
bytes constant defaultvalue = bytes("")
```


## Functions
### toId

Derives a unique market good ID from `T_GoodKey`.

Native / ERC-20: lower 160 bits of `contractAddress`.
ERC-1155 / ERC-6909: `keccak256(packed, id)` where
`packed = (ercType << 160) | uint160(contractAddress)` (one 32-byte word).


```solidity
function toId(T_GoodKey memory goodkey) internal pure returns (uint256 goodid);
```

### balanceof


```solidity
function balanceof(T_GoodKey memory goodkey, address _sender) internal view returns (uint256 amount);
```

### transferFrom

Transfers tokens from one address to another using various authorization methods.

Supports native ETH, standard ERC20, and various Permit schemes via `detail`.

**Notes:**
- security: CRITICAL: If `token` is native ETH, `executor` MUST be `from`.

- security: CRITICAL: If `detail` is provided, `transfertype` MUST be supported (2-5), otherwise it reverts.


```solidity
function transferFrom(
    T_GoodKey memory goodkey,
    address from,
    address to,
    address executor,
    uint256 amount,
    bytes calldata detail
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodkey`|`T_GoodKey`|The address of the token to transfer (or address(1) for native ETH).|
|`from`|`address`|The address to transfer tokens from.|
|`to`|`address`|The address to transfer tokens to.|
|`executor`|`address`|The address executing the transaction (usually msg.sender).|
|`amount`|`uint256`|The amount of tokens to transfer.|
|`detail`|`bytes`|Encoded `S_transferData` containing transfer type and signature data.|


### transferFrom


```solidity
function transferFrom(
    T_GoodKey memory goodkey,
    address from,
    address executor,
    uint256 amount,
    bytes calldata trandata
) internal;
```

### transferFromInter


```solidity
function transferFromInter(address currency, address from, address to, uint256 amount) internal;
```

### safeTransfer


```solidity
function safeTransfer(T_GoodKey memory goodkey, address to, uint256 amount) internal;
```

### isNative

Returns `contractAddress == address(1)` (native ETH sentinel, not a deployed contract).


```solidity
function isNative(T_GoodKey memory goodkey) internal pure returns (bool);
```

### composedata

Packs `(ercType, contractAddress)` into one word for `e_initGood` indexing.


```solidity
function composedata(T_GoodKey memory goodkey) internal pure returns (uint256);
```

### to_uint160


```solidity
function to_uint160(uint256 amount) internal pure returns (uint160);
```

## Errors
### NativeETHTransferFailed
Thrown when an ETH transfer fails.


```solidity
error NativeETHTransferFailed();
```

### ERC20TransferFailed
Thrown when an ERC20 transfer fails (e.g. insufficient balance or allowance).


```solidity
error ERC20TransferFailed();
```

### ERC20PermitFailed
Thrown when an ERC20 Permit operation fails.


```solidity
error ERC20PermitFailed();
```

### UnsupportedTransferType
Thrown when an unsupported transfer type is provided.


```solidity
error UnsupportedTransferType();
```

### ApproveFailed

```solidity
error ApproveFailed();
```

## Structs
### S_Permit

```solidity
struct S_Permit {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

### S_Permit2

```solidity
struct S_Permit2 {
    uint256 value;
    uint256 deadline;
    uint256 nonce;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

### S_transferData
Structure to decode user-supplied transfer data.


```solidity
struct S_transferData {
    uint8 transfertype;
    bytes sigdata;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`transfertype`|`uint8`|The type of transfer mechanism to use. 2: DAI-style Permit or EIP-2612 Permit 3: Permit2 TransferFrom (allowance already set) 4: Permit2 Permit + TransferFrom 5: Permit2 PermitTransferFrom (signature transfer)|
|`sigdata`|`bytes`|The encoded signature data (S_Permit or S_Permit2).|

