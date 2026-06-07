# TTSwap v2.0 测试任务清单

> 由 [`COVERAGE_REPORT.md`](./COVERAGE_REPORT.md) 未覆盖行映射生成。  
> 基线：**297/298** 通过（1 skip）· Lines **67.42%** · Branches **44.90%**

**图例**：`[ ]` 待做 · `[~]` 进行中 · `[x]` 完成  
**优先级**：P0 安全/资金路径 · P1 核心业务 · P2 view/边缘 · P3 低优先/依赖外部环境

---

## 进度总览

| 优先级 | 任务数 | 已完成 | 目标文件 |
|--------|--------|--------|----------|
| P0 | 8 | 8 | 见 §1 |
| P1 | 12 | 12 | 见 §2 |
| P2 | 10 | 10 | 见 §3 |
| P3 | 6 | 5 | 见 §4（P3-001 仍阻塞） |

---

## §1 P0 — 安全与资金路径

### 1.1 `buyGood` meta-tx / relayer

- [x] **TASK-P0-001** `testBuyGoodMetaTx_relayer_happyPath`  
  - 文件：`test/testBuyGoodMetaTx.t.sol`（新建）  
  - 覆盖：L352–L375 签名验证、L405–L419 relayer fee + commission  
  - 步骤：relayer 代 `trader` 签 EIP-712 `buyGood`；断言 output 扣 `executeFee`、relayer commission 增加  
  - 依赖：`L_SignatureVerification`、DOMAIN_SEPARATOR、nonces

- [x] **TASK-P0-002** `testBuyGoodMetaTx_revert_expiredDeadline`  
  - 覆盖：L378–L379 · error **49**  
  - `external_info` 低 64 位设过去时间戳

- [x] **TASK-P0-003** `testBuyGoodMetaTx_revert_feeExceedsOutput` *(view: error-50 条件断言; 集成路径待池子调参)*  
  - 覆盖：L413 · error **50**  
  - 极小 swap + 高 `executeFee` 配置

- [x] **TASK-P0-004** `testBuyGoodMetaTx_revert_invalidSignature`  
  - 覆盖：`L_SignatureVerification` L38–L55  
  - 错误 signer / 错误 nonce

### 1.2 AMM safeLine / exact-out

- [x] **TASK-P0-005** `testBuyGood_revert_safeLine`  
  - 文件：扩展 `test/modified_swap_fee.sol` 或 `test/testBuySafeLine.t.sol`  
  - 覆盖：`L_Good` L187–L188、L253–L255、L270–L275 · error **45**  
  - 大额 swap 逼近 `getSafeLine` 上限

- [x] **TASK-P0-006** `testGood1Swap_exactOut_math`  
  - 文件：扩展 `test/modified_swap_without_fee.sol`  
  - 覆盖：`L_Good` L156–L161、L200–L211 · error **54**  
  - `side=false` 路径纯数学断言

- [x] **TASK-P0-007** `testGood2Swap_outputSide`  
  - 覆盖：`L_Good` L249–L277  
  - good2 exact-out 或 payGood 恢复后的对称路径

### 1.3 invest overflow

- [x] **TASK-P0-008** `testInvestGood_revert_poolOverflow`  
  - 文件：扩展 `test/testInvestGood.t.sol`  
  - 覆盖：`TTSwap_Market` L241 · error **18**  
  - 构造 `currentState.amount1() + invest > 2^109`

---

## §2 P1 — 核心业务补全

### 2.1 Market admin

- [x] **TASK-P1-001** `testLockGood_byManager`  
  - 文件：扩展 `test/testModifyGood.t.sol`  
  - 覆盖：L898–L909、`L_Good.lockGood` L83–L84  
  - manager 锁定后 `buyGood`/`investGood` revert **10**

- [x] **TASK-P1-002** `testLockGood_byOwner`  
  - good owner 锁定自己的 good

- [x] **TASK-P1-003** `testLockGood_revert_notAuthorized`  
  - 非 manager/非 owner · error **20**

- [x] **TASK-P1-004** `testChangeGoodOwner_happyPath`  
  - 覆盖：L918–L926  
  - 断言新 owner 可 `modifyGoodByGoodOwner`

