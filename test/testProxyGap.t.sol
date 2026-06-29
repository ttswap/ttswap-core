// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P1-01 ~ P1-03: Proxy freeze / fallback / permission branches.
contract testProxyGap is BaseSetup {
    function testMarketProxy_freeze_thenFallbackReverts63() public {
        vm.prank(marketcreator);
        market_proxy.freezeMarket();

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.getGoodState(0);
    }

    function testMarketProxy_disableUpgrade_thenFreezeMarket_reverts1() public {
        vm.prank(marketcreator);
        market_proxy.disableUpgrade();

        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market_proxy.freezeMarket();
    }

    function testMarketProxy_upgrade_toZero_equivalentToFreeze() public {
        vm.prank(marketcreator);
        market_proxy.upgrade(address(0));
        assertEq(market_proxy.implementation(), address(0), "impl zero");

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.getGoodState(0);
    }

    function testMarketProxy_receiveEth_acceptsValue() public {
        (bool ok,) = address(market_proxy).call{value: 1 ether}("");
        assertTrue(ok, "market proxy accepts eth");
        assertEq(address(market_proxy).balance, 1 ether, "balance held");
    }

    function testTokenProxy_freeze_delegatecallToZero_emptyReturn() public {
        vm.prank(marketcreator);
        tts_token_proxy.freezeToken();
        assertEq(tts_token_proxy.implementation(), address(0), "impl zero");

        (bool ok, bytes memory ret) = address(tts_token_proxy).staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        assertTrue(ok, "delegatecall succeeds");
        assertEq(ret.length, 0, "empty returndata unlike Market proxy TTSwapError(63)");
    }

    function testTokenProxy_freezeToken_revert_notManager() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token_proxy.freezeToken();
    }

    function testTokenProxy_upgrade_toZero_emptyReturn() public {
        vm.prank(marketcreator);
        tts_token_proxy.upgrade(address(0));
        assertEq(tts_token_proxy.implementation(), address(0), "impl zero");

        (bool ok, bytes memory ret) = address(tts_token_proxy).staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        assertTrue(ok, "delegatecall succeeds");
        assertEq(ret.length, 0, "zero impl yields empty returndata");
    }

    function testTokenProxy_receiveEth_acceptsValue() public {
        (bool ok,) = address(tts_token_proxy).call{value: 1 ether}("");
        assertTrue(ok, "token proxy accepts eth");
        assertEq(address(tts_token_proxy).balance, 1 ether, "balance held");
    }
}
