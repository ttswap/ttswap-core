# I_TTSwap_Market
**Title:**
I_TTSwap_Market

Public API for the TTSwap on-chain market (v2.0.0).

**Core concepts**
- **Good**: one token pool (`T_GoodKey` → `goodId`) with virtual AMM state and fee config.
- **Proof**: one user's LP position in a good; id = `keccak256(owner, goodId)`.
- **buyGood**: exact-input swap — specify input token qty + minimum gross output.
- **payGood**: exact-output swap / same-token pay — specify max input + target output.

**Good quantity fields** (see `L_GoodConfig` glossary):
`currentState.amount0` = investQty; `currentState.amount1` = Q;
`goodConfig.amount1()` = leverage virtualQty only; `investState.amount1` = V.

**Packed return / state words** (`TTSwapUINT256`): high 128 bits = `amount0`, low 128 bits = `amount1`.
Swap legs return `(fee, quantityOrValue)`; see `L_TTSwapUINT256.sol` for field semantics per context.

**Meta-transactions**
Only `buyGood` and `payGood` verify EIP-712 when `msg.sender != _trader`.
Every other function that includes `bytes calldata signature` keeps it for ABI compatibility only;
the implementation requires `_trader == msg.sender` via `_checkTrader`.


## Functions
### nonces

EIP-712 nonce for `_trader` on signed `buyGood` / `payGood`; increment via `cancelNonce`.


```solidity
function nonces(address _trader) external view returns (uint256);
```

### initGood

Create a new good (token pool) at a user-declared initial price.


```solidity
function initGood(
    T_GoodKey memory _goodKey,
    uint256 _initial,
    bytes memory _normaldata,
    address _trader,
    bytes calldata _signature
) external payable returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey`|`T_GoodKey`|Token identifier (ERC-20 or native `address(1)`).|
|`_initial`|`uint256`|amount0 = declared total value, amount1 = token quantity deposited.|
|`_normaldata`|`bytes`|Transfer auth: empty + `msg.value` for native; approve/permit data for ERC-20.|
|`_trader`|`address`|Must equal `msg.sender`.|
|`_signature`|`bytes`|Unused (ABI placeholder).|


### investGood

Add single-token liquidity to an existing good.

Deposits `_invest.amount1` tokens; virtual shares scale by pool leverage (`getInvestPower`).
Reverts: 10 frozen, 12 missing good, 18 overflow, 38 value dust, 46 run-block replay.


```solidity
function investGood(
    T_GoodKey memory _goodKey,
    uint256 _invest,
    bytes calldata _gooddata,
    bytes calldata signature,
    address _trader
) external payable returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey`|`T_GoodKey`|Good to invest in.|
|`_invest`|`uint256`|amount1 = token quantity to deposit (amount0 unused on input).|
|`_gooddata`|`bytes`|Encoded transfer (approve / EIP-2612 / Permit2).|
|`signature`|`bytes`|Unused (ABI placeholder).|
|`_trader`|`address`|Must equal `msg.sender`.|


### buyGood

Exact-input swap: sell `_goodKey1`, buy `_goodKey2`.

Flow: `buyGoodInput` on good1 → `buyGoodOutput` on good2 → token transfers.
When `msg.sender != _trader`, `signature` must be valid EIP-712 over the typed payload + `nonces[_trader]`.


```solidity
function buyGood(
    T_GoodKey memory _goodKey1,
    T_GoodKey memory _goodKey2,
    uint256 _swapQuantity,
    address _referral,
    bytes calldata data,
    address _trader,
    bytes calldata signature,
    uint256 external_info
) external payable returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey1`|`T_GoodKey`|Input (sell) good.|
|`_goodKey2`|`T_GoodKey`|Output (buy) good.|
|`_swapQuantity`|`uint256`|amount0 = exact input token qty; amount1 = min gross output (slippage, 0 = no check).|
|`_referral`|`address`|Referral recipient when `!= _trader` and `!= 0` (registered via TTS token); else ignored.|
|`data`|`bytes`|Input-token transfer authorization for the relayer path.|
|`_trader`|`address`|Signer / economic actor.|
|`signature`|`bytes`|EIP-712 signature; required when caller is a relayer.|
|`external_info`|`uint256`|App metadata; low 64 bits = unix deadline (reverts 49 if expired).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|`(sellFee, exportedValue)` on input good.|
|`good2change`|`uint256`|`(buyFee, netOutputQty)` on output good (relayer fee deducted off-chain transfer).|


### payGood

Exact-output swap or same-token payment.

Cross-good: `payGoodOutput` on good2 → `payGoodInput` on good1.
Same good: direct transfer without AMM (good2 event field = 0).


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
) external payable returns (uint256 good1change, uint256 good2change);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodKey1`|`T_GoodKey`|Pay-token / input good.|
|`_goodKey2`|`T_GoodKey`|Output good (may equal good1 for direct pay).|
|`_swapQuantity`|`uint256`|amount0 = max input (slippage cap); amount1 = target gross output qty.|
|`_recipient`|`address`|Must be non-zero; receives output tokens (net of relayer fee when applicable).|
|`data`|`bytes`|Input-token transfer authorization.|
|`_trader`|`address`|Signer / payer.|
|`signature`|`bytes`|EIP-712 signature when `msg.sender != _trader`.|
|`external_info`|`uint256`|App metadata; low 64 bits = deadline (reverts 53 if expired).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1change`|`uint256`|Input-side packed change (fees + quantities).|
|`good2change`|`uint256`|Output-side packed change.|


