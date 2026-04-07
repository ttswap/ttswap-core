# TTSwap_Token_Proxy
This contract implements a decentralized market system with the following key features:
- Meta good, value goods, and normal goods management
- Automated market making (AMM) with configurable fees
- Investment and disinvestment mechanisms
- Flash loan functionality
- Commission distribution system
- ETH or WETH staking integration

*Core market contract for TTSwap protocol that manages goods trading, investing, and staking operations*


## State Variables
### name

```solidity
string internal name;
```


### symbol

```solidity
string internal symbol;
```


### totalSupply

```solidity
string internal totalSupply;
```


### balanceOf

```solidity
mapping(address => uint256) internal balanceOf;
```


### allowance

```solidity
mapping(address => mapping(address => uint256)) internal allowance;
```


### nonces

```solidity
mapping(address => uint256) internal nonces;
```


### implementation

```solidity
address internal implementation;
```


### upgradeable

```solidity
bool internal upgradeable;
```


### usdt

```solidity
address internal usdt;
```


### ttstokenconfig

```solidity
uint256 internal ttstokenconfig;
```


### stakestate

```solidity
uint256 internal stakestate;
```


### left_share

```solidity
uint128 internal left_share = 45_000_000_000_000;
```


### publicsell

```solidity
uint128 internal publicsell;
```


### userConfig

```solidity
mapping(address => uint256) internal userConfig;
```


## Functions
### constructor


```solidity
constructor(
    address _usdt,
    address _dao_admin,
    uint256 _ttsconfig,
    string memory _name,
    string memory _symbol,
    address _implementation
);
```

### fallback


```solidity
fallback() external payable;
```

### onlyTokenAdminProxy

onlydao admin can execute


```solidity
modifier onlyTokenAdminProxy();
```

### onlyTokenOperatorProxy

onlydao admin can execute


```solidity
modifier onlyTokenOperatorProxy();
```

### upgrade


```solidity
function upgrade(address _implementation) external onlyTokenAdminProxy;
```

### freezeToken


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

