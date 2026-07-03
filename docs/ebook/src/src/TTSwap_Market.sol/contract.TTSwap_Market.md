# TTSwap_Market
**Inherits:**
[I_TTSwap_Market](/src/interfaces/I_TTSwap_Market.sol/interface.I_TTSwap_Market.md), [IMulticall_v4](/src/interfaces/IMulticall_v4.sol/interface.IMulticall_v4.md)

**Title:**
TTSwap_Market

**Author:**
ttswap.exchange@gmail.com

Core on-chain market: create goods, provide liquidity, swap, pay, and withdraw.

**Mental model for integrators**
- A **good** = one token pool with its own virtual AMM state and fee config.
- A **proof** = one user's LP position in a good (id = hash of owner + good).
- **buyGood** = exact-input swap (you specify how much you sell; min output is slippage guard).
- **payGood** = exact-output swap or same-token transfer (you specify how much recipient gets).
- **Value good** flag (config bit 255) marks pricing/reference tokens (e.g. stablecoin side).

**Good quantity fields** (see `L_GoodConfig` glossary):
`currentState.amount0` = investQty; `currentState.amount1` = Q;
`goodConfig.amount1()` = leverage virtualQty only; `investState.amount1` = V.

**Meta-transactions**
Only `buyGood` and `payGood` verify EIP-712 when `msg.sender != _trader`.
All other functions with a `signature` argument keep it for ABI compatibility only;
they require `_trader == msg.sender` via `_checkTrader`.

**Security modifiers**
- `guardedEntry`: reentrancy lock (standalone 0→2, or 1→2 inside multicall).
- `msgValue`: transient native-ETH budget for the whole call tree.
- `multicallEntry`: arms lock level 1 so batched delegatecalls share one ETH budget.
website  http://www.ttswap.io
twitter  https://x.com/ttswapfinance
telegram https://t.me/ttswapfinance
discord  https://discord.gg/XygqnmQgX3


## State Variables
### implementation
Reserved storage slot for **proxy implementation pointer** (UUPS / transparent proxy layout).
Intentionally unused in logic-only builds; keeps layout aligned with deployed proxy. See audit M-06.


```solidity
address internal implementation
```


### TTS_CONTRACT
TTS token contract — permissions, referral, stake/unstake hooks.


```solidity
I_TTSwap_Token internal immutable TTS_CONTRACT
```


### nonces
Per-trader nonce consumed by EIP-712 signed `buyGood` / `payGood` (also manually bumpable via `cancelNonce`).


```solidity
mapping(address _trader => uint256 nonce) public nonces
```


### upgradeable
Reserved flag for upgrade / admin flows in proxy deployments; placeholder in logic contract. See audit M-06.


```solidity
bool internal upgradeable
```


### goods
All goods indexed by `T_GoodKey.toId()`.
Each stores pool depth, LP totals, owner, fees, and per-recipient commission balances.


```solidity
mapping(uint256 goodid => S_GoodState) private goods
```


### proofs
LP proofs indexed by `S_ProofKey.toId()` (hash of owner + good id).


```solidity
mapping(uint256 proofid => S_ProofState) private proofs
```


### executeFee
Relayer execution fee denominator: fee in output-token units = poolPrice(executeFee).
`50_000_000_000` is the fixed amount0 side; amount1 is derived per output good price.


```solidity
uint128 internal constant executeFee = 50_000_000_000
```


### Version
EIP-712 domain version string.


```solidity
string internal constant Version = "2.0.0"
```


## Functions
### constructor


```solidity
constructor(I_TTSwap_Token _TTS_Contract) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TTS_Contract`|`I_TTSwap_Token`|Official TTSwap token (roles, referral, staking).|


### onlyMarketadmin

Requires `TTS_CONTRACT.userConfig(msg.sender).isMarketAdmin()`.


```solidity
modifier onlyMarketadmin() ;
```

### onlyMarketor

Requires `TTS_CONTRACT.userConfig(msg.sender).isMarketManager()`.


```solidity
modifier onlyMarketor() ;
```

### msgValue

Wraps native-ETH accounting (`L_Transient`) around the function body.
Use on any entrypoint that may move native goods or receive `msg.value`.


```solidity
modifier msgValue() ;
```

### multicallEntry

Multicall entry: arms lock level 1 so guarded subcalls can promote 1→2.


```solidity
modifier multicallEntry() ;
```

### guardedEntry

Guarded entry: works standalone (lock 0→2) and inside multicall (lock 1→2).
Reverts on reentrancy (lock == 2). Restores previous lock level on exit.


```solidity
modifier guardedEntry() ;
```

### _checkTrader

