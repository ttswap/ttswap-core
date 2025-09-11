# I_TTSwap_Token
Contains a series of interfaces for goods


## Functions
### usershares

*Returns the share information for a given user address.*


```solidity
function usershares(address user) external view returns (s_share memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to query for share information.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`s_share`|The s_share struct containing the user's share details.|


### stakestate

*Returns the current staking state.*


```solidity
function stakestate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The staking state as a uint256 value.|


### poolstate

*Returns the current pool state.*


```solidity
function poolstate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pool state as a uint256 value.|


### ttstokenconfig

*Returns the TTS token configuration value.*


```solidity
function ttstokenconfig() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The configuration as a uint256 value.|


### left_share

*Returns the amount of left share available for minting.*


```solidity
function left_share() external view returns (uint128);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|The left share as a uint128 value.|


### stakeproofinfo

*Returns the stake proof information for a given index.*


```solidity
function stakeproofinfo(uint256 index) external view returns (s_proof memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index to query for stake proof information.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`s_proof`|The s_proof struct containing the stake proof details.|


### setRatio

*Sets the trading volume ratio for the protocol.*


```solidity
function setRatio(uint256 _ratio) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_ratio`|`uint256`|The new ratio value (max 10000).|


### setDAOAdmin

*Grants or revokes DAO admin privileges to a recipient address.*


```solidity
function setDAOAdmin(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke DAO admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setTokenAdmin

*Grants or revokes Token admin privileges to a recipient address.*


```solidity
function setTokenAdmin(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Token admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setTokenManager

*Grants or revokes Token manager privileges to a recipient address.*


```solidity
function setTokenManager(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Token manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setCallMintTTS

*Grants or revokes permission to call mintTTS to a recipient address.*


```solidity
function setCallMintTTS(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke permission.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setMarketAdmin

*Grants or revokes Market admin privileges to a recipient address.*


```solidity
function setMarketAdmin(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Market admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setMarketManager

*Grants or revokes Market manager privileges to a recipient address.*


```solidity
function setMarketManager(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Market manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setStakeAdmin

*Grants or revokes Stake admin privileges to a recipient address.*


```solidity
function setStakeAdmin(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Stake admin rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setStakeManager

*Grants or revokes Stake manager privileges to a recipient address.*


```solidity
function setStakeManager(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to grant or revoke Stake manager rights.|
|`result`|`bool`|Boolean indicating whether to grant (true) or revoke (false) the privilege.|


### setBan

*Sets or unsets a ban on a recipient address, restricting their access.*


```solidity
function setBan(address _recipient, bool result) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address to ban or unban.|
|`result`|`bool`|Boolean indicating whether to ban (true) or unban (false) the address.|


### publicsell

*Returns the amount of TTS available for public sale*


```solidity
function publicsell() external view returns (uint128 _publicsell);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_publicsell`|`uint128`|Returns the amount of TTS available for public sale|


### userConfig

*Returns the authorization level for a given address*


```solidity
function userConfig(address recipent) external view returns (uint256 _auth);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipent`|`address`|user's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_auth`|`uint256`|Returns the authorization level|


### setEnv

*Sets the environment variables for normal good ID, value good ID, and market contract address*


```solidity
function setEnv(address _marketcontract) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_marketcontract`|`address`|The address of the market contract|


### addShare

Only callable on the main chain by the DAO admin

Reduces the left_share by the amount in _share

Increments the shares_index and adds the new share to the shares mapping

Emits an e_addShare event with the share details

*Adds a new mint share to the contract*


```solidity
function addShare(s_share calldata _share, address owner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_share`|`s_share`|The share structure containing recipient, amount, metric, and chips|
|`owner`|`address`||


### burnShare

*Burns the share at the specified index*


```solidity
function burnShare(address owner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|owner of share|


### shareMint

*Mints a share at the specified*


```solidity
function shareMint() external;
```

### publicSell

*how much cost to buy tts*


```solidity
function publicSell(uint256 usdtamount, bytes calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdtamount`|`uint256`|usdt amount|
|`data`|`bytes`||


### withdrawPublicSell

*Withdraws the specified amount from the public sale to the recipient*


```solidity
function withdrawPublicSell(uint256 amount, address recipent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|admin tranfer public sell to another address|
|`recipent`|`address`|user's address|


### burn

*Burns the specified value of tokens from the given account*


```solidity
function burn(uint256 value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|the amount will be burned|


### setReferral

Add a referral relationship


```solidity
function setReferral(address user, address referral) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user being referred|
|`referral`|`address`|The address of the referrer|


### stake

Stake tokens


```solidity
function stake(address staker, uint128 proofvalue) external returns (uint128 construct);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`staker`|`address`|The address of the staker|
|`proofvalue`|`uint128`|The proof value for the stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`construct`|`uint128`|The construct value after staking|


### unstake

Unstake tokens


```solidity
function unstake(address staker, uint128 proofvalue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`staker`|`address`|The address of the staker|
|`proofvalue`|`uint128`|The proof value for unstaking|


### getreferral

Get the DAO admin and referral for a customer


```solidity
function getreferral(address _customer) external view returns (address referral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_customer`|`address`|The address of the customer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`referral`|`address`|The address of the referrer|


### permitShare

*Permits a share to be transferred*


```solidity
function permitShare(s_share memory _share, uint128 dealline, bytes calldata signature, address signer) external;
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
    external
    pure
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


## Events
### e_setenv
Emitted when environment variables are set


```solidity
event e_setenv(address marketcontract);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marketcontract`|`address`|The address of the market contract|

### e_updateUserConfig
Emitted when user config is updated


```solidity
event e_updateUserConfig(address user, uint256 config);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`config`|`uint256`|The new config value|

### e_addreferral
Emitted when a referral relationship is added


```solidity
event e_addreferral(address user, address referal);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user being referred|
|`referal`|`address`||

### e_addShare
Emitted when minting is added


```solidity
event e_addShare(address recipient, uint128 leftamount, uint120 metric, uint8 chips);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address receiving the minted tokens|
|`leftamount`|`uint128`|The remaining amount to be minted|
|`metric`|`uint120`|The metric used for minting|
|`chips`|`uint8`|The number of chips|

### e_burnShare
Emitted when minting is burned


```solidity
event e_burnShare(address owner);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The index of the minting operation being burned|

### e_shareMint
Emitted when DAO minting occurs


```solidity
event e_shareMint(uint128 mintamount, address owner);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mintamount`|`uint128`|The amount being minted|
|`owner`|`address`|The index of the minting operation|

### e_publicsell
Emitted during a public sale


```solidity
event e_publicsell(uint256 usdtamount, uint256 ttsamount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdtamount`|`uint256`|The amount of USDT involved|
|`ttsamount`|`uint256`|The amount of TTS involved|

### e_syncChainStake
Emitted when chain stake is synchronized


```solidity
event e_syncChainStake(uint32 chain, uint128 poolasset, uint256 proofstate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`chain`|`uint32`|The chain ID|
|`poolasset`|`uint128`|The pool asset value|
|`proofstate`|`uint256`| The value of the pool|

### e_stakeinfo
Emitted when unstaking occurs


```solidity
event e_stakeinfo(address recipient, uint256 proofvalue, uint256 unstakestate, uint256 stakestate, uint256 poolstate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address receiving the unstaked tokens|
|`proofvalue`|`uint256`|first 128 bit proofvalue,last 128 bit poolcontruct|
|`unstakestate`|`uint256`|The state after unstaking|
|`stakestate`|`uint256`|The state of the stake|
|`poolstate`|`uint256`|The state of the pool|

### e_updatepool
Emitted when the pool state is updated


```solidity
event e_updatepool(uint256 poolstate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolstate`|`uint256`|The new state of the pool|

### e_updatettsconfig
Emitted when the pool state is updated


```solidity
event e_updatettsconfig(uint256 ttsconfig);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ttsconfig`|`uint256`|The new state of the pool|

