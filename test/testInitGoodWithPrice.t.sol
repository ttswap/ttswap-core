// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Tests for `initGood` with user-specified price (v2.0 single-token init)
///         and subsequent `investGood` flows.
contract testInitGoodWithPrice is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    bytes32 internal constant INIT_GOOD_TOPIC =
        keccak256(
            "e_initGood(uint256,uint256,uint256,uint256,uint256,uint256,address)"
        );

    uint256 internal constant INITIAL_CONFIG = TestConfigConstants.INITIAL_GOOD_CONFIG;

    uint256 internal constant MIN_VALUE = 500_000_000_000_000;
    uint256 internal constant MIN_QTY = 500_000;

    uint256 internal metaGoodId;
    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(63000 * 10 ** 12);

    /// @dev Invest timestamps cycling 1..9: satisfies both
    ///      `_checkGoodActive` (runSlot != t%10) and `updateRunTimeConfig` (runSlot == t/10)
    ///      when initial lastRunSlot = 0.

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        _initMetaGood();
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _initMetaGood() internal {
        vm.startPrank(marketcreator);
        T_GoodKey memory usdtKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        uint128 metaQty = uint128(50000 * 10 ** 6);
        uint128 metaValue = uint128(50000 * 10 ** 12);
        usdt.mint(marketcreator, 100000);
        usdt.approve(address(market), metaQty);
        market.initGood(
            usdtKey,
            toTTSwapUINT256(metaValue, metaQty),
            defaultdata,
            marketcreator,
            defaultdata
        );
        metaGoodId = usdtKey.toId();
        vm.stopPrank();
    }

    function _expectedGoodConfig() internal pure returns (uint256) {
        return TestConfigConstants.INITIAL_GOOD_CONFIG;
    }

    function _proofIdFromInitGoodEvent() internal returns (uint256 proofId) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == INIT_GOOD_TOPIC) {
                return uint256(logs[i - 1].topics[1]);
            }
        }
        revert("e_initGood not found");
    }

    function _assertGoodState(
        uint256 goodId,
        address owner,
        uint128 qty,
        uint128 value
    ) internal view {
        S_GoodTmpState memory good_ = market.getGoodState(goodId);
        assertEq(good_.currentState, toTTSwapUINT256(qty, qty), "currentState");
        assertEq(good_.investState, toTTSwapUINT256(qty, value), "investState");
        assertEq(good_.goodConfig, _expectedGoodConfig(), "goodConfig");
        assertEq(good_.owner, owner, "owner");
    }

    function _assertProofState(
        uint256 proofId,
        uint256 goodId,
        uint128 qty,
        uint128 value
    ) internal view {
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, goodId, "proof currentgood");
        assertEq(proof.state, toTTSwapUINT256(value, value), "proof state");
        assertEq(proof.shares, toTTSwapUINT256(qty, 0), "proof shares");
        assertEq(proof.invest, toTTSwapUINT256(qty, qty), "proof invest");
    }

    function _fundAndApproveBtc(address user, uint256 totalQty) internal {
        deal(address(btc), user, totalQty, false);
        btc.approve(address(market), type(uint256).max);
    }

    function _initBtcGood(
        address trader,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        T_GoodKey memory key = _btcKey();
        goodId = key.toId();
        vm.recordLogs();
        market.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            trader,
            defaultdata
        );
    }


    function _verifyAndPromiseGood(
        uint256 goodId,
        address restoreTrader
    ) internal {
        vm.stopPrank();
        vm.startPrank(marketcreator);
        uint256 cfg = market
            .getGoodState(goodId)
            .goodConfig
            
            .setPromised(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
        vm.startPrank(restoreTrader);
    }

    /// @dev Pick t ∈ [1,9] so runSlot(0) passes anti-replay checks for first invest.

    // ── initGood happy path ────────────────────────────────────────────────

    function testInitGood_basic() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);

        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        snapLastCall("initGood_BTC_withPrice");

        assertEq(btc.balanceOf(users[1]), 9 * BTC_QTY, "user btc balance");
        assertEq(btc.balanceOf(address(market)), BTC_QTY, "market btc balance");
        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "metagood unchanged"
        );

        _assertGoodState(goodId, users[1], BTC_QTY, BTC_VALUE);
        _assertProofState(_proofIdFromInitGoodEvent(), goodId, BTC_QTY, BTC_VALUE);
        vm.stopPrank();
    }

    function testInitGood_nativeETH() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], 10 * BTC_QTY);

        T_GoodKey memory key = _nativeKey();
        uint256 goodId = key.toId();

        vm.recordLogs();
        market.initGood{value: BTC_QTY}(
            key,
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        snapLastCall("initGood_NativeETH_withPrice");

        assertEq(users[1].balance, 9 * BTC_QTY, "user eth balance");
        assertEq(address(market).balance, BTC_QTY, "market eth balance");
        _assertGoodState(goodId, users[1], BTC_QTY, BTC_VALUE);
        _assertProofState(_proofIdFromInitGoodEvent(), goodId, BTC_QTY, BTC_VALUE);
        vm.stopPrank();
    }

    function testInitGood_boundary_minimum() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * MIN_QTY);

        uint256 goodId = _initBtcGood(
            users[1],
            uint128(MIN_VALUE),
            uint128(MIN_QTY)
        );

        _assertGoodState(goodId, users[1], uint128(MIN_QTY), uint128(MIN_VALUE));
        assertEq(btc.balanceOf(address(market)), MIN_QTY, "min qty deposited");
        vm.stopPrank();
    }

    function testInitGood_customPrice() public {
        vm.startPrank(users[2]);
        _fundAndApproveBtc(users[2], 10 * BTC_QTY);

        uint128 customValue = uint128(50000 * 10 ** 12);
        uint256 goodId = _initBtcGood(users[2], customValue, BTC_QTY);

        _assertGoodState(goodId, users[2], BTC_QTY, customValue);
        vm.stopPrank();
    }

    // ── initGood revert cases ──────────────────────────────────────────────

    function testInitGood_revert_duplicate() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        _initBtcGood(users[1], BTC_VALUE, BTC_QTY);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 5));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_quantityTooSmall() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 36));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, uint128(MIN_QTY - 1)),
            defaultdata,
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_quantityTooLarge() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 36));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, uint128(2 ** 109 + 1)),
            defaultdata,
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_valueTooSmall() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 35));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(uint128(MIN_VALUE - 1), BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_valueTooLarge() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 35));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(uint128(2 ** 109 + 1), BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_traderMismatch() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            users[2],
            defaultdata
        );
        vm.stopPrank();
    }

    function testInitGood_revert_zeroTrader() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 0);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.initGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            address(0),
            defaultdata
        );
        vm.stopPrank();
    }

    // ── investGood after initGood ──────────────────────────────────────────

    function testInitGood_then_investGood_poolPrice_owner() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        _warpToFreshRunSlot();

        S_GoodTmpState memory before = market.getGoodState(goodId);
        uint128 investQty = BTC_QTY;

        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            users[1]
        );
        snapLastCall("investGood_poolPrice_first");

        S_GoodTmpState memory after1 = market.getGoodState(goodId);
        assertGt(
            after1.currentState.amount1(),
            before.currentState.amount1(),
            "qty increased after invest"
        );
        assertGe(
            after1.currentState.amount0(),
            after1.currentState.amount1(),
            "virtual qty >= actual qty"
        );

        _warpToFreshRunSlot();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            users[1]
        );
        snapLastCall("investGood_poolPrice_second");

        S_GoodTmpState memory after2 = market.getGoodState(goodId);
        assertGt(
            after2.currentState.amount1(),
            after1.currentState.amount1(),
            "second invest increased qty"
        );
        vm.stopPrank();
    }


    function testInitGood_then_investGood_revert_highPrice() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        _verifyAndPromiseGood(goodId, users[1]);
        _warpToFreshRunSlot();

        uint128 higherPrice = uint128(64000 * 10 ** 12);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(higherPrice, BTC_QTY),
            defaultdata,
            defaultdata,
            users[1]
        );
        assertGt(
            market.getGoodState(goodId).currentState.amount1(),
            BTC_QTY,
            "high-price invest allowed in v2"
        );
        vm.stopPrank();
    }

    function testInitGood_nonOwner_investGood_poolPrice() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        vm.stopPrank();

        vm.startPrank(users[2]);
        _fundAndApproveBtc(users[2], 10 * BTC_QTY);
        _warpToFreshRunSlot();

        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_QTY),
            defaultdata,
            defaultdata,
            users[2]
        );
        snapLastCall("investGood_nonOwner_poolPrice");

        S_GoodTmpState memory state = market.getGoodState(goodId);
        assertGt(state.currentState.amount1(), BTC_QTY, "pool grew");
        vm.stopPrank();
    }

    function testInitGood_nonOwner_investGood_revert_explicitPrice() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        vm.stopPrank();

        _verifyAndPromiseGood(goodId, users[2]);
        _fundAndApproveBtc(users[2], 10 * BTC_QTY);
        _warpToFreshRunSlot();

        market.investGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            defaultdata,
            users[2]
        );
        assertGt(
            market.getGoodState(goodId).currentState.amount1(),
            BTC_QTY,
            "non-owner explicit price invest allowed in v2"
        );
        vm.stopPrank();
    }

    function testInitGood_owner_investGood_explicitPoolPrice() public {
        vm.startPrank(users[1]);
        _fundAndApproveBtc(users[1], 10 * BTC_QTY);
        uint256 goodId = _initBtcGood(users[1], BTC_VALUE, BTC_QTY);
        _verifyAndPromiseGood(goodId, users[1]);
        _warpToFreshRunSlot();

        market.investGood(
            _btcKey(),
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            defaultdata,
            users[1]
        );
        snapLastCall("investGood_owner_samePrice");

        S_GoodTmpState memory state = market.getGoodState(goodId);
        assertGt(state.currentState.amount1(), BTC_QTY, "same-price invest ok");
        vm.stopPrank();
    }

    function testInitGood_metagood_investByNormalUser() public {
        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 100 * 10 ** 6, false);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();

        S_GoodTmpState memory before = market.getGoodState(metaGoodId);
        uint128 investQty = 100 * 10 ** 6;

        market.investGood(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            users[1]
        );
        snapLastCall("investGood_metagood_normalUser");

        S_GoodTmpState memory after_ = market.getGoodState(metaGoodId);
        assertGt(
            after_.currentState.amount1(),
            before.currentState.amount1(),
            "metagood pool grew"
        );
        vm.stopPrank();
    }
}
