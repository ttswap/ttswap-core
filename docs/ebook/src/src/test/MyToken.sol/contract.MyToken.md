# MyToken
**Inherits:**
[ERC20](/src/base/ERC20.sol/abstract.ERC20.md)


## State Variables
### owner

```solidity
address public owner;
```


## Functions
### constructor


```solidity
constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol, _decimals);
```

### mint


```solidity
function mint(address recipent, uint256 amount) external;
```

### deposit


```solidity
function deposit() public payable virtual;
```

### withdraw


```solidity
function withdraw(uint256 amount) public virtual;
```

### receive


```solidity
receive() external payable virtual;
```

## Events
### Deposit

```solidity
event Deposit(address indexed from, uint256 amount);
```

### Withdrawal

```solidity
event Withdrawal(address indexed to, uint256 amount);
```

