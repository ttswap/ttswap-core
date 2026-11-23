// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for #319: goods created with the default config must be
///         tradable — safeLineUpper=100 left zero headroom and every swap
///         reverted TTSwapError(55). These tests deliberately do NOT relax the
///         safe line.
contract DefaultSafeLineSwap is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);
    uint128 internal constant PAY_OUT = uint128(1 * 10 ** 6);
    uint128 internal constant MAX_USDT_IN = uint128(6300 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        // NOTE: no _relaxSafeLine — default config must trade.
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 100000);
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

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function testBuyGood_succeedsAtDefaultSafeLine() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 1000000);
        usdt.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();

        assertGt(g1change.amount1(), 0, "usdt value moved");
        assertGt(g2change.amount1(), 0, "btc output > 0");
    }

    function testPayGood_succeedsAtDefaultSafeLine() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100_000_000);
        usdt.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        (uint256 g1change,) = market.payGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(MAX_USDT_IN, PAY_OUT),
            users[1],
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();

        assertGt(g1change.amount1(), 0, "usdt input used");
    }
}
