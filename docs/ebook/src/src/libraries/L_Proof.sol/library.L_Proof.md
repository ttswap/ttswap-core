# L_Proof

## Functions
### updateInvest

*Updates the investment state of a proof*


```solidity
function updateInvest(
    S_ProofState storage _self,
    address _currenctgood,
    address _valuegood,
    uint256 _shares,
    uint256 _state,
    uint256 _invest,
    uint256 _valueinvest
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_ProofState`|The proof state to update|
|`_currenctgood`|`address`|The current good value|
|`_valuegood`|`address`|The value good|
|`_shares`|`uint256`|amount0:normal shares amount1:value shares|
|`_state`|`uint256`|amount0 (first 128 bits) represents total value,amount1 (last 128 bits) represents total actual value|
|`_invest`|`uint256`|amount0 (first 128 bits) represents normal virtual invest quantity, amount1 (last 128 bits) represents normal actual invest quantity|
|`_valueinvest`|`uint256`|amount0 (first 128 bits) represents value virtual invest quantity, amount1 (last 128 bits) represents value actual invest quantity|


### burnProof

*Burns a portion of the proof*


```solidity
function burnProof(S_ProofState storage _self, uint256 _shares, uint256 _state, uint256 _invest, uint256 _valueinvest)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_ProofState`|The proof state to update|
|`_shares`|`uint256`|amount0:normal shares amount1:value shares|
|`_state`|`uint256`|amount0 (first 128 bits) represents total value,amount1 (last 128 bits) represents total actual value|
|`_invest`|`uint256`|amount0 (first 128 bits) represents normal virtual invest quantity, amount1 (last 128 bits) represents normal actual invest quantity|
|`_valueinvest`|`uint256`|amount0 (first 128 bits) represents value virtual invest quantity, amount1 (last 128 bits) represents value actual invest quantity|


### stake

*Stakes a certain amount of proof value*


```solidity
function stake(I_TTSwap_Token contractaddress, address to, uint128 proofvalue) internal returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractaddress`|`I_TTSwap_Token`|The address of the staking contract|
|`to`|`address`|The address to stake for|
|`proofvalue`|`uint128`|The amount of proof value to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|The contruct amount|


### unstake

*Unstakes a certain amount of proof value*


```solidity
function unstake(I_TTSwap_Token contractaddress, address from, uint128 divestvalue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractaddress`|`I_TTSwap_Token`|The address of the staking contract|
|`from`|`address`|The address to unstake from|
|`divestvalue`|`uint128`|The amount of proof value to unstake|


