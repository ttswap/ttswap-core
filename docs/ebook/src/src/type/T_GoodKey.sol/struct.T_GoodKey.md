# T_GoodKey
**Title:**
T_GoodKey — universal token identifier for market operations

Every tradable asset is addressed by `(ercType, contractAddress, id)`.

**ercType** (v2.0 production paths):
- `1` = ERC-20 or native ETH placeholder
- `2` = ERC-1155 (reserved, reverts today)
- `3` = ERC-6909 (reserved, reverts today)

**Native ETH**: `contractAddress == address(1)`; value moves via `msg.value` + `L_Transient` budget.

**Good id**: `toId()` — for ERC-20/native, lower 160 bits of `contractAddress`; for 1155/6909, hashed key.


```solidity
struct T_GoodKey {
uint8 ercType;
address contractAddress;
uint256 id;
}
```

