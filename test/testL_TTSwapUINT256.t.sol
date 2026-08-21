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
    TTSwapUINT256NotValid,
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

    function testToUint128_happyPath() public pure {
        assertEq(toUint128(99), 99);
    }

    function testAddsub_happyPath() public pure {
        uint256 c = addsub(toTTSwapUINT256(100, 80), toTTSwapUINT256(10, 30));
        assertEq(c.amount0(), 110);
        assertEq(c.amount1(), 50);
    }

    function testSubadd_happyPath() public pure {
        uint256 c = subadd(toTTSwapUINT256(100, 80), toTTSwapUINT256(10, 30));
        assertEq(c.amount0(), 90);
        assertEq(c.amount1(), 110);
    }

    function testAmount01_andGet64bit() public pure {
        uint256 packed = toTTSwapUINT256(7, 9);
        (uint128 a0, uint128 a1) = packed.amount01();
        assertEq(a0, 7);
        assertEq(a1, 9);
        assertEq(packed.get64bit(), uint64(9));
    }

    function testCheckUint256Valid() public {
        uint256 ok = toTTSwapUINT256(1, 10_000);
        ok.checkUint256Valid();

        vm.expectRevert(TTSwapUINT256NotValid.selector);
        this._check(toTTSwapUINT256(1, 9_999));

        vm.expectRevert(TTSwapUINT256NotValid.selector);
        this._check(toTTSwapUINT256(1, uint128(uint256(2 ** 109) + 1)));
    }

    function testMulDiv_revert_divZero() public {
        vm.expectRevert();
        this._get0(toTTSwapUINT256(100, 0), 10);
    }

    function _check(uint256 a) external pure {
        a.checkUint256Valid();
    }

    function _get0(uint256 ratio, uint128 amt) external pure returns (uint128) {
        return ratio.getamount0fromamount1(amt);
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
