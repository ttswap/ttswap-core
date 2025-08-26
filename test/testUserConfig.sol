// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";

contract testUserConfig is Test {
    using L_UserConfigLibrary for uint256;

    uint256 public config;
    
    function test_isDAOAdmin() public  {
        config = 1 * 2 ** 255+2**254;
        assertEq(config.isDAOAdmin(), true);
        config = 0 * 2 ** 255+2**254;
        assertEq(config.isDAOAdmin(), false);
    }
    
    function test_setDAOAdmin() public  {
        config =  0 * 2 ** 255+2**254;
        assertEq(config.setDAOAdmin(true), 1 * 2 ** 255+2**254);
        config = 1 * 2 ** 255+2**254;
        assertEq(config.setDAOAdmin(false),  0 * 2 ** 255+1 * 2 ** 254);
    }
    
    function test_isTokenAdmin() public  {
        config = 1 * 2 ** 254+2**255+2**253;
        assertEq(config.isTokenAdmin(), true);
        config = 0 * 2 ** 254+2**255+2**253;
        assertEq(config.isTokenAdmin(), false);
    }

    function test_setTokenAdmin() public  {
        config =  0 * 2 ** 254+2**255+2**253;
        assertEq(config.setTokenAdmin(true), 1 * 2 ** 254+2**255+2**253);
        config = 1 * 2 ** 254+2**255+2**253;
        assertEq(config.setTokenAdmin(false), 0 * 2 ** 254+2**255+2**253);
    }

    function test_isTokenManager() public  {
        config = 1 * 2 ** 253+2**255+2**254+2**252;
        assertEq(config.isTokenManager(), true);
        config = 0 * 2 ** 253+2**255+2**254+2**252;
        assertEq(config.isTokenManager(), false);
    }

    function test_setTokenManager() public  {
        config =  0 * 2 ** 253+2**255+2**254+2**252;
        assertEq(config.setTokenManager(true), 1 * 2 ** 253+2**255+2**254+2**252);
        config = 1 * 2 ** 253+2**255+2**254+2**252;
        assertEq(config.setTokenManager(false), 0 * 2 ** 253+2**255+2**254+2**252);
    }

    function test_isMarketAdmin() public  {
        config = 1 * 2 ** 252+2**253+2**251;
        assertEq(config.isMarketAdmin(), true);
        config = 0 * 2 ** 252+2**253+2**251;
        assertEq(config.isMarketAdmin(), false);
    }

    function test_setMarketAdmin() public  {
        config =  0 * 2 ** 252+2**253+2**251;
        assertEq(config.setMarketAdmin(true), 1 * 2 ** 252+2**253+2**251);
        config = 1 * 2 ** 252+2**253+2**251;
        assertEq(config.setMarketAdmin(false), 0 * 2 ** 252+2**253+2**251);
    }
    function test_isMarketManager() public  {
        config = 1 * 2 ** 251+2**252+2**250;
        assertEq(config.isMarketManager(), true);
        config = 0 * 2 ** 251+2**252+2**250;
        assertEq(config.isMarketManager(), false);
    }
    function test_setMarketManager() public  {  
        config =  0 * 2 ** 251+2**252+2**250;
        assertEq(config.setMarketManager(true), 1 * 2 ** 251+2**252+2**250);
        config = 1 * 2 ** 251+2**252+2**250;
        assertEq(config.setMarketManager(false), 0 * 2 ** 251+2**252+2**250);
    }
    function test_isCallMintTTS() public  {
        config = 1 * 2 ** 250+2**251+2**249;
        assertEq(config.isCallMintTTS(), true);
        config = 0 * 2 ** 250+2**251+2**249;
        assertEq(config.isCallMintTTS(), false);
    }
    function test_setCallMintTTS() public  {
        config =  0 * 2 ** 250+2**251+2**249;
        assertEq(config.setCallMintTTS(true), 1 * 2 ** 250+2**251+2**249);
        config = 1 * 2 ** 250+2**251+2**249;
        assertEq(config.setCallMintTTS(false), 0 * 2 ** 250+2**251+2**249);
    }
    function test_isStakeAdmin() public  {
        config = 1 * 2 ** 249+2**250+2**248;
        assertEq(config.isStakeAdmin(), true);
        config = 0 * 2 ** 249+2**250+2**248;
        assertEq(config.isStakeAdmin(), false);
    }
    function test_setStakeAdmin() public  {
        config =  0 * 2 ** 249+2**250+2**248;
        assertEq(config.setStakeAdmin(true), 1 * 2 ** 249+2**250+2**248);
        config = 1 * 2 ** 249+2**250+2**248;
        assertEq(config.setStakeAdmin(false), 0 * 2 ** 249+2**250+2**248);
    }
    function test_isStakeManager() public  {
        config = 1 * 2 ** 248+2**249+2**247;
        assertEq(config.isStakeManager(), true);
        config = 0 * 2 ** 248+2**249+2**247;
        assertEq(config.isStakeManager(), false);
    }
    function test_setStakeManager() public  {
        config =  0 * 2 ** 248+2**249+2**247;
        assertEq(config.setStakeManager(true), 1 * 2 ** 248+2**249+2**247);
        config = 1 * 2 ** 248+2**249+2**247;
        assertEq(config.setStakeManager(false), 0 * 2 ** 248+2**249+2**247);
    }
    function test_isBan() public  {
        config = 1 * 2 ** 160+2**161+2**159;
        assertEq(config.isBan(), true);
        config = 0 * 2 ** 160+2**161+2**159;
        assertEq(config.isBan(), false);
    }
    function test_setBan() public  {
        config =  0 * 2 ** 160+2**161+2**159;
        assertEq(config.setBan(true), 1 * 2 ** 160+2**161+2**159);
        config = 1 * 2 ** 160+2**161+2**159;
        assertEq(config.setBan(false), 0 * 2 ** 160+2**161+2**159);
    }
    function test_referral() public {
        config = 1 * 2 ** 159+2**160;
        assertEq(config.referral(), address(2 ** 159));
        config = 0 * 2 ** 159+2**160;
        assertEq(config.referral(), address(0));
    }
    function test_setReferral() public {
        config =  0 * 2 ** 159+2**160;
        assertEq(config.setReferral(address(2 ** 159)), 1 * 2 ** 159+2**160);
        config = 1 * 2 ** 159+2**160;
        assertEq(config.setReferral(address(0)), 0 * 2 ** 159+2**160);
    }
}
