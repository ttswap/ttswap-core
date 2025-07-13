// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {IERC20Permit} from "../interfaces/IERC20Permit.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IDAIPermit} from "../interfaces/IDAIPermit.sol";
import {L_Transient} from "./L_Transient.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";

address constant NATIVE = address(1);
address constant SETH = address(2);
address constant SWETH = address(3);
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant _permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

/// @title L_CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library L_CurrencyLibrary {
    using L_CurrencyLibrary for address;

    struct S_Permit {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct S_Permit2 {
        uint256 value;
        uint256 deadline;
        uint256 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    bytes constant defualtvalue = bytes("");

    struct S_transferData {
        uint8 transfertype;
        bytes sigdata;
    }

    /// @notice Thrown when an ERC20 transfer fails
    error NativeETHTransferFailed();
    /// @notice Thrown when an ERC20 transfer fails
    error ERC20TransferFailed();
    /// @notice Thrown when an ERC20Permit transfer fails
    error ERC20PermitFailed();

    error ApproveFailed();

    function balanceof(address token, address _sender) internal view returns (uint256 amount) {
        if (token.isNative()) {
            amount = address(_sender).balance;
        } else if (token.isWETH()) {
            amount = IERC20(WETH).balanceOf(_sender);
        } else {
            amount = IERC20(token).balanceOf(_sender);
        }
    }

    function transferFrom(address token, address from, address to, uint256 amount, bytes calldata detail) internal {
        bool success;
        if (token.isNative()) {
            L_Transient.decreaseValue(amount);
        } else if (token.isWETH()) {
            transferFromInter(WETH, from, to, amount);
        } else if (detail.length == 0) {
            transferFromInter(token, from, to, amount);
        } else {
            S_transferData memory _simplePermit = abi.decode(detail, (S_transferData));
            if (_simplePermit.transfertype == 2) {
                S_Permit memory _permit = abi.decode(_simplePermit.sigdata, (S_Permit));
                bytes memory inputdata = token == dai
                    ? abi.encodeCall(
                        IDAIPermit.permit,
                        (
                            from,
                            address(this),
                            IDAIPermit(token).nonces(from),
                            _permit.deadline,
                            true,
                            _permit.v,
                            _permit.r,
                            _permit.s
                        )
                    )
                    : abi.encodeCall(
                        IERC20Permit.permit,
                        (from, address(this), _permit.value, _permit.deadline, _permit.v, _permit.r, _permit.s)
                    );

                assembly {
                    success := call(gas(), token, 0, add(inputdata, 32), mload(inputdata), 0, 0)
                }
                if (success) {
                    transferFromInter(token, from, to, amount);
                } else {
                    revert ERC20PermitFailed();
                }
            } else if (_simplePermit.transfertype == 3) {
                IAllowanceTransfer(_permit2).transferFrom(from, to, to_uint160(amount), token);
            } else if (_simplePermit.transfertype == 4) {
                S_Permit2 memory _permit = abi.decode(_simplePermit.sigdata, (S_Permit2));
                IAllowanceTransfer(_permit2).permit(
                    from,
                    IAllowanceTransfer.PermitSingle({
                        details: IAllowanceTransfer.PermitDetails({
                            token: token,
                            amount: to_uint160(_permit.value),
                            // Use an unlimited expiration because it most
                            // closely mimics how a standard approval works.
                            expiration: type(uint48).max,
                            nonce: uint48(_permit.nonce)
                        }),
                        spender: address(this),
                        sigDeadline: _permit.deadline
                    }),
                    bytes.concat(_permit.r, _permit.s, bytes1(_permit.v))
                );

                IAllowanceTransfer(_permit2).transferFrom(from, to, to_uint160(amount), token);
            } else if (_simplePermit.transfertype == 5) {
                S_Permit2 memory _permit = abi.decode(_simplePermit.sigdata, (S_Permit2));
                ISignatureTransfer(_permit2).permitTransferFrom(
                    ISignatureTransfer.PermitTransferFrom({
                        permitted: ISignatureTransfer.TokenPermissions({token: token, amount: _permit.value}),
                        nonce: _permit.nonce,
                        deadline: _permit.deadline
                    }),
                    ISignatureTransfer.SignatureTransferDetails({to: to, requestedAmount: amount}),
                    from,
                    bytes.concat(_permit.r, _permit.s, bytes1(_permit.v))
                );
            }
        }
    }

    function transferFrom(address token, address from, address to, uint256 amount) internal {
        if (token.isNative()) {
            L_Transient.decreaseValue(amount);
        } else if (token.isWETH()) {
            transferFromInter(WETH, from, to, amount);
        } else {
            transferFromInter(token, from, to, amount);
        }
    }

    function transferFromInter(address token, address from, address to, uint256 amount) internal {
        bool success;

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
        if (!success) revert ERC20TransferFailed();
    }

    function transferFrom(address token, address from, uint256 amount, bytes calldata trandata) internal {
        address to = address(this);
        transferFrom(token, from, to, uint128(amount), trandata);
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
            if (!success) revert NativeETHTransferFailed();
        } else if (currency == SWETH) {
            safeTransfer(WETH, to, amount);
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

    function isNative(address currency) internal pure returns (bool) {
        return currency == address(1) || currency == SETH;
    }

    function isWETH(address currency) internal pure returns (bool) {
        return currency == SWETH;
    }

    function to_uint160(uint256 amount) internal pure returns (uint160) {
        return amount == uint160(amount) ? uint160(amount) : 0;
    }

    function to_uint256(address amount) internal pure returns (uint256 a) {
        return uint256(uint160(amount));
    }

    function canRestake(address token) internal pure returns (bool a) {
        return token == SWETH || token == SETH;
    }

    function approve(address token, address to, uint128 amount) internal {
        if (token == SWETH) {
            if (!IERC20(WETH).approve(to, uint256(amount))) {
                revert ApproveFailed();
            }
        } else {
            if (!IERC20(token).approve(to, uint256(amount))) {
                revert ApproveFailed();
            }
        }
    }
}
