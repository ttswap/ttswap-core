# TTSwap_Token_Proxy
**Title:**
TTSwap Token Proxy

This contract stores the token state (balances, allowances, etc.) and delegates
logic execution to the implementation contract. It supports upgradability.

Proxy contract for TTSwap Token using delegatecall.


## State Variables
### name

```solidity
string internal name
```


### symbol

```solidity
string internal symbol
```


### totalSupply

```solidity
uint256 internal totalSupply
```


### balanceOf

```solidity
mapping(address => uint256) internal balanceOf
```


### allowance

```solidity
mapping(address => mapping(address => uint256)) internal allowance
```


### nonces

```solidity
mapping(address => uint256) internal nonces
```


### implementation

```solidity
address public implementation
```


### ttstokenconfig

```solidity
uint256 internal ttstokenconfig
```


### upgradeable

```solidity
bool public upgradeable
```


### stakestate

```solidity
uint256 internal stakestate
```


### left_share

```solidity
uint128 internal left_share = 45_000_000_000_000_000_000
```


### publicsell

```solidity
uint128 internal publicsell
```


### userConfig

```solidity
mapping(address => uint256) internal userConfig
```


## Functions
### constructor

Initializes the token proxy with admin, config, metadata, and implementation.


```solidity
constructor(
    address _dao_admin,
    uint256 _ttsconfig,
    string memory _name,
    string memory _symbol,
    address _implementation
) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dao_admin`|`address`|The address of the initial DAO admin.|
|`_ttsconfig`|`uint256`|The initial token configuration value.|
|`_name`|`string`|The name of the token.|
|`_symbol`|`string`|The symbol of the token.|
|`_implementation`|`address`|The address of the initial Token implementation logic.|


### fallback

Fallback function that delegates calls to the implementation contract.


```solidity
fallback() external payable;
```

### onlyTokenAdminProxy

Restricts access to Token Admins.


```solidity
modifier onlyTokenAdminProxy() ;
```

### onlyTokenOperatorProxy

Restricts access to Token Managers (Operators).


```solidity
modifier onlyTokenOperatorProxy() ;
```

### upgrade

Upgrades the token implementation contract.


```solidity
function upgrade(address _implementation) external onlyTokenAdminProxy;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_implementation`|`address`|The new implementation address.|


### freezeToken

Freezes the token logic by setting implementation to address(0).

Can be called by Token Manager for emergency stops.


```solidity
function freezeToken() external onlyTokenOperatorProxy;
```

### receive


```solidity
receive() external payable;
```

## Events
### e_updateUserConfig

```solidity
event e_updateUserConfig(address user, uint256 config);
```

