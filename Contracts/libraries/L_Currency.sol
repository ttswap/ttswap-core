// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title L_CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library L_CurrencyLibrary {
    using L_CurrencyLibrary for address;

    using L_CurrencyLibrary for uint256;
    /// @notice Thrown when a native transfer fails

    error NativeTransferFailed();

    error ValueToBiggerthanUint128();
    /// @notice Thrown when an ERC20 transfer fails
    error ERC20TransferFailed();

    address public constant NATIVE = address(0);

    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success;
        if (token.isNative()) {
            assembly {
                // Transfer the ETH and store if it succeeded or not.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }

            if (!success) revert NativeTransferFailed();
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                // Get a pointer to some free memory.
                let freeMemoryPointer := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
                mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
                mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

                success :=
                    and(
                        // Set success to whether the call reverted, if not we check it either
                        // returned exactly 1 (can't just be non-zero data), or had no return data.
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                        // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                        // Counterintuitively, this call must be positioned second to the or() call in the
                        // surrounding and() call or else returndatasize() will be zero during the computation.
                        call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
                    )
            }
        }
        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(address currency, address to, uint256 amount) internal {
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
                mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(4, to) // Append the "to" argument.
                mstore(36, amount) // Append the "amount" argument.

                success :=
                    and(
                        // Set success to whether the call reverted, if not we check it either
                        // returned exactly 1 (can't just be non-zero data), or had no return data.
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
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

    function transferFrom(address token, address from, uint256 value) internal returns (uint128 resultvalue) {
        if (token.isNative()) {
            if (msg.value != value) revert NativeTransferFailed();
            value = msg.value;
        } else {
            (bool success, bytes memory data) = address(token).call(
                abi.encodeWithSelector(IERC20(token).transferFrom.selector, from, address(this), value)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "STF");
        }
        resultvalue = value.safe_uint128();
    }

    function isNative(address currency) internal pure returns (bool) {
        return currency == address(0);
    }

    function safe_uint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert ValueToBiggerthanUint128();
        } else {
            return uint128(value);
        }
    }
}
