// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title L_GoodConfigLibrary
/// @notice Packed good configuration stored in a single `uint256` (high 128 bits) plus live market value `V` (low 128 bits).
/// @dev Bit extraction pattern: `shr(255 - hi + lo, shl(255 - hi, config))` reads the field `[hi..lo]`.
///      Fee split fields must sum to 100% when normalized by `checkGoodConfig()`.
///
/// @dev Configuration bit layout (MSB = bit 255):
/// | Bits      | Field           | Width | Scale / unit              | Default |
/// |-----------|-----------------|-------|---------------------------|---------|
/// | 255       | isValueGood     | 1     | flag                      | 0       |
/// | 254-247   | ercType         | 8     | enum                      | 0       |
/// | 246       | isFreeze        | 1     | flag                      | 0       |
/// | 245       | isVerified      | 1     | flag                      | 0       |
/// | 244       | isPromise       | 1     | flag                      | 0       |
/// | 243-241   | liquidFee       | 3     | × 0.1  (stored / 10)      | 6       |
/// | 240-237   | operatorFee     | 4     | × 0.02 (stored / 50)      | 1       |
/// | 236-234   | gateFee         | 3     | × 0.04 (stored / 25)      | 5       |
/// | 233-229   | referFee        | 5     | × 0.01 (stored / 100)     | 8       |
/// | 228-224   | customerFee     | 5     | × 0.01 (stored / 100)     | 8       |
/// | 223-219   | platformFee     | 5     | × 0.01 (stored / 100)     | 2       |
/// | 218-214   | limitPower      | 5     | × 100 (0 → 100)           | 1       |
/// | 213-204   | safeLine        | 10    | raw                       | 80      |
/// | 203-192   | contractType    | 12    | raw                       | 0       |
/// | 191       | reserved        | 1     | unused                    | 0       |
/// | 190-179   | lastRunSlot     | 12    | anti-replay time slot     | 0       |
/// | 178-167   | reserved        | 12    | unused                    | 0       |
/// | 166-162   | power           | 5     | × 100 (0 → 100)           | 1       |
/// | 161-154   | disinvestChips  | 8     | chunk divisor (×4 output) | 10      |
/// | 153-148   | investFee       | 6     | × 0.0001 (stored / 10000) | 8       |
/// | 147-142   | disinvestFee    | 6     | × 0.0001 (stored / 10000) | 8       |
/// | 141-135   | buyFee          | 7     | × 0.0001 (stored / 10000) | 8       |
/// | 134-128   | sellFee         | 7     | × 0.0001 (stored / 10000) | 8       |
/// | 127-0     | marketValue (V) | 128   | live pool value           | 0       |
///
/// @dev Default `initial_config` composition:
///      6·2^241 + 1·2^237 + 5·2^234 + 8·2^229 + 8·2^224 + 2·2^219
///      + 1·2^214 + 80·2^204 + 1·2^167 + 1·2^162 + 10·2^154
///      + 8·2^148 + 8·2^142 + 8·2^135 + 8·2^128
library L_GoodConfigLibrary {
    using L_GoodConfigLibrary for uint256;

    /// @dev Default packed config (fee split sums to 100%, trading fees = 8 bps each).
    uint256 constant initial_config =
        0x000c350810450000000000842882040800000000000000000000000000000000;

    /// @dev Admin-writable region: bit 255 (good type) + bits 254-247 (ERC type).
    uint256 constant admin_config_mask =
        0xff80000000000000000000000000000000000000000000000000000000000000;

    /// @dev Market-manager-writable region: bits 246-191 (flags, fee split, limits, metadata).
    uint256 constant marketmanager_config_mask =
        0x0fffffffffffffff800000000000000000000000000000000000000000000000;

    /// @dev Good-owner-writable region: bits 166-128 (power, chips, trading fees). Low 128 bits hold live `V`.
    uint256 constant owner_config_mask =
        0x00000000000000000000007fffffffff00000000000000000000000000000000;

    /// @dev Isolated mask for `contractType` (bits 203-192).
    uint256 constant contract_type_mask =
        0x0000000000000fff000000000000000000000000000000000000000000000000;

    /// @dev ERC type field mask (bits 254-247); preserves bit 255 (`isValueGood`).
    uint256 constant erc_type_mask =
        0x7f80000000000000000000000000000000000000000000000000000000000000;

    /// @dev `lastRunSlot` field mask (bits 190-179).
    uint256 constant run_time_config_mask =
        0x00000000000000007ff800000000000000000000000000000000000000000000;

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
        uint256 run_time_config = (block.timestamp % 4095) % 10;
        require(
            config.getRunTimeConfig() == run_time_config,
            "transaction busy error"
        );
        return (config & ~run_time_config_mask) | (run_time_config << 179);
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
        return (config & (1 << 246)) != 0;
    }

    /// @notice Sets or clears bit 246 (`isFreeze`).
    function setFreeze(
        uint256 config,
        bool freeze
    ) internal pure returns (uint256 a) {
        if (freeze) {
            return (config | (1 << 246));
        } else {
            return (config & ~uint256(1 << 246));
        }
    }

    /// @notice Reads ERC token type from bits 254-247.
    function getERCType(uint256 config) internal pure returns (uint8 a) {
        unchecked {
            assembly {
                a := shr(248, shl(1, config))
            }
        }
    }

    /// @notice Writes ERC token type to bits 254-247 without touching bit 255.
    function setERCType(
        uint256 config,
        uint8 erc_type
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                a := erc_type
                a := shl(247, a)
                a := add(and(config, not(erc_type_mask)), a)
            }
        }
    }

    /// @notice Returns whether the good is verified (bit 245).
    function isVerified(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 245)) != 0;
    }

    /// @notice Sets or clears bit 245 (`isVerified`).
    function setVerified(
        uint256 config,
        bool verified
    ) internal pure returns (uint256 a) {
        if (verified) {
            return (config | (1 << 245));
        } else {
            return (config & ~uint256(1 << 245));
        }
    }

    /// @notice Returns whether the good is under a value promise (bit 244).
    function isPromised(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 244)) != 0;
    }
    /// @notice Sets or clears bit 244 (`isPromise`).
    function setPromised(
        uint256 config,
        bool promised
    ) internal pure returns (uint256 a) {
        if (promised) {
            return (config | (1 << 244));
        } else {
            return (config & ~uint256(1 << 244));
        }
    }

    /// @notice Liquidity-provider fee from bits 243-241: `stored × amount / 10`.
    function getLiquidFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(253, shl(12, config))
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
                config := shr(252, shl(15, config))
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
                config := shr(253, shl(19, config))
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
                config := shr(251, shl(22, config))
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
                config := shr(251, shl(27, config))
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
                config := shr(251, shl(32, config))
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
                config := shr(251, shl(32, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Max swap leverage from bits 218-214, scaled ×100 (stored 0 → 100).
    function getLimitPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(37, config))
            }
            if (a == 0) {
                a = 100;
            } else {
                a = a * 100;
            }
        }
    }

    /// @notice Safety-line threshold from bits 213-204 (raw 10-bit value).
    function getSafeLine(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(246, shl(42, config))
            }
        }
    }

    /// @notice Safety-line amount from bits 213-204: stored 0 → `amount`, else `stored × amount / 1000`.
    function getSafeLine(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(246, shl(42, config))
            }
            if (a == 0) return amount;
            return ((a * amount) / 1000);
        }
    }

    /// @notice Contract-type identifier from bits 203-192.
    function getContractType(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(244, shl(52, config))
            }
        }
    }

    /// @notice Anti-replay time slot from bits 190-179.
    function getRunTimeConfig(
        uint256 config
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                a := shr(244, shl(65, config))
            }
        }
    }

    /// @notice Active swap power from bits 166-162, scaled ×100 (stored 0 → 100).
    function getPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(89, config))
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
            a := shr(248, shl(94, config))
        }
        if (a == 0) return amount;
        return ((amount / a) * 4);
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
            liquid := mul(and(shr(241, config), 0x7), 10)
            operator := mul(and(shr(237, config), 0xF), 2)
            gate := mul(and(shr(234, config), 0x7), 4)
            referal := and(shr(229, config), 0x1F)
            cust := and(shr(224, config), 0x1F)
            platform := and(shr(219, config), 0x1F)
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
