// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

/// @dev Shared v2.0 good-config constants aligned with `L_GoodConfig.sol`.
library TestConfigConstants {
    uint256 internal constant INITIAL_GOOD_CONFIG =
        0x230d42042643c000000001146482040800000000000000000000000000000000;

    uint256 internal constant LIQUID_SHIFT = 247;
    uint256 internal constant OPERATOR_SHIFT = 243;
    uint256 internal constant GATE_SHIFT = 240;
    uint256 internal constant REFER_SHIFT = 235;
    uint256 internal constant CUSTOMER_SHIFT = 230;
    uint256 internal constant PLATFORM_SHIFT = 225;
    uint256 internal constant LIMIT_POWER_SHIFT = 220;
    uint256 internal constant SAFE_LINE_UPPER_SHIFT = 212;
    uint256 internal constant SAFE_LINE_LOWER_SHIFT = 204;
    uint256 internal constant CONTRACT_TYPE_SHIFT = 197;
    uint256 internal constant RUN_TIME_SHIFT = 185;
    uint256 internal constant POWER_SHIFT = 168;
    uint256 internal constant DISINVEST_CHIPS_SHIFT = 160;
    uint256 internal constant INVEST_FEE_SHIFT = 148;
    uint256 internal constant DISINVEST_FEE_SHIFT = 142;
    uint256 internal constant BUY_FEE_SHIFT = 135;
    uint256 internal constant SELL_FEE_SHIFT = 128;

    uint256 internal constant ADMIN_MASK =
        0xe000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant MANAGER_MASK =
        0x1fffffffffffffe0000000000000000000000000000000000000000000000000;
    uint256 internal constant OWNER_MASK =
        0x000000000000000000001fffffffffff00000000000000000000000000000000;
}
