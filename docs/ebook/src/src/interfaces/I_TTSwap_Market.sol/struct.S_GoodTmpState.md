# S_GoodTmpState
Good snapshot returned by `getGoodState` (no mappings).

Read `goodConfig.amount1()` for leverage `virtualQty`; `investState.amount1()` for `V`.


```solidity
struct S_GoodTmpState {
uint256 goodConfig;
address owner;
uint256 currentState;
uint256 investState;
}
```

