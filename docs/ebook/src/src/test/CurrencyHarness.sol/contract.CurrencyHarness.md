# CurrencyHarness
Public wrapper for `L_CurrencyLibrary` unit tests.


## Functions
### balanceOf


```solidity
function balanceOf(address token, address who) external view returns (uint256);
```

### pullErc20


```solidity
function pullErc20(address token, address from, uint256 amount, bytes calldata detail) external;
```

### pullErc20Executor


```solidity
function pullErc20Executor(address token, address from, address executor, uint256 amount, bytes calldata detail)
    external;
```

### pushErc20


```solidity
function pushErc20(address token, address to, uint256 amount) external;
```

### pushNative


```solidity
function pushNative(address to, uint256 amount) external;
```

### seedNative


```solidity
function seedNative(uint256 amount) external payable;
```

### pullNative


```solidity
function pullNative(address from, uint256 amount, bytes calldata detail) external payable;
```

