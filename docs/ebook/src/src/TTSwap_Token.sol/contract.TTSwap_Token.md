# TTSwap_Token
**Inherits:**
[I_TTSwap_Token](/src/interfaces/I_TTSwap_Token.sol/interface.I_TTSwap_Token.md), [ERC20](/src/base/ERC20.sol/abstract.ERC20.md), [IEIP712](/src/interfaces/IEIP712.sol/interface.IEIP712.md)

*Implements ERC20 token with additional staking and cross-chain functionality*


## State Variables
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
uint256 public override ttstokenconfig;
```


### stakestate

```solidity
uint256 public override stakestate;
```


### left_share

```solidity
uint128 public override left_share = 45_000_000_000_000;
```


### publicsell
*Returns the amount of TTS available for public sale*


```solidity
uint128 public override publicsell;
```


### userConfig
*Returns the authorization level for a given address*


```solidity
mapping(address => uint256) public override userConfig;
```


### marketcontract

```solidity
address internal marketcontract;
```


### poolstate

```solidity
uint256 public override poolstate;
```


### shares

```solidity
mapping(address => s_share) internal shares;
```


### stakeproof

```solidity
mapping(uint256 => s_proof) internal stakeproof;
```


### _PERMITSHARE_TYPEHASH

```solidity
bytes32 internal constant _PERMITSHARE_TYPEHASH = keccak256(
    "permitShare(uint128 amount,uint120 chips,uint8 metric,address owner,uint128 existamount,uint128 deadline,uint256 nonce)"
);
```


## Functions
### constructor


```solidity
constructor() ERC20("TTSwap Token", "TTS", 6);
```

### onlymain

*Modifier to ensure function is only called on the main chain*


```solidity
modifier onlymain();
```

### setDAOAdmin

Only callable by an existing DAO admin.

*Grants or revokes DAO admin privileges to a recipient address.*


```solidity
function setDAOAdmin(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke DAO admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setTokenAdmin

Only callable by a DAO admin.

*Grants or revokes Token admin privileges to a recipient address.*


```solidity
function setTokenAdmin(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Token admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setTokenManager

Only callable by a Token admin.

*Grants or revokes Token manager privileges to a recipient address.*


```solidity
function setTokenManager(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Token manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setCallMintTTS

Only callable by a Token admin.

*Grants or revokes permission to call mintTTS to a recipient address.*


```solidity
function setCallMintTTS(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke permission.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setMarketAdmin

Only callable by a DAO admin.

*Grants or revokes Market admin privileges to a recipient address.*


```solidity
function setMarketAdmin(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Market admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setMarketManager

Only callable by a Market admin.

*Grants or revokes Market manager privileges to a recipient address.*


```solidity
function setMarketManager(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Market manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setStakeAdmin

Only callable by a DAO admin.

*Grants or revokes Stake admin privileges to a recipient address.*


```solidity
function setStakeAdmin(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Stake admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setStakeManager

Only callable by a Stake admin.

*Grants or revokes Stake manager privileges to a recipient address.*


```solidity
function setStakeManager(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Stake manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setBan

Only callable by a Token manager.

*Sets or unsets a ban on a recipient address, restricting their access.*


```solidity
function setBan(address _recipient, bool result) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to ban or unban.|
|`result`|`bool`|Boolean indicating whether to ban (true) or unban (false) the address.|


### usershares

*Returns the share information for a given user address.*


```solidity
function usershares(address user) external view override returns (s_share memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to query for share information.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`s_share`|The s_share struct containing the user's share details.|


### stakeproofinfo

*Returns the stake proof information for a given index.*


```solidity
function stakeproofinfo(uint256 index) external view override returns (s_proof memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index to query for stake proof information.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`s_proof`|The s_proof struct containing the stake proof details.|


### setReferral

Only callable by authorized addresses (auths[msg.sender] == 1)

Will only set the referral if the user doesn't already have one

*Adds a referral relationship between a user and a referrer*


```solidity
function setReferral(address user, address referral) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user being referred|
|`referral`|`address`|The address of the referrer|


### getreferral

Get the DAO admin and referral for a customer

*Retrieves both the DAO admin address and the referrer address for a given customer*


```solidity
function getreferral(address _customer) external view override returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_customer`|`address`|The address of the customer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|A tuple containing the DAO admin address and the customer's referrer address|


### setRatio

*this chain trade vol ratio in protocol*


```solidity
function setRatio(uint256 _ratio) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_ratio`|`uint256`|The new ratio value (max 10000).|


### setEnv

*Set environment variables for the contract*


```solidity
function setEnv(address _marketcontract) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_marketcontract`|`address`|Address of the market contract|


### addShare

Only callable on the main chain by the DAO admin

Reduces the left_share by the amount in _share

Increments the shares_index and adds the new share to the shares mapping

Emits an e_addShare event with the share details

*Adds a new mint share to the contract*


```solidity
function addShare(s_share memory _share, address owner) external override onlymain;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_share`|`s_share`|The share structure containing recipient, amount, metric, and chips|
|`owner`|`address`||


### _addShare


```solidity
function _addShare(s_share memory _share, address owner) internal;
```

### burnShare

Only callable on the main chain by the DAO admin

Adds the leftamount of the burned share back to left_share

Emits an e_burnShare event and deletes the share from the shares mapping

*Burns (removes) a mint share from the contract*


```solidity
function burnShare(address owner) external override onlymain;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|owner of share|


### shareMint

Only callable on the main chain

Requires the market price to be below a certain threshold

Mints tokens to the share recipient, reduces leftamount, and increments metric

Emits an e_daomint event with the minted amount and index

*Allows the DAO to mint tokens based on a specific share*


```solidity
function shareMint() external override onlymain;
```

### publicSell

*Perform public token sale*


```solidity
function publicSell(uint256 usdtamount, bytes calldata data) external override onlymain;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdtamount`|`uint256`|Amount of USDT to spend on token purchase|
|`data`|`bytes`||


### withdrawPublicSell

Only callable on the main chain by the DAO admin

Transfers the specified amount of USDT to the recipient

*Withdraws funds from public token sale*


```solidity
function withdrawPublicSell(uint256 amount, address recipient) external override onlymain;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of USDT to withdraw|
|`recipient`|`address`|The address to receive the withdrawn funds|


### stake

Stake tokens

*Stake tokens*


```solidity
function stake(address _staker, uint128 proofvalue) external override returns (uint128 netconstruct);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_staker`|`address`|Address of the staker|
|`proofvalue`|`uint128`|Amount to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`netconstruct`|`uint128`|Net construct value|


### unstake

Unstake tokens

*Unstake tokens*


```solidity
function unstake(address _staker, uint128 proofvalue) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_staker`|`address`|Address of the staker|
|`proofvalue`|`uint128`|Amount to unstake|


### _stakeFee

*Internal function to handle staking fees*


```solidity
function _stakeFee() internal;
```

### burn

*Burn tokens from an account*


```solidity
function burn(uint256 value) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|Amount of tokens to burn|


### _mint


```solidity
function _mint(address to, uint256 amount) internal override;
```

### _burn


```solidity
function _burn(address from, uint256 amount) internal override;
```

### permitShare

*Permits a share to be transferred*


```solidity
function permitShare(s_share memory _share, uint128 dealline, bytes calldata signature, address signer)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_share`|`s_share`|The share structure containing recipient, amount, metric, and chips|
|`dealline`|`uint128`|The deadline for the share transfer|
|`signature`|`bytes`|The signature of the share transfer|
|`signer`|`address`|The address of the signer|


### shareHash

*Calculates the hash of a share transfer*


```solidity
function shareHash(s_share memory _share, address owner, uint128 leftamount, uint128 deadline, uint256 nonce)
    public
    pure
    override
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_share`|`s_share`|The share structure containing recipient, amount, metric, and chips|
|`owner`|`address`|The address of the owner|
|`leftamount`|`uint128`|The amount of left share|
|`deadline`|`uint128`|The deadline for the share transfer|
|`nonce`|`uint256`||


### _buildDomainSeparator

Builds a domain separator using the current chainId and contract address.


```solidity
function _buildDomainSeparator(bytes32 typeHash, bytes32 nameHash) private view returns (bytes32);
```

### _hashTypedData

Creates an EIP-712 typed data hash


```solidity
function _hashTypedData(bytes32 dataHash) internal view returns (bytes32);
```

### DOMAIN_SEPARATOR


```solidity
function DOMAIN_SEPARATOR() public view override(ERC20, IEIP712) returns (bytes32);
```

### computeDomainSeparator


```solidity
function computeDomainSeparator() internal view override returns (bytes32);
```

### disableUpgrade


```solidity
function disableUpgrade() external;
```

