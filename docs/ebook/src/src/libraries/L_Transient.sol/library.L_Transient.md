# L_Transient
**Title:**
L_Transient — per-transaction ETH budget and reentrancy lock

Uses EIP-1153 transient storage (`tstore`/`tload`) so state does not persist across transactions.

Three slots:
- `VALUE_SLOT`: remaining native ETH budget for this outer call tree
- `DEPTH_SLOT`: nesting depth of `msgValue`-wrapped calls
- `LOCK_SLOT`: reentrancy lock (0 = open, 1 = multicall batch, 2 = guarded function)

**Native ETH accounting**
When the outermost `msgValue` call starts (`depth == 0`), `checkbefore` seeds `VALUE_SLOT` with `msg.value`.
Each native transfer via `T_GoodKey.transferFrom` calls `decreaseValue(amount)`.
At the end of the outermost call, `checkafter` refunds any leftover budget to `msg.sender`.
This lets one `msg.value` be split across multiple sub-operations without double-spending.

**Multicall safety (C-01)**
`multicall` uses `multicallEntry` (lock 1) plus outer `msgValue` so subcalls do NOT re-arm
`VALUE_SLOT` from `msg.value` when depth returns to 0 inside the batch.


## State Variables
### VALUE_SLOT
Transient slot for remaining native ETH budget.
`bytes32(uint256(keccak256("VALUE_SLOT")) - 1)`


```solidity
bytes32 constant VALUE_SLOT = 0xcbe27d488af5b5c1b0bd8d89be6fdfeaed3ad42719044fd9b728f33df1d6f1d1
```


### DEPTH_SLOT
Transient slot for `msgValue` call nesting depth.


```solidity
bytes32 constant DEPTH_SLOT = 0x87b52c29898e62efc1f9a9b00a26dcbdaee98d728c56841703077b7c0d20dee7
```


### LOCK_SLOT
Transient slot for reentrancy lock level (see `TTSwap_Market.guardedEntry` / `multicallEntry`).


```solidity
bytes32 constant LOCK_SLOT = 0xe2afc7ec4dbb9bfdb1b8e8bcf21a055747c25bf2faaea9cb5a134005381f4843
```


## Functions
### set

Sets the reentrancy lock level.


```solidity
function set(uint256 lock) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lock`|`uint256`|0 = unlocked, 1 = multicall context, 2 = single guarded entry active.|


### get

Gets the current reentrancy lock level.


```solidity
function get() internal view returns (uint256 lock);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lock`|`uint256`|The current lock level (0 / 1 / 2).|


### setValue

Overwrites the transient native-ETH budget.


```solidity
function setValue(uint256 locker) internal;
```

### getValue

Reads the remaining native-ETH budget for this transaction tree.


```solidity
function getValue() internal view returns (uint256 value);
```

### increaseValue

Adds `amount` to the transient ETH budget (rare; budget is usually set once at depth 0).


```solidity
function increaseValue(uint256 amount) internal;
```

### decreaseValue

Deducts `amount` from the transient ETH budget before a native good transfer.

Reverts `TTSwapError(30)` when the budget is insufficient.


```solidity
function decreaseValue(uint256 amount) internal;
```

### getDepth

Current nesting depth of `msgValue`-wrapped calls.


```solidity
function getDepth() internal view returns (uint256 step);
```

### clearDepth

Resets call depth to zero (internal cleanup helper).


```solidity
function clearDepth() internal;
```

### addDepth

Increments `msgValue` nesting depth on entry.


```solidity
function addDepth() internal;
```

### subDepth

Decrements `msgValue` nesting depth on exit.


```solidity
function subDepth() internal;
```

### checkbefore

Entry hook for `msgValue` modifier.

Only when `depth == 0` does it initialize `VALUE_SLOT` from `msg.value`.
Always increments depth so nested guarded calls share one budget.


```solidity
function checkbefore() internal;
```

### checkafter

Exit hook for `msgValue` modifier.

Decrements depth; when depth returns to 0, refunds leftover ETH to `msg.sender`.


```solidity
function checkafter() internal;
```

