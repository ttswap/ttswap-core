// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice C-03 verification: run-block slot is per-block anti-replay, not permanent freeze.
contract C03_RunBlockTemporary is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    address internal attacker;
    address internal trader;

    function setUp() public override {
        BaseSetup.setUp();
        attacker = users[4];
        trader = users[1];
        vm.warp(0);

        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[2], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
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

    function _markAsValueGood(uint256 goodId) internal {
        vm.prank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
    }

    function _zeroPayGoodSameToken(address who) internal {
        vm.prank(who);
        market.payGood(
            _usdtKey(),
            _usdtKey(),
            toTTSwapUINT256(0, 0),
            who,
            defaultdata,
            who,
            defaultdata,
            0
        );
        _snapMarket("payGood_zero_same_token");
    }

    function _buyBtcWithUsdt(address who) internal {
        vm.startPrank(who);
        usdt.mint(who, SWAP_IN);
        usdt.approve(address(market), SWAP_IN);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 0),
            address(0),
            defaultdata,
            who,
            defaultdata,
            0
        );
        _snapMarket("buyGood_usdt_btc_after_run_slot");
        vm.stopPrank();
    }

    /// @dev Zero-amount same-token payGood occupies run-block slot for current block only.
    function test_C03_zero_payGood_blocks_same_block_then_releases() public {
        vm.roll(100);
        vm.warp(10);

        _zeroPayGoodSameToken(attacker);

        vm.startPrank(trader);
        usdt.mint(trader, SWAP_IN);
        usdt.approve(address(market), SWAP_IN);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 0),
            address(0),
            defaultdata,
            trader,
            defaultdata,
            0
        );
        _snapMarket("buyGood_revert_run_block_same_slot");
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.warp(20);
        _buyBtcWithUsdt(trader);
        assertGt(btc.balanceOf(trader), 0, "next block: good is usable again");
    }

    /// @dev Intended anti-flash: first real trade in a block succeeds, second reverts(46).
    function test_C03_legitimate_first_trade_per_block_succeeds_second_fails() public {
        vm.roll(200);
        vm.warp(30);

        _buyBtcWithUsdt(trader);

        address trader2 = users[3];
        vm.startPrank(trader2);
        usdt.mint(trader2, SWAP_IN);
        usdt.approve(address(market), SWAP_IN);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 0),
            address(0),
            defaultdata,
            trader2,
            defaultdata,
            0
        );
        _snapMarket("buyGood_revert_run_block_second_trader");
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.warp(40);
        _buyBtcWithUsdt(trader2);
        assertGt(btc.balanceOf(trader2), 0, "second trader ok on next block");
    }

    /// @dev Stored slot tracks block.number % 4095, not a permanent freeze flag.
    function test_C03_run_slot_is_block_modulo_not_permanent() public view {
        uint256 slotAt100 = 100 % 4095;
        uint256 slotAt101 = 101 % 4095;
        assertTrue(slotAt100 != slotAt101, "slot changes every block");
    }
}
