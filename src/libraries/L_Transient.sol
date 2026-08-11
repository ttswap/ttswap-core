// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.29;

import {TTSwapError} from "./L_Error.sol";

/// @title L_Transient — per-transaction ETH budget and reentrancy lock
/// @notice Uses EIP-1153 transient storage (`tstore`/`tload`) so state does not persist across transactions.
/// @dev Three slots:
///      - `VALUE_SLOT`: remaining native ETH budget for this outer call tree
///      - `DEPTH_SLOT`: nesting depth of `msgValue`-wrapped calls
///      - `LOCK_SLOT`: reentrancy lock (0 = open, 1 = multicall batch, 2 = guarded function)
///
/// @dev **Native ETH accounting**
///      When the outermost `msgValue` call starts (`depth == 0`), `checkbefore` seeds `VALUE_SLOT` with `msg.value`.
///      Each native transfer via `T_GoodKey.transferFrom` calls `decreaseValue(amount)`.
///      At the end of the outermost call, `checkafter` refunds any leftover budget to `msg.sender`.
///      This lets one `msg.value` be split across multiple sub-operations without double-spending.
///
/// @dev **Multicall safety (C-01)**
///      `multicall` uses `multicallEntry` (lock 1) plus outer `msgValue` so subcalls do NOT re-arm
///      `VALUE_SLOT` from `msg.value` when depth returns to 0 inside the batch.
library L_Transient {
    /// @dev Transient slot for remaining native ETH budget.
    ///      `bytes32(uint256(keccak256("VALUE_SLOT")) - 1)`
    bytes32 constant VALUE_SLOT =
        0xcbe27d488af5b5c1b0bd8d89be6fdfeaed3ad42719044fd9b728f33df1d6f1d1;

    /// @dev Transient slot for `msgValue` call nesting depth.
    bytes32 constant DEPTH_SLOT =
        0x87b52c29898e62efc1f9a9b00a26dcbdaee98d728c56841703077b7c0d20dee7;

    /// @dev Transient slot for reentrancy lock level (see `TTSwap_Market.guardedEntry` / `multicallEntry`).
    bytes32 constant LOCK_SLOT =
        0xe2afc7ec4dbb9bfdb1b8e8bcf21a055747c25bf2faaea9cb5a134005381f4843;

    /// @notice Sets the reentrancy lock level.
    /// @param lock 0 = unlocked, 1 = multicall context, 2 = single guarded entry active.
    function set(uint256 lock) internal {
        assembly {
            tstore(LOCK_SLOT, lock)
        }
    }

    /// @notice Gets the current reentrancy lock level.
    /// @return lock The current lock level (0 / 1 / 2).
    function get() internal view returns (uint256 lock) {
        assembly {
            lock := tload(LOCK_SLOT)
        }
    }

    /// @notice Overwrites the transient native-ETH budget.
    function setValue(uint256 locker) internal {
        assembly {
            tstore(VALUE_SLOT, locker)
        }
    }

    /// @notice Reads the remaining native-ETH budget for this transaction tree.
    function getValue() internal view returns (uint256 value) {
        assembly {
            value := tload(VALUE_SLOT)
        }
    }

    /// @notice Adds `amount` to the transient ETH budget (rare; budget is usually set once at depth 0).
    function increaseValue(uint256 amount) internal {
        assembly {
            tstore(VALUE_SLOT, add(tload(VALUE_SLOT), amount))
        }
    }

    /// @notice Deducts `amount` from the transient ETH budget before a native good transfer.
    /// @dev Reverts `TTSwapError(30)` when the budget is insufficient.
    function decreaseValue(uint256 amount) internal {
        if (amount > getValue()) revert TTSwapError(30);
        assembly {
            tstore(VALUE_SLOT, sub(tload(VALUE_SLOT), amount))
        }
    }

    /// @notice Current nesting depth of `msgValue`-wrapped calls.
    function getDepth() internal view returns (uint256 step) {
        assembly {
            step := tload(DEPTH_SLOT)
        }
    }

    /// @notice Resets call depth to zero (internal cleanup helper).
    function clearDepth() internal {
        assembly {
            tstore(DEPTH_SLOT, 0)
        }
    }

    /// @notice Increments `msgValue` nesting depth on entry.
    function addDepth() internal {
        assembly {
            tstore(DEPTH_SLOT, add(tload(DEPTH_SLOT), 1))
        }
    }

    /// @notice Decrements `msgValue` nesting depth on exit.
    function subDepth() internal {
        assembly {
            tstore(DEPTH_SLOT, sub(tload(DEPTH_SLOT), 1))
        }
    }

    /// @notice Entry hook for `msgValue` modifier.
    /// @dev Only when `depth == 0` does it initialize `VALUE_SLOT` from `msg.value`.
    ///      Always increments depth so nested guarded calls share one budget.
    function checkbefore() internal {
        if (getDepth() == 0) {
            setValue(msg.value);
        }
        addDepth();
    }

    /// @notice Exit hook for `msgValue` modifier.
    /// @dev Decrements depth; when depth returns to 0, refunds leftover ETH to `msg.sender`.
    function checkafter() internal {
        subDepth();
        uint256 amount = getValue();
        if (getDepth() == 0 && amount > 0) {
            setValue(0);
            bool success;
            address to = msg.sender;
            assembly {
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            if (!success) revert TTSwapError(31);
        }
    }
}
