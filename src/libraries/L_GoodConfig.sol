// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {TTSwapError} from "./L_Error.sol";

/// @title L_GoodConfigLibrary
/// @notice Packed good configuration stored in a single `uint256` (high 128 bits) plus live market value `V` (low 128 bits).
/// @dev Bit extraction pattern: `shr(255 - hi + lo, shl(255 - hi, config))` reads the field `[hi..lo]`.
///      Fee split fields must sum to 100% when normalized by `checkGoodConfig()`.
///
/// @dev Configuration bit layout (MSB = bit 255):
/// | Bits      | Field           | Width | Scale / unit              | Default |
/// |-----------|-----------------|-------|---------------------------|---------|
/// | 255       | isValueGood     | 1     | flag                      | 0       |
/// | 254-253   | isreserved1     | 2     |                           | 0       |
/// | 252       | isFreeze        | 1     | flag                      | 0       |
/// | 251       | reserved1       | 1     | flag                      | 0       |
/// | 250       | isPromise       | 1     | flag                      | 0       |
/// | 249-247   | liquidFee       | 3     | × 0.1  (stored / 10)      | 6       |
/// | 246-243   | operatorFee     | 4     | × 0.02 (stored / 50)      | 1       |
/// | 242-240   | gateFee         | 3     | × 0.04 (stored / 25)      | 5       |
/// | 239-235   | referFee        | 5     | × 0.01 (stored / 100)     | 8       |
/// | 234-230   | customerFee     | 5     | × 0.01 (stored / 100)     | 8       |
/// | 229-225   | platformFee     | 5     | × 0.01 (stored / 100)     | 2       |
/// | 224-220   | limitPower      | 5     | × 100 (0 → 100)           | 1       |
/// | 219-212   | safeLineUpper   | 8     |                           | 100     |
/// | 211-204   | safeLineLower   | 8     |                           | 60      |
/// | 203-197   | contractType    | 8     | raw                       | 0       |
/// | 196-185   | lastRunSlot     | 12    | anti-replay time slot     | 0       |
/// | 184-173   | reserved        | 12    | unused                    | 0       |
/// | 172-168   | power           | 5     | × 100 (0 → 100)           | 1       |
/// | 167-160   | disinvestChips  | 8     | chunk divisor (×4 output) | 10      |
/// | 159-154   | investThreshold | 6     |                           | 30      |
/// | 153-148   | investFee       | 6     | × 0.0001 (stored / 10000) | 8       |
/// | 147-142   | disinvestFee    | 6     | × 0.0001 (stored / 10000) | 8       |
/// | 141-135   | buyFee          | 7     | × 0.0001 (stored / 10000) | 8       |
/// | 134-128   | sellFee         | 7     | × 0.0001 (stored / 10000) | 8       |
/// | 127-0     | marketValue (V) | 128   | live pool value           | 0       |
///
/// @dev Default `initial_config` composition:
///      2*2**252 +6* 2**247 + 1 * 2**243 + 5 * 2**240 + 8 * 2**235 + 8 * 2**230 + 2 * 2**225 +2 * 2**220+100*2**212+60*2**204+25*2**154+ 8 * 2**148 + 8 * 2**142 + 8 * 2**135 + 8 * 2**128 + 1 * 2**168 + 20 * 2**160 
library L_GoodConfigLibrary {
    using L_GoodConfigLibrary for uint256;

    /// @dev Default packed config (fee split sums to 100%, trading fees = 8 bps each).
    uint256 constant initial_config =
        0x230d42042643c000000001146482040800000000000000000000000000000000;

    /// @dev Admin-writable region: bit 255 (good type) + bits 254-253 (ERC type).
    uint256 constant admin_config_mask =
        0xe000000000000000000000000000000000000000000000000000000000000000;

    /// @dev Market-manager-writable region: bits 252-197 (flags, fee split, limits, metadata).
    uint256 internal constant marketmanager_config_mask =
        0x1fffffffffffffe0000000000000000000000000000000000000000000000000;

    /// @dev Good-owner-writable region: bits 172-128 (power, chips, trading fees). Low 128 bits hold live `V`.
    uint256 internal constant owner_config_mask =
        0x000000000000000000001fffffffffff00000000000000000000000000000000;

    /// @dev Isolated mask for `contractType` (bits 203-192).
    uint256 internal constant contract_type_mask =
        0x0000000000000fe0000000000000000000000000000000000000000000000000;

    /// @dev `lastRunSlot` field mask (bits 196-185).
    uint256 internal constant run_time_config_mask =
        0x000000000000001ffe0000000000000000000000000000000000000000000000;

    uint256 internal constant min_invest_threshold = 30;

    /// @notice Returns the protocol default packed configuration.
    function setInitialConfig() internal pure returns (uint256) {
        return initial_config;
    }

    /// @notice Merges admin-controlled bits (255, 254-247) from `admin_config`.
    function updateAdminConfig(
        uint256 config,
        uint256 admin_config
    ) internal pure returns (uint256) {
        return
            (config & ~admin_config_mask) | (admin_config & admin_config_mask);
    }

    /// @notice Merges market-manager-controlled bits (246-191) from `market_manager_config`.
    function updateManagerConfig(
        uint256 config,
        uint256 market_manager_config
    ) internal pure returns (uint256) {
        return
            (config & ~marketmanager_config_mask) |
            (market_manager_config & marketmanager_config_mask);
    }

    /// @notice Merges good-owner-controlled bits (166-128) from `owner_config`.
    function updateGoodOwnerConfig(
        uint256 config,
        uint256 owner_config
    ) internal pure returns (uint256) {
        return
            (config & ~owner_config_mask) | (owner_config & owner_config_mask);
    }

    /// @notice Refreshes the anti-replay time slot and enforces single-writer per slot.
    /// @dev Slot = `(block.timestamp % 4095) % 10` (0-9). Caller must match the stored slot;
    ///      after success the slot is rewritten to the current value (bits 190-179).
    function updateRunTimeConfig(
        uint256 config
    ) internal view returns (uint256 a) {
        uint256 run_time_config = (block.timestamp % 4095) / 10;
        if (config.getRunTimeConfig() == run_time_config) {
            revert TTSwapError(46);
        }
        return (config & ~run_time_config_mask) | (run_time_config << 185);
    }

    /// @notice Checks if the good is configured as a value good.
    /// @param config The configuration value.
    /// @return a True if it's a value good, false otherwise.
    function isvaluegood(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 255)) != 0;
    }

    /// @notice Checks if the good is configured as a normal good.
    /// @param config The configuration value.
    /// @return a True if it's a normal good, false otherwise.
    function isnormalgood(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 255)) == 0;
    }

    /// @notice Sets or clears bit 255 (`isValueGood`).
    function setValueGood(
        uint256 config,
        bool value_good
    ) internal pure returns (uint256 a) {
        if (value_good) {
            return (config | (1 << 255));
        } else {
            return (config & ~uint256(1 << 255));
        }
    }

    /// @notice Checks if the good is frozen (trading paused).
    /// @param config The configuration value.
    /// @return a True if the good is frozen, false otherwise.
    function isFreeze(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 252)) != 0;
    }

    /// @notice Sets or clears bit 246 (`isFreeze`).
    function setFreeze(
        uint256 config,
        bool freeze
    ) internal pure returns (uint256 a) {
        if (freeze) {
            return (config | (1 << 252));
        } else {
            return (config & ~uint256(1 << 252));
        }
    }

    /// @notice Returns whether the good is under a value promise (bit 244).
    function isPromised(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 250)) != 0;
    }
    /// @notice Sets or clears bit 244 (`isPromise`).
    function setPromised(
        uint256 config,
        bool promised
    ) internal pure returns (uint256 a) {
        if (promised) {
            return (config | (1 << 250));
        } else {
            return (config & ~uint256(1 << 250));
        }
    }

    /// @notice Liquidity-provider fee from bits 243-241: `stored × amount / 10`.
    function getLiquidFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(253, shl(6, config))
                config := mul(config, amount)
                a := div(config, 10)
            }
        }
    }

    /// @notice Operator fee from bits 240-237: `stored × amount / 50`.
    function getOperatorFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(252, shl(9, config))
                config := mul(config, amount)
                a := div(config, 50)
            }
        }
    }

    /// @notice Gate fee from bits 236-234: `stored × amount / 25`.
    function getGateFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(253, shl(13, config))
                config := mul(config, amount)
                a := div(config, 25)
            }
        }
    }

    /// @notice Referral fee from bits 233-229: `stored × amount / 100`.
    function getReferFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(16, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Customer fee from bits 228-224: `stored × amount / 100`.
    function getCustomerFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(21, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Platform fee from bits 223-219: `stored × amount / 100` (uint128).
    function getPlatformFee128(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(26, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Platform fee from bits 223-219: `stored × amount / 100` (uint256).
    function getPlatformFee256(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                config := shr(251, shl(26, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Max swap leverage from bits 218-214, scaled ×100 (stored 0 → 100).
    function getLimitPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(31, config))
            }
            if (a == 0) {
                a = 100;
            } else {
                a = a * 100;
            }
        }
    }

    /// @notice Safety-line amount from bits 219-212: stored 0 → `amount`, else `stored × amount / 1000`.
    function getSafeLineUpper(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(248, shl(36, config))
            }
            if (a == 0) return amount;
            return ((a * amount) / 100);
        }
    }

    /// @notice Safety-line amount from bits 211-204: stored 0 → `amount`, else `stored × amount / 1000`.
    function getSafeLineLower(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(248, shl(44, config))
            }
            if (a == 0) return amount;
            return ((a * amount) / 100);
        }
    }

    /// @notice Contract-type identifier from bits 203-197.
    function getContractType(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(244, shl(49, config))
            }
        }
    }

    /// @notice Anti-replay time slot from bits 190-179.
    function getRunTimeConfig(
        uint256 config
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                a := shr(244, shl(59, config))
            }
        }
    }

    /// @notice Active swap power from bits 166-162, scaled ×100 (stored 0 → 100).
    function getPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(83, config))
            }
        }
        return a == 0 ? 100 : 100 * a;
    }

    /// @notice Max single disinvest chunk from bits 161-154.
    /// @dev Stored value is a divisor; output cap = `(amount / stored) × 4`. Stored 0 disables chunking.
    function getDisinvestChips(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(248, shl(88, config))
        }
        if (a == 0) return amount;
        return ((amount / a) * 4);
    }

    /// @notice Invest threshold from bits 153-148.
    function getInvestThreshold(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        uint256 b;
        unchecked {
            assembly {
                b := shr(250, shl(96, config))
            }
            if (b > min_invest_threshold) {
                b = min_invest_threshold;
            }
            if (b == 0) return amount;
            b = 100 - b;
            a = uint128((amount * b) / 100);
        }
    }

    /// @notice Invest fee from bits 153-148: `stored × amount / 10000`.
    function getInvestFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(102, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Calculate the full investment quantity (before fee deduction).
    /// @dev This is the inverse of fee calculation, used when determining how much initial input is needed to yield a target output amount after fees.
    /// @param config The configuration value.
    /// @param amount The target investment amount (net of fees).
    /// @return a The gross investment amount required.
    function getInvestFullFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(102, config))
                a := div(mul(amount, 10000), sub(10000, config))
            }
        }
    }

    /// @notice Disinvest fee from bits 147-142: `stored × amount / 10000`.
    function getDisinvestFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(108, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Buy fee from bits 141-135: `stored × amount / 10000`.
    function getBuyFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(114, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Sell fee from bits 134-128: `stored × amount / 10000`.
    function getSellFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(121, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Validates if a configuration value is well-formed and consistent.
    /// @dev Checks that the sum of all fee components (liquidity, operator, gate, referal, customer, platform) equals 100%.
    /// Each component is extracted from specific bit ranges and normalized.
    /// - Liquid: [241..243] * 10
    /// - Operator: [237..240] * 2
    /// - Gate: [234..236] * 4
    /// - Referral: [229..233]
    /// - Customer: [224..228]
    /// - Platform: [219..223]
    /// @param config The configuration value to check.
    /// @return result True if the configuration is valid (sum == 100 and no component is 0), false otherwise.
    function checkGoodConfig(
        uint256 config
    ) internal pure returns (bool result) {
        uint256 liquid;
        uint256 operator;
        uint256 gate;
        uint256 referal;
        uint256 cust;
        uint256 platform;

        assembly {
            liquid := mul(and(shr(247, config), 0x7), 10)
            operator := mul(and(shr(243, config), 0xF), 2)
            gate := mul(and(shr(240, config), 0x7), 4)
            referal := and(shr(235, config), 0x1F)
            cust := and(shr(230, config), 0x1F)
            platform := and(shr(225, config), 0x1F)
        }

        // Check all components are non-zero and sum equals 100
        if (
            liquid == 0 ||
            operator == 0 ||
            gate == 0 ||
            referal == 0 ||
            cust == 0 ||
            platform == 0
        ) return false;

        return (liquid + operator + gate + referal + cust + platform == 100);
    }
}
