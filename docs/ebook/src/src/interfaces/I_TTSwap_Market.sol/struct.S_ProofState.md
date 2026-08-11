# S_ProofState
LP position snapshot returned by `getProofState`.

Packed fields use `TTSwapUINT256` encoding (amount0 high, amount1 low).
Not the same as global `goodConfig.amount1()` / `currentState` — these are per-proof snapshots.


```solidity
struct S_ProofState {
uint256 currentgood;
uint256 shares;
uint256 state;
uint256 invest;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`currentgood`|`uint256`|Good id this proof is bound to.|
|`shares`|`uint256`|amount0 = LP shares; amount1 = TTS stake value linked to proof.|
|`state`|`uint256`|amount0 = virtual value; amount1 = actual value at proof ratios.|
|`invest`|`uint256`|amount0 = virtual qty (`Q` leg at invest); amount1 = actual qty deposited (`investQty` leg).|