- [x] **TASK-P1-005** `testGoodWelfare_happyPath`  
  - 文件：`test/testGoodWelfare.t.sol`（新建）  
  - 覆盖：L1009–L1034  
  - 参考：`testback/goodwarefareERC20NormalGood`

- [x] **TASK-P1-006** `testGoodWelfare_revert_overflow`  
  - 覆盖：L1018–L1019 · error **18**

- [x] **TASK-P1-007** `testGoodWelfare_revert_goodNotExist`  
  - 覆盖：L1017 · error **12**

### 2.2 Commission / referral

- [x] **TASK-P1-008** `testCollectCommission_referralPath`  
  - 文件：扩展 `test/testCollectCommission.t.sol`  
  - referral 用户 collect 自己 commission（非 gate/platform）

- [x] **TASK-P1-009** `testDisinvestProof_bannedGate`  
  - 文件：扩展 `test/testDisinvestProof.t.sol`  
  - banned gate 撤资手续费路径

### 2.3 Promise / proof

- [x] **TASK-P1-010** `testRefreshPromise_happyPath`  
  - 文件：`test/testRefreshPromise.t.sol`（新建）  
  - promised good owner 调用，断言 `e_getPromiseProof`

- [x] **TASK-P1-011** `testRefreshPromise_revert_notOwner`  
  - 覆盖：L731 · error **19**

### 2.4 TTSwap_Token 质押

- [x] **TASK-P1-012** `testTTSwapToken_stake_unstake_cycle`  
  - 文件：`test/testTTSwapToken.t.sol`（重写/扩展）  
  - 覆盖：`stake` L429–L458、`unstake` L473+  
  - Market 以 `isCallMintTTS` 调用；参考 `testback/Fuzz_Stake`、`testback/testTTSwapToken`  
  - 断言 `stakestate`/`poolstate`/profit mint

---

## §3 P2 — View / 边缘 / 库

### 3.1 View 函数

- [x] **TASK-P2-001** `testIshigher_comparePrices`  
  - 文件：`test/testMarketViews.t.sol`（新建）  
  - 覆盖：L755–L771  
  - init + invest 后比较两 good 价格

- [x] **TASK-P2-002** `testGetRecentGoodState`  
  - 覆盖：L788–L797

- [x] **TASK-P2-003** `testQueryCommission_view`  
  - 覆盖：L990  
  - 有/无 commission 两态

- [x] **TASK-P2-004** `testCancelNonce`  
  - 覆盖：L1060–L1061  
  - `testBuyGoodMetaTx_revert_staleNonce`（递增 nonce 后旧签名失效）

### 3.2 Multicall / 重入

- [x] **TASK-P2-005** `testGuardedEntry_revert_reentrancy`  
  - 文件：`test/testMarketReentrancy.t.sol`（新建）  
  - 覆盖：`noReentrant` L118–L122、`L_Transient`  
  - v2 无 public `multicall`；token callback 嵌套 `buyGood` → 内层 **3**，外层 `ERC20TransferFailed`

### 3.3 Token 治理（主链 mock）

- [x] **TASK-P2-006** `testTTSwapToken_setDAOAdmin_setRatio`  
  - 覆盖：L81–L84、L261–L265 · error **62/63/66**  
  - Proxy `ttstokenconfig` 含 `ismain()` bit

- [x] **TASK-P2-007** `testTTSwapToken_addShare_burnShare_shareMint`  
  - 覆盖：L287–L368  
  - `setEnv(market)` + `vm.mockCall` `ishigher`

- [x] **TASK-P2-008** `testTTSwapToken_publicSell_tiers`  
  - 覆盖：L376–L397 · error **70**  
  - tier1/tier2 + hard cap

- [x] **TASK-P2-009** `testTTSwapToken_usershares_stakeproofinfo`  
  - 覆盖：L208–L223 view

### 3.4 GoodKey / Currency

- [x] **TASK-P2-010** `testGoodKey_transfer_edgeCases`  
  - 文件：`test/testGoodKeyTransfer.t.sol`（新建）  
  - 覆盖：`T_GoodKey` balanceof、transfer executor mismatch **39**、unsupported ercType **42**  
  - DAI permit / ERC1155 路径留 P3

---

## §4 P3 — 延后 / 外部依赖

