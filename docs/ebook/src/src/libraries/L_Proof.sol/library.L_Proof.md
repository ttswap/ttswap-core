# L_Proof
**Title:**
L_Proof Library

Tracks a user's liquidity position in one good as an "investment proof" (NFT-like id).

Proof id = `keccak256(abi.encode(S_ProofKey))` where key is `(owner, currentgood)`.

**Proof state fields** (`S_ProofState`) — per-position snapshots, not global pool fields:
- `currentgood`: good id this proof is bound to
- `shares.amount0`: LP shares; `shares.amount1`: TTS stake value
- `state.amount0`: virtual value at proof ratios; `state.amount1`: actual value at proof ratios
- `invest.amount0`: virtual qty at proof time (`Q` leg); `invest.amount1`: actual qty deposited (`investQty` leg)

Distinct from on-pool `goodConfig.amount1()` (`virtualQty` tracker) and `currentState` (`investQty`, `Q`).


## Functions
### updateInvest

Adds a new deposit (or increases position) on an existing proof.

On first deposit (`invest.amount1 == 0`), sets `currentgood`.


```solidity
function updateInvest(
    S_ProofState storage _self,
    uint256 _currenctgood,
    uint256 _shares,
    uint256 _state,
    uint256 _invest
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_ProofState`||
|`_currenctgood`|`uint256`||
|`_shares`|`uint256`|`(newShares, ttsStakeValue)` to add.|
|`_state`|`uint256`|`(virtualValue, actualValue)` increment.|
|`_invest`|`uint256`|`(virtualQty, actualQty)` increment.|


### burnProof

Reduces proof balances after a partial or full disinvest.

Called from `L_Good.disinvestGood` after pool state is updated.


```solidity
function burnProof(S_ProofState storage _self, uint256 _shares, uint256 _state, uint256 _invest) internal;
```

### stake

Stakes proof value into the TTS governance token (called on invest).


```solidity
function stake(I_TTSwap_Token contractaddress, address to, uint128 proofvalue) internal returns (uint128);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|Amount recorded by the token contract (may net construction fee).|


### unstake

Unstakes TTS when LP withdraws and proof TTS value is released.


```solidity
function unstake(I_TTSwap_Token contractaddress, address from, uint128 divestvalue) internal;
```

