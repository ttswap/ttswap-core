// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {L_CurrencyLibrary} from "../libraries/L_Currency.sol";
import {L_Transient} from "../libraries/L_Transient.sol";

/// @dev Public wrapper for `L_CurrencyLibrary` unit tests.
contract CurrencyHarness {
    using L_CurrencyLibrary for address;

    function balanceOf(address token, address who) external view returns (uint256) {
        return token.balanceof(who);
    }

    function pullErc20(
        address token,
        address from,
        uint256 amount,
        bytes calldata detail
    ) external {
        address t = token;
        t.transferFrom(from, from, amount, detail);
    }

    function pullErc20Executor(
        address token,
        address from,
        address executor,
        uint256 amount,
        bytes calldata detail
    ) external {
        address t = token;
        t.transferFrom(from, executor, amount, detail);
    }

    function pushErc20(address token, address to, uint256 amount) external {
        address t = token;
        t.safeTransfer(to, amount);
    }

    function pushNative(address to, uint256 amount) external {
        address(1).safeTransfer(to, amount);
    }

    function seedNative(uint256 amount) external payable {
        L_Transient.increaseValue(amount);
    }

    function pullNative(
        address from,
        uint256 amount,
        bytes calldata detail
    ) external payable {
        L_Transient.increaseValue(msg.value);
        address t = address(1);
        t.transferFrom(from, msg.sender, amount, detail);
    }

    function pullErc20To(
        address token,
        address from,
        address to,
        address executor,
        uint256 amount,
        bytes calldata detail
    ) external {
        address t = token;
        t.transferFrom(from, to, executor, amount, detail);
    }

    function isNative(address token) external pure returns (bool) {
        return token.isNative();
    }

    function toUint160(uint256 amount) external pure returns (uint160) {
        return L_CurrencyLibrary.to_uint160(amount);
    }
}
