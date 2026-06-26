// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {
    toTTSwapUINT256,
    add,
    sub,
    addsub,
    subadd,
    lowerprice,
    toUint128,
    TTSwapUINT256AddOverflow,
    TTSwapUINT256SubOverflow,
    TTSwapUINT256AddSubOverflow,
    TTSwapUINT256SubAddOverflow,
    TTSwapUINT256ToUint128Overflow,
    L_TTSwapUINT256Library
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice P3-03: packed uint256 math boundaries.
contract testL_TTSwapUINT256 is Test {
    using L_TTSwapUINT256Library for uint256;

    function testAdd_happyPath() public pure {
        uint256 a = toTTSwapUINT256(100, 200);
        uint256 b = toTTSwapUINT256(50, 75);
        uint256 c = add(a, b);
        assertEq(c.amount0(), 150);
        assertEq(c.amount1(), 275);
    }

    function testAdd_revert_overflow() public {
        uint256 a = toTTSwapUINT256(type(uint128).max, type(uint128).max);
        vm.expectRevert(TTSwapUINT256AddOverflow.selector);
        this._add(a, toTTSwapUINT256(1, 0));
    }

    function testSub_happyPath() public pure {
        uint256 a = toTTSwapUINT256(100, 200);
        uint256 b = toTTSwapUINT256(40, 50);
        uint256 c = sub(a, b);
        assertEq(c.amount0(), 60);
        assertEq(c.amount1(), 150);
    }

    function testSub_revert_underflow() public {
        vm.expectRevert(TTSwapUINT256SubOverflow.selector);
        this._sub(toTTSwapUINT256(10, 10), toTTSwapUINT256(11, 0));
    }

    function testAddsub_revert_underflowOnAmount1() public {
        vm.expectRevert(TTSwapUINT256AddSubOverflow.selector);
        this._addsub(toTTSwapUINT256(100, 50), toTTSwapUINT256(10, 60));
    }

    function testSubadd_revert_underflowOnAmount0() public {
        vm.expectRevert(TTSwapUINT256SubAddOverflow.selector);
        this._subadd(toTTSwapUINT256(10, 100), toTTSwapUINT256(20, 0));
    }

    function testGetamount0fromamount1_rounding() public pure {
        uint256 ratio = toTTSwapUINT256(300, 100);
        assertEq(ratio.getamount0fromamount1(50), 150);
    }

    function testGetamount1fromamount0_rounding() public pure {
        uint256 ratio = toTTSwapUINT256(200, 400);
        assertEq(ratio.getamount1fromamount0(100), 200);
    }

    function testLowerprice_compareSides() public pure {
        uint256 a = toTTSwapUINT256(2, 3);
        uint256 b = toTTSwapUINT256(4, 5);
        uint256 c = toTTSwapUINT256(6, 7);
        assertTrue(lowerprice(a, b, c) != lowerprice(b, a, c), "order matters");
    }

    function testToUint128_revert_overflow() public {
        vm.expectRevert(TTSwapUINT256ToUint128Overflow.selector);
        this._toUint128(uint256(type(uint128).max) + 1);
    }

    function _add(uint256 a, uint256 b) external pure returns (uint256) {
        return add(a, b);
    }

    function _sub(uint256 a, uint256 b) external pure returns (uint256) {
        return sub(a, b);
    }

    function _addsub(uint256 a, uint256 b) external pure returns (uint256) {
        return addsub(a, b);
    }

    function _subadd(uint256 a, uint256 b) external pure returns (uint256) {
        return subadd(a, b);
    }

    function _toUint128(uint256 a) external pure returns (uint128) {
        return toUint128(a);
    }
}
