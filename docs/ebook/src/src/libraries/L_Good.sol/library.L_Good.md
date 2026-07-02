# L_Good
**Title:**
L_Good Library

**Author:**
ttswap.exchange@gmail.com

Core AMM + LP accounting for a single "good" (one token pool).

Each good stores:
- `currentState.amount0` (`investQty`): actual token units deposited / principal.
- `currentState.amount1` (`Q`): total virtual pool depth (actual + leverage virtual).
- `goodConfig.amount1()` (`virtualQty`): leverage-only virtual excess (not including actual).
- `investState`: (totalShares, `V` market value) — LP shares and pricing anchor.
- `goodConfig` high bits: packed fees, safe lines, flags (see `L_GoodConfig`).

**Example (3× invest, 1 token, ignore fees)**
After invest: `investQty=1`, `virtualQty=2`, `Q=3` because `Q = investQty + virtualQty`.

**Pricing model**
Pool price ≈ `investState.amount1 / currentState.amount1` (`V / Q`).
Swaps move value between two goods by:
1. Input good: user sells tokens → pool virtual qty rises → value exported (`buyGoodInput` / `payGoodInput`)
2. Output good: value imported → virtual qty falls → tokens sent to user (`buyGoodOutput` / `payGoodOutput`)
Large trades are chunked in 1% steps of pool depth to approximate a bonding curve and stay within safe-line bounds.


## Functions
### toGoodKey


```solidity
function toGoodKey(S_GoodState storage _self) internal view returns (T_GoodKey memory);
```

### updateConfigbyGoodOwner

Update the good configuration only goodowner

enpower,disinvest chips,invest fee,disinvest fee,buy fee,sell fee


```solidity
function updateConfigbyGoodOwner(S_GoodState storage _self, uint256 _goodConfig) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the good state|
|`_goodConfig`|`uint256`|New configuration value to be applied|


### updateConfigbyManager

Modify the good configuration

This function modifies the good configuration by preserving the top 33 bits and updating the rest


```solidity
function updateConfigbyManager(S_GoodState storage _self, uint256 _goodconfig) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the good state|
|`_goodconfig`|`uint256`|The new configuration value to be applied|


### updateConfigbyAdmin

Modify the good configuration

This function modifies the good configuration by preserving the top 33 bits and updating the rest


```solidity
function updateConfigbyAdmin(S_GoodState storage _self, uint256 _goodconfig) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the good state|
|`_goodconfig`|`uint256`|The new configuration value to be applied|


### lockGood

Locks a good by setting `isFreeze` (bit 246).


```solidity
function lockGood(S_GoodState storage _self) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the good state.|


### init

First-time pool setup after tokens are received.

No leverage at init: `investQty = Q = deposit`, `goodConfig.amount1()` (`virtualQty`) stays 0.
`investState` seeds shares and declared value from `_initial`.


```solidity
function init(S_GoodState storage self, uint256 _init, T_GoodKey memory _goodKey) internal;
```

### buyGoodInput

Input leg of `buyGood`: user sells tokens **into** this pool (exact-input swap, side A).

Pool notation for swap loops:
`Q` = `currentState.amount1` (total virtual depth),
`V` = `investState.amount1` (pool value). Price ≈ V/Q.
Safe-line baseline uses `currentState.amount0 + goodConfig.amount1()` (= actual + leverage virtual).
Called by `TTSwap_Market.buyGood` **before** the output good runs `buyGoodOutput`.


```solidity
function buyGoodInput(S_GoodState storage _self, uint128 _swapParam) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`||
|`_swapParam`|`uint128`|Gross token quantity the user sends (sell fee is deducted inside).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`(amount0, amount1)` = `(sellFee, exportedValue)` passed to the output good.|


### buyGoodOutput

Output leg of `buyGood`: convert imported value into tokens **out** of this pool (side B).

Receives `exportedValue` from `buyGoodInput` on the paired good.
Walks the curve in value chunks, then charges buy fee on the total token outflow.


```solidity
function buyGoodOutput(S_GoodState storage _self, uint128 _swapParam) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`||
|`_swapParam`|`uint128`|Value imported from the input good (already net of input sell fee economics).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`(amount0, amount1)` = `(buyFee, netOutputQuantity)` sent to the user.|


### payGoodOutput

Output leg of `payGood`: user wants exactly `_swapParam` **net** output tokens (exact-output, side B first).

Called **before** `payGoodInput` in `TTSwap_Market.payGood` (reverse order vs `buyGood`).
Gross pool withdrawal = desired output + buy fee. Returns how much **value** the input good must supply.


```solidity
function payGoodOutput(S_GoodState storage _self, uint128 _swapParam) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`||
|`_swapParam`|`uint128`|Target token quantity the recipient must receive (before relayer fee in market layer).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`(amount0, amount1)` = `(buyFee, valueRequired)` for the input good's `payGoodInput`.|


### payGoodInput

Input leg of `payGood`: absorb `valueRequired` from `payGoodOutput` and compute pay-token input (side A).

Mirror of `buyGoodInput` direction but driven by a **value budget** instead of a token budget.
Market checks `sellFee + netInput <= maxInput` (slippage on payer side).


```solidity
function payGoodInput(S_GoodState storage _self, uint128 _swapParam) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`||
|`_swapParam`|`uint128`|Value to import (from `payGoodOutput.get` on the output good).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`(amount0, amount1)` = `(sellFee, grossInputQuantity)` user must transfer in.|


### getGoodState

Packs live pool price as `(V, Q)` = `(investState.amount1, currentState.amount1)`.


```solidity
function getGoodState(S_GoodState storage _self) internal view returns (uint256 currentstate);
```

