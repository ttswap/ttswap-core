# L_CurrencyLibrary
**Title:**
L_CurrencyLibrary

This library allows for transferring and holding native tokens and ERC20 tokens.

Handles various transfer methods including native ETH, standard ERC20 transferFrom,
ERC20 Permit, and Permit2 (TransferFrom, Permit, PermitTransferFrom).
It abstracts away the complexity of different token standards and permit signatures.


## State Variables
### defaultvalue

```solidity
bytes constant defaultvalue = bytes("")
```


## Functions
### balanceof


```solidity
function balanceof(address token, address _sender) internal view returns (uint256 amount);
```

### transferFrom

Transfers tokens from one address to another using various authorization methods.

Supports native ETH, standard ERC20, and various Permit schemes via `detail`.

**Notes:**
- security: CRITICAL: If `token` is native ETH, `executor` MUST be `from`.

- security: CRITICAL: If `detail` is provided, `transfertype` MUST be supported (2-5), otherwise it reverts.


```solidity
function transferFrom(
    address token,
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
|`token`|`address`|The address of the token to transfer (or address(1) for native ETH).|
|`from`|`address`|The address to transfer tokens from.|
|`to`|`address`|The address to transfer tokens to.|
|`executor`|`address`|The address executing the transaction (usually msg.sender).|
|`amount`|`uint256`|The amount of tokens to transfer.|
|`detail`|`bytes`|Encoded `S_transferData` containing transfer type and signature data.|


### transferFrom


```solidity
function transferFrom(address token, address from, address executor, uint256 amount, bytes calldata trandata)
    internal;
```

### transferFromInter


```solidity
function transferFromInter(address currency, address from, address to, uint256 amount) internal;
```

### safeTransfer


```solidity
function safeTransfer(address currency, address to, uint256 amount) internal;
```

### isNative


```solidity
function isNative(address currency) internal pure returns (bool);
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

