// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression test for issue #332: the good owner can `lockGood`
///         (freeze) a pool but could not clear the freeze themselves —
///         bit 252 sits in the manager mask, so `modifyGoodByGoodOwner`
///         silently drops it and only the market manager could unfreeze.
///         `unlockGood` gives the owner (or manager) symmetric control.
contract UnlockGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal btcGoodId;

    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant BTC_INVEST = uint128(1 * 10 ** 7);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initBtcGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 20 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _frozen() internal view returns (bool) {
        return market.getGoodState(btcGoodId).goodConfig.isFreeze();
    }

    function _invest(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        vm.prank(trader);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function test_unlockGood_owner_clearsFreeze() public {
        // Owner freezes the pool.
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.lockGood(btcGoodId, users[1], defaultdata);
        assertTrue(_frozen(), "freeze bit set");

        // Frozen good rejects new investment (TTSwapError 10).
        deal(address(btc), users[2], 10 * BTC_INVEST, false);
        vm.startPrank(users[2]);
        btc.approve(address(market), BTC_INVEST);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();

        // Owner clears the freeze themselves — previously impossible.
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.unlockGood(btcGoodId, users[1], defaultdata);
        assertFalse(_frozen(), "freeze bit cleared");

        // Pool is live again: the previously-reverting invest now succeeds.
        _invest(users[2], BTC_INVEST);
    }

    function test_unlockGood_revert_notOwnerNotManager() public {
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.lockGood(btcGoodId, users[1], defaultdata);
        assertTrue(_frozen(), "freeze bit set");

        _warpToFreshRunSlot();
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 20));
        market.unlockGood(btcGoodId, users[2], defaultdata);
        assertTrue(_frozen(), "freeze bit still set");
    }

    function test_unlockGood_marketManager_canClear() public {
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.lockGood(btcGoodId, users[1], defaultdata);
        assertTrue(_frozen(), "freeze bit set");

        _warpToFreshRunSlot();
        vm.prank(marketcreator);
        market.unlockGood(btcGoodId, marketcreator, defaultdata);
        assertFalse(_frozen(), "manager cleared freeze");
    }

    function test_unlockGood_revert_traderMismatch() public {
        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.lockGood(btcGoodId, users[1], defaultdata);

        _warpToFreshRunSlot();
        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.unlockGood(btcGoodId, users[2], defaultdata);
    }
}
