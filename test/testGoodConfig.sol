// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

/// @notice Unit tests for `L_GoodConfigLibrary` bit layout (v2.0.0).
/// @dev Bit positions follow `L_GoodConfig.sol` NatSpec table.
contract testGoodConfig is Test {
    using L_GoodConfigLibrary for uint256;

    uint256 internal constant INITIAL_CONFIG =
        0x000c350810450000000000842882040800000000000000000000000000000000;

    // field shift anchors (LSB of each field)
    uint256 internal constant LIQUID_SHIFT = 241;
    uint256 internal constant OPERATOR_SHIFT = 237;
    uint256 internal constant GATE_SHIFT = 234;
    uint256 internal constant REFER_SHIFT = 229;
    uint256 internal constant CUSTOMER_SHIFT = 224;
    uint256 internal constant PLATFORM_SHIFT = 219;
    uint256 internal constant LIMIT_POWER_SHIFT = 214;
    uint256 internal constant SAFE_LINE_SHIFT = 204;
    uint256 internal constant CONTRACT_TYPE_SHIFT = 192;
    uint256 internal constant RUN_TIME_SHIFT = 179;
    uint256 internal constant POWER_SHIFT = 162;
    uint256 internal constant DISINVEST_CHIPS_SHIFT = 154;
    uint256 internal constant INVEST_FEE_SHIFT = 148;
    uint256 internal constant DISINVEST_FEE_SHIFT = 142;
    uint256 internal constant BUY_FEE_SHIFT = 135;
    uint256 internal constant SELL_FEE_SHIFT = 128;

    function _pack(uint256 value, uint256 shift) internal pure returns (uint256) {
        return value << shift;
    }

    /// @dev External wrapper so `vm.expectRevert` can observe library reverts.
    function _updateRunTime(uint256 cfg) external returns (uint256) {
        return cfg.updateRunTimeConfig();
    }

    /// @dev Valid fee split: 6/10 + 1/50 + 5/25 + 8/100 + 8/100 + 2/100 = 100%.
    function _validFeeSplitConfig() internal pure returns (uint256) {
        return
            _pack(6, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
    }

    // ── flags ──────────────────────────────────────────────────────────────

    function test_isvaluegood_and_isnormalgood() public pure {
        uint256 valueGood = 1 << 255;
        assertTrue(valueGood.isvaluegood());
        assertFalse(valueGood.isnormalgood());

        uint256 normalGood = _validFeeSplitConfig();
        assertFalse(normalGood.isvaluegood());
        assertTrue(normalGood.isnormalgood());
    }

    function test_setValueGood() public pure {
        uint256 cfg = _validFeeSplitConfig();
        uint256 asValue = cfg.setValueGood(true);
        assertTrue(asValue.isvaluegood());
        assertEq(asValue.setValueGood(false).isvaluegood(), false);
    }

    function test_isFreeze_and_setFreeze() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isFreeze());
        uint256 frozen = cfg.setFreeze(true);
        assertTrue(frozen.isFreeze());
        assertFalse(frozen.setFreeze(false).isFreeze());
    }

    function test_isVerified_and_setVerified() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isVerified());
        uint256 verified = cfg.setVerified(true);
        assertTrue(verified.isVerified());
        assertFalse(verified.setVerified(false).isVerified());
    }

    function test_isPromised_and_setPromised() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isPromised());
        uint256 promised = cfg.setPromised(true);
        assertTrue(promised.isPromised());
        assertFalse(promised.setPromised(false).isPromised());
    }

    // ── commission fee getters ───────────────────────────────────────────

    function test_getLiquidFee() public pure {
        assertEq(_pack(1, LIQUID_SHIFT).getLiquidFee(10_000), 1_000);
        assertEq(_pack(3, LIQUID_SHIFT).getLiquidFee(10_000), 3_000);
        assertEq(_pack(7, LIQUID_SHIFT).getLiquidFee(10_000), 7_000);
        assertEq(INITIAL_CONFIG.getLiquidFee(10_000), 6_000);
    }

    function test_getOperatorFee() public pure {
        assertEq(_pack(1, OPERATOR_SHIFT).getOperatorFee(10_000), 200);
        assertEq(_pack(7, OPERATOR_SHIFT).getOperatorFee(10_000), 1_400);
        assertEq(_pack(15, OPERATOR_SHIFT).getOperatorFee(10_000), 3_000);
        assertEq(INITIAL_CONFIG.getOperatorFee(10_000), 200);
    }

    function test_getGateFee() public pure {
        assertEq(_pack(1, GATE_SHIFT).getGateFee(10_000), 400);
        assertEq(_pack(3, GATE_SHIFT).getGateFee(10_000), 1_200);
        assertEq(_pack(7, GATE_SHIFT).getGateFee(10_000), 2_800);
        assertEq(INITIAL_CONFIG.getGateFee(10_000), 2_000);
    }

    function test_getReferFee() public pure {
        assertEq(_pack(1, REFER_SHIFT).getReferFee(10_000), 100);
        assertEq(_pack(15, REFER_SHIFT).getReferFee(10_000), 1_500);
        assertEq(_pack(31, REFER_SHIFT).getReferFee(10_000), 3_100);
        assertEq(INITIAL_CONFIG.getReferFee(10_000), 800);
    }

    function test_getCustomerFee() public pure {
        assertEq(_pack(1, CUSTOMER_SHIFT).getCustomerFee(10_000), 100);
        assertEq(_pack(15, CUSTOMER_SHIFT).getCustomerFee(10_000), 1_500);
        assertEq(_pack(31, CUSTOMER_SHIFT).getCustomerFee(10_000), 3_100);
        assertEq(INITIAL_CONFIG.getCustomerFee(10_000), 800);
    }

    function test_getPlatformFee() public pure {
        assertEq(_pack(1, PLATFORM_SHIFT).getPlatformFee128(10_000), 100);
        assertEq(_pack(15, PLATFORM_SHIFT).getPlatformFee128(10_000), 1_500);
        assertEq(_pack(31, PLATFORM_SHIFT).getPlatformFee128(10_000), 3_100);
        assertEq(INITIAL_CONFIG.getPlatformFee128(10_000), 200);
        assertEq(
            INITIAL_CONFIG.getPlatformFee256(10_000),
            INITIAL_CONFIG.getPlatformFee128(10_000)
        );
    }

    // ── leverage / safety / metadata ─────────────────────────────────────

    function test_getLimitPower() public pure {
        assertEq(_pack(0, LIMIT_POWER_SHIFT).getLimitPower(), 100);
        assertEq(_pack(1, LIMIT_POWER_SHIFT).getLimitPower(), 100);
        assertEq(_pack(15, LIMIT_POWER_SHIFT).getLimitPower(), 1_500);
        assertEq(_pack(31, LIMIT_POWER_SHIFT).getLimitPower(), 3_100);
        assertEq(INITIAL_CONFIG.getLimitPower(), 100);
    }

    function test_getSafeLine() public pure {
        assertEq(_pack(0, SAFE_LINE_SHIFT).getSafeLine(), 0);
        assertEq(_pack(80, SAFE_LINE_SHIFT).getSafeLine(), 80);
        assertEq(INITIAL_CONFIG.getSafeLine(), 80);

        assertEq(_pack(0, SAFE_LINE_SHIFT).getSafeLine(50_000), 50_000);
        assertEq(_pack(80, SAFE_LINE_SHIFT).getSafeLine(50_000), 4_000);
        assertEq(INITIAL_CONFIG.getSafeLine(50_000), 4_000);
    }

    function test_getContractType() public pure {
        assertEq(_pack(0, CONTRACT_TYPE_SHIFT).getContractType(), 0);
        assertEq(_pack(0xABC, CONTRACT_TYPE_SHIFT).getContractType(), 0xABC);
    }

    function test_getRunTimeConfig() public pure {
        assertEq(_pack(0, RUN_TIME_SHIFT).getRunTimeConfig(), 0);
        assertEq(_pack(7, RUN_TIME_SHIFT).getRunTimeConfig(), 7);
        assertEq(_pack(0xFFF, RUN_TIME_SHIFT).getRunTimeConfig(), 0xFFF);
    }

    function test_updateRunTimeConfig() public {
        uint256 slot = (block.timestamp % 4095) / 10;
        uint256 cfg = _validFeeSplitConfig() | _pack(slot, RUN_TIME_SHIFT);

        uint256 updated = cfg.updateRunTimeConfig();
        assertEq(updated.getRunTimeConfig(), slot);

        uint256 wrongSlot = _validFeeSplitConfig() | _pack(slot + 1, RUN_TIME_SHIFT);
        vm.expectRevert("transaction busy error");
        this._updateRunTime(wrongSlot);
    }

    // ── owner-controlled trading params ──────────────────────────────────

    function test_getPower() public pure {
        assertEq(_pack(0, POWER_SHIFT).getPower(), 100);
        assertEq(_pack(1, POWER_SHIFT).getPower(), 100);
        assertEq(_pack(15, POWER_SHIFT).getPower(), 1_500);
        assertEq(_pack(31, POWER_SHIFT).getPower(), 3_100);
        assertEq(INITIAL_CONFIG.getPower(), 100);
    }

    function test_getDisinvestChips() public pure {
        assertEq(_pack(0, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 10_000);
        assertEq(_pack(2, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 20_000);
        assertEq(_pack(10, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 4_000);
        assertEq(_pack(255, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 156);
        assertEq(INITIAL_CONFIG.getDisinvestChips(10_000), 4_000);
    }

    function test_getInvestFee() public pure {
        assertEq(_pack(1, INVEST_FEE_SHIFT).getInvestFee(10_000), 1);
        assertEq(_pack(32, INVEST_FEE_SHIFT).getInvestFee(10_000), 32);
        assertEq(_pack(63, INVEST_FEE_SHIFT).getInvestFee(10_000), 63);
        assertEq(INITIAL_CONFIG.getInvestFee(10_000), 8);
    }

    function test_getInvestFullFee() public pure {
        assertEq(_pack(8, INVEST_FEE_SHIFT).getInvestFullFee(9_992), 10_000);
        assertEq(_pack(0, INVEST_FEE_SHIFT).getInvestFullFee(10_000), 10_000);
        assertEq(INITIAL_CONFIG.getInvestFullFee(9_992), 10_000);
    }

    function test_getDisinvestFee() public pure {
        assertEq(_pack(1, DISINVEST_FEE_SHIFT).getDisinvestFee(10_000), 1);
        assertEq(_pack(32, DISINVEST_FEE_SHIFT).getDisinvestFee(10_000), 32);
        assertEq(_pack(63, DISINVEST_FEE_SHIFT).getDisinvestFee(10_000), 63);
        assertEq(INITIAL_CONFIG.getDisinvestFee(10_000), 8);
    }

    function test_getBuyFee() public pure {
        assertEq(_pack(1, BUY_FEE_SHIFT).getBuyFee(10_000), 1);
        assertEq(_pack(64, BUY_FEE_SHIFT).getBuyFee(10_000), 64);
        assertEq(_pack(127, BUY_FEE_SHIFT).getBuyFee(10_000), 127);
        assertEq(INITIAL_CONFIG.getBuyFee(10_000), 8);
    }

    function test_getSellFee() public pure {
        assertEq(_pack(1, SELL_FEE_SHIFT).getSellFee(10_000), 1);
        assertEq(_pack(64, SELL_FEE_SHIFT).getSellFee(10_000), 64);
        assertEq(_pack(127, SELL_FEE_SHIFT).getSellFee(10_000), 127);
        assertEq(INITIAL_CONFIG.getSellFee(10_000), 8);
    }

    // ── config merge helpers ─────────────────────────────────────────────

    function test_updateAdminConfig() public pure {
        uint256 base = INITIAL_CONFIG;
        uint256 adminPatch = (1 << 255) | (3 << 247);
        uint256 merged = base.updateAdminConfig(adminPatch);

        assertTrue(merged.isvaluegood());
        // admin region updated; owner/trading bits preserved
        assertEq(merged.getBuyFee(10_000), base.getBuyFee(10_000));
        assertEq(merged.getLiquidFee(10_000), base.getLiquidFee(10_000));
    }

    function test_updateManagerConfig() public pure {
        uint256 base = INITIAL_CONFIG;
        uint256 managerPatch = _validFeeSplitConfig() |
            _pack(1, LIMIT_POWER_SHIFT) |
            _pack(90, SAFE_LINE_SHIFT) |
            setFreezeBits(true);
        uint256 merged = base.updateManagerConfig(managerPatch);

        assertEq(merged.getSafeLine(), 90);
        assertTrue(merged.isFreeze());
        // owner region untouched
        assertEq(merged.getBuyFee(10_000), base.getBuyFee(10_000));
        assertEq(merged.getPower(), base.getPower());
    }

    function test_updateGoodOwnerConfig() public pure {
        uint256 base = INITIAL_CONFIG;
        uint256 ownerPatch = _pack(20, POWER_SHIFT) |
            _pack(20, DISINVEST_CHIPS_SHIFT) |
            _pack(16, INVEST_FEE_SHIFT) |
            _pack(16, DISINVEST_FEE_SHIFT) |
            _pack(16, BUY_FEE_SHIFT) |
            _pack(16, SELL_FEE_SHIFT);
        uint256 merged = base.updateGoodOwnerConfig(ownerPatch);

        assertEq(merged.getPower(), 2_000);
        assertEq(merged.getInvestFee(10_000), 16);
        assertEq(merged.getBuyFee(10_000), 16);
        // manager region untouched
        assertEq(merged.getLiquidFee(10_000), base.getLiquidFee(10_000));
        assertEq(merged.getSafeLine(), base.getSafeLine());
    }

    function setFreezeBits(bool freeze) private pure returns (uint256) {
        return freeze ? (1 << 246) : 0;
    }

    // ── validation ───────────────────────────────────────────────────────

    function test_checkGoodConfig_valid() public pure {
        assertTrue(_validFeeSplitConfig().checkGoodConfig());
        assertTrue(INITIAL_CONFIG.checkGoodConfig());

        // alternate valid split: 5·10 + 2·2 + 4·4 + 10 + 10 + 10 = 100
        uint256 alt = _pack(5, LIQUID_SHIFT) |
            _pack(2, OPERATOR_SHIFT) |
            _pack(4, GATE_SHIFT) |
            _pack(10, REFER_SHIFT) |
            _pack(10, CUSTOMER_SHIFT) |
            _pack(10, PLATFORM_SHIFT);
        assertTrue(alt.checkGoodConfig());
    }

    function test_checkGoodConfig_invalid() public pure {
        // sum != 100
        uint256 badSum = _pack(5, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
        assertFalse(badSum.checkGoodConfig());

        // zero component
        uint256 zeroLiquid = _pack(0, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
        assertFalse(zeroLiquid.checkGoodConfig());

        assertFalse(uint256(0).checkGoodConfig());
    }

    // ── initial_config integration ───────────────────────────────────────

    function test_initialConfig_allDefaults() public pure {
        assertTrue(INITIAL_CONFIG.checkGoodConfig());
        assertFalse(INITIAL_CONFIG.isvaluegood());
        assertFalse(INITIAL_CONFIG.isFreeze());
        assertFalse(INITIAL_CONFIG.isVerified());
        assertFalse(INITIAL_CONFIG.isPromised());

        // fee split on 10_000 base
        assertEq(INITIAL_CONFIG.getLiquidFee(10_000), 6_000);
        assertEq(INITIAL_CONFIG.getOperatorFee(10_000), 200);
        assertEq(INITIAL_CONFIG.getGateFee(10_000), 2_000);
        assertEq(INITIAL_CONFIG.getReferFee(10_000), 800);
        assertEq(INITIAL_CONFIG.getCustomerFee(10_000), 800);
        assertEq(INITIAL_CONFIG.getPlatformFee128(10_000), 200);

        // owner params
        assertEq(INITIAL_CONFIG.getLimitPower(), 100);
        assertEq(INITIAL_CONFIG.getSafeLine(), 80);
        assertEq(INITIAL_CONFIG.getPower(), 100);
        assertEq(INITIAL_CONFIG.getDisinvestChips(10_000), 4_000);
        assertEq(INITIAL_CONFIG.getInvestFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getDisinvestFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getBuyFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getSellFee(10_000), 8);
    }
}
