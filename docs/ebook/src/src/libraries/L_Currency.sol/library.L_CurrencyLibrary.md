# L_CurrencyLibrary
*This library allows for transferring and holding native tokens and ERC20 tokens*


## State Variables
### defualtvalue

```solidity
bytes constant defualtvalue = bytes("");
```


## Functions
### balanceof


```solidity
function balanceof(address token, address _sender) internal view returns (uint256 amount);
```

### transferFrom


```solidity
function transferFrom(address token, address from, address to, uint256 amount, bytes calldata detail) internal;
```

### transferFrom


```solidity
function transferFrom(address token, address from, uint256 amount, bytes calldata trandata) internal;
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

### to_uint256


```solidity
function to_uint256(address amount) internal pure returns (uint256 a);
```

## Errors
### NativeETHTransferFailed
Thrown when an ERC20 transfer fails


```solidity
error NativeETHTransferFailed();
```

### ERC20TransferFailed
Thrown when an ERC20 transfer fails


```solidity
error ERC20TransferFailed();
```

### ERC20PermitFailed
Thrown when an ERC20Permit transfer fails


```solidity
error ERC20PermitFailed();
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

```solidity
struct S_transferData {
    uint8 transfertype;
    bytes sigdata;
}
```

