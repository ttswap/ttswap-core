// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Proxy upgrade / freeze paths (TASK-P3-002 simplified, P3-003).
contract testProxyUpgrade is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood();
        btcGoodId = _initBtcGood();
        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
    }


    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initUsdtGood() internal returns (uint256 goodId) {
        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 100_000_000);
        usdt.approve(address(market), 50_000 * 10 ** 6);
        T_GoodKey memory key = _usdtKey();
        market.initGood(
            key,
            toTTSwapUINT256(50_000 * 10 ** 12, 50_000 * 10 ** 6),
            defaultdata,
            marketcreator,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initBtcGood() internal returns (uint256 goodId) {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 ** 9, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(63_000 * 10 ** 12, 1 * 10 ** 8),
            defaultdata,
            users[1],
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _doBuy() internal {
        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 10_000_000 * 10 ** 6, false);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(50 * 10 ** 6, 0),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    // ── Market proxy ───────────────────────────────────────────────────────

    function testMarketProxy_upgrade_preservesState() public {
        _doBuy();
        S_GoodTmpState memory preUsdt = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory preBtc = market.getGoodState(btcGoodId);

        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(marketcreator);
        market_proxy.upgrade(address(newImpl));

        assertEq(market_proxy.implementation(), address(newImpl), "impl updated");
        S_GoodTmpState memory postUsdt = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory postBtc = market.getGoodState(btcGoodId);
        assertEq(postUsdt.currentState, preUsdt.currentState, "usdt currentState");
        assertEq(postUsdt.investState, preUsdt.investState, "usdt investState");
        assertEq(postBtc.currentState, preBtc.currentState, "btc currentState");
        assertEq(postBtc.investState, preBtc.investState, "btc investState");
    }

    function testMarketProxy_upgrade_then_buyGood() public {
        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(marketcreator);
        market_proxy.upgrade(address(newImpl));

        vm.startPrank(users[2]);
        deal(address(usdt), users[2], 10_000_000 * 10 ** 6, false);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(50 * 10 ** 6, 0),
            address(0),
            defaultdata,
            users[2],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    function testMarketProxy_freezeMarket_implZeroed_restoreViaUpgrade() public {
        vm.prank(marketcreator);
        market_proxy.freezeMarket();
        assertEq(market_proxy.implementation(), address(0), "impl zeroed");

        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(marketcreator);
        market_proxy.upgrade(address(newImpl));
        assertEq(market.getGoodState(usdtGoodId).owner, marketcreator, "state intact");
    }

    function testMarketProxy_disableUpgrade() public {
        vm.prank(marketcreator);
        market_proxy.disableUpgrade();

        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market_proxy.upgrade(address(newImpl));
    }

    function testMarketProxy_upgrade_revert_notAdmin() public {
        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market_proxy.upgrade(address(newImpl));
    }

    function testMarketProxy_disableUpgrade_revert_notDAO() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        market_proxy.disableUpgrade();
    }

    // ── Token proxy ────────────────────────────────────────────────────────

    function testTokenProxy_upgrade() public {
        TTSwap_Token newImpl = new TTSwap_Token(address(usdt));
        vm.prank(marketcreator);
        tts_token_proxy.upgrade(address(newImpl));
        assertEq(tts_token_proxy.implementation(), address(newImpl), "token impl");

        assertGt(tts_token.ttstokenconfig(), 0, "state readable after upgrade");
    }

    function testTokenProxy_freezeToken_implZeroed_restoreViaUpgrade() public {
        vm.prank(marketcreator);
        tts_token_proxy.freezeToken();
        assertEq(tts_token_proxy.implementation(), address(0), "token impl zeroed");

        TTSwap_Token newImpl = new TTSwap_Token(address(usdt));
        vm.prank(marketcreator);
        tts_token_proxy.upgrade(address(newImpl));
        assertGt(tts_token.ttstokenconfig(), 0, "token state intact");
    }

    function testTokenProxy_upgrade_revert_notAdmin() public {
        TTSwap_Token newImpl = new TTSwap_Token(address(usdt));
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        tts_token_proxy.upgrade(address(newImpl));
    }
}
