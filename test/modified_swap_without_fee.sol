// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test, console2, Vm} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import "../src/TTSwap_Token.sol";
import "../src/TTSwap_Token_Proxy.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";

contract modified_swap_without_fee is Test, GasSnapshot {
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    address metagood;
    address normalgoodusdt;
    address normalgoodusdc;
    address normalgoodbtc;
    address payable[8] internal users;
    MyToken usdc;
    MyToken usdt;
    MyToken btc;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Token tts_token;
    TTSwap_Token_Proxy tts_token_proxy;
    bytes internal constant defaultdata = bytes("");

    function setUp() public {
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        marketcreator = payable(address(6));
        usdt = new MyToken("USDT", "USDT", 6);
        usdc = new MyToken("USDC", "USDC", 6);
        btc = new MyToken("BTC", "BTC", 8);
        vm.startPrank(marketcreator);
        TTSwap_Token tts_token_logic = new TTSwap_Token();
        tts_token_proxy = new TTSwap_Token_Proxy(
            address(usdt),
            marketcreator,
            2 ** 255 + 10000,
            "TTSwap Token",
            "TTS",
            address(tts_token_logic)
        );
        tts_token = TTSwap_Token(payable(address(tts_token_proxy)));
         market = new TTSwap_Market(tts_token,marketcreator);
       
        tts_token.setTokenAdmin(marketcreator, true);
        tts_token.setTokenManager(marketcreator, true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator, true);
        tts_token.setStakeAdmin(marketcreator, true);
        tts_token.setStakeManager(marketcreator, true);
        vm.stopPrank();
        initmetagood();
        initusdcgood();
        initbtcgood();
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        metagood = address(usdt);
        vm.stopPrank();
    }

    function initusdcgood() public {
        vm.startPrank(marketcreator);
        deal(address(usdc), marketcreator, 1000000 * 10 ** 6, false);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(usdc),
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        normalgoodusdc = address(usdc);
        vm.stopPrank();
    }

    function initbtcgood() public {
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 1000000 * 10 ** 8, false);
        btc.approve(address(market), 100 * 10 ** 8 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(btc),
            toTTSwapUINT256(118000 * 10 ** 6, 1 * 10 ** 8),
            _goodconfig,
            defaultdata
        );
        normalgoodbtc = address(btc);
        vm.stopPrank();
    }

    function testswapA2B2Awithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        market.buyGood(
            address(usdt),
            address(usdc),
            toTTSwapUINT256(8333333332, 6000000000),
            
            msg.sender,
            "",
            marketcreator,""
        );

        snapLastCall("testswapwithoutfee1");
        usdcafter = usdc.balanceOf(address(marketcreator));
        usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        S_GoodTmpState memory afterusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory afterusdt = market.getGoodState(address(usdt));
        console2.log(
            "beforeusdc_currentStateamount0:",
            beforeusdc.currentState.amount0()
        );
        console2.log(
            "afterusdc_currentStateamount0:",
            afterusdc.currentState.amount0()
        );
        console2.log(
            "beforeusdc_currentStateamount1:",
            beforeusdc.currentState.amount1()
        );
        console2.log(
            "afterusdc_currentStateamount1:",
            afterusdc.currentState.amount1()
        );
        console2.log(
            "beforeusdc_investStateamount0:",
            beforeusdc.investState.amount0()
        );
        console2.log(
            "afterusdc_investStateamount0:",
            afterusdc.investState.amount0()
        );
        console2.log(
            "beforeusdc_investStateamount1:",
            beforeusdc.investState.amount1()
        );
        console2.log(
            "afterusdc_investStateamount1:",
            afterusdc.investState.amount1()
        );
       
        console2.log(
            "beforeusdt_currentStateamount0:",
            beforeusdt.currentState.amount0()
        );
        console2.log(
            "afterusdt_currentStateamount0:",
            afterusdt.currentState.amount0()
        );
        console2.log(
            "beforeusdt_currentStateamount1:",
            beforeusdt.currentState.amount1()
        );
        console2.log(
            "afterusdt_currentStateamount1:",
            afterusdt.currentState.amount1()
        );
        console2.log(
            "beforeusdt_investStateamount0:",
            beforeusdt.investState.amount0()
        );
        console2.log(
            "afterusdt_investStateamount0:",
            afterusdt.investState.amount0()
        );
        console2.log(
            "beforeusdt_investStateamount1:",
            beforeusdt.investState.amount1()
        );
        console2.log(
            "afterusdt_investStateamount1:",
            afterusdt.investState.amount1()
        );
        
        vm.stopPrank();
    }

    function testswapA2B2C2Awithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(address(market));
        uint256 usdtbefore = usdt.balanceOf(address(market));
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(address(market)));
        uint256 usdtafter = usdt.balanceOf(address(address(market)));
        uint256 btcbefore = btc.balanceOf(address(address(market)));
        console2.log("btcbefore:", btcbefore);
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        market.buyGood(
            address(usdt),
            address(btc),
            toTTSwapUINT256(8333333332, 0),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        usdcafter = usdc.balanceOf(address(address(market)));
        usdtafter = usdt.balanceOf(address(address(market)));
        uint256 btcafter = btc.balanceOf(address(address(market)));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        console2.log("btcafter:", btcafter);
        market.buyGood(
            address(btc),
            address(usdc),
            toTTSwapUINT256(7418397, 0),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee3");
        usdcafter = usdc.balanceOf(address(market));
        usdtafter = usdt.balanceOf(address(market));
        btcafter = btc.balanceOf(address(market));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        console2.log("btcafter:", btcafter);
        vm.stopPrank();
    }

    function testswapA2B_part1() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        vm.stopPrank();
    }

  //usdcbefore: 950000000000
  //usdtbefore: 950000000000
  //usdcafter: 940000000000
  //usdtafter: 958333333332
    function testswapA2B_part2() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(5000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );

        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(5000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        vm.stopPrank();
    }

    function testpaywithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(address(marketcreator));
        uint256 usdtbefore = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.payGood(
            address(usdt),
            address(usdc),
            toTTSwapUINT256(3000 * 10 ** 6, 1000 * 10 ** 6),
            
            marketcreator,
            "",
            marketcreator,""
        );
        snapLastCall("testpaywithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        market.payGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1020408163),
            marketcreator,
            "",
            marketcreator,""
        );
        snapLastCall("testpaywithoutfee2");
        usdcafter = usdc.balanceOf(address(marketcreator));
        usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        S_GoodTmpState memory afterusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory afterusdt = market.getGoodState(address(usdt));
        console2.log(
            "beforeusdc_currentStateamount0:",
            beforeusdc.currentState.amount0()
        );
        console2.log(
            "afterusdc_currentStateamount0:",
            afterusdc.currentState.amount0()
        );
        console2.log(
            "beforeusdc_currentStateamount1:",
            beforeusdc.currentState.amount1()
        );
        console2.log(
            "afterusdc_currentStateamount1:",
            afterusdc.currentState.amount1()
        );
        console2.log(
            "beforeusdc_investStateamount0:",
            beforeusdc.investState.amount0()
        );
        console2.log(
            "afterusdc_investStateamount0:",
            afterusdc.investState.amount0()
        );
        console2.log(
            "beforeusdc_investStateamount1:",
            beforeusdc.investState.amount1()
        );
        console2.log(
            "afterusdc_investStateamount1:",
            afterusdc.investState.amount1()
        );
       
        console2.log(
            "beforeusdt_currentStateamount0:",
            beforeusdt.currentState.amount0()
        );
        console2.log(
            "afterusdt_currentStateamount0:",
            afterusdt.currentState.amount0()
        );
        console2.log(
            "beforeusdt_currentStateamount1:",
            beforeusdt.currentState.amount1()
        );
        console2.log(
            "afterusdt_currentStateamount1:",
            afterusdt.currentState.amount1()
        );
        console2.log(
            "beforeusdt_investStateamount0:",
            beforeusdt.investState.amount0()
        );
        console2.log(
            "afterusdt_investStateamount0:",
            afterusdt.investState.amount0()
        );
        console2.log(
            "beforeusdt_investStateamount1:",
            beforeusdt.investState.amount1()
        );
        console2.log(
            "afterusdt_investStateamount1:",
            afterusdt.investState.amount1()
        );
        
        vm.stopPrank();
    }

    // function testaaswap()public{
    //     vm.startPrank(marketcreator);
    //     uint256 usdcbefore=usdc.balanceOf(marketcreator);
    //     uint256 usdtbefore=usdt.balanceOf(marketcreator);
    //     usdc.approve(address(market), 50000 * 10 ** 6 + 1);
    //     usdt.approve(address(market), 50000 * 10 ** 6 + 1);
    //     market.buyGood(address(usdc),address(usdt),1000*10**6,5,address(0),"");
    //     uint256 usdcafter=usdc.balanceOf(marketcreator);
    //     uint256 usdtafter=usdt.balanceOf(marketcreator);
    //     console2.log("usdcbefore:",usdcbefore);
    //     console2.log("usdtbefore:",usdtbefore);
    //     console2.log("usdcafter:",usdcafter);
    //     console2.log("usdtafter:",usdtafter);
    //     market.buyGood(address(usdt),address(usdc),99601593,5,address(0),"");
    //     usdcafter=usdc.balanceOf(marketcreator);
    //     usdtafter=usdt.balanceOf(marketcreator);

    //     console2.log("usdcafter:",usdcafter);
    //     console2.log("usdtafter:",usdtafter);
    //     vm.stopPrank();
    // }
}
