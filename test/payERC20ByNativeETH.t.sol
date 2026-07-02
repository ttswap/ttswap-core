// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice payGood: pay Native ETH (good1) → receive ERC20 BTC (good2), exact gross output.
contract payERC20ByNativeETH is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal nativeGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant NATIVE_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant PAY_OUT = uint128(1 * 10 ** 6);
    uint128 internal constant MAX_ETH_IN = uint128(6300 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        nativeGoodId = _initNativeGood(marketcreator, NATIVE_INIT_VALUE, NATIVE_INIT_QTY);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(nativeGoodId);
        _relaxSafeLine(nativeGoodId);
        _relaxSafeLine(btcGoodId);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initNativeGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 10 * qty);
        T_GoodKey memory key = _nativeKey();
        market.initGood{value: qty}(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
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

    function _payBtcWithNative(
        address trader,
        address recipient,
        uint128 ethBudget,
        uint128 maxEthIn,
        uint128 btcOut
    ) internal returns (uint256 g1change, uint256 g2change) {
        return market.payGood{value: ethBudget}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(maxEthIn, btcOut),
            recipient,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    function testPayERC20ByNativeETH() public {
        vm.deal(users[1], 100 * MAX_ETH_IN);
        vm.startPrank(users[1]);

        uint256 ethBefore = address(market).balance;
        uint256 btcBefore = btc.balanceOf(address(market));
        uint256 userBtcBefore = btc.balanceOf(users[1]);

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _payBtcWithNative(
            users[1],
            users[1],
            MAX_ETH_IN,
            MAX_ETH_IN,
            PAY_OUT
        );
        _snapMarket("pay_erc20_by_NativeETH_to_self_first");

        assertGt(g1change.amount1(), 0, "eth input used");
        assertGt(g2change.amount1(), 0, "value moved on output side");
        assertGt(address(market).balance, ethBefore, "market eth increased");
        assertLt(btc.balanceOf(address(market)), btcBefore, "market btc decreased");
        assertEq(btc.balanceOf(users[1]), userBtcBefore + PAY_OUT, "user received btc");

        _warpToFreshRunSlot();
        _payBtcWithNative(users[1], users[1], MAX_ETH_IN * 2, MAX_ETH_IN * 2, PAY_OUT);
        _snapMarket("pay_erc20_by_NativeETH_to_self_second");
        vm.stopPrank();
    }

    function testPayERC20ByNativeETHToOtherUser() public {
        address recipient = address(100);
        vm.deal(users[1], 100 * MAX_ETH_IN);
        vm.startPrank(users[1]);

        uint256 recipientBtcBefore = btc.balanceOf(recipient);

        _warpToFreshRunSlot();
        _payBtcWithNative(users[1], recipient, MAX_ETH_IN, MAX_ETH_IN, PAY_OUT);
        _snapMarket("pay_erc20_by_NativeETH_to_other_user_first");
        assertEq(btc.balanceOf(recipient), recipientBtcBefore + PAY_OUT, "recipient got btc");

        _warpToFreshRunSlot();
        _payBtcWithNative(users[1], recipient, MAX_ETH_IN * 2, MAX_ETH_IN * 2, PAY_OUT);
        _snapMarket("pay_erc20_by_NativeETH_to_other_user_second");
        vm.stopPrank();
    }
}
