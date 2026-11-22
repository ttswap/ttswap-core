// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Issue #321: the run-block anti-replay guard compared only the
/// stored slot `block.number % 4095`, so a good's FIRST touch in a block
/// congruent (mod 4095) to its last touch reverted TTSwapError(46) — a
/// protocol-wide, predictable one-block liveness outage every 4095 blocks.
/// Fix: also store a run epoch `(block.number / 4095) % 4096` in the
/// previously-reserved config bits 184-173, so only a true same-block
/// retouch reverts.
contract RunBlockEpoch is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_GoodConfigLibrary for uint256;

    uint256 internal usdtGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _initUsdtGood(address owner) internal returns (uint256) {
        vm.startPrank(owner);
        usdt.mint(owner, 1_000_000); // 1e12 raw
        usdt.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _usdtKey();
        market.initGood(
            key,
            toTTSwapUINT256(uint128(1e15), uint128(1e9)),
            defaultdata,
            owner,
            defaultdata
        );
        vm.stopPrank();
        return key.toId();
    }

    function _passThrough(address trader, uint128 qty) internal {
        market.payGood(
            _usdtKey(),
            _usdtKey(),
            toTTSwapUINT256(qty, qty),
            trader,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    /// @dev initGood at block 1 stores slot 1 / epoch 0. A second touch in
    /// the SAME block must still revert (anti-replay preserved), a touch at
    /// block 2 works, and the first touch at block 4097 — same slot (2) as
    /// the block-2 touch but a different epoch — must also work.
    function test_runBlock_epochDistinguishesSameSlot() public {
        address trader = users[3];
        vm.startPrank(trader);
        usdt.mint(trader, 1_000); // 1e9 raw
        usdt.approve(address(market), type(uint256).max);

        // First touch at block 1 (initGood does not write the slot): succeeds,
        // stores slot 1 / epoch 0.
        _passThrough(trader, uint128(1e6));
        uint256 cfg = market.getGoodState(usdtGoodId).goodConfig;
        assertEq(cfg.getRunBlockConfig(), 1);
        assertEq(cfg.getRunEpochConfig(), 0);

        // Second touch in the SAME block must still revert (anti-replay).
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        _passThrough(trader, uint128(1e6));

        // Next block: fresh slot, succeeds and stores slot 2 / epoch 0.
        vm.roll(2);
        vm.warp(10);
        _passThrough(trader, uint128(1e6));
        cfg = market.getGoodState(usdtGoodId).goodConfig;
        assertEq(cfg.getRunBlockConfig(), 2);
        assertEq(cfg.getRunEpochConfig(), 0);

        // Block 4097: slot 4097 % 4095 == 2 (collision with stored slot),
        // epoch 4097 / 4095 == 1 (different). Pre-fix this reverted 46.
        vm.roll(4097);
        vm.warp(20);
        _passThrough(trader, uint128(1e6));
        cfg = market.getGoodState(usdtGoodId).goodConfig;
        assertEq(cfg.getRunBlockConfig(), 2);
        assertEq(cfg.getRunEpochConfig(), 1);
        vm.stopPrank();
    }

    /// @dev A never-touched-since-upgrade good (epoch bits still 0) keeps
    /// working across a slot collision once the epoch advances.
    function test_runBlock_firstTouchAfterUpgrade() public {
        // Fresh good initialized directly at block 4096 (slot 1, epoch 1).
        vm.roll(4096);
        vm.warp(30);
        uint256 goodId = _initEthGood(marketcreator);

        address trader = users[4];
        vm.startPrank(trader);
        eth.mint(trader, 1_000);
        eth.approve(address(market), type(uint256).max);

        // Block 8191: slot 8191 % 4095 == 1 (same as init), epoch 2.
        vm.roll(8191);
        vm.warp(40);
        T_GoodKey memory key = _ethKey();
        market.payGood(
            key,
            key,
            toTTSwapUINT256(uint128(1e6), uint128(1e6)),
            trader,
            defaultdata,
            trader,
            defaultdata,
            0
        );
        vm.stopPrank();
        assertTrue(goodId != 0);
    }

    function _ethKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(eth), id: 0});
    }

    /// @dev Second good needs a distinct token; use `eth` (MyToken) so
    /// `toId()` differs from the usdt good.
    function _initEthGood(address owner) internal returns (uint256) {
        vm.startPrank(owner);
        eth.mint(owner, 1_000_000);
        eth.approve(address(market), type(uint256).max);
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(eth),
            id: 0
        });
        market.initGood(
            key,
            toTTSwapUINT256(uint128(1e15), uint128(1e9)),
            defaultdata,
            owner,
            defaultdata
        );
        vm.stopPrank();
        return key.toId();
    }
}
