# TTSwap v2.0 测试覆盖率报告

> 生成时间：2026-06-06  
> 命令：`forge coverage --match-path "test/*" --ir-minimum`  
> 套件：**297 tests · 1 skipped · 39 suites · 全部通过**

---

## 1. 如何复现

```bash
# 摘要表（终端输出）
forge coverage --match-path "test/*" --ir-minimum --report summary

# LCOV（供 IDE / genhtml 使用）
mkdir -p coverage
forge coverage --match-path "test/*" --ir-minimum \
  --report lcov --report-file coverage/lcov.info
```

**注意**

- `forge coverage` 会关闭 optimizer；`L_Good.sol` 等大函数需加 `--ir-minimum` 避免 stack too deep。
- 产物：`coverage/lcov.info`、`coverage/summary.txt`。

---

## 2. 总体覆盖率

| 指标 | 覆盖率 | 命中/总数 |
|------|--------|-----------|
| **Lines** | **67.42%** | 801 / 1188 |
| **Statements** | **65.29%** | 807 / 1236 |
| **Branches** | **44.90%** | 110 / 245 |
| **Functions** | **76.92%** | 180 / 234 |

P0–P3 完成后，Market 近满覆盖，Token 约 79% lines；分支仍受 `L_Currency` Permit2/DAI 路径、`payGood` 缺失等影响。

---

## 3. 按文件覆盖率（`src/` 核心）

| 文件 | Lines | Branches | 评价 |
|------|-------|----------|------|
| `TTSwap_Market.sol` | **97.52%** (197/202) | 90.24% | 主路径基本打满 |
| `TTSwap_Token.sol` | **79.01%** (143/181) | 38.10% | 治理/publicSell/stake 已补 |
| `libraries/L_Good.sol` | **80.86%** (131/162) | 50.00% | fuzz 覆盖 disinvest 边缘 |
| `type/T_GoodKey.sol` | **73.81%** (62/84) | 51.52% | permit 部分仍缺 |
| `libraries/L_Currency.sol` | **22.22%** (14/63) | 3.70% | 直测补 ERC20/native；Permit2/DAI 仍低 |
| `libraries/L_Proof.sol` | **93.33%** (14/15) | 100% | — |
| `TTSwap_Market_Proxy.sol` | 24.00% | 0% | upgrade/freeze 有集成测，fallback 难满覆盖 |
| `TTSwap_Token_Proxy.sol` | 40.74% | 0% | 同上 |
| `libraries/L_SignatureVerification.sol` | **72.22%** | 57.14% | meta-tx 已测 |
| `libraries/L_Transient.sol` | 44.12% | 25.00% | 重入守卫部分覆盖 |

完整表格见 [`coverage/summary.txt`](../coverage/summary.txt)。

---

## 4. 剩余缺口（按优先级）

1. **P3-001 `payGood`** — v2 注释，恢复后从 `testback/pay*.t.sol` 迁移  
2. **`L_Currency` Permit2 (type 3–5) + DAI permit** — 需 fork 或 mock Permit2  
3. **Proxy fallback 行** — freeze 后 delegatecall(0) 不 revert 的行为未计入  
4. **`TTSwap_Token` branches** — ban、referral、复杂 unstake 分岔  
5. **完整 v1.5→v2 升级** — 见 `testback/testUpgradeV1_5ToV2.t.sol`

---

## 5. 维护

每次完成 TASK 后：

1. `forge test --match-path "test/*"` 全绿  
2. `forge coverage --match-path "test/*" --ir-minimum --report summary` 更新本节数据  
3. 同步 `TEST_TASKS.md` / `TEST_MAP.md`

---

*Last updated: 2026-06-06 · 297 tests · P0–P3 done (payGood blocked)*
