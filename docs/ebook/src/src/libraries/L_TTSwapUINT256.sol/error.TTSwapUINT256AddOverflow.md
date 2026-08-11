# TTSwapUINT256AddOverflow
**Title:**
TTSwap Packed Balance Type (`TTSwapUINT256`)

Protocol-wide packed pair: one `uint256` holds two `uint128` limbs.

Custom errors for gas-efficient overflow handling

Layout: `amount0` in the high 128 bits, `amount1` in the low 128 bits.
The **meaning** of amount0/amount1 depends on context:
**Good `currentState`**
- amount0 (`investQty`): actual / principal token quantity in the pool.
- amount1 (`Q`): total virtual depth for AMM (= actual + leveraged virtual; e.g. invest 1 @ 3× → Q = 3).
**Good `goodConfig` low 128 bits** (via `config.amount1()`)
- `virtualQty`: leverage-only virtual excess, **excluding** actual deposits.
Example: invest 1 token at 3× power → `virtualQty += 2`, while `investQty = 1` and `Q = 3`.
Not the same as market value `V` (see `investState.amount1`).
**Good `investState`**
- amount0: total LP shares outstanding.
- amount1 (`V`): total pool value used for pricing (`price ≈ V / Q`).
**Proof `shares`**
- amount0: LP shares in the normal good
- amount1: TTS stake value linked to this proof
**Proof `invest`**
- amount0: virtual quantity at investment time
- amount1: actual token quantity deposited
**Swap return values (`good1change`, `good2change`)**
- amount0: fee taken from the trade
- amount1: net quantity moved (value for input side, tokens for output side)
Helpers `getamount0fromamount1` / `getamount1fromamount0` perform proportional
math using the ratio encoded in the packed word (cross-multiply with overflow checks).


```solidity
error TTSwapUINT256AddOverflow();
```

