// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

/// @notice Default-fee swap tests (buyFee/sellFee = 8 bps from `initial_config`).
/// @dev `payGood` is commented out in v2.0 — only `buyGood` paths are covered here.
contract testSwapWithFee is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal constant SAFE_LINE_SHIFT = 204;
    uint256 internal constant SAFE_LINE_MASK = uint256(0x3FF) << SAFE_LINE_SHIFT;

    uint128 internal constant POOL_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant POOL_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(118_000 * 10 ** 12);

    uint128 internal constant SWAP_IN = uint128(500 * 10 ** 6);
    uint128 internal constant LARGE_SWAP = uint128(1_000 * 10 ** 6);
    uint128 internal constant MIN_OUT = uint128(1 * 10 ** 6);

    MyToken internal usdc;
    uint256 internal usdtGoodId;
    uint256 internal usdcGoodId;
    uint256 internal btcGoodId;
    uint256 internal swapTs = 1;

    function setUp() public override {
        BaseSetup.setUp();
        usdc = new MyToken("USDC", "USDC", 6);
        vm.warp(0);

        usdtGoodId = _initValueGood(_usdtKey(), POOL_VALUE, POOL_QTY);
        usdcGoodId = _initValueGood(_usdcKey(), POOL_VALUE, POOL_QTY);
        btcGoodId = _initValueGood(_btcKey(), BTC_VALUE, BTC_QTY);

        _prepareGood(usdtGoodId);
        _prepareGood(usdcGoodId);
        _prepareGood(btcGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _usdcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdc), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initValueGood(
        T_GoodKey memory key,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(marketcreator);
        if (key.contractAddress == address(btc)) {
            deal(address(btc), marketcreator, 100 * qty, false);
            btc.approve(address(market), qty);
        } else if (key.contractAddress == address(usdc)) {
            deal(address(usdc), marketcreator, 100 * qty, false);
            usdc.approve(address(market), qty);
        } else {
            deal(address(usdt), marketcreator, 100 * uint256(qty), false);
            usdt.approve(address(market), qty);
        }
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, marketcreator, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _prepareGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setVerified(true);
        cfg = (cfg & ~SAFE_LINE_MASK) | (uint256(1023) << SAFE_LINE_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _warp() internal {
        vm.warp(swapTs);
        swapTs++;
        if (swapTs > 9) swapTs = 1;
    }

    function _approveIn(T_GoodKey memory keyIn, uint128 amountIn) internal {
        address token = keyIn.contractAddress;
        if (token == address(usdc)) {
            usdc.approve(address(market), amountIn);
        } else if (token == address(btc)) {
            btc.approve(address(market), amountIn);
        } else {
            usdt.approve(address(market), amountIn);
        }
    }

    function _buy(
        T_GoodKey memory keyIn,
        T_GoodKey memory keyOut,
        uint128 amountIn,
        uint128 minOut
    ) internal returns (uint256 g1change, uint256 g2change) {
        _approveIn(keyIn, amountIn);
        _warp();
        return market.buyGood(
            keyIn,
            keyOut,
            toTTSwapUINT256(amountIn, minOut),
            address(0),
            defaultdata,
            marketcreator,
            defaultdata,
            0
        );
    }

    function _fundTrader() internal {
        deal(address(usdc), marketcreator, 200_000 * 10 ** 6, false);
        deal(address(usdt), marketcreator, 200_000 * 10 ** 6, false);
        usdc.approve(address(market), type(uint256).max);
        usdt.approve(address(market), type(uint256).max);
        btc.approve(address(market), type(uint256).max);
    }

    function _assertDefaultFees(uint256 goodId) internal view {
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        assertEq(cfg.getBuyFee(10_000), 8, "buy fee 8 bps");
        assertEq(cfg.getSellFee(10_000), 8, "sell fee 8 bps");
    }

    // ── config sanity ──────────────────────────────────────────────────────

    function testSwapFees_defaultConfig() public view {
        _assertDefaultFees(usdcGoodId);
        _assertDefaultFees(usdtGoodId);
        _assertDefaultFees(btcGoodId);
    }

    // ── single-leg swap ────────────────────────────────────────────────────

    function testSwapA2B_withFee() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);
        uint256 usdtBefore = usdt.balanceOf(marketcreator);
        S_GoodTmpState memory usdcStateBefore = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtStateBefore = market.getGoodState(usdtGoodId);

        (uint256 g1, uint256 g2) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        snapLastCall("swap_with_fee_a2b");

        assertGt(g1.amount1(), 0, "value moved on input good");
        assertGt(g2.amount1(), 0, "output received");
        assertGt(g1.amount0(), 0, "sell fee charged on input");
        assertGt(g2.amount0(), 0, "buy fee charged on output");

        assertEq(usdc.balanceOf(marketcreator), usdcBefore - SWAP_IN, "spent usdc");
        assertGt(usdt.balanceOf(marketcreator), usdtBefore, "gained usdt");

        S_GoodTmpState memory usdcAfter = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtAfter = market.getGoodState(usdtGoodId);
        assertGt(
            usdcAfter.currentState.amount1(),
            usdcStateBefore.currentState.amount1(),
            "usdc pool qty grew"
        );
        assertLt(
            usdtAfter.currentState.amount1(),
            usdtStateBefore.currentState.amount1(),
            "usdt pool qty shrank"
        );
        vm.stopPrank();
    }

    // ── round-trip bleeds fees ─────────────────────────────────────────────

    function testSwapA2B2A_withFee_notReversible() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        _buy(_usdtKey(), _usdcKey(), leg1.amount1(), 0);
        snapLastCall("swap_with_fee_a2b2a");

        assertLt(usdc.balanceOf(marketcreator), usdcBefore, "fees reduce round-trip usdc");
        assertGt(usdcBefore - usdc.balanceOf(marketcreator), 0, "non-zero fee loss");
        vm.stopPrank();
    }

    function testSwapA2B2A_withFee_lossBounded() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), LARGE_SWAP, MIN_OUT);
        _buy(_usdtKey(), _usdcKey(), leg1.amount1(), 0);

        uint256 loss = usdcBefore - usdc.balanceOf(marketcreator);
        // Four 8 bps legs (sell+buy each direction) → theoretical max ~32 bps of notional.
        assertGt(loss, 0, "fees taken");
        assertLt(loss, (uint256(LARGE_SWAP) * 50) / 10_000, "loss within 50 bps bound");
        vm.stopPrank();
    }

    // ── triangular path ────────────────────────────────────────────────────

    function testSwapA2B2C2A_withFee() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), LARGE_SWAP, MIN_OUT);
        (, uint256 leg2) = _buy(_usdtKey(), _btcKey(), leg1.amount1(), 0);
        _buy(_btcKey(), _usdcKey(), leg2.amount1(), 0);
        snapLastCall("swap_with_fee_a2b2c2a");

        assertLt(usdc.balanceOf(marketcreator), usdcBefore, "triangular path pays fees");
        assertGt(usdcBefore - usdc.balanceOf(marketcreator), LARGE_SWAP / 10_000, "meaningful fee drag");
        vm.stopPrank();
    }

    // ── pool fee accounting ────────────────────────────────────────────────

    function testSwap_poolRetainsFeeQuantity() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        S_GoodTmpState memory usdcBefore = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtBefore = market.getGoodState(usdtGoodId);

        _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);

        S_GoodTmpState memory usdcAfter = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtAfter = market.getGoodState(usdtGoodId);

        // Input good keeps sell-fee tokens; output good fee stays in pool currentState.
        assertGt(
            usdcAfter.currentState.amount0(),
            usdcBefore.currentState.amount0(),
            "usdc fee accumulator grew"
        );
        assertGt(
            usdtAfter.currentState.amount0(),
            usdtBefore.currentState.amount0(),
            "usdt fee accumulator grew"
        );
        vm.stopPrank();
    }
}
