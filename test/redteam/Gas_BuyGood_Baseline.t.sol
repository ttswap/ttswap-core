// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {toTTSwapUINT256} from "../../src/libraries/L_TTSwapUINT256.sol";

contract Gas_BuyGood_Baseline is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(100);
        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 100_000_000);
        usdt.approve(address(market), type(uint256).max);
        T_GoodKey memory uk = T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
        market.initGood(uk, toTTSwapUINT256(uint128(50_000 * 10 ** 12), uint128(50_000 * 10 ** 6)), defaultdata, marketcreator, defaultdata);
        _snapMarket("market_initGood_Gas_BuyGood_Baseline.t_20");
        usdtGoodId = uk.toId();
        vm.stopPrank();
        vm.startPrank(users[1]);
        btc.mint(users[1], 10);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory bk = T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
        market.initGood(bk, toTTSwapUINT256(uint128(63_000 * 10 ** 12), uint128(1 * 10 ** 8)), defaultdata, users[1], defaultdata);
        _snapMarket("market_initGood_Gas_BuyGood_Baseline.t_27");
        btcGoodId = bk.toId();
        vm.stopPrank();
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
    }

    function test_gas_buyGood_with_delta() public {
        address trader = users[4];
        deal(address(usdt), trader, 1_000_000 * 10 ** 6, false);
        uint128 swapIn = 50 * 10 ** 6;
        vm.startPrank(trader);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0}),
            toTTSwapUINT256(swapIn, 0), address(0), defaultdata, trader, defaultdata, 0
        );
        _snapMarket("market_buyGood_Gas_BuyGood_Baseline.t_45");
        _warpToFreshRunSlot();
        market.buyGood(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0}),
            toTTSwapUINT256(swapIn, 0), address(0), defaultdata, trader, defaultdata, 0
        );
        _snapMarket("market_buyGood_Gas_BuyGood_Baseline.t_51");
        _snapMarket("buyGood_with_delta_patch");
        vm.stopPrank();
    }
}
