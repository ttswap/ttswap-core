# ERC20
**Authors:**
Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol), Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)

Modern and gas efficient ERC20 + EIP-2612 implementation.

*Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.*


## State Variables
### name

```solidity
string public name;
```


### symbol

```solidity
string public symbol;
```


### decimals

```solidity
uint8 public immutable decimals;
```


### totalSupply

```solidity
uint256 public totalSupply;
```


### balanceOf

```solidity
mapping(address => uint256) public balanceOf;
```


### allowance

```solidity
mapping(address => mapping(address => uint256)) public allowance;
```


### INITIAL_CHAIN_ID

```solidity
uint256 internal immutable INITIAL_CHAIN_ID;
```


### INITIAL_DOMAIN_SEPARATOR

```solidity
bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
```


### nonces

```solidity
mapping(address => uint256) public nonces;
```


## Functions
### constructor


```solidity
constructor(string memory _name, string memory _symbol, uint8 _decimals);
```

### approve


```solidity
function approve(address spender, uint256 amount) public virtual returns (bool);
```

### transfer


```solidity
function transfer(address to, uint256 amount) public virtual returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) public virtual returns (bool);
```

### permit


```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    public
    virtual;
```

### DOMAIN_SEPARATOR


```solidity
function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
```

### computeDomainSeparator


```solidity
function computeDomainSeparator() internal view virtual returns (bytes32);
```

### _mint


```solidity
function _mint(address to, uint256 amount) internal virtual;
```

### _burn


```solidity
function _burn(address from, uint256 amount) internal virtual;
```

## Events
### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 amount);
```

