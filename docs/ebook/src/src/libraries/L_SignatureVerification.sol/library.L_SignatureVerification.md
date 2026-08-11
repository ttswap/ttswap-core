# L_SignatureVerification
**Title:**
Signature Verification Library

Provides functions to verify ECDSA signatures.

Supports both standard 65-byte signatures (r, s, v) and EIP-2098 compact 64-byte signatures (r, vs).


## State Variables
### UPPER_BIT_MASK

```solidity
bytes32 constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
```


## Functions
### verify

Verifies that a signature was produced by a specific address.

Reverts if the signature is invalid or the signer does not match.


```solidity
function verify(bytes calldata signature, bytes32 hash, address claimedSigner) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signature`|`bytes`|The signature bytes (64 or 65 bytes).|
|`hash`|`bytes32`|The 32-byte hash of the data that was signed.|
|`claimedSigner`|`address`|The address expected to have signed the hash.|


## Errors
### InvalidSignatureLength
Thrown when the passed in signature is not a valid length (must be 64 or 65 bytes).


```solidity
error InvalidSignatureLength();
```

### InvalidSignature
Thrown when the recovered signer is the zero address (ecrecover failure).


```solidity
error InvalidSignature();
```

### InvalidSigner
Thrown when the recovered signer does not match the expected claimedSigner.


```solidity
error InvalidSigner();
```

### InvalidContractSignature
Thrown when the recovered contract signature is incorrect (reserved for EIP-1271 support in future).


```solidity
error InvalidContractSignature();
```

