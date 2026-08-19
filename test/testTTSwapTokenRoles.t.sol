// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {I_TTSwap_Market} from "../src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token, s_share} from "../src/interfaces/I_TTSwap_Token.sol";
import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P0-03: Token governance permission matrix.
contract testTTSwapTokenRoles is BaseSetup {
    using L_UserConfigLibrary for uint256;

    address internal recipient = users[7];

    function testSetTokenAdmin_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(recipient, true);
        _snapToken("tts_token_setTokenAdmin_testTTSwapTokenRoles.t_18");
        assertTrue(tts_token.userConfig(recipient).isTokenAdmin());
        tts_token.setTokenAdmin(recipient, false);
        _snapToken("tts_token_setTokenAdmin_testTTSwapTokenRoles.t_20");
        assertFalse(tts_token.userConfig(recipient).isTokenAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenAdmin(recipient, true);
        _snapToken("tts_token_setTokenAdmin_testTTSwapTokenRoles.t_26");
    }

    function testSetTokenManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setTokenManager(recipient, true);
        _snapToken("tts_token_setTokenManager_testTTSwapTokenRoles.t_31");
        assertTrue(tts_token.userConfig(recipient).isTokenManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenManager(recipient, true);
        _snapToken("tts_token_setTokenManager_testTTSwapTokenRoles.t_37");
    }

    function testSetCallMintTTS_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(recipient, true);
        _snapToken("tts_token_setCallMintTTS_testTTSwapTokenRoles.t_42");
        assertTrue(tts_token.userConfig(recipient).isCallMintTTS());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setCallMintTTS(recipient, true);
        _snapToken("tts_token_setCallMintTTS_testTTSwapTokenRoles.t_48");
    }

    function testSetMarketAdmin_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setMarketAdmin(recipient, true);
        _snapToken("tts_token_setMarketAdmin_testTTSwapTokenRoles.t_53");
        assertTrue(tts_token.userConfig(recipient).isMarketAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setMarketAdmin(recipient, true);
        _snapToken("tts_token_setMarketAdmin_testTTSwapTokenRoles.t_59");
    }

    function testSetMarketManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setMarketManager(recipient, true);
        _snapToken("tts_token_setMarketManager_testTTSwapTokenRoles.t_64");
        assertTrue(tts_token.userConfig(recipient).isMarketManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token.setMarketManager(recipient, true);
        _snapToken("tts_token_setMarketManager_testTTSwapTokenRoles.t_70");
    }

    function testSetStakeAdmin_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setStakeAdmin(recipient, true);
        _snapToken("tts_token_setStakeAdmin_testTTSwapTokenRoles.t_75");
        assertTrue(tts_token.userConfig(recipient).isStakeAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setStakeAdmin(recipient, true);
        _snapToken("tts_token_setStakeAdmin_testTTSwapTokenRoles.t_81");
    }

    function testSetStakeManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setStakeManager(recipient, true);
        _snapToken("tts_token_setStakeManager_testTTSwapTokenRoles.t_86");
        assertTrue(tts_token.userConfig(recipient).isStakeManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 64));
        tts_token.setStakeManager(recipient, true);
        _snapToken("tts_token_setStakeManager_testTTSwapTokenRoles.t_92");
    }

    function testSetBan_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setBan(recipient, true);
        _snapToken("tts_token_setBan_testTTSwapTokenRoles.t_97");
        assertTrue(tts_token.userConfig(recipient).isBan());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 65));
        tts_token.setBan(recipient, true);
        _snapToken("tts_token_setBan_testTTSwapTokenRoles.t_103");
    }

    function testSetEnv_ok_and_revert() public {
        address newMarket = address(0xBEEF);
        address shareOwner = users[4];
        s_share memory share = s_share({leftamount: 1_000_000, metric: 10, chips: 4});

        vm.startPrank(marketcreator);
        tts_token.addShare(share, shareOwner);
        _snapToken("tts_token_addShare_testTTSwapTokenRoles.t_112");
        tts_token.setEnv(newMarket);
        _snapToken("tts_token_setEnv_testTTSwapTokenRoles.t_113");
        vm.stopPrank();

        vm.mockCall(
            newMarket,
            abi.encodeWithSelector(I_TTSwap_Market.ishigher.selector),
            abi.encode(false)
        );

        vm.prank(shareOwner);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_testTTSwapTokenRoles.t_124");

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setEnv(address(market));
        _snapToken("tts_token_setEnv_testTTSwapTokenRoles.t_128");
    }

    function testRoleIsolation_tokenAdminCannotSetMarketAdmin() public {
        address tokenOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(tokenOnly, true);
        _snapToken("tts_token_setTokenAdmin_testTTSwapTokenRoles.t_134");
        tts_token.setMarketAdmin(tokenOnly, false);
        _snapToken("tts_token_setMarketAdmin_testTTSwapTokenRoles.t_135");
        vm.stopPrank();

        vm.prank(tokenOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setMarketAdmin(recipient, true);
        _snapToken("tts_token_setMarketAdmin_testTTSwapTokenRoles.t_140");
    }

    function testRoleIsolation_marketAdminCannotSetTokenManager() public {
        address marketOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setMarketAdmin(marketOnly, true);
        _snapToken("tts_token_setMarketAdmin_testTTSwapTokenRoles.t_146");
        tts_token.setTokenAdmin(marketOnly, false);
        _snapToken("tts_token_setTokenAdmin_testTTSwapTokenRoles.t_147");
        tts_token.setTokenManager(marketOnly, false);
        _snapToken("tts_token_setTokenManager_testTTSwapTokenRoles.t_148");
        vm.stopPrank();

        vm.prank(marketOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenManager(recipient, true);
        _snapToken("tts_token_setTokenManager_testTTSwapTokenRoles.t_153");
    }

    function testRoleIsolation_stakeAdminCannotSetMarketManager() public {
        address stakeOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setStakeAdmin(stakeOnly, true);
        _snapToken("tts_token_setStakeAdmin_testTTSwapTokenRoles.t_159");
        tts_token.setMarketManager(stakeOnly, false);
        _snapToken("tts_token_setMarketManager_testTTSwapTokenRoles.t_160");
        vm.stopPrank();

        vm.prank(stakeOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token.setMarketManager(recipient, true);
        _snapToken("tts_token_setMarketManager_testTTSwapTokenRoles.t_165");
    }
}
