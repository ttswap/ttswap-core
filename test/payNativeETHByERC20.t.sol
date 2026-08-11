// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice payGood: pay ERC20 USDT (good1) → receive Native ETH (good2), exact gross output.
contract payNativeETHByERC20 is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal usdtGoodId;
    uint256 internal nativeGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant NATIVE_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant PAY_OUT = uint128(1 * 10 ** 6);
    uint128 internal constant MAX_USDT_IN = uint128(6300 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        nativeGoodId = _initNativeGood(users[1], NATIVE_INIT_VALUE, NATIVE_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(nativeGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
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

    function _markAsValueGood(uint256 goodId) internal {
        vm.prank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
    }

    function _payNativeWithUsdt(
        address trader,
        address recipient,
        uint128 maxUsdtIn,
        uint128 ethOut
    ) internal returns (uint256 g1change, uint256 g2change) {
        usdt.approve(address(market), maxUsdtIn);
        return market.payGood(
            _usdtKey(),
            _nativeKey(),
            toTTSwapUINT256(maxUsdtIn, ethOut),
            recipient,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    function testPayNativeETHByERC20() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100_000_000);

        uint256 usdtBefore = usdt.balanceOf(address(market));
        uint256 ethBefore = address(market).balance;
        uint256 userEthBefore = users[1].balance;

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _payNativeWithUsdt(
            users[1],
            users[1],
            MAX_USDT_IN,
            PAY_OUT
        );
        _snapMarket("pay_NativeETH_by_erc20_to_self_first");

        assertGt(g1change.amount1(), 0, "usdt input used");
        assertGt(g2change.amount1(), 0, "value moved on output side");
        assertGt(usdt.balanceOf(address(market)), usdtBefore, "market usdt increased");
        assertLt(address(market).balance, ethBefore, "market eth decreased");
        assertEq(users[1].balance, userEthBefore + PAY_OUT, "user received eth");

        _warpToFreshRunSlot();
        _payNativeWithUsdt(users[1], users[1], MAX_USDT_IN * 2, PAY_OUT);
        _snapMarket("pay_NativeETH_by_erc20_to_self_second");
        vm.stopPrank();
    }

    function testPayNativeETHByERC20ToOtherUser() public {
        address recipient = address(100);
        vm.deal(recipient, 0);
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100_000_000);

        uint256 recipientEthBefore = recipient.balance;

        _warpToFreshRunSlot();
        _payNativeWithUsdt(users[1], recipient, MAX_USDT_IN, PAY_OUT);
        _snapMarket("pay_NativeETH_by_erc20_to_other_user_first");
        assertEq(recipient.balance, recipientEthBefore + PAY_OUT, "recipient got eth");

        _warpToFreshRunSlot();
        _payNativeWithUsdt(users[1], recipient, MAX_USDT_IN * 2, PAY_OUT);
        _snapMarket("pay_NativeETH_by_erc20_to_other_user_second");
        vm.stopPrank();
    }
}
