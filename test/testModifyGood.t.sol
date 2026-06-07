// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Integration tests for `modifyGoodByGoodOwner`, `modifyGoodByManager`,
///         and `modifyGoodByAdmin` (I_TTSwap_Market.sol L278-314).
contract testModifyGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal constant INITIAL_CONFIG =
        0x000c350810450000000000842882040800000000000000000000000000000000;

    uint256 internal constant ADMIN_MASK =
        0xff80000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant MANAGER_MASK =
        0x0fffffffffffffff800000000000000000000000000000000000000000000000;
    uint256 internal constant OWNER_MASK =
        0x00000000000000000000007fffffffff00000000000000000000000000000000;

    uint256 internal constant LIQUID_SHIFT = 241;
    uint256 internal constant OPERATOR_SHIFT = 237;
    uint256 internal constant GATE_SHIFT = 234;
    uint256 internal constant REFER_SHIFT = 229;
    uint256 internal constant CUSTOMER_SHIFT = 224;
    uint256 internal constant PLATFORM_SHIFT = 219;
    uint256 internal constant POWER_SHIFT = 162;
    uint256 internal constant BUY_FEE_SHIFT = 135;
    uint256 internal constant SELL_FEE_SHIFT = 128;

    uint256 internal btcGoodId;
    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(63000 * 10 ** 12);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        btcGoodId = _initBtcGood(users[1]);
        _verifyBtcGood();
    }

    function _verifyBtcGood() internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(btcGoodId).goodConfig.setVerified(true);
        market.modifyGoodByManager(btcGoodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _pack(uint256 value, uint256 shift) internal pure returns (uint256) {
        return value << shift;
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

    function _validFeeSplit() internal pure returns (uint256) {
        return
            _pack(6, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
    }

    function _invalidFeeSplit() internal pure returns (uint256) {
        return
            _pack(5, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
    }

    function _currentConfig() internal view returns (uint256) {
        return market.getGoodState(btcGoodId).goodConfig;
    }

    function _assertRegionUnchanged(
        uint256 before_,
        uint256 after_,
        uint256 changedMask
    ) internal pure {
        assertEq(after_ & ~changedMask, before_ & ~changedMask, "other region preserved");
    }

    // ── modifyGoodByGoodOwner ──────────────────────────────────────────────

    function test_modifyGoodByGoodOwner_updateTradingFees() public {
        vm.startPrank(users[1]);
        uint256 before_ = _currentConfig();
        uint256 patch = _pack(16, BUY_FEE_SHIFT) | _pack(20, SELL_FEE_SHIFT);

        bool ok = market.modifyGoodByGoodOwner(
            btcGoodId,
            patch,
            users[1],
            defaultdata
        );
        snapLastCall("modifyGoodByGoodOwner_fees");

        assertTrue(ok, "returns true");
        uint256 after_ = _currentConfig();
        assertEq(after_.getBuyFee(10_000), 16, "buy fee updated");
        assertEq(after_.getSellFee(10_000), 20, "sell fee updated");
        _assertRegionUnchanged(before_, after_, OWNER_MASK);
        assertEq(after_.getLiquidFee(10_000), before_.getLiquidFee(10_000), "manager fee unchanged");
        vm.stopPrank();
    }

    function test_modifyGoodByGoodOwner_updatePowerWithinLimit() public {
        vm.startPrank(users[1]);
        uint256 before_ = _currentConfig();
        uint256 patch = _pack(1, POWER_SHIFT);

        market.modifyGoodByGoodOwner(btcGoodId, patch, users[1], defaultdata);

        uint256 after_ = _currentConfig();
        assertEq(after_.getPower(), 100, "power still 100x");
        _assertRegionUnchanged(before_, after_, OWNER_MASK);
        vm.stopPrank();
    }

    function test_modifyGoodByGoodOwner_revert_notOwner() public {
        vm.startPrank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 20));
        market.modifyGoodByGoodOwner(
            btcGoodId,
            _pack(16, BUY_FEE_SHIFT),
            users[2],
            defaultdata
        );
        vm.stopPrank();
    }

    function test_modifyGoodByGoodOwner_revert_traderMismatch() public {
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.modifyGoodByGoodOwner(
            btcGoodId,
            _pack(16, BUY_FEE_SHIFT),
            users[2],
            defaultdata
        );
        vm.stopPrank();
    }

    function test_modifyGoodByGoodOwner_revert_powerExceedsLimit() public {
        vm.startPrank(users[1]);
        uint256 patch = _pack(15, POWER_SHIFT);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 23));
        market.modifyGoodByGoodOwner(btcGoodId, patch, users[1], defaultdata);
        vm.stopPrank();
    }

    function test_modifyGoodByGoodOwner_managerCannotCall() public {
        vm.startPrank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 20));
        market.modifyGoodByGoodOwner(
            btcGoodId,
            _pack(16, BUY_FEE_SHIFT),
            marketcreator,
            defaultdata
        );
        vm.stopPrank();
    }

    // ── modifyGoodByManager ────────────────────────────────────────────────

    function test_modifyGoodByManager_setVerified() public {
        vm.startPrank(marketcreator);
        uint256 before_ = _currentConfig();
        uint256 patch = before_.setVerified(true);

        bool ok = market.modifyGoodByManager(
            btcGoodId,
            patch,
            marketcreator,
            defaultdata
        );
        snapLastCall("modifyGoodByManager_verified");

        assertTrue(ok, "returns true");
        uint256 after_ = _currentConfig();
        assertTrue(after_.isVerified(), "verified flag set");
        _assertRegionUnchanged(before_, after_, MANAGER_MASK);
        assertEq(after_.getBuyFee(10_000), before_.getBuyFee(10_000), "owner fee unchanged");
        vm.stopPrank();
    }

    function test_modifyGoodByManager_updateFeeSplit() public {
        vm.startPrank(marketcreator);
        uint256 before_ = _currentConfig();
        uint256 patch = _validFeeSplit() |
            before_.setVerified(true).setPromised(true);

        market.modifyGoodByManager(btcGoodId, patch, marketcreator, defaultdata);

        uint256 after_ = _currentConfig();
        assertTrue(after_.checkGoodConfig(), "valid fee split");
        assertTrue(after_.isVerified(), "verified");
        assertTrue(after_.isPromised(), "promised");
        assertEq(after_.getLiquidFee(10_000), 6000, "liquid fee from new split");
        _assertRegionUnchanged(before_, after_, MANAGER_MASK);
        vm.stopPrank();
    }

    function test_modifyGoodByManager_revert_notManager() public {
        uint256 patch = _currentConfig().setVerified(true);
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 2));
        market.modifyGoodByManager(btcGoodId, patch, users[1], defaultdata);
        vm.stopPrank();
    }

    function test_modifyGoodByManager_revert_invalidConfig() public {
        vm.startPrank(marketcreator);
        uint256 patch = _invalidFeeSplit();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 24));
        market.modifyGoodByManager(btcGoodId, patch, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function test_modifyGoodByManager_revert_traderMismatch() public {
        uint256 patch = _currentConfig().setVerified(true);
        vm.startPrank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.modifyGoodByManager(btcGoodId, patch, users[1], defaultdata);
        vm.stopPrank();
    }

    // ── modifyGoodByAdmin ──────────────────────────────────────────────────

    function test_modifyGoodByAdmin_setValueGood() public {
        vm.startPrank(marketcreator);
        uint256 before_ = _currentConfig();
        uint256 patch = (1 << 255);

        bool ok = market.modifyGoodByAdmin(
            btcGoodId,
            patch,
            marketcreator,
            defaultdata
        );
        snapLastCall("modifyGoodByAdmin_valueGood");

        assertTrue(ok, "returns true");
        uint256 after_ = _currentConfig();
        assertTrue(after_.isvaluegood(), "marked as value good");
        _assertRegionUnchanged(before_, after_, ADMIN_MASK);
        assertEq(after_.getBuyFee(10_000), before_.getBuyFee(10_000), "owner fee unchanged");
        vm.stopPrank();
    }

    function test_modifyGoodByAdmin_setErcType() public {
        vm.startPrank(marketcreator);
        uint256 before_ = _currentConfig();
        uint256 patch = _pack(3, 247);

        market.modifyGoodByAdmin(btcGoodId, patch, marketcreator, defaultdata);

        uint256 after_ = _currentConfig();
        _assertRegionUnchanged(before_, after_, ADMIN_MASK);
        assertFalse(after_.isvaluegood(), "still normal good");
        vm.stopPrank();
    }

    function test_modifyGoodByAdmin_revert_notAdmin() public {
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market.modifyGoodByAdmin(
            btcGoodId,
            (1 << 255),
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    function test_modifyGoodByAdmin_revert_traderMismatch() public {
        vm.startPrank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.modifyGoodByAdmin(
            btcGoodId,
            (1 << 255),
            users[1],
            defaultdata
        );
        vm.stopPrank();
    }

    // ── cross-role isolation ───────────────────────────────────────────────

    function test_modifyGood_emitsCorrectEvents() public {
        bytes32 updateTopic = keccak256(
            "e_updateGoodConfig(uint256,uint256,address)"
        );
        bytes32 modifyTopic = keccak256(
            "e_modifyGoodConfig(uint256,uint256,address)"
        );

        vm.startPrank(users[1]);
        vm.recordLogs();
        market.modifyGoodByGoodOwner(
            btcGoodId,
            _pack(10, BUY_FEE_SHIFT),
            users[1],
            defaultdata
        );
        Vm.Log[] memory ownerLogs = vm.getRecordedLogs();
        assertEq(ownerLogs[ownerLogs.length - 1].topics[0], updateTopic);
        assertEq(uint256(ownerLogs[ownerLogs.length - 1].topics[1]), btcGoodId);
        vm.stopPrank();

        vm.startPrank(marketcreator);
        vm.recordLogs();
        market.modifyGoodByManager(
            btcGoodId,
            _currentConfig().setVerified(true),
            marketcreator,
            defaultdata
        );
        Vm.Log[] memory managerLogs = vm.getRecordedLogs();
        assertEq(managerLogs[managerLogs.length - 1].topics[0], modifyTopic);
        vm.stopPrank();

        vm.startPrank(marketcreator);
        vm.recordLogs();
        market.modifyGoodByAdmin(btcGoodId, (1 << 255), marketcreator, defaultdata);
        Vm.Log[] memory adminLogs = vm.getRecordedLogs();
        assertEq(adminLogs[adminLogs.length - 1].topics[0], modifyTopic);
        vm.stopPrank();
    }

    function test_modifyGood_roleIsolation() public {
        uint256 base = _currentConfig();

        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(btcGoodId, (1 << 255), marketcreator, defaultdata);
        uint256 afterAdmin = _currentConfig();
        vm.stopPrank();

        vm.startPrank(marketcreator);
        market.modifyGoodByManager(
            btcGoodId,
            afterAdmin.setVerified(true),
            marketcreator,
            defaultdata
        );
        vm.stopPrank();

        vm.startPrank(users[1]);
        market.modifyGoodByGoodOwner(
            btcGoodId,
            _pack(32, BUY_FEE_SHIFT),
            users[1],
            defaultdata
        );
        uint256 afterOwner = _currentConfig();
        vm.stopPrank();

        assertTrue(afterOwner.isvaluegood(), "admin bit kept");
        assertTrue(afterOwner.isVerified(), "manager bit kept");
        assertEq(afterOwner.getBuyFee(10_000), 32, "owner bit applied");
        assertEq(afterOwner.getLiquidFee(10_000), base.getLiquidFee(10_000), "default liquid fee kept");
    }

    function test_modifyGood_ownerCannotChangeManagerFlags() public {
        vm.startPrank(users[1]);
        uint256 before_ = _currentConfig();
        uint256 patch = _pack(1, 246);
        market.modifyGoodByGoodOwner(btcGoodId, patch, users[1], defaultdata);
        uint256 after_ = _currentConfig();
        assertFalse(after_.isFreeze(), "freeze bit not writable by owner");
        _assertRegionUnchanged(before_, after_, OWNER_MASK);
        vm.stopPrank();
    }

    function test_modifyGood_managerCannotChangeAdminFlags() public {
        vm.startPrank(marketcreator);
        uint256 before_ = _currentConfig();
        market.modifyGoodByManager(
            btcGoodId,
            (1 << 255) | _validFeeSplit(),
            marketcreator,
            defaultdata
        );
        uint256 after_ = _currentConfig();
        assertFalse(after_.isvaluegood(), "value-good bit not writable by manager");
        _assertRegionUnchanged(before_, after_, MANAGER_MASK);
        vm.stopPrank();
    }

    // ── lockGood / changeGoodOwner (TASK-P1-001 ~ P1-004) ───────────────────

    function testLockGood_byManager() public {
        vm.prank(marketcreator);
        market.lockGood(btcGoodId, marketcreator, defaultdata);

        assertTrue(_currentConfig().isFreeze(), "good frozen");
        vm.startPrank(users[2]);
        deal(address(btc), users[2], BTC_QTY, false);
        btc.approve(address(market), BTC_QTY / 10);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_QTY / 10),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();
    }

    function testLockGood_byOwner() public {
        vm.prank(users[1]);
        market.lockGood(btcGoodId, users[1], defaultdata);
        assertTrue(_currentConfig().isFreeze(), "owner locked good");
    }

    function testLockGood_revert_notAuthorized() public {
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 20));
        market.lockGood(btcGoodId, users[2], defaultdata);
    }

    function testChangeGoodOwner_happyPath() public {
        vm.prank(marketcreator);
        market.changeGoodOwner(btcGoodId, users[2], marketcreator, defaultdata);

        S_GoodTmpState memory state = market.getGoodState(btcGoodId);
        assertEq(state.owner, users[2], "owner transferred");

        vm.startPrank(users[2]);
        uint256 cfg = state.goodConfig;
        market.modifyGoodByGoodOwner(btcGoodId, cfg, users[2], defaultdata);
        vm.stopPrank();
    }
}
