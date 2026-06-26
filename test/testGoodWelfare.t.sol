// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice `goodWelfare` pool top-up (TASK-P1-005 ~ P1-007).
contract testGoodWelfare is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant WELFARE = uint128(1 * 10 ** 7);

    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        btcGoodId = _initBtcGood(users[1]);
        _verifyGood(btcGoodId);
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initBtcGood(address owner) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * BTC_QTY, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function testGoodWelfare_happyPath() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 5 * BTC_QTY, false);
        btc.approve(address(market), WELFARE);

        S_GoodTmpState memory before_ = market.getGoodState(btcGoodId);
        market.goodWelfare(btcGoodId, WELFARE, defaultdata, users[1], defaultdata);
        snapLastCall("goodWelfare_btc");

        S_GoodTmpState memory after_ = market.getGoodState(btcGoodId);
        assertEq(
            after_.currentState.amount0(),
            before_.currentState.amount0() + WELFARE,
            "current amount0 increased"
        );
        assertEq(
            after_.currentState.amount1(),
            before_.currentState.amount1() + WELFARE,
            "current amount1 increased"
        );
        assertEq(
            after_.investState.amount1(),
            before_.investState.amount1(),
            "invest state unchanged"
        );
        vm.stopPrank();
    }

    function testGoodWelfare_revert_goodNotExist() public {
        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 12));
        market.goodWelfare(uint256(uint160(address(0xBEEF))), WELFARE, defaultdata, users[1], defaultdata);
    }

    function testGoodWelfare_revert_overflow() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * BTC_QTY, false);
        btc.approve(address(market), type(uint256).max);

        uint128 overflowAmt = uint128(2 ** 109);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 18));
        market.goodWelfare(btcGoodId, overflowAmt, defaultdata, users[1], defaultdata);
        vm.stopPrank();
    }
}
