// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";


contract DeployMarket is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address usdt =0xdAC17F958D2ee523a2206206994597C13D831ec7;
        TTSwap_Token ttstoken = new TTSwap_Token(
            address(usdt)
        );

        TTSwap_Token_Proxy ttstoken_proxy = new TTSwap_Token_Proxy(
           
            msg.sender,
            57896044618658097711785492504343953926634992332820282019728792003956564819968,
            "TTSwap Token",
            "TTS",
            address(ttstoken)
        );
        
        
        vm.stopBroadcast();
    }

}
