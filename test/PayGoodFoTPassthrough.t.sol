// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {FeeOnTransferToken} from "../src/test/FeeOnTransferToken.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Issue #329: same-good `payGood` is a pure pass-through — it pulls
/// `_swapQuantity.amount1()` via `transferFrom` then sends the same nominal
/// amount out via `safeTransfer`, with no balance-delta check. A fee-on-
/// transfer token delivers only (1 - fee) on the inbound leg while the
/// outbound leg pays full nominal, so the Market's token balance drops by
/// `fee * amount` per call and the pool can be drained.
contract PayGoodFoTPassthrough is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;

    FeeOnTransferToken internal fot;
    uint256 internal fotGoodId;

    uint128 internal constant FOT_INIT_QTY = uint128(1e12);
    uint128 internal constant FOT_INIT_VALUE = uint128(1e18);
    uint128 internal constant PASS_QTY = uint128(1e10);

    function setUp() public override {
        BaseSetup.setUp();
        fot = new FeeOnTransferToken(1000); // 10% fee
        vm.warp(0);

        // Victim LP initializes the good; the Market actually receives 90%.
        vm.startPrank(users[1]);
        fot.mint(users[1], FOT_INIT_QTY);
        fot.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _fotKey();
        market.initGood(
            key,
            toTTSwapUINT256(FOT_INIT_VALUE, FOT_INIT_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        fotGoodId = key.toId();
        vm.stopPrank();
    }

    function _fotKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(fot), id: 0});
    }

    function _passThrough(address trader, uint128 qty) internal {
        market.payGood(
            _fotKey(),
            _fotKey(),
            toTTSwapUINT256(qty, qty),
            trader,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    /// @dev Same-good pass-through must never decrease the Market's token
    /// balance: what arrives must cover what leaves.
    function testSameGoodPayGood_revertsOnFoTDrain() public {
        vm.startPrank(users[2]); // attacker
        fot.mint(users[2], 1e11);
        fot.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        uint256 marketBefore = fot.balanceOf(address(market));
        vm.expectRevert(); // TTSwapError(56) once fixed; succeeds pre-fix
        _passThrough(users[2], PASS_QTY);
        vm.stopPrank();

        assertEq(fot.balanceOf(address(market)), marketBefore, "no drain");
    }

    /// @dev Control: a non-fee token same-good pass-through still works and
    /// leaves the Market balance unchanged.
    function testSameGoodPayGood_normalTokenStillWorks() public {
        uint128 qty = uint128(1e6);
        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 1_000_000); // 1e12 raw (whole-token units)
        usdt.approve(address(market), type(uint256).max);
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        market.initGood(
            key,
            toTTSwapUINT256(1e15, 1e9),
            defaultdata,
            marketcreator,
            defaultdata
        );
        vm.stopPrank();

        address trader = users[3];
        vm.startPrank(trader);
        usdt.mint(trader, 1_000); // 1e9 raw
        usdt.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        uint256 marketBefore = usdt.balanceOf(address(market));
        uint256 traderBefore = usdt.balanceOf(trader);
        market.payGood(
            key,
            key,
            toTTSwapUINT256(qty, qty),
            trader,
            defaultdata,
            trader,
            defaultdata,
            0
        );
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(market)), marketBefore, "balance neutral");
        assertEq(usdt.balanceOf(trader), traderBefore, "pass-through nets zero");
    }
}
