// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

/// @dev Shared v2.0 good-config constants aligned with `L_GoodConfig.sol`.
library TestConfigConstants {
    /// @dev Must match `L_GoodConfigLibrary.initial_config`.
    uint256 internal constant INITIAL_GOOD_CONFIG =
        0x321e230d42042000000001140082040800000000000000000000000000000000;

    uint256 internal constant SAFE_LINE_UPPER_SHIFT = 247;
    uint256 internal constant SAFE_LINE_LOWER_SHIFT = 239;
    uint256 internal constant LIQUID_SHIFT = 231;
    uint256 internal constant OPERATOR_SHIFT = 227;
    uint256 internal constant GATE_SHIFT = 224;
    uint256 internal constant REFER_SHIFT = 219;
    uint256 internal constant CUSTOMER_SHIFT = 214;
    uint256 internal constant PLATFORM_SHIFT = 209;
    uint256 internal constant LIMIT_POWER_SHIFT = 204;
    uint256 internal constant CONTRACT_TYPE_SHIFT = 197;
    uint256 internal constant RUN_TIME_SHIFT = 185;
    uint256 internal constant POWER_SHIFT = 168;
    uint256 internal constant DISINVEST_CHIPS_SHIFT = 160;
    uint256 internal constant INVEST_FEE_SHIFT = 148;
    uint256 internal constant DISINVEST_FEE_SHIFT = 142;
    uint256 internal constant BUY_FEE_SHIFT = 135;
    uint256 internal constant SELL_FEE_SHIFT = 128;

    /// @dev Bits 255-237: isValueGood + safeLineUpper/Lower + isreserved1.
    uint256 internal constant ADMIN_MASK =
        0xffffe00000000000000000000000000000000000000000000000000000000000;
    /// @dev Bits 236-197: freeze/promise/fee-split/limitPower/contractType.
    uint256 internal constant MANAGER_MASK =
        0x1fffffffffe0000000000000000000000000000000000000000000000000;
    /// @dev Bits 172-128: power/chips/trading fees.
    uint256 internal constant OWNER_MASK =
        0x000000000000000000001fffffffffff00000000000000000000000000000000;
}
