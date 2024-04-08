// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20Minimal} from "../interfaces/IERC20Minimal.sol";

/// @title L_CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library L_CurrencyLibrary {
    using L_CurrencyLibrary for address;

    /// @notice Thrown when a native transfer fails
    error NativeTransferFailed();

    /// @notice Thrown when an ERC20 transfer fails
    error ERC20TransferFailed();

    address public constant NATIVE = address(0);

    function approve(address currency, uint256 amount) internal {
        IERC20Minimal(currency).approve(address(this), amount);
    }

    function decimals(address currency) internal view returns (uint8) {
        return IERC20Minimal(currency).decimals();
    }

    function totalSupply(address currency) internal view returns (uint256) {
        return IERC20Minimal(currency).totalSupply();
    }

    function transferFrom(
        address currency,
        address from,
        uint256 amount
    ) internal {
        IERC20Minimal(currency).transferFrom(from, address(this), amount);
    }

    function transfer(address currency, address to, uint256 amount) internal {
        // implementation from
        // https://github.com/transmissions11/solmate/blob/e8f96f25d48fe702117ce76c79228ca4f20206cb/src/utils/SafeTransferLib.sol

        bool success;
        if (currency.isNative()) {
            assembly {
                // Transfer the ETH and store if it succeeded or not.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }

            if (!success) revert NativeTransferFailed();
        } else {
            assembly {
                // We'll write our calldata to this slot below, but restore it later.
                let memPointer := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(
                    0,
                    0xa9059cbb00000000000000000000000000000000000000000000000000000000
                )
                mstore(4, to) // Append the "to" argument.
                mstore(36, amount) // Append the "amount" argument.

                success := and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    // We use 68 because that's the total length of our calldata (4 + 32 * 2)
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    call(gas(), currency, 0, 0, 68, 0, 32)
                )

                mstore(0x60, 0) // Restore the zero slot to zero.
                mstore(0x40, memPointer) // Restore the memPointer.
            }

            if (!success) revert ERC20TransferFailed();
        }
    }

    function balanceOfSelf(address currency) internal view returns (uint256) {
        if (currency.isNative()) {
            return address(this).balance;
        } else {
            return IERC20Minimal(currency).balanceOf(address(this));
        }
    }

    function balanceOf(
        address currency,
        address owner
    ) internal view returns (uint256) {
        if (currency.isNative()) {
            return owner.balance;
        } else {
            return IERC20Minimal(currency).balanceOf(owner);
        }
    }

    function isNative(address currency) internal pure returns (bool) {
        return currency == address(0);
    }
}