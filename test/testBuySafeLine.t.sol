// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice buyGood safeLine guard (TASK-P0-005).
contract testBuySafeLine is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(100 * 10 ** 6);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _markAsValueGood(usdtGoodId);
        _tightSafeLine(usdtGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }



    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    /// @dev Tight upper safeline on input good: post-swap qty must not exceed ~80% of reserve.
    function _tightSafeLine(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg =
            (cfg & ~BaseSetup.SAFE_LINE_MASK) |
            (uint256(80) << TestConfigConstants.SAFE_LINE_UPPER_SHIFT) |
            (uint256(1) << TestConfigConstants.SAFE_LINE_LOWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 100_000_000);
        usdt.approve(address(market), qty);
        T_GoodKey memory key = _usdtKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initBtcGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function testBuyGood_revert_safeLine() public {
        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 10_000_000 * 10 ** 6, false);
        usdt.approve(address(market), SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 0),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        _snapMarket("buyGood_revert_safeLine");
        vm.stopPrank();
    }
}
