# TTSwap_Market_Proxy
**Title:**
TTSwap Market Proxy

This contract holds the storage and delegates logic execution to the implementation contract.
It supports upgradability controlled by admins.

Proxy contract for TTSwap Market using delegatecall.


## State Variables
### implementation

```solidity
address public implementation
```


### TTS_CONTRACT

```solidity
I_TTSwap_Token public immutable TTS_CONTRACT
```


### nonces

```solidity
mapping(address _trader => uint256 nonce) private nonces
```


### upgradeable

```solidity
bool public upgradeable
```


## Functions
### constructor

Initializes the proxy with the token contract and initial implementation.


```solidity
constructor(I_TTSwap_Token _TTS_Contract, address _implementation) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TTS_Contract`|`I_TTSwap_Token`|The address of the TTSwap Token contract (for permission checks).|
|`_implementation`|`address`|The address of the initial Market implementation logic.|


### fallback

Fallback function that delegates calls to the implementation contract.


```solidity
fallback() external payable;
```

### onlyMarketAdminProxy

Restricts access to Market Admins.


```solidity
modifier onlyMarketAdminProxy() ;
```

### onlyMarketManagerProxy

Restricts access to Market Managers.


```solidity
modifier onlyMarketManagerProxy() ;
```

### upgrade

Upgrades the market implementation contract.


```solidity
function upgrade(address _implementation) external onlyMarketAdminProxy;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_implementation`|`address`|The new implementation address.|


### disableUpgrade

Permanently disables upgradability.

Can only be called by DAO Admin. Once disabled, the implementation cannot be changed.


```solidity
function disableUpgrade() external;
```

### freezeMarket

Freezes the market by setting implementation to address(0).

Can be called by Market Manager for emergency stops.


```solidity
function freezeMarket() external onlyMarketManagerProxy;
```

### receive


```solidity
receive() external payable;
```

