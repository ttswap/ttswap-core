// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

// TTSwap Protocol Errors — single custom error `TTSwapError(seq)` used across Market, Token, Proxy.
// Integrators decode `seq` off-chain. Market-relevant codes include:
// 1 admin, 2 manager, 3 reentrancy, 5 good exists, 9 same good swap, 10 frozen, 12/13 missing good,
// 14 dust, 15 slippage, 18 overflow, 19 proof mismatch, 20 not owner, 21 >100 goods, 23 power limit,
// 24 bad config, 26-27 disinvest chunk, 32 zero addr, 34 profit<fee, 35-36 init bounds, 38 invest dust,
// 39 trader mismatch, 40 promised owner, 41 shares, 42 unsupported type, 46 run-block, 49/53 deadline,
// 50 relayer fee, 52 uint160, 55 upper safe line, 56 lower safe line / shallow pool, 30-31 native ETH.
error TTSwapError(uint256 seq);
