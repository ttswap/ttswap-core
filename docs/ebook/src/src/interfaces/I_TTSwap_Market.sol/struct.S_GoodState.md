# S_GoodState
Full good state in storage (includes mappings; not returned verbatim to callers).


```solidity
struct S_GoodState {
uint256 goodConfig;
uint88 reserverd1; // commission config (reserved)
uint8 erctype;
address contractAddress;
uint96 reserved2;
address owner;
uint256 id;
address hookAddress;
uint256 currentState;
uint256 investState;
uint256 extendsState1;
uint256 extendsState2;
uint256 extendsState3;
uint256 extendsState4;
uint256 extendsState5;
uint256 extendsState6;
uint256 extendsState7;
uint256 extendsState8;
uint256 extendsState9;
mapping(address => uint256) commission;
mapping(address => uint256) extendmapping1;
mapping(address => uint256) extendmapping2;
mapping(address => uint256) extendmapping3;
mapping(address => uint256) extendmapping4;
mapping(address => uint256) extendmapping5;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`goodConfig`|`uint256`|High bits = fee config; low 128 bits (`amount1()`) = leverage `virtualQty` only.|
|`reserverd1`|`uint88`||
|`erctype`|`uint8`||
|`contractAddress`|`address`||
|`reserved2`|`uint96`||
|`owner`|`address`||
|`id`|`uint256`||
|`hookAddress`|`address`||
|`currentState`|`uint256`|amount0 = `investQty` (actual tokens); amount1 = `Q` (total virtual depth for AMM).|
|`investState`|`uint256`|amount0 = total LP shares; amount1 = `V` (pool value, `price ≈ V/Q`).|
|`extendsState1`|`uint256`||
|`extendsState2`|`uint256`||
|`extendsState3`|`uint256`||
|`extendsState4`|`uint256`||
|`extendsState5`|`uint256`||
|`extendsState6`|`uint256`||
|`extendsState7`|`uint256`||
|`extendsState8`|`uint256`||
|`extendsState9`|`uint256`||
|`commission`|`mapping(address => uint256)`|Per-address accrued fee balances (1-unit sentinel after first collect).|
|`extendmapping1`|`mapping(address => uint256)`||
|`extendmapping2`|`mapping(address => uint256)`||
|`extendmapping3`|`mapping(address => uint256)`||
|`extendmapping4`|`mapping(address => uint256)`||
|`extendmapping5`|`mapping(address => uint256)`||

