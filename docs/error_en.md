TTSwapError(uint256) 0xd1b51911
1: Execution failed: caller is not the market super administrator.
2: Execution failed: caller is not an administrator.
3: Execution failed: operation is locked; please wait and retry.
4: Execution failed: token must be configured as a value token.
5: Execution failed: token (good) has already been created.
6: Execution failed: value-token contract parameters are invalid.
8: Execution failed: swap direction / side configuration is invalid.
9: Execution failed: the two tokens must not be the same address.
10: Execution failed: token 1 (good) is frozen.
11: Execution failed: token 2 (good) is frozen.
12: Execution failed: token 1 (good) is not initialized.
13: Execution failed: token 2 (good) is not initialized.
14: Execution failed: trade value is below the minimum (dust relative to 100_000 value units).
    Condition: normal-good threshold = 1_000_000 * current_quantity / current_value.
15: Execution failed: MEV / slippage protection — trade did not fill (output below limit).
16: Execution failed: token 2 liquidity insufficient for this trade.
    Condition: trade_qty + good2_current_quantity > good2config.amount1() * 11 / 10.
7: Execution failed: token 2 liquidity insufficient for this trade.
    Condition: current_quantity - trade_qty > current_quantity / 10.
17: Execution failed: exactly one of the two goods must be a value token.
18: Execution failed: investment size exceeds the allowed threshold.
19: Execution failed: you are not the creator of this proof.
20: Execution failed: you are not the creator of this good.
21: Execution failed: batch query length exceeds 100.
22: Execution failed: caller is not the protocol security officer.
23: Execution failed: investment leverage exceeds the maximum allowed.
24: Execution failed: fee ratios in configuration do not sum to 100%.
25: Execution failed: on initialization, investment power / leverage must equal 1 (100%).
26: Execution failed: disinvest value exceeds the per-transaction cap; reduce the amount.
27: Execution failed: disinvest quantity exceeds the per-transaction cap; reduce the amount.
28: Execution failed: value-token disinvest value exceeds the per-transaction cap; reduce the amount.
29: Execution failed: value-token disinvest quantity exceeds the per-transaction cap; reduce the amount.
30: Execution failed: insufficient NativeETH balance in transient vault.
31: Execution failed: refunding remaining NativeETH failed.
32: Execution failed: recipient address must not be zero.
33: Execution failed: protocol would receive more of the good than allowed vs. invested depth.
    Condition: trade_qty + good1_current_quantity < good1_current_quantity * 2 - good1config.amount1().
34: Execution failed: good is not frozen; freeze it first where required.
35: Execution failed: initial token value is below the minimum threshold (init uses 500_000_000 value basis).
    Condition: threshold = 500_000_000 * current_quantity / current_value.
36: Execution failed: initial token quantity is too small or too large.
38: Execution failed: investment value is below the dust threshold (invest uses 1_000_000 value basis).
39: Execution failed: trader and executor (msg.sender) do not match when required.
40: Execution failed: this good owner’s proof is in a locked / restricted state.
41: Execution failed: disinvest shares exceed the proof’s position.
42: Execution failed: token transfer failed.
43: Execution failed: good configuration update failed (K / consistency check).
44: Execution failed: good configuration update failed (duplicate path / config branch).
45: Execution failed: good is in buy-only mode; operation not allowed.
47: Execution failed: single-sided invest price guard .
49: Execution failed: signature expired.
50: Execution failed: relayer executeFee exceeds the actual output token amount .
51: Execution failed: good2Swap exact-out — requested value/quantity violates the pool invariant .
52: Execution failed: amount cannot be represented as uint160.
53: Execution failed: signature expired.
54: Execution failed: exact-out (value side) — request exceeds pool depth.
61: Execution failed: chain is not configured as mainnet for this operation.
62: Execution failed: caller is not a DAO administrator.
63: Execution failed: caller is not a token super administrator.
64: Execution failed: caller is not a stake administrator.
65: Execution failed: caller is not a token manager.
66: Execution failed: ratio must not exceed 10_000 (basis points cap).
67: Execution failed: allocated share exceeds remaining mintable amount.
68: Execution failed: price has not doubled enough for this mint tranche.
69: Execution failed: no remaining mint allowance for this tranche.
70: Execution failed: public sale cumulative amount exceeds the cap.
71: Execution failed: caller lacks secondary mint / stake permission.
72: Execution failed: signature or permit deadline has expired.
NativeETHTransferFailed()          6c0f429e   Native ETH transfer failed
ERC20TransferFailed()              f27f64e4   ERC-20 transfer failed
ERC20PermitFailed()                40754b6a   ERC-20 permit / allowance path failed
InvalidSignature()                 8baa579f   Invalid signature
InvalidSignatureLength()           4be6321b   Invalid signature length
InvalidSigner()                    815e1d64   Invalid signer
AllowanceExpired(uint256)          d81b2f2e   Allowance expired
ExcessiveInvalidation()            24d35a26   Excessive invalidation
InsufficientAllowance(uint256)     f96fb071   Insufficient allowance
InvalidAmount(uint256)             3728b83d   Invalid amount
InvalidContractSignature()         b0669cbc   Invalid contract signature
InvalidNonce()                     756688fe   Invalid nonce
LengthMismatch()                   ff633a38   Length mismatch
SignatureExpired(uint256)          cd21db4f   Signature expired
