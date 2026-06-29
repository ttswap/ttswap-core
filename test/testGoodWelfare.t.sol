// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice `goodWelfare` pool top-up (TASK-P1-005 ~ P1-007, P2-04).
contract testGoodWelfare is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant WELFARE = uint128(1 * 10 ** 7);

    uint256 internal btcGoodId;
    uint256 internal nativeGoodId;

    bytes32 internal constant WELFARE_TOPIC =
        keccak256("e_goodWelfare(uint256,uint128,address)");

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        btcGoodId = _initBtcGood(users[1]);
        nativeGoodId = _initNativeGood(users[1]);
        _verifyGood(btcGoodId);
        _verifyGood(nativeGoodId);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _initNativeGood(address owner) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 20 * BTC_QTY);
        T_GoodKey memory key = _nativeKey();
        market.initGood{value: BTC_QTY}(
            key,
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
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

    function testGoodWelfare_nativeEth() public {
        uint128 welfare = 1 ether;
        vm.deal(users[1], 5 ether);
        S_GoodTmpState memory before_ = market.getGoodState(nativeGoodId);

        vm.prank(users[1]);
        market.goodWelfare{value: welfare}(
            nativeGoodId,
            welfare,
            defaultdata,
            users[1],
            defaultdata
        );

        S_GoodTmpState memory after_ = market.getGoodState(nativeGoodId);
        assertEq(
            after_.currentState.amount0(),
            before_.currentState.amount0() + welfare,
            "native welfare amount0"
        );
    }

    function testGoodWelfare_revert_traderMismatch() public {
        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.goodWelfare(btcGoodId, WELFARE, defaultdata, users[2], defaultdata);
    }

    function testGoodWelfare_revert_insufficientAllowance() public {
        address donor = users[5];
        vm.startPrank(donor);
        deal(address(btc), donor, WELFARE, false);
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        market.goodWelfare(btcGoodId, WELFARE, defaultdata, donor, defaultdata);
        vm.stopPrank();
    }

    function testGoodWelfare_eventFields() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 5 * BTC_QTY, false);
        btc.approve(address(market), WELFARE);
        vm.recordLogs();
        market.goodWelfare(btcGoodId, WELFARE, defaultdata, users[1], defaultdata);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == WELFARE_TOPIC) {
                found = true;
                assertEq(uint256(logs[i - 1].topics[1]), btcGoodId, "good id");
                (uint128 welfareAmt, address trader) = abi.decode(logs[i - 1].data, (uint128, address));
                assertEq(welfareAmt, WELFARE, "welfare amount");
                assertEq(trader, users[1], "trader");
                break;
            }
        }
        assertTrue(found, "e_goodWelfare emitted");
        vm.stopPrank();
    }
}