### disinvestProof

Withdraw LP shares (partial allowed per `getDisinvestChips`).


```solidity
function disinvestProof(
    uint256 _proofid,
    uint128 _goodQuantity,
    address _gate,
    address _trader,
    bytes calldata signature
) external returns (uint128 reward1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofid`|`uint256`|Proof id for `(msg.sender, good)`.|
|`_goodQuantity`|`uint128`|Share amount to burn (not token amount).|
|`_gate`|`address`|Gate address for operator/gate fee split.|
|`_trader`|`address`|Must equal `msg.sender`.|
|`signature`|`bytes`|Unused (ABI placeholder).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reward1`|`uint128`|Profit credited to user after disinvest fee (normal-good leg).|


### ishigher

Compare implied prices of two goods using `lowerprice` (512-bit safe).


```solidity
function ishigher(uint256 goodid, uint256 valuegood, uint256 compareprice) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`uint256`|First good id.|
|`valuegood`|`uint256`|Second good id (reference / value side).|
|`compareprice`|`uint256`|Packed ratio threshold `(num, den)`.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when goodid's price is higher than valuegood under the compare ratio.|


### refreshPromise

Owner-only signal for promised goods; emits `e_getPromiseProof` when eligible.

No EIP-712, no relayer — `msg.sender` must own the proof.


```solidity
function refreshPromise(uint256 _proofid) external;
```

### getProofState

Full on-chain proof snapshot for indexing / UI.


