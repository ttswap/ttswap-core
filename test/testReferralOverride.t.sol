// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";

contract testReferralOverride is BaseSetup {
    using L_UserConfigLibrary for uint256;

    address internal victim;
    address internal hijacker;
    address internal realReferrer;

    function setUp() public override {
        BaseSetup.setUp();
        victim = users[4];
        hijacker = address(0xDEAD);
        realReferrer = address(0xBEEF);

        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(marketcreator, true);
        tts_token.setCallMintTTS(marketcreator, true);
        vm.stopPrank();
    }

    function test_victim_can_override_referral() public {
        vm.prank(marketcreator);
        tts_token.setReferral(victim, hijacker);
        assertEq(tts_token.userConfig(victim).referral(), hijacker);

        vm.prank(victim);
        tts_token.updateUserReferral(realReferrer);
        assertEq(tts_token.userConfig(victim).referral(), realReferrer);

        vm.prank(victim);
        tts_token.updateUserReferral(address(0));
        assertEq(tts_token.userConfig(victim).referral(), address(0));
    }

    function test_admin_can_reset_hijacked_referral() public {
        vm.prank(marketcreator);
        tts_token.setReferral(victim, hijacker);
        assertEq(tts_token.userConfig(victim).referral(), hijacker);

        vm.prank(marketcreator);
        tts_token.adminResetReferral(victim, address(0));
        assertEq(tts_token.userConfig(victim).referral(), address(0));
    }
}