- [ ] **TASK-P3-001** `testPayGood_*` — **阻塞**：`payGood` v2 已注释；合约恢复后从 `testback/pay*.t.sol` 迁移

- [x] **TASK-P3-002** `testMarketProxy_upgrade_preservesState`  
  - 文件：`test/testProxyUpgrade.t.sol`  
  - 简化版：v2 proxy 升级后 good state 保持（完整 v1.5→v2 见 `testback/testUpgradeV1_5ToV2`）

- [x] **TASK-P3-003** `testProxy_upgrade`  
  - Market/Token：`upgrade`、`freeze*`、`disableUpgrade`、ACL revert

- [x] **TASK-P3-004** `Fuzz_*` 迁移  
  - `FuzzBase.t.sol` + `Fuzz_BuyGood/InvestGood/DisinvestProof/CollectCommission/Stake/Unstake/Shares`

- [x] **TASK-P3-005** `testMainnetAttackForkReplay_skipsWithoutFixture`  
  - 文件：`test/MainnetAttackForkReplay.t.sol`（无 fixture/RPC 时 `vm.skip`）

- [x] **TASK-P3-006** `testL_Currency_direct`  
  - `src/test/CurrencyHarness.sol` + `test/testL_Currency.t.sol`（ERC20/native/permit/错误路径）

---

## §5 建议实施顺序（迭代计划）

### Sprint 1 — 交易安全（预估 +8~12 tests）

1. TASK-P0-001 ~ P0-004（meta-tx）
2. TASK-P0-005 ~ P0-007（AMM 边缘）
3. TASK-P0-008（invest overflow）

**目标**：`TTSwap_Market` lines → **~88%**，branches → **~75%**

### Sprint 2 — Admin + 福利（预估 +10 tests）

1. TASK-P1-001 ~ P1-007
2. TASK-P1-008 ~ P1-009

**目标**：`TTSwap_Market` lines → **~95%**

### Sprint 3 — Token + Views（预估 +12 tests）

1. TASK-P1-012
2. TASK-P2-001 ~ P2-009

**目标**：`TTSwap_Token` lines → **~65%**

### Sprint 4 — Fuzz + 基础设施

1. TASK-P3-004 ~ P3-006
2. TASK-P2-005（multicall）

**目标**：总 branches → **~50%**

---

## §6 新文件模板约定

沿用 [`TEST_MAP.md`](./TEST_MAP.md) §8：

```solidity
// test/testBuyGoodMetaTx.t.sol
contract testBuyGoodMetaTx is BaseSetup {
    function testBuyGoodMetaTx_relayer_happyPath() public {
        vm.warp(1);
        // goodId = T_GoodKey(...).toId();
        // EIP-712 sign + buyGood as relayer
        snapLastCall("buyGood_metaTx");
    }
}
```

**Checklist（每个任务）**

- [ ] 继承 `BaseSetup`（或文档说明例外）
- [ ] `vm.warp(1..9)` 若触发 `updateRunTimeConfig`
- [ ] `goodId` / `proofId` 用 v2 key 推导
- [ ] revert 测试：`vm.expectRevert` 紧贴调用
- [ ] 完成后更新 `TEST_MAP.md` §5 用例表与本文件 checkbox

---

## §7 未覆盖 error code → 任务映射

| Code | 任务 ID |
|------|---------|
| 3 | TASK-P2-005 |
| 12 | TASK-P1-007 |
| 14 | TASK-P0-003 或单独 slippage 任务 |
| 18 | TASK-P0-008, TASK-P1-006 |
| 45 | TASK-P0-005 |
| 49 | TASK-P0-002 |
| 50 | TASK-P0-003 |
| 54 | TASK-P0-006 |
| 61–75 | TASK-P2-006 ~ P2-008 |
| 19 (refreshPromise) | TASK-P1-011 |

---

## §8 维护

每次完成 TASK 后：

1. `forge test --match-path "test/*"` 全绿  
2. `forge coverage --match-path "test/*" --ir-minimum --report summary` 更新 `COVERAGE_REPORT.md` 数据  
3. 将本文件对应 `[ ]` 改为 `[x]`  
4. `TEST_MAP.md` §7.1 同步勾选

---

*Last updated: 2026-06-06 · 基线 297 tests (+1 skip) · P0–P3 完成（除 P3-001 payGood）*