```solidity
function getProofState(uint256 proofid) external view returns (S_ProofState memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`S_ProofState`|proofstate `S_ProofState` — see `L_Proof` for field meanings (position snapshots).|


### getGoodState

Lightweight good snapshot (no commission mappings).


```solidity
function getGoodState(uint256 good) external view returns (S_GoodTmpState memory);
```

### getRecentGoodState

Packed `(V, Q)` price snapshot for two goods in one call.


```solidity
function getRecentGoodState(uint256 good1, uint256 good2)
    external
    view
    returns (uint256 good1currentstate, uint256 good2currentstate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`good1currentstate`|`uint256`|`(V, Q)` for good1 — see `L_Good.getGoodState`.|
|`good2currentstate`|`uint256`|`(V, Q)` for good2.|


### queryCommission

Accrued commission balances per good for `_recipient` (max 100 ids).

`address(0)` recipient reads protocol/platform commission slot.


```solidity
function queryCommission(uint256[] calldata _goodid, address _recipient) external view returns (uint256[] memory);
```

### modifyGoodByGoodOwner

Good owner patches owner-writable config bits (fees, power, chips).


```solidity
function modifyGoodByGoodOwner(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    returns (bool);
```

### modifyGoodByManager

Market manager patches manager-writable bits (fee split, safe lines, flags).


```solidity
function modifyGoodByManager(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    returns (bool);
```

### modifyGoodByAdmin

Market admin patches admin bits (value-good flag, ERC type).


```solidity
function modifyGoodByAdmin(uint256 _goodid, uint256 _goodConfig, address _trader, bytes calldata signature)
    external
    returns (bool);
```

### lockGood

Freeze trading on a good (manager or good owner).


```solidity
function lockGood(uint256 _goodid, address _trader, bytes calldata signature) external;
```

### changeGoodOwner

Transfer good ownership (market manager only).


```solidity
function changeGoodOwner(uint256 _goodid, address _to, address _trader, bytes calldata signature) external;
```

### collectCommission

Pull accrued commission for up to 100 goods to `msg.sender`.

Market admin collects platform slot (`recipient == address(0)` internally).


```solidity
function collectCommission(uint256[] calldata _goodid, address _trader, bytes calldata signature) external;
```

### goodWelfare

Donate tokens to a pool's depth without minting shares (LP welfare).


```solidity
function goodWelfare(
    uint256 goodid,
    uint128 welfare,
    bytes calldata data1,
    address _trader,
    bytes calldata signature
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`uint256`||
|`welfare`|`uint128`||
|`data1`|`bytes`|Transfer authorization for the donated tokens.|
|`_trader`|`address`||
|`signature`|`bytes`||


### cancelNonce

Invalidate pending signed `buyGood` / `payGood` intents by bumping caller nonce.


```solidity
function cancelNonce() external;
```

## Events
### e_updateGoodConfig
Good owner updated fee/power region of `goodConfig` (owner-writable bits).


```solidity
event e_updateGoodConfig(uint256 indexed _goodid, uint256 _goodConfig, address _trader);
```

### e_modifyGoodConfig
Market manager or admin updated `goodConfig` (manager/admin bit regions).


```solidity
event e_modifyGoodConfig(uint256 indexed _goodid, uint256 _goodconfig, address _trader);
```

### e_changegoodowner
Good ownership transferred by market manager.


```solidity
event e_changegoodowner(uint256 goodid, address to, address _trader);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goodid`|`uint256`|Good id.|
|`to`|`address`|New owner.|
|`_trader`|`address`||

### e_collectcommission
Commission balances withdrawn for one or more goods.


```solidity
event e_collectcommission(uint256[] _goodid, uint256[] _commisionamount, address _trader);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_goodid`|`uint256[]`|Good ids processed (max 100 per call).|
|`_commisionamount`|`uint256[]`|Token amount sent per good (parallel array).|
|`_trader`|`address`||

### e_goodWelfare
Donor topped up pool reserves without minting shares (welfare).


```solidity
event e_goodWelfare(uint256 indexed goodid, uint128 welfare, address _trader);
```

### e_investGood
Liquidity added to an existing good (`investGood`).


```solidity
event e_investGood(
    uint256 indexed _proofNo,
    uint256 indexed _goodid,
    uint256 _construct,
    uint256 _value,
    uint256 _invest,
    address _trader
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|Proof id for `(msg.sender, _goodid)`.|
|`_goodid`|`uint256`|Target good id.|
|`_construct`|`uint256`|TTS stake receipt from `TTS_CONTRACT.stake` (0 if good not promised).|
|`_value`|`uint256`|Packed `(virtualInvestValue, actualInvestValue)` after leverage normalization.|
|`_invest`|`uint256`|Packed `(investFeeQty, virtualInvestQty)` credited to the pool.|
|`_trader`|`address`||

### e_initGood
New good pool created (`initGood`).


```solidity
event e_initGood(
    uint256 indexed _proofNo,
    uint256 indexed _goodid,
    uint256 _goodinfo,
    uint256 _good_id,
    uint256 _normalinitial,
    address _trader
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|Creator's initial proof id.|
|`_goodid`|`uint256`|New good id.|
|`_goodinfo`|`uint256`|Packed `(ercType << 160) | tokenAddress` from `T_GoodKey.composedata()`.|
|`_good_id`|`uint256`|ERC-1155/6909 id field (0 for ERC-20 / native).|
|`_normalinitial`|`uint256`|Packed init: amount0 = declared value, amount1 = deposited quantity.|
|`_trader`|`address`||

### e_buyGood
Exact-input swap completed (`buyGood`).


```solidity
event e_buyGood(
    uint256 indexed sellgood,
    uint256 indexed forgood,
    uint256 swapvalue,
    uint256 good1change,
    uint256 good2change,
    address _trader,
    uint256 external_info
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sellgood`|`uint256`|Input good id (tokens sold in).|
|`forgood`|`uint256`|Output good id (tokens bought out).|
|`swapvalue`|`uint256`|Input token quantity moved on the sell side (good1change.amount1).|
|`good1change`|`uint256`|Packed `(sellFee, inputQty)` on the input good.|
|`good2change`|`uint256`|Packed `(buyFee, grossOutputQty)` on the output good (before relayer fee).|
|`_trader`|`address`||
|`external_info`|`uint256`|Opaque metadata; low 64 bits may encode deadline for meta-tx.|

### e_payGood
Exact-output payment completed (`payGood`).


```solidity
event e_payGood(
    uint256 indexed sellgood,
    uint256 indexed forgood,
    uint256 swapvalue,
    uint256 good1change,
    uint256 good2change,
    address _trader,
    address _recipient,
    uint256 external_info
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sellgood`|`uint256`|Input / pay-token good id.|
|`forgood`|`uint256`|Output good id (0 when same-token direct pay path).|
|`swapvalue`|`uint256`|Gross output quantity targeted on cross-good path.|
|`good1change`|`uint256`|Packed input-side fee and quantities.|
|`good2change`|`uint256`|Packed output-side fee and quantities.|
|`_trader`|`address`||
|`_recipient`|`address`|Final token recipient.|
|`external_info`|`uint256`|Business metadata; low 64 bits = deadline on signed pay path.|

### e_disinvestProof
LP shares burned and proceeds distributed (`disinvestProof`).


```solidity
event e_disinvestProof(
    uint256 indexed _proofNo,
    uint256 _normalGoodNo,
    address _gate,
    uint256 _value,
    uint256 _normalprofit,
    uint256 _normaldisvest,
    uint256 _TTSValue,
    address _trader
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proofNo`|`uint256`|Proof id.|
|`_normalGoodNo`|`uint256`|Good id being exited.|
|`_gate`|`address`|Gate address used for fee routing (may be zeroed if banned).|
|`_value`|`uint256`|Packed disinvest value snapshot from proof ratios.|
|`_normalprofit`|`uint256`|Packed `(profit, virtualDisinvestQty)`.|
|`_normaldisvest`|`uint256`|Packed `(disinvestFee, actualDisinvestQty)`.|
|`_TTSValue`|`uint256`|TTS unstaked on this withdrawal.|
|`_trader`|`address`||

### e_getPromiseProof
Emitted when a promised-good owner signals a claimable proof (`refreshPromise`).


```solidity
event e_getPromiseProof(uint256 indexed _goodid, uint256 _proofid);
```

