// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";

/// @notice Bit-layout unit tests for `L_UserConfigLibrary`.
contract testUserConfig is Test {
    using L_UserConfigLibrary for uint256;

    address internal constant REF = address(0xBEEF);

    function test_roleBits_roundTrip() public pure {
        uint256 cfg = 0;
        cfg = cfg.setDAOAdmin(true);
        cfg = cfg.setTokenAdmin(true);
        cfg = cfg.setTokenManager(true);
        cfg = cfg.setMarketAdmin(true);
        cfg = cfg.setMarketManager(true);
        cfg = cfg.setCallMintTTS(true);
        cfg = cfg.setStakeAdmin(true);
        cfg = cfg.setStakeManager(true);
        cfg = cfg.setBan(true);

        assertTrue(cfg.isDAOAdmin());
        assertTrue(cfg.isTokenAdmin());
        assertTrue(cfg.isTokenManager());
        assertTrue(cfg.isMarketAdmin());
        assertTrue(cfg.isMarketManager());
        assertTrue(cfg.isCallMintTTS());
        assertTrue(cfg.isStakeAdmin());
        assertTrue(cfg.isStakeManager());
        assertTrue(cfg.isBan());

        cfg = cfg.setDAOAdmin(false);
        cfg = cfg.setTokenAdmin(false);
        cfg = cfg.setTokenManager(false);
        cfg = cfg.setMarketAdmin(false);
        cfg = cfg.setMarketManager(false);
        cfg = cfg.setCallMintTTS(false);
        cfg = cfg.setStakeAdmin(false);
        cfg = cfg.setStakeManager(false);
        cfg = cfg.setBan(false);

        assertFalse(cfg.isDAOAdmin());
        assertFalse(cfg.isTokenAdmin());
        assertFalse(cfg.isTokenManager());
        assertFalse(cfg.isMarketAdmin());
        assertFalse(cfg.isMarketManager());
        assertFalse(cfg.isCallMintTTS());
        assertFalse(cfg.isStakeAdmin());
        assertFalse(cfg.isStakeManager());
        assertFalse(cfg.isBan());
    }

    function test_referral_setKeepsRoleBits() public pure {
        uint256 cfg = uint256(0).setDAOAdmin(true).setReferral(REF);
        assertEq(cfg.referral(), REF);
        assertTrue(cfg.isDAOAdmin());

        address other = address(0x1234);
        cfg = cfg.setReferral(other);
        assertEq(cfg.referral(), other);
        assertTrue(cfg.isDAOAdmin());
    }
}
