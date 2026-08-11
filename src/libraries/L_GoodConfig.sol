// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {TTSwapError} from "./L_Error.sol";

/// @title L_GoodConfigLibrary
/// @notice Packed good configuration: fee flags in high bits + **live `virtualQty` tracker** in low 128 bits.
/// @dev `config.amount1()` (low 128 bits) is NOT market value `V` — use `investState.amount1()` for `V`.
/// @dev Bit extraction pattern: `shr(255 - hi + lo, shl(255 - hi, config))` reads the field `[hi..lo]`.
///      Fee split fields must sum to 100% when normalized by `checkGoodConfig()`.
///
/// @dev **Quantity glossary (see also `L_TTSwapUINT256`)**
///      - `currentState.amount0` (`investQty`): actual / principal token units in the pool.
///      - `currentState.amount1` (`Q`): total virtual pool depth for the AMM (= actual + leverage virtual + fee legs on swaps).
///      - `goodConfig.amount1()` (`virtualQty`): **leverage-only** virtual excess, excluding actual deposits.
///        Updated on invest/disinvest: `+= investQuantity - netActual` (e.g. invest 1 @ 3× → `+= 2`).
///        Invariant at invest time: `Q ≈ investQty + virtualQty` (before swap fee skew).
///      - `investState.amount1` (`V`): total pool value used for pricing (`price ≈ V / Q`).
///
/// @dev Configuration bit layout (MSB = bit 255):
/// | Bits      | Field           | Width | Scale / unit              | Default | Role   |
/// |-----------|-----------------|-------|---------------------------|---------|--------|
/// | 255       | isValueGood     | 1     | flag                      | 0       | admin  |
/// | 254-247   | safeLineUpper   | 8     | × amount / 100            | 100     | admin  |
/// | 246-239   | safeLineLower   | 8     | × amount / 100            | 60      | admin  |
/// | 238-237   | isreserved1     | 2     |                           | 1       | admin  |
/// | 236       | isFreeze        | 1     | flag                      | 0       | manager|
/// | 235       | reserved1       | 1     | flag                      | 0       | manager|
/// | 234       | isPromise       | 1     | flag                      | 0       | manager|
/// | 233-231   | liquidFee       | 3     | × 0.1  (stored / 10)      | 6       | manager|
/// | 230-227   | operatorFee     | 4     | × 0.02 (stored / 50)      | 1       | manager|
/// | 226-224   | gateFee         | 3     | × 0.04 (stored / 25)      | 5       | manager|
/// | 223-219   | referFee        | 5     | × 0.01 (stored / 100)     | 8       | manager|
/// | 218-214   | customerFee     | 5     | × 0.01 (stored / 100)     | 8       | manager|
/// | 213-209   | platformFee     | 5     | × 0.01 (stored / 100)     | 2       | manager|
/// | 208-204   | limitPower      | 5     | × 100 (0 → 100)           | 2       | manager|
/// | 203-197   | contractType    | 7     | raw                       | 0       | manager|
/// | 196-185   | lastRunSlot     | 12    | anti-replay time slot     | 0       | runtime|
/// | 184-173   | reserved        | 12    | unused                    | 0       | —      |
/// | 172-168   | power           | 5     | × 100 (0 → 100)           | 1       | owner  |
/// | 167-160   | disinvestChips  | 8     | chunk divisor (×4 output) | 20      | owner  |
/// | 159-154   | investThreshold | 6     |                           | 0       | owner  |
/// | 153-148   | investFee       | 6     | × 0.0001 (stored / 10000) | 8       | owner  |
/// | 147-142   | disinvestFee    | 6     | × 0.0001 (stored / 10000) | 8       | owner  |
/// | 141-135   | buyFee          | 7     | × 0.0001 (stored / 10000) | 8       | owner  |
/// | 134-128   | sellFee         | 7     | × 0.0001 (stored / 10000) | 8       | owner  |
/// | 127-0     | virtualQty      | 128   | leverage virtual only (excludes actual investQty) | 0 | runtime|
///
/// @dev Default `initial_config` composition:
///      100*2**247 + 60*2**239 + 1*2**237 + 6*2**231 + 1*2**227 + 5*2**224 + 8*2**219
///      + 8*2**214 + 2*2**209 + 2*2**204 + 1*2**168 + 20*2**160
///      + 8*2**148 + 8*2**142 + 8*2**135 + 8*2**128
library L_GoodConfigLibrary {
    using L_GoodConfigLibrary for uint256;

    /// @dev Default packed config (fee split sums to 100%, trading fees = 8 bps each).
    uint256 constant initial_config =
        0x321e230d42042000000001140082040800000000000000000000000000000000;

    /// @dev Admin-writable region: bit 255 (good type) + bits 254-239 (safe lines) + bits 238-237 (reserved).
    uint256 constant admin_config_mask =
        0xffffe00000000000000000000000000000000000000000000000000000000000;

    /// @dev Market-manager-writable region: bits 236-197 (flags, fee split, limits, metadata).
    uint256 internal constant marketmanager_config_mask =
        0x1fffffffffe0000000000000000000000000000000000000000000000000;

    /// @dev Good-owner-writable region: bits 172-128 (power, chips, trading fees).
    uint256 internal constant owner_config_mask =
        0x000000000000000000001fffffffffff00000000000000000000000000000000;

    /// @dev Isolated mask for `contractType` (bits 203-197).
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

    /// @notice Merges admin-controlled bits (255-237) from `admin_config`.
    function updateAdminConfig(
        uint256 config,
        uint256 admin_config
    ) internal pure returns (uint256) {
        return
            (config & ~admin_config_mask) | (admin_config & admin_config_mask);
    }

    /// @notice Merges market-manager-controlled bits (236-197) from `market_manager_config`.
    function updateManagerConfig(
        uint256 config,
        uint256 market_manager_config
    ) internal pure returns (uint256) {
        return
            (config & ~marketmanager_config_mask) |
            (market_manager_config & marketmanager_config_mask);
    }

    /// @notice Merges good-owner-controlled bits (172-128) from `owner_config`.
    function updateGoodOwnerConfig(
        uint256 config,
        uint256 owner_config
    ) internal pure returns (uint256) {
        return
            (config & ~owner_config_mask) | (owner_config & owner_config_mask);
    }

    /// @notice Records that this good was used in the current block slot (`block.number % 4095`).
    /// @dev Reverts `TTSwapError(46)` if the same good is touched twice in the same slot —
    ///      mitigates same-block replay / flash-loan style sequencing on a single pool.
    /// @dev Integrators: advance `block.number` or wait one block between dependent trades on the same good.
    function updateRunBlockConfig(
        uint256 config
    ) internal view returns (uint256 a) {
        uint256 run_time_config = block.number % 4095;
        if (config.getRunBlockConfig() == run_time_config) {
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
        return (config & (1 << 236)) != 0;
    }

    /// @notice Sets or clears bit 236 (`isFreeze`).
    function setFreeze(
        uint256 config,
        bool freeze
    ) internal pure returns (uint256 a) {
        if (freeze) {
            return (config | (1 << 236));
        } else {
            return (config & ~uint256(1 << 236));
        }
    }

    /// @notice Returns whether the good is under a value promise (bit 234).
    function isPromised(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 234)) != 0;
    }

    /// @notice Sets or clears bit 234 (`isPromise`).
    function setPromised(
        uint256 config,
        bool promised
    ) internal pure returns (uint256 a) {
        if (promised) {
            return (config | (1 << 234));
        } else {
            return (config & ~uint256(1 << 234));
        }
    }

    /// @notice Liquidity-provider fee from bits 233-231: `stored × amount / 10`.
    function getLiquidFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(253, shl(22, config))
                config := mul(config, amount)
                a := div(config, 10)
            }
        }
    }

    /// @notice Operator fee from bits 230-227: `stored × amount / 50`.
    function getOperatorFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(252, shl(25, config))
                config := mul(config, amount)
                a := div(config, 50)
            }
        }
    }

    /// @notice Gate fee from bits 226-224: `stored × amount / 25`.
    function getGateFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(253, shl(29, config))
                config := mul(config, amount)
                a := div(config, 25)
            }
        }
    }

    /// @notice Referral fee from bits 223-219: `stored × amount / 100`.
    function getReferFee(
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

    /// @notice Customer fee from bits 218-214: `stored × amount / 100`.
    function getCustomerFee(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(37, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Platform fee from bits 213-209: `stored × amount / 100` (uint128).
    function getPlatformFee128(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(42, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Platform fee from bits 213-209: `stored × amount / 100` (uint256).
    function getPlatformFee256(
        uint256 config,
        uint256 amount
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                config := shr(251, shl(42, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    /// @notice Max swap leverage from bits 208-204, scaled ×100 (stored 0 → 100).
    function getLimitPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(47, config))
            }
            if (a == 0) {
                a = 100;
            } else {
                a = a * 100;
            }
        }
    }

    /// @notice Safety-line amount from bits 254-247: stored 0 → `amount`, else `stored × amount / 100`.
    function getSafeLineUpper(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(248, shl(1, config))
            }
            if (a == 0) return amount;
            return ((a * amount) / 100);
        }
    }

    /// @notice Safety-line amount from bits 246-239: stored 0 → `amount`, else `stored × amount / 100`.
    function getSafeLineLower(
        uint256 config,
        uint128 amount
    ) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(248, shl(9, config))
            }
            if (a == 0) return amount;
            return ((a * amount) / 100);
        }
    }

    /// @notice Contract-type identifier from bits 203-197 (7 bits).
    function getContractType(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(249, shl(52, config))
            }
        }
    }

    /// @notice Anti-replay time slot from bits 196-185.
    function getRunBlockConfig(
        uint256 config
    ) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                a := shr(244, shl(59, config))
            }
        }
    }

    /// @notice Active swap power from bits 172-168, scaled ×100 (stored 0 → 100).
    function getPower(uint256 config) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                a := shr(251, shl(83, config))
            }
        }
        return a == 0 ? 100 : 100 * a;
    }

    /// @notice Max single disinvest chunk from bits 167-160.
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

    /// @notice Invest threshold from bits 159-154.
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
    /// - Liquid:    [233..231] * 10
    /// - Operator:  [230..227] * 2
    /// - Gate:      [226..224] * 4
    /// - Referral:  [223..219]
    /// - Customer:  [218..214]
    /// - Platform:  [213..209]
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
            liquid := mul(and(shr(231, config), 0x7), 10)
            operator := mul(and(shr(227, config), 0xF), 2)
            gate := mul(and(shr(224, config), 0x7), 4)
            referal := and(shr(219, config), 0x1F)
            cust := and(shr(214, config), 0x1F)
            platform := and(shr(209, config), 0x1F)
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
