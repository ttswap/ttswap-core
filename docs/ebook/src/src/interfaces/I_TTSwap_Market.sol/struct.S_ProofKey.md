# S_ProofKey
Proof id derivation input: `proofId = keccak256(abi.encodePacked(owner, currentgood))` (64 bytes in memory).


```solidity
struct S_ProofKey {
address owner;
uint256 currentgood;
}
```

