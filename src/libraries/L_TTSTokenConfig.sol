// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title TTS Token Configuration Library
/// @notice A library for handling TTS token configurations
library L_TTSTokenConfigLibrary {
    /// @notice Checks if the given configuration represents a main item
    /// @dev Uses assembly to perform a bitwise right shift operation
    /// @param config The configuration value to check
    /// @return a True if the configuration represents a main item, false otherwise
    function ismain(uint256 config) internal pure returns (bool a) {
        uint256 b;
        assembly {
            b := shr(255, config)
        }
        return b == 1 ? true : false;
    }

    /// @notice Calculates the ratio amount based on configuration.
    /// @dev Extracts the lower 16 bits (0xffff) of config as a basis point ratio (dividend/10000) and applies it to amount.
    /// @param config The configuration value containing the ratio in the lowest 16 bits.
    /// @param amount The amount to apply the ratio to.
    /// @return b The calculated amount.
    function getratio(uint256 config, uint128 amount) internal pure returns (uint128 b) {
        unchecked {
            assembly {
                config := and(config, 0xffff)
                config := mul(config, amount)
                b := div(config, 10000)
            }
        }
    }

    /// @notice Updates the ratio configuration.
    /// @dev Replaces the lower 16 bits of `config` with the lower 16 bits of `ttsconfig`.
    /// This effectively updates the stored ratio while preserving other configuration bits.
    /// @param config The original configuration value.
    /// @param ttsconfig The new configuration value containing the new ratio in its lower 16 bits.
    /// @return b The updated configuration value.
    function setratio(uint256 config, uint256 ttsconfig) internal pure returns (uint256 b) {
        unchecked {
            assembly {
                ttsconfig := and(ttsconfig, 0xffff)
                config := shl(32, shr(32, config))
                b := add(ttsconfig, config)
            }
        }
    }
}
