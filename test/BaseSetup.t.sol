// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
    import {TTSwap_Market} from "../src/TTSwap_Market.sol";
    import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";


contract BaseSetup is Test, GasSnapshot {
    address payable[8] internal users;
    MyToken btc;
    MyToken usdt;
    MyToken eth;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Market_Proxy market_proxy;
    TTSwap_Token tts_token;
    TTSwap_Token_Proxy tts_token_proxy;
    bytes internal constant defaultdata = bytes("");


    function setUp() public virtual {
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        marketcreator = payable(address(6));
        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);
        vm.startPrank(marketcreator);
        TTSwap_Token tts_token_logic = new TTSwap_Token(address(usdt));
        tts_token_proxy=new TTSwap_Token_Proxy( marketcreator, 2 ** 255 + 10000,"TTSwap Token","TTS",address(tts_token_logic));
        tts_token=TTSwap_Token(payable(address(tts_token_proxy)));
        snapStart("depoly Market Manager");
        market = new TTSwap_Market(tts_token);
        market_proxy = new TTSwap_Market_Proxy(tts_token,address(market));
        market = TTSwap_Market(payable(address(market_proxy)));
        snapEnd();
        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        tts_token.setMarketManager(marketcreator,true);
        tts_token.setStakeAdmin(marketcreator,true);
        tts_token.setStakeManager(marketcreator,true);
        vm.stopPrank();
    }

    function test_market_proxy() public {
        assertEq(address(market), address(market_proxy));
    }
    
}
