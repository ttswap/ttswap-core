# 1. TTSWAP

TTSWAP (token-token swap) protocol is a decentralized automated market-making protocol built on the EVM blockchain. Its underlying principle is based on the transfer of market value triggered by user behavior, and it constructs a platform using value conservation trading strategies.
The whitepaper explains the design logic of the ttswap project, covering principles and implementations of goods trading, investment, and withdrawal of value goods, as well as ordinary goods investment and withdrawal, and the generation and distribution of goods transaction fees.

# 2 Features

1. ***Value Conservation Trading Strategy***
The value conservation trading strategy accurately reflects the true market value of currencies and facilitates fast goods transactions.

1. ***Direct Trading without Intermediaries***
On this platform, any two types of items can be directly traded without the need for intermediate conversions.

1. ***Lower Slippage with Strengthened & Concentrated Invest***
Through stengthened and concentrated invest, reduce the slippage more then 50%.

1. ***No Impermanent Loss for Liquidity Providers or goods Investors***
Constant market value inherently prevents impermanent loss. When users withdraw their investment, they receive the original invested goods plus profits generated from providing liquidity.

1. ***Low Gas Fees with Simple Computational Logic***
The logic behind the constant value trading model is simple, resulting in low computational load and gas consumption.

1. ***Fee Distribution Based on Roles for Everyone***
Fees are distributed based on roles, allowing anyone to become a goods investor (liquidity provider), goods seller, gater, referrer, user, or platform role, sharing in the platform's growth earnings.

1. ***Support Native ETH Exchange and Invest***
anyone can you native ETH without wrap to swap, invest easily.

1. ***Support mint TTS token***
when customer invest good, the protocol will auto mint tts token for customer.

1. ***Community-Driven Developement and Innovation***
ttswap emphasizes a community-driven approach to development and innovation. Since its code release, there has been active community engagement, with many issues, pull requests, and unique feature ideas contributed by users. The protocol is designed to encourage innovation, allowing the global community to shape the future of AMMs.

# 3. Contributing

If you’re interested in contributing please see our [contribution guidelines](./CONTRIBUTING.md)!

# 4. Whitepaper

A more detailed description of ttswap Core can be found in the draft of the [TTSWAP Core Whitepaper-en](./docs/whitepaper_en.pdf) |[TTSWAP Core Whitepaper-cn](./docs/whitepaper_cn.pdf).   

# 5. Architecture

`ttswap-core` uses a singleton-style architecture, where all goods state is managed in the `MarketManager.sol` contract.

# 6. Repository Structure && License

All contracts are held within the `ttswap-core/Contracts` folder.

Note  but all foundry tests are in the `ttswap-core/test` folder.

```markdown
Contract
├── TTSwap_Market.sol(BUSL-1.1)  
├── TTSwap_Token.sol(BUSL-1.1)
├── interfaces  
│   ├── I_TTSwap_Market.sol(MIT)   
│   └── I_TTSwap_Token.sol(MIT)    
└── libraries           
   ├── L_Currency.sol (MIT)    
   ├── L_Error.sol (MIT)     
   ├── L_Good.sol(BUSL-1.1)    
   ├── L_GoodConfig.sol(MIT)     
   ├── L_MarketConfig.sol(MIT)    
   ├── L_Proof.sol(BUSL-1.1)   
   ├── L_Transient.sol (MIT)  
   ├── L_TTSTokenConfig.sol (MIT)     
   ├── L_TTSwapUINT256.sol (MIT)     
   └── L_UserConfig.sol(MIT)    
docs
├── ebook
├── whitepaper-cn
│   └──whitepaper-cn.pdf(BUSL-1.1)
└── whitepaper-en
    └──whitepaper-en.pdf(BUSL-1.1)
tests

```
The primary license for ttswap-core is the Business Source License 1.1 (`BUSL-1.1`), see [LICENSE](https://github.com/tt-swap/ttswap-core/blob/main/LICENSE).

# 7. Everyone Can be Gater

To utilize the contracts and deploy to a local testnet, you can install the code in your repo with forge:

```markdown
forge install https://github.com/ttswap/ttswap-core
```

To integrate with the contracts, the interfaces are available to use:

```solidity

import {I_TTSwap_Market} from 'ttswap-core/contracts/interfaces/I_TTSwap_Market.sol';

contract MyPortal  {
    I_TTSwap_Market market;
    address IamGater

    function doThing () {
        market.buyGood(...,referal);
        market.initGood(...);
        market.investGood(...);
        market.disinvestProof(....,IamGater);
        ....
    }
}
```

# 8. Deploy local instruction only for study 
step 1:instrall forge  
step 2:forge install permit2  


# 9. Socials / Contract
Twitter:[@ttswapfinance](https://x.com/ttswapfinance)  
Telegram:[@ttswapfinance](https://t.me/ttswapfinance)  
Email:[bussiness@ttswap.io](mailto:bussiness@ttswap.io)  
Discord:[ttswap](https://discord.gg/XygqnmQgX3)  
Github:[ttswap](http://github.com/ttswap)  
Website:[ttswap.io](https://ttswap.io)

