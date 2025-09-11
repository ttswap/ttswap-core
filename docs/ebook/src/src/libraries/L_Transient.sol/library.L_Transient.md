# L_Transient
This is a temporary library that allows us to use transient storage (tstore/tload)
TODO: This library can be deleted when we have the transient keyword support in solidity.


## State Variables
### VALUE_SLOT

```solidity
bytes32 constant VALUE_SLOT = 0xcbe27d488af5b5c1b0bd8d89be6fdfeaed3ad42719044fd9b728f33df1d6f1d1;
```


### DEPTH_SLOT

```solidity
bytes32 constant DEPTH_SLOT = 0x87b52c29898e62efc1f9a9b00a26dcbdaee98d728c56841703077b7c0d20dee7;
```


### LOCK_SLOT

```solidity
bytes32 constant LOCK_SLOT = 0xe2afc7ec4dbb9bfdb1b8e8bcf21a055747c25bf2faaea9cb5a134005381f4843;
```


## Functions
### set


```solidity
function set(address locker) internal;
```

### get


```solidity
function get() internal view returns (address locker);
```

### setValue


```solidity
function setValue(uint256 locker) internal;
```

### getValue


```solidity
function getValue() internal view returns (uint256 value);
```

### increaseValue


```solidity
function increaseValue(uint256 amount) internal;
```

### decreaseValue


```solidity
function decreaseValue(uint256 amount) internal;
```

### getDepth


```solidity
function getDepth() internal view returns (uint256 step);
```

### clearDepth


```solidity
function clearDepth() internal;
```

### addDepth


```solidity
function addDepth() internal;
```

### subDepth


```solidity
function subDepth() internal;
```

### checkbefore


```solidity
function checkbefore() internal;
```

### checkafter


```solidity
function checkafter() internal;
```

