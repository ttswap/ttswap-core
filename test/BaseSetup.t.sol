// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";

contract BaseSetup is Test, GasSnapshot {
    address payable[8] internal users;
    MyToken btc;
    MyToken usdt;
    MyToken eth;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Token tts_token;
    bytes internal constant defaultdata = bytes("");

    event debuggdata(bytes);

    function setUp() public virtual {
        uint256 m_marketconfig = (45 << 250) + (5 << 244) + (10 << 238) + (15 << 232) + (25 << 226) + (20 << 220);

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
        tts_token = new TTSwap_Token(address(usdt), marketcreator, 2 ** 255);
        snapStart("depoly Market Manager");
        market = new TTSwap_Market(m_marketconfig, tts_token, marketcreator);
        snapEnd();
        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        tts_token.setStakeAdmin(marketcreator,true);
        tts_token.setStakeManager(marketcreator,true);
        vm.stopPrank();
    }
}
