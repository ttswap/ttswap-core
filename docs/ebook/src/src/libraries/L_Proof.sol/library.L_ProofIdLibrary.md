# L_ProofIdLibrary
**Title:**
L_ProofIdLibrary

Deterministic proof id from `(owner, goodId)` — one proof per user per good.


## Functions
### toId

`keccak256` over 64 bytes of `S_ProofKey` (owner + currentgood).


```solidity
function toId(S_ProofKey memory proofKey) internal pure returns (uint256 poolId);
```

