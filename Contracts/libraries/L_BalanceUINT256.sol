// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

type T_BalanceUINT256 is uint256;

using {add as +, sub as -} for T_BalanceUINT256 global;
using L_BalanceUINT256Library for T_BalanceUINT256 global;

function toBalanceUINT256(uint128 _amount0, uint128 _amount1) pure returns (T_BalanceUINT256 balanceDelta) {
    /// @solidity memory-safe-assembly
    assembly {
        balanceDelta :=
            or(shl(128, _amount0), and(0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, _amount1))
    }
}

function add(T_BalanceUINT256 a, T_BalanceUINT256 b) pure returns (T_BalanceUINT256) {
    return toBalanceUINT256(a.amount0() + b.amount0(), a.amount1() + b.amount1());
}

function sub(T_BalanceUINT256 a, T_BalanceUINT256 b) pure returns (T_BalanceUINT256) {
    return toBalanceUINT256(a.amount0() - b.amount0(), a.amount1() - b.amount1());
}

function addsub(T_BalanceUINT256 a, T_BalanceUINT256 b) pure returns (T_BalanceUINT256) {
    return toBalanceUINT256(a.amount0() + b.amount0(), a.amount1() - b.amount1());
}

function subadd(T_BalanceUINT256 a, T_BalanceUINT256 b) pure returns (T_BalanceUINT256) {
    return toBalanceUINT256(a.amount0() - b.amount0(), a.amount1() + b.amount1());
}

function lowerprice(T_BalanceUINT256 a, T_BalanceUINT256 b, T_BalanceUINT256 c) pure returns (bool) {
    if (a.amount1() == 0 || b.amount0() == 0 || c.amount0() == 0) return false;
    require(a.amount0() * b.amount1() * c.amount1() <= type(uint256).max, "overflow");
    require(a.amount1() * b.amount0() * c.amount0() <= type(uint256).max, "overflow");
    return a.amount0() * b.amount1() * c.amount1() < a.amount1() * b.amount0() * c.amount0() ? true : false;
    //return uint256((a.amount0()*b.amount1())/(a.amount1()*b.amount0()));
}

library L_BalanceUINT256Library {
    function amount0(T_BalanceUINT256 balanceDelta) internal pure returns (uint128 _amount0) {
        /// @solidity memory-safe-assembly
        assembly {
            _amount0 := shr(128, balanceDelta)
        }
    }

    function amount1(T_BalanceUINT256 balanceDelta) internal pure returns (uint128 _amount1) {
        /// @solidity memory-safe-assembly
        assembly {
            _amount1 := balanceDelta
        }
    }

    function getamount0fromamount1(T_BalanceUINT256 balanceDelta, uint128 amount1delta)
        internal
        pure
        returns (uint128 _amount0)
    {
        if (balanceDelta.amount1() == 0) return 0;
        uint256 result = (uint256(balanceDelta.amount0()) * uint256(amount1delta)) / uint256(balanceDelta.amount1());
        return uint128(result <= type(uint128).max ? result : 0);
    }

    function getamount1fromamount0(T_BalanceUINT256 balanceDelta, uint128 amount0delta)
        internal
        pure
        returns (uint128 _amount1)
    {
        if (balanceDelta.amount0() == 0) return 0;
        uint256 result = (uint256(balanceDelta.amount1()) * uint256(amount0delta)) / uint256(balanceDelta.amount0());
        return uint128(result <= type(uint128).max ? result : 0);
    }
}
