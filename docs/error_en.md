TTSwapError(uint256) 0xd1b51911
1: Execution failed: user lacks market super administrator permission.
2: Execution failed: user lacks administrator permission.
3: Execution failed: operation is locked; please wait.
5: Execution failed: token has already been created.
7: Execution failed: token 2 liquidity insufficient for this trade.
    Condition: current_quantity - trade_qty > current_quantity / 10.
10: Execution failed: token is frozen.
12: Execution failed: token is not initialized.
14: Execution failed: trade value is below the minimum (quantity corresponding to value 100000).
    Condition: normal good threshold = 1_000_000 * current_quantity / current_value.
15: Execution failed: MEV attack protection — trade did not fill.
18: Execution failed: investment amount exceeds the threshold.
19: Execution failed: you are not the creator of this proof.
20: Execution failed: you do not have permission to perform this operation.
21: Execution failed: query count exceeds 100.
23: Execution failed: exceeds maximum investment leverage multiplier.
24: Execution failed: fee ratios do not sum to 100.
26: Execution failed: disinvest value exceeds the token maximum single-transaction value; reduce disinvest amount.
27: Execution failed: disinvest quantity exceeds the token maximum single-transaction quantity; reduce disinvest amount.
30: Execution failed: insufficient NativeETH.
31: Execution failed: refunding remaining NativeETH failed.
32: Execution failed: recipient cannot be empty.
34: Execution failed: payment of transaction fee failed.
35: Execution failed: initial token value is below the threshold (during initialization, quantity converted at value 500_000_000_000_000 must not fall below this at invest time).
    Condition: threshold = 500_000_000_000_000 * current_quantity / current_value.
36: Execution failed: initial token quantity is too small or too large.
37: Execution failed: good is under verification.
38: Execution failed: investment value is too low (during investment, quantity converted at value 1_000_000_000_000 must not fall below this).
39: Execution failed: trader and executor are not the same person.
40: Execution failed: good administrator's investment proof is locked.
41: Execution failed: disinvest amount exceeds investment amount.
42: Execution failed: transfer failed.
45: Execution failed: good is oversold; only buy operations are allowed temporarily.
46: Execution failed: operation queued.
47: Execution failed: invest price protection.
49: Execution failed: signature expired.
50: Execution failed: execution fee is below output amount.
51: Execution failed: trade quantity is too large.
52: Execution failed: amount is too large.
54: Execution failed: trade quantity is too large.
61: Execution failed: not mainnet.
62: Execution failed: not DAO administrator.
63: Execution failed: not token super administrator.
64: Execution failed: not stake administrator.
65: Execution failed: not token administrator.
66: Execution failed: ratio configuration must not exceed 10_000.
67: Execution failed: allocated quantity exceeds remaining quantity.
68: Execution failed: price has not doubled; mint failed.
69: Execution failed: remaining mint quantity is 0.
70: Execution failed: public sale quantity exceeds target.
71: Execution failed: no secondary stake permission.
72: Execution failed: signature has expired.
73: Execution failed: unlock ratio is 0.
74: Execution failed: unlocked quantity is 0.
75: Execution failed: unlock burn amount is too large.
NativeETHTransferFailed()          6c0f429e   Native ETH transfer failed
ERC20TransferFailed()              f27f64e4   ERC-20 transfer failed
ERC20PermitFailed()                40754b6a   ERC-20 transfer failed
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
