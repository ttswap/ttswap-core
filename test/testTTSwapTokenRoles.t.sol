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
        assertTrue(tts_token.userConfig(recipient).isTokenAdmin());
        tts_token.setTokenAdmin(recipient, false);
        assertFalse(tts_token.userConfig(recipient).isTokenAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenAdmin(recipient, true);
    }

    function testSetTokenManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setTokenManager(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isTokenManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenManager(recipient, true);
    }

    function testSetCallMintTTS_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isCallMintTTS());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setCallMintTTS(recipient, true);
    }

    function testSetMarketAdmin_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setMarketAdmin(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isMarketAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setMarketAdmin(recipient, true);
    }

    function testSetMarketManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setMarketManager(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isMarketManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token.setMarketManager(recipient, true);
    }

    function testSetStakeAdmin_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setStakeAdmin(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isStakeAdmin());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setStakeAdmin(recipient, true);
    }

    function testSetStakeManager_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setStakeManager(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isStakeManager());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 64));
        tts_token.setStakeManager(recipient, true);
    }

    function testSetBan_ok_and_revert() public {
        vm.startPrank(marketcreator);
        tts_token.setBan(recipient, true);
        assertTrue(tts_token.userConfig(recipient).isBan());
        vm.stopPrank();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 65));
        tts_token.setBan(recipient, true);
    }

    function testSetEnv_ok_and_revert() public {
        address newMarket = address(0xBEEF);
        address shareOwner = users[4];
        s_share memory share = s_share({leftamount: 1_000_000, metric: 10, chips: 4});

        vm.startPrank(marketcreator);
        tts_token.addShare(share, shareOwner);
        tts_token.setEnv(newMarket);
        vm.stopPrank();

        vm.mockCall(
            newMarket,
            abi.encodeWithSelector(I_TTSwap_Market.ishigher.selector),
            abi.encode(false)
        );

        vm.prank(shareOwner);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setEnv(address(market));
    }

    function testRoleIsolation_tokenAdminCannotSetMarketAdmin() public {
        address tokenOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(tokenOnly, true);
        tts_token.setMarketAdmin(tokenOnly, false);
        vm.stopPrank();

        vm.prank(tokenOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setMarketAdmin(recipient, true);
    }

    function testRoleIsolation_marketAdminCannotSetTokenManager() public {
        address marketOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setMarketAdmin(marketOnly, true);
        tts_token.setTokenAdmin(marketOnly, false);
        tts_token.setTokenManager(marketOnly, false);
        vm.stopPrank();

        vm.prank(marketOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setTokenManager(recipient, true);
    }

    function testRoleIsolation_stakeAdminCannotSetMarketManager() public {
        address stakeOnly = users[2];
        vm.startPrank(marketcreator);
        tts_token.setStakeAdmin(stakeOnly, true);
        tts_token.setMarketManager(stakeOnly, false);
        vm.stopPrank();

        vm.prank(stakeOnly);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token.setMarketManager(recipient, true);
    }
}