Direct-call only: `_trader` must be `msg.sender` (no relayer on this path).


```solidity
function _checkTrader(address _trader) private view;
```

### _checkGoodActive

Shared guard for swap / invest paths.

Also enforces **run-block** anti-replay: one state-changing touch per good per `block.number % 4095`.


```solidity
function _checkGoodActive(S_GoodState storage g, uint256 freezeErr, uint256 emptyErr) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`g`|`S_GoodState`||
|`freezeErr`|`uint256`|Error code when good is frozen (10 buy-side, 11 pay output, etc.).|
|`emptyErr`|`uint256`|Error code when good not initialized (12 / 13).|


### multicall

Batch multiple market calls in one transaction (delegatecall into self).

Must be `payable` with `msgValue` + `multicallEntry` so native ETH budget is set once
at the outer boundary and not re-seeded on each subcall (see `L_Transient`).


```solidity
function multicall(bytes[] calldata data)
    external
    payable
    msgValue
    multicallEntry
    returns (bytes[] memory results);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes[]`|The encoded function data for each of the calls to make to this contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`results`|`bytes[]`|The results from each of the calls passed in via data|


### initGood

Create a new good (token pool) with a user-chosen initial price.

Deposits `_initial.amount1` tokens and declares `_initial.amount0` as total pool value.
Mints the first proof for `msg.sender` with 100% of initial shares.


```solidity
function initGood(
    T_GoodKey memory _goodKey,
    uint256 _initial,
    bytes calldata _normaldata,
    address _trader,
    bytes calldata _signature
) external payable override guardedEntry msgValue returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey`|`T_GoodKey`|Token identifier (ERC-20 or native sentinel `address(1)`).|
|`_initial`|`uint256`|amount0 = declared value, amount1 = token quantity deposited.|
|`_normaldata`|`bytes`|Encoded transfer path (approve / permit / Permit2) for ERC-20; empty for native with `msg.value`.|
|`_trader`|`address`|Must equal `msg.sender`.|
|`_signature`|`bytes`|Unused (ABI placeholder).|


### investGood

Add single-token liquidity to an existing good without pairing a value good.

The caller deposits only the target token; its credited value is derived from
the current pool price and scaled by the leverage factor (`enpower`).
Flow: isInvestBlocked (price guard) → transfer tokens in → compute virtual shares
→ update good state → update/create proof → stake value to TTS.
Reverts with TTSwapError(47) if the deposit price exceeds the current pool price,
TTSwapError(38) if the resulting investment value is below the dust threshold.


```solidity
function investGood(
    T_GoodKey memory _goodKey,
    uint256 _invest,
    bytes calldata _gooddata,
    bytes calldata signature,
    address _trader
) external payable override guardedEntry msgValue returns (bool result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey`|`T_GoodKey`| Address of the ERC-20 token (good) to invest in.|
|`_invest`|`uint256`| Packed uint256 — amount0: credited value per unit, amount1: token quantity to deposit.|
|`_gooddata`|`bytes`| Encoded transfer authorisation (plain approve / EIP-2612 / Permit2).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here (C-01 scheme B). Do not rely on relayer semantics.|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`); receives the investment proof context in events.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bool`| True on success.|


### buyGood

This function calculates the swap amount based on the AMM formula, deducts fees,
updates reserves, and transfers tokens.

Executes a swap (buy) between two goods.

**Notes:**
- security: Protected by reentrancy guard.

- security: Verifies EIP-712 signature if the caller is a relayer.

- security: Checks slippage tolerance against gross AMM output (`_swapQuantity.amount1()`).

- security: Validates that the pool has sufficient liquidity and is not frozen.


```solidity
function buyGood(
    T_GoodKey memory _goodKey1,
    T_GoodKey memory _goodKey2,
    uint256 _swapQuantity,
    address _recipient,
    bytes calldata data,
    address _trader,
    bytes calldata signature,
    uint256 external_info
) external payable override guardedEntry msgValue returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey1`|`T_GoodKey`|The address of the input good (selling).|
|`_goodKey2`|`T_GoodKey`|The address of the output good (buying).|
|`_swapQuantity`|`uint256`|The swap details: - amount0: The input quantity of _goodid1. - amount1: The minimum gross output quantity of _goodid2 before any relayer execution fee.|
|`_recipient`|`address`|The address to receive the bought goods (if different from trader). Also used for referral tracking if different from trader.|
|`data`|`bytes`|Additional data for the input token transfer (Permit/Transfer).|
|`_trader`|`address`|The address of the trader initiating the swap (must match signer if signature used).|
|`signature`|`bytes`|The EIP-712 signature authorizing the trade (if msg.sender != _trader).|
|`external_info`|`uint256`|External business metadata (e.g., payment order id or other extra info).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|The state change of the input good: - amount0: Fee quantity deducted. - amount1: Actual input quantity swapped.|
|`good2change`|`uint256`|The state change of the output good: - amount0: Fee quantity deducted. - amount1: Gross output quantity from the AMM before any relayer execution fee.|


### payGood

This function calculates the input amount needed to get a specific gross output amount (inverse swap).
If `_goodid1` == `_goodid2`, it performs a direct transfer path with relayer fee deduction semantics.

Executes a payment or swap using specific output quantity (Pay).

**Notes:**
- security: Protected by reentrancy guard.

- security: Verifies EIP-712 signature if the caller is a relayer.

- security: Checks max input limit (`_swapQuantity.amount0()`).

- security: `external_info` is included in signature payload as business context metadata.


```solidity
function payGood(
    T_GoodKey memory _goodKey1,
    T_GoodKey memory _goodKey2,
    uint256 _swapQuantity,
    address _recipient,
    bytes calldata data,
    address _trader,
    bytes calldata signature,
    uint256 external_info
) external payable guardedEntry msgValue returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey1`|`T_GoodKey`|The address of the input good (paying with).|
|`_goodKey2`|`T_GoodKey`|The address of the output good (paying to).|
|`_swapQuantity`|`uint256`|The swap details: - amount0: The maximum input quantity of _goodid1 (slippage protection). - amount1: The target gross output quantity of _goodid2 before any relayer execution fee.|
|`_recipient`|`address`|The address to receive the payment (goods). In relayer mode, net delivery may be lower because execution fee is deducted from gross output.|
|`data`|`bytes`|Additional data for the input token transfer (Permit/Transfer).|
|`_trader`|`address`|The address of the trader initiating the payment (must match signer).|
|`signature`|`bytes`|The EIP-712 signature authorizing the payment (if msg.sender != _trader).|
|`external_info`|`uint256`|amount0: external business metadata (e.g. payment order id). amount1: deadline; if non-zero and `block.timestamp` exceeds it, reverts `TTSwapError(53)`.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|The state change of the input good: - amount0: Fee quantity deducted. - amount1: Actual input quantity used.|
|`good2change`|`uint256`|The state change of the output good: - amount0: Fee quantity deducted. - amount1: Gross output quantity from the AMM / direct-pay path before any relayer execution fee.|


### disinvestProof

Withdraw LP shares: return principal + profit, split fees to gate/referral/platform.


```solidity
function disinvestProof(
    uint256 _proofid,
    uint128 _goodshares,
    address _gate,
    address _trader,
    bytes calldata signature
) external override guardedEntry returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofid`|`uint256`|Proof id for `(msg.sender, good)`.|
|`_goodshares`|`uint128`|Share amount to burn (partial withdraw allowed per `getDisinvestChips`).|
|`_gate`|`address`|Gate address for operator/customer fee routing (zeroed if banned).|
|`_trader`|`address`|Must equal `msg.sender`.|
|`signature`|`bytes`|Unused (ABI placeholder).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|Profit credited to the user after fees (normal-good leg).|


### refreshPromise

Emits `e_getPromiseProof` for applied goods when the caller is the good owner and proof matches `msg.sender`.

**C-01 / M-08**: No EIP-712 and **no relayer/meta-tx**; only the proof owner can call (enforced via `S_ProofKey(msg.sender, ...)`).
Integrators must not assume a signature or `_trader` parameter — caller MUST be `msg.sender`.


```solidity
function refreshPromise(uint256 _proofid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofid`|`uint256`|Proof id derived from `(msg.sender, currentgood, valuegood)`.|


### ishigher

This function:
- Compares the current trading iterations (states) of two goods
- Used to determine the trading order and eligibility for operations
- Essential for maintaining trading synchronization between goods
- Returns false if either good is not registered (state = 0)

Compares the current trading states of two goods to determine if the first good is in a higher iteration

**Notes:**
- security: This is a view function with no state modifications

- security: Returns false for unregistered goods to prevent invalid operations


```solidity
function ishigher(uint256 goodid, uint256 valuegood, uint256 compareprice) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`uint256`|First good id.|
|`valuegood`|`uint256`|Second good id (reference / value side).|
|`compareprice`|`uint256`|the price of use good2 for good1|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Returns true if good1's current state is higher than good2's, false otherwise|


### getRecentGoodState

This function is a view function that:
- Returns the current trading iteration (state) for both goods
- Useful for checking the latest trading status of a pair of goods
- Can be used to verify if goods are in sync for trading operations

Retrieves the current state of two goods in a single call

**Notes:**
- security: This is a view function with no state modifications

- security: Returns 0 if either good address is not registered


```solidity
function getRecentGoodState(uint256 good1, uint256 good2)
    external
    view
    returns (uint256 good1currentstate, uint256 good2currentstate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`good1`|`uint256`|The address of the first good to query|
|`good2`|`uint256`|The address of the second good to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1currentstate`|`uint256`|`(V, Q)` for good1 — see `L_Good.getGoodState`.|
|`good2currentstate`|`uint256`|`(V, Q)` for good2.|


### getProofState

Retrieves the current state of a proof.


```solidity
function getProofState(uint256 proofid) external view returns (S_ProofState memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proofid`|`uint256`|Proof id (`keccak256(owner, goodId)`).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`S_ProofState`|proofstate Snapshot — see `S_ProofState` / `L_Proof` (position-level, not pool `virtualQty`).|


### getGoodState

Retrieves the current state of a good.


```solidity
function getGoodState(uint256 good) external view returns (S_GoodTmpState memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`good`|`uint256`|Good id.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`S_GoodTmpState`|goodstate Snapshot: - goodConfig: fee flags + `virtualQty` in low 128 bits (`config.amount1()`). - currentState.amount0 = `investQty`; amount1 = `Q` (total virtual depth). - investState.amount0 = shares; amount1 = `V` (pool value).|


### modifyGoodByGoodOwner

Updates a good's configuration


```solidity
function modifyGoodByGoodOwner(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### modifyGoodByManager

Market manager patches manager-writable bits (fee split, safe lines, flags).


```solidity
function modifyGoodByManager(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    onlyMarketor
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### modifyGoodByAdmin

Market admin patches admin bits (value-good flag, ERC type).


```solidity
function modifyGoodByAdmin(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    override
    onlyMarketadmin
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256`|The ID of the good|
|`_goodConfig`|`uint256`|The new configuration|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success status|


### lockGood

Locks a good when the caller is market manager or good owner.


```solidity
function lockGood(uint256 _goodid, address _trader, bytes calldata signature) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256`|The good to lock.|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|


### changeGoodOwner

Changes the owner of a good


```solidity
function changeGoodOwner(uint256 _goodid, address _to, address _trader, bytes calldata signature)
    external
    override
    onlyMarketor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256`|The ID of the good|
|`_to`|`address`|The new owner's address|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|


### collectCommission

Collects commission for specified goods

Market admin collects platform slot (`recipient == address(0)` internally).


```solidity
function collectCommission(uint256[] calldata _goodid, address _trader, bytes calldata signature)
    external
    override
    guardedEntry;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256[]`|Array of good IDs|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|


### queryCommission

This function:
- Returns commission amounts for up to 100 goods in a single call
- Each amount represents the commission available for the recipient
- Returns 0 for goods where no commission is available
- Maintains gas efficiency by using a fixed array size

Queries commission amounts for multiple goods for a specific recipient

**Notes:**
- security: Reverts if more than 100 goods are queried

- security: View function, does not modify state


```solidity
function queryCommission(uint256[] calldata _goodid, address _recipient) external view returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256[]`|Array of good addresses to query commission for|
|`_recipient`|`address`|The address to check commission amounts for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|feeamount Array of commission amounts corresponding to each good|


### goodWelfare

This function:
- Allows anyone to contribute additional funds to a good's fee pool
- Increases the good's feeQuantityState by the welfare amount
- Transfers tokens from the sender to the good
- Emits an event with the welfare contribution details

Adds welfare funds to a good's fee pool

**Notes:**
- security: Protected by noReentrant modifier

- security: Checks for overflow in feeQuantityState


```solidity
function goodWelfare(
    uint256 goodid,
    uint128 welfare,
    bytes calldata data,
    address _trader,
    bytes calldata signature
) external payable guardedEntry msgValue;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`uint256`|The address of the good to receive welfare|
|`welfare`|`uint128`|The amount of tokens to add as welfare|
|`data`|`bytes`|Additional data for token transfer|
|`_trader`|`address`|Must equal `msg.sender` (enforced by `_checkTrader`).|
|`signature`|`bytes`|Reserved for ABI compatibility; **not verified** here.|


### DOMAIN_SEPARATOR

Returns the EIP-712 domain separator used by relayed entrypoints.

Always computed from the current execution context so proxy calls bind signatures
to the proxy address instead of the implementation address.


```solidity
function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
```

### computeDomainSeparator


```solidity
function computeDomainSeparator() internal view virtual returns (bytes32);
```

### cancelNonce

Invalidate pending EIP-712 signatures by bumping the caller's nonce.


```solidity
function cancelNonce() external;
```

