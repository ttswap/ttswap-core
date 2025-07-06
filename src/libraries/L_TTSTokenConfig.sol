// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title TTS Token Configuration Library
/// @notice A library for handling TTS token configurations
library L_TTSTokenConfigLibrary {
      uint256 internal constant LTV_MASK =                       0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

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

    function getratio(uint256 config, uint128 amount) internal pure returns (uint128 b) {
        unchecked {
            assembly {
                config := and(config, 0xffff)
                config := mul(config, amount)
                b := div(config, 10000)
            }
        }
    }

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
