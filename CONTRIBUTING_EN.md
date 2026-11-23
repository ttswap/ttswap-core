# Contribution Guidelines

Thank you for your interest in contributing to **TTSwap V1 Core**!
TTSwap V1 core smart contracts, maintenance, bug fixes, and V1-to-V2 migration support.

Every meaningful community contribution is tracked transparently and will be mapped directly into retroactive token airdrop credits upon protocol token distribution.

If you need to get in contact with repository maintainers, please reach out in our official Discord or community channels.

---

## 1. Types of Contributions

1. **Opening an Issue**: Report reproducible bugs, edge cases, vulnerability findings, or propose feature improvements.
2. **Resolving an Issue & Pull Requests**: Implement bug fixes, algorithmic enhancements, UI features, or write invariant tests.
3. **Reviewing Open PRs**: Provide architectural feedback, audit opinions, gas optimizations, or design suggestions.

---

## 2. Contribution Scoring & Retroactive Airdrop Rules

Each merged Pull Request will be assigned a quantified contribution score based on its **Base Points (Difficulty)** and **Topic Weight (Domain Impact)**:

$$\text{Final Score} = \text{Base Points} \times \text{Topic Weight} \times \text{Time Multiplier}$$

*(Note: Genesis and early-stage contributions enjoy a $1.5\times \sim 2.0\times$ risk multiplier.)*

### 2.1 Topic Weights (Specific to TTSwap V1 Core)

| Topic Tag | Multiplier | Scope & Domain Focus |
| :--- | :---: | :--- |
| `topic:v1-maintenance` | **1.2x** | V1 core contract maintenance and standard bug fixes |
| `topic:security` | **1.5x** | V1 vulnerability discovery, critical patches, safety hardening |
| `topic:v1-v2-migration` | **1.3x** | Migration helpers, adapter contracts, historical state reconciliation |
| `topic:tests` | **1.0x** | Regression testing and replay test suites |

### 2.2 Base Difficulty Points Scale

- **T1 · Minor (1~2 pts)**: Simple typo, comment update, parameter naming
- **T2 · Standard (3~5 pts)**: Standard bug fix, test case addition, helper adjustment
- **T3 · Major (8~13 pts)**: V1-V2 migration helper contract, security patch
- **T4 · Critical (21~34 pts)**: Critical exploit remediation in V1 contracts

---

## 3. Pull Request Workflow & Rules

1. **Pre-bind EVM Wallet**: You **MUST** fill in your EVM wallet address in the PR template. This address will be permanently recorded in [CONTRIBUTIONS.md](CONTRIBUTIONS.md) upon merge for retroactive airdrops.
2. **Do Not Edit CONTRIBUTIONS.md**: Contributors **MUST NOT** modify [CONTRIBUTIONS.md](CONTRIBUTIONS.md) in PR branches. Maintainers will record the entry upon merge to avoid Git merge conflicts.
3. **Commit Standards**: Write clear, imperative commit messages. Sign your commits if possible.
4. **Code Quality & Tests**: Always run local tests before submitting. Ensure code adheres to repository formatting standards.

---

## 4. Setup & Build Commands

```bash
`forge build` to compile contracts
`forge test --isolate` to run V1 test suite
```

---

## 5. Code of Conduct

Be respectful and constructive. Harassment, spam, or manipulative behavior will not be tolerated and will forfeit contribution credits.
