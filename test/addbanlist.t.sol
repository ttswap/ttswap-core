// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";

contract addbanlist is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_UserConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodbtc;

    function setUp() public override {
        BaseSetup.setUp();
    }

    function testaddbanlist() public {
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(marketcreator, true);
        tts_token.setBan(users[4], true);
        assertEq(tts_token.userConfig(users[4]).isBan(), true, "banlist error");
        tts_token.setBan(users[4], false);
        assertEq(tts_token.userConfig(users[4]).isBan(), false, "banlist error");
        vm.stopPrank();
    }
}