### investGood

Mint LP shares and deepen the pool when a user deposits `_invest` tokens.

Steps:
1. Charge invest fee → reduce actual deposit.
2. Scale deposit by `enpower` (leverage) to virtual quantity.
3. Price virtual quantity at current pool ratio → `investValue`.
4. Mint shares proportional to virtual deposit vs existing shares.
5. Update `currentState`, `investState`, and config virtual-quantity tracker.


```solidity
function investGood(
    S_GoodState storage _self,
    uint128 _invest,
    S_GoodInvestReturn memory investResult_,
    uint128 enpower
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`||
|`_invest`|`uint128`||
|`investResult_`|`S_GoodInvestReturn`||
|`enpower`|`uint128`|Leverage factor in percent (100 = 1x, 200 = 2x virtual liquidity).|


### disinvestGood

Disinvest from a good and potentially its associated value good

This function handles the complex process of disinvesting from a good, including fee calculations and state updates


```solidity
function disinvestGood(
    S_GoodState storage _self,
    S_ProofState storage _investProof,
    S_GoodDisinvestParam memory _params
) internal returns (S_GoodDisinvestReturn memory normalGoodResult1_, uint256 disinvestvalue);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the main good state|
|`_investProof`|`S_ProofState`|Storage pointer to the investment proof state|
|`_params`|`S_GoodDisinvestParam`|Struct containing disinvestment parameters|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`normalGoodResult1_`|`S_GoodDisinvestReturn`|Struct containing disinvestment results for the main good|
|`disinvestvalue`|`uint256`|The total value being disinvested|


### allocateFee

Allocate fees to various parties

This function handles the allocation of fees to the market creator, gater, referrer, and liqidity providers


```solidity
function allocateFee(
    S_GoodState storage _self,
    uint128 _profit,
    address _gater,
    address _referral,
    uint128 _divestQuantity,
    address _sender
) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_self`|`S_GoodState`|Storage pointer to the good state|
|`_profit`|`uint128`|The total profit to be allocated|
|`_gater`|`address`|The address of the gater (if applicable)|
|`_referral`|`address`|The address of the referrer (if applicable)|
|`_divestQuantity`|`uint128`|The quantity of goods being divested (if applicable)|
|`_sender`|`address`||


### getInvestPower

Dynamic leverage cap based on pool utilization.

`config.amount1()` = leverage `virtualQty` only.
`currentState.amount1 - virtualQty` ≈ actual token depth; compared to `currentState.amount0` (`investQty`).


```solidity
function getInvestPower(S_GoodState storage _self) internal view returns (uint128 limitpower_);
```

## Structs
### S_SwapTemp
Scratch space for iterative swap simulation (memory-only, not persisted).


```solidity
struct S_SwapTemp {
    uint128 swap_fee;
    uint128 remain;
    uint128 get;
    uint128 current_quantity;
    uint128 current_value;
    uint256 config;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`swap_fee`|`uint128`|Fee charged on this leg of the swap (sell or buy fee depending on direction).|
|`remain`|`uint128`|Value or quantity still to process in the chunking loop.|
|`get`|`uint128`|Accumulated output (value on input leg, quantity on output leg).|
|`current_quantity`|`uint128`|Pool virtual quantity at the current simulation step.|
|`current_value`|`uint128`|Pool total value (V) at the current simulation step.|
|`config`|`uint256`|Cached `goodConfig` to avoid repeated SLOADs in the loop.|

### S_GoodInvestReturn
Return struct for `investGood` — intermediate values before proof update.


```solidity
struct S_GoodInvestReturn {
    uint128 investFeeQuantity; // The actual fee amount charged for the investment
    uint128 investShare; // The construction fee amount (if applicable)
    uint128 investValue; // The actual value invested after fees
    uint128 investQuantity; // Virtual total credited to Q (actual × leverage%; e.g. 1 @ 3× → 3)
    uint128 goodShares;
    uint128 goodValues;
    uint128 goodInvestQuantity;
    uint128 goodCurrentQuantity;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`investFeeQuantity`|`uint128`|Tokens retained as invest fee (stay in pool).|
|`investShare`|`uint128`|New LP shares minted to the investor.|
|`investValue`|`uint128`|Virtual value credited at pool price (before leverage normalization).|
|`investQuantity`|`uint128`|Virtual quantity added (actual deposit × leverage / 100).|
|`goodShares`|`uint128`|Cached total shares before update.|
|`goodValues`|`uint128`|Cached total value before update.|
|`goodInvestQuantity`|`uint128`|Cached `investQty` (`currentState.amount0`).|
|`goodCurrentQuantity`|`uint128`|Cached total depth `Q` (`currentState.amount1`).|

### S_GoodDisinvestReturn
Struct to hold the return values of a disinvestment operation

Used to store and return the results of disinvesting from a good


```solidity
struct S_GoodDisinvestReturn {
    uint128 profit; // The profit earned from disinvestment
    uint128 actual_fee; // The actual fee charged for disinvestment
    uint128 shares;
    uint128 virtualDisinvestQuantity; // Virtual qty divested from Q (includes leverage leg)
    uint128 actualDisinvestQuantity;
    uint128 disinvestTTSValue;
}
```

### S_GoodDisinvestParam
Struct to hold the parameters for a disinvestment operation

Used to pass multiple parameters to the disinvestGood function


```solidity
struct S_GoodDisinvestParam {
    uint128 _goodshares; // The shares of goods to disinvest
    address _gater; // The address of the gater (if applicable)
    address _referral; // The address of the referrer (if applicable)
    address _sender; // The address of the sender
}
```

