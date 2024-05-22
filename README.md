# Uniswap v4 Core



Uniswap v4 is a new automated market maker protocol that provides extensible and customizable pools. `v4-core` hosts the core pool logic for creating pools and executing pool actions like swapping and providing liquidity.

The contracts in this repo are in early stages - we are releasing the draft code now so that v4 can be built in public, with open feedback and meaningful community contribution. We expect this will be a months-long process, and we appreciate any kind of contribution, no matter how small.
## Features
Value Conservation Trading Strategy
The value conservation trading strategy accurately reflects the true market value of currencies and facilitates fast good transactions.

1. Direct Trading without Intermediaries
On this platform, any two types of items can be directly traded without the need for intermediate conversions.

2. No Slippage within Trading Threshold
Transactions below the good trading threshold incur no slippage.

3. No Impermanent Loss for Liquidity Providers or good Investors
Constant market value inherently prevents impermanent loss. When users withdraw their investment, they receive the original invested good plus profits generated from providing liquidity.

4. Low Gas Fees with Simple Computational Logic
The logic behind the constant value trading model is simple, resulting in low computational load and gas consumption.

5. Fee Distribution Based on Roles for Everyone
Fees are distributed based on roles, allowing anyone to become a good investor (liquidity provider), goods seller, gater, referrer, user, or platform role, sharing in the platform's growth earnings.

6. Support Native ETH Exchange and Invest
anyone can you native ETH without wrap to swap, invest easily.
## Contributing

If you’re interested in contributing please see our [contribution guidelines](./CONTRIBUTING.md)!

## Whitepaper

A more detailed description of ttswap Core can be found in the draft of the [TTSWAP Core Whitepaper](./docs/whitepaper_en.pdf).

## Architecture

`ttswap-core` uses a singleton-style architecture, where all goods state is managed in the `MarketManager.sol` contract.

the contract devide four part:

Part 1: the action relate to good'initial ,good investing (stake or add liquidity),good disinvestint (unstake or remove liquidity),good swaping , or disinvesting proof ( burn stake proof or liquidity position )  are defined in marketmanager.sol.

Part 2: the action relate good config , collect fee of good , good's attribute defined in goodmanage.sol.

Part 3: because proof is ERC721 standard, and it's define in proofmanage.sol

Part 4: about user's refer is defined in referermanager.sol

## Repository Structure && License

All contracts are held within the `ttswap-core/Contracts` folder.

Note  but all foundry tests are in the `ttswap-core/test` folder.

```markdown
Contract
├── GoodManage.sol(BUSL-1.1)  
├── MarketManager.sol(BUSL-1.1)  
├── ProofManage.sol(BUSL-1.1)  
├── RefererManage.sol(BUSL-1.1) 
├── Multicall.sol( GPL-2.0-or-later)
├── interfaces  
│   ├── I_Good.sol(MIT)  
│   ├── I_MarketManage.sol(MIT)  
│   └── I_Proof.sol(MIT)   
└── libraries      
   ├── L_Good.sol(BUSL-1.1)    
   ├── L_GoodConfig.sol(MIT)     
   ├── L_MarketConfig.sol(MIT)    
   ├── L_Proof.sol(BUSL-1.1)   
   ├── T_BalanceUINT256.sol (MIT)     
   ├── T_Currency.sol (MIT)       
   ├── L_Struct.sol (MIT)     
   └── L_ArrayStorage.sol(MIT)    
docs
├── ebook
├── whitepaper-cn
│   └──whitepaper-cn.pdf(BUSL-1.1)
└── whitepaper-en
    └──whitepaper-en.pdf(BUSL-1.1)
tests

```
The primary license for ttswap-core is the Business Source License 1.1 (`BUSL-1.1`), see [LICENSE](https://github.com/tt-swap/ttswap-core/blob/main/LICENSE).

## Everyone Can be Gater

To utilize the contracts and deploy to a local testnet, you can install the code in your repo with forge:

```markdown
forge install https://github.com/tt-swap/ttswap-core
```

To integrate with the contracts, the interfaces are available to use:

```solidity

import {I_MarketManager} from 'ttswap-core/contracts/interfaces/I_MarketManager.sol';

contract MyPortal  {
    IPoolManager poolManager;
    address IamGater

    function excellentThing () {
        poolManager.buyGood(...,IamGater);
    }
}

```
