// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";

/// @notice Unit tests for `L_GoodConfigLibrary` bit layout (v2.0.0).
contract testGoodConfig is Test {
    using L_GoodConfigLibrary for uint256;

    uint256 internal constant INITIAL_CONFIG = TestConfigConstants.INITIAL_GOOD_CONFIG;
    uint256 internal constant LIQUID_SHIFT = TestConfigConstants.LIQUID_SHIFT;
    uint256 internal constant OPERATOR_SHIFT = TestConfigConstants.OPERATOR_SHIFT;
    uint256 internal constant GATE_SHIFT = TestConfigConstants.GATE_SHIFT;
    uint256 internal constant REFER_SHIFT = TestConfigConstants.REFER_SHIFT;
    uint256 internal constant CUSTOMER_SHIFT = TestConfigConstants.CUSTOMER_SHIFT;
    uint256 internal constant PLATFORM_SHIFT = TestConfigConstants.PLATFORM_SHIFT;
    uint256 internal constant LIMIT_POWER_SHIFT = TestConfigConstants.LIMIT_POWER_SHIFT;
    uint256 internal constant SAFE_LINE_UPPER_SHIFT = TestConfigConstants.SAFE_LINE_UPPER_SHIFT;
    uint256 internal constant SAFE_LINE_LOWER_SHIFT = TestConfigConstants.SAFE_LINE_LOWER_SHIFT;
    uint256 internal constant CONTRACT_TYPE_SHIFT = TestConfigConstants.CONTRACT_TYPE_SHIFT;
    uint256 internal constant RUN_TIME_SHIFT = TestConfigConstants.RUN_TIME_SHIFT;
    uint256 internal constant POWER_SHIFT = TestConfigConstants.POWER_SHIFT;
    uint256 internal constant DISINVEST_CHIPS_SHIFT = TestConfigConstants.DISINVEST_CHIPS_SHIFT;
    uint256 internal constant INVEST_FEE_SHIFT = TestConfigConstants.INVEST_FEE_SHIFT;
    uint256 internal constant DISINVEST_FEE_SHIFT = TestConfigConstants.DISINVEST_FEE_SHIFT;
    uint256 internal constant BUY_FEE_SHIFT = TestConfigConstants.BUY_FEE_SHIFT;
    uint256 internal constant SELL_FEE_SHIFT = TestConfigConstants.SELL_FEE_SHIFT;

    function _pack(uint256 value, uint256 shift) internal pure returns (uint256) {
        return value << shift;
    }

    function _updateRunTime(uint256 cfg) external returns (uint256) {
        return cfg.updateRunTimeConfig();
    }

    function _validFeeSplitConfig() internal pure returns (uint256) {
        return
            _pack(6, LIQUID_SHIFT) |
            _pack(1, OPERATOR_SHIFT) |
            _pack(5, GATE_SHIFT) |
            _pack(8, REFER_SHIFT) |
            _pack(8, CUSTOMER_SHIFT) |
            _pack(2, PLATFORM_SHIFT);
    }

    function test_isvaluegood_and_isnormalgood() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isvaluegood());
        assertTrue(cfg.isnormalgood());
        uint256 valueCfg = cfg.setValueGood(true);
        assertTrue(valueCfg.isvaluegood());
        assertFalse(valueCfg.isnormalgood());
    }

    function test_setValueGood() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.setValueGood(false).isvaluegood());
        assertTrue(cfg.setValueGood(true).isvaluegood());
    }

    function test_isFreeze_and_setFreeze() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isFreeze());
        uint256 frozen = cfg.setFreeze(true);
        assertTrue(frozen.isFreeze());
        assertFalse(frozen.setFreeze(false).isFreeze());
    }

    function test_isPromised_and_setPromised() public pure {
        uint256 cfg = _validFeeSplitConfig();
        assertFalse(cfg.isPromised());
        uint256 promised = cfg.setPromised(true);
        assertTrue(promised.isPromised());
        assertFalse(promised.setPromised(false).isPromised());
    }

    function test_getLiquidFee() public pure {
        assertEq(_pack(1, LIQUID_SHIFT).getLiquidFee(10_000), 1_000);
        assertEq(_pack(6, LIQUID_SHIFT).getLiquidFee(10_000), 6_000);
        assertEq(INITIAL_CONFIG.getLiquidFee(10_000), 6_000);
    }

    function test_getOperatorFee() public pure {
        assertEq(_pack(1, OPERATOR_SHIFT).getOperatorFee(10_000), 200);
        assertEq(INITIAL_CONFIG.getOperatorFee(10_000), 200);
    }

    function test_getGateFee() public pure {
        assertEq(_pack(5, GATE_SHIFT).getGateFee(10_000), 2_000);
        assertEq(INITIAL_CONFIG.getGateFee(10_000), 2_000);
    }

    function test_getReferFee() public pure {
        assertEq(_pack(8, REFER_SHIFT).getReferFee(10_000), 800);
        assertEq(INITIAL_CONFIG.getReferFee(10_000), 800);
    }

    function test_getCustomerFee() public pure {
        assertEq(_pack(8, CUSTOMER_SHIFT).getCustomerFee(10_000), 800);
        assertEq(INITIAL_CONFIG.getCustomerFee(10_000), 800);
    }

    function test_getPlatformFee() public pure {
        assertEq(_pack(2, PLATFORM_SHIFT).getPlatformFee128(10_000), 200);
        assertEq(
            INITIAL_CONFIG.getPlatformFee256(10_000),
            INITIAL_CONFIG.getPlatformFee128(10_000)
        );
    }

    function test_getLimitPower() public pure {
        assertEq(_pack(0, LIMIT_POWER_SHIFT).getLimitPower(), 100);
        assertEq(_pack(2, LIMIT_POWER_SHIFT).getLimitPower(), 200);
        assertEq(INITIAL_CONFIG.getLimitPower(), 200);
    }

    function test_getSafeLineUpper() public pure {
        assertEq(_pack(0, SAFE_LINE_UPPER_SHIFT).getSafeLineUpper(50_000), 50_000);
        assertEq(_pack(80, SAFE_LINE_UPPER_SHIFT).getSafeLineUpper(50_000), 40_000);
        assertEq(INITIAL_CONFIG.getSafeLineUpper(50_000), 50_000);
    }

    function test_getSafeLineLower() public pure {
        assertEq(_pack(0, SAFE_LINE_LOWER_SHIFT).getSafeLineLower(50_000), 50_000);
        assertEq(_pack(60, SAFE_LINE_LOWER_SHIFT).getSafeLineLower(50_000), 30_000);
        assertEq(INITIAL_CONFIG.getSafeLineLower(50_000), 30_000);
    }

    function test_getContractType() public pure {
        assertEq(_pack(0, CONTRACT_TYPE_SHIFT).getContractType(), 0);
        assertEq(_pack(0x3C, CONTRACT_TYPE_SHIFT).getContractType(), 0x3C);
        assertEq(_pack(0x7F, CONTRACT_TYPE_SHIFT).getContractType(), 0x7F);
        assertEq(INITIAL_CONFIG.getContractType(), 0);
    }

    function test_getRunTimeConfig() public pure {
        assertEq(_pack(0, RUN_TIME_SHIFT).getRunTimeConfig(), 0);
        assertEq(_pack(7, RUN_TIME_SHIFT).getRunTimeConfig(), 7);
    }

    function test_updateRunTimeConfig() public {
        uint256 slot = (block.timestamp % 4095) / 10;
        uint256 cfg = _validFeeSplitConfig() | _pack(slot + 1, RUN_TIME_SHIFT);
        uint256 updated = cfg.updateRunTimeConfig();
        assertEq(updated.getRunTimeConfig(), slot);

        uint256 wrongSlot = _validFeeSplitConfig() | _pack(slot, RUN_TIME_SHIFT);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        this._updateRunTime(wrongSlot);
    }

    function test_getPower() public pure {
        assertEq(_pack(0, POWER_SHIFT).getPower(), 100);
        assertEq(_pack(1, POWER_SHIFT).getPower(), 100);
        assertEq(_pack(15, POWER_SHIFT).getPower(), 1_500);
        assertEq(INITIAL_CONFIG.getPower(), 100);
    }

    function test_getDisinvestChips() public pure {
        assertEq(_pack(0, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 10_000);
        assertEq(_pack(10, DISINVEST_CHIPS_SHIFT).getDisinvestChips(10_000), 4_000);
        assertEq(INITIAL_CONFIG.getDisinvestChips(10_000), 2_000);
    }

    function test_getInvestFee() public pure {
        assertEq(_pack(8, INVEST_FEE_SHIFT).getInvestFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getInvestFee(10_000), 8);
    }

    function test_getInvestFullFee() public pure {
        assertEq(_pack(8, INVEST_FEE_SHIFT).getInvestFullFee(9_992), 10_000);
        assertEq(INITIAL_CONFIG.getInvestFullFee(9_992), 10_000);
    }

    function test_getDisinvestFee() public pure {
        assertEq(_pack(8, DISINVEST_FEE_SHIFT).getDisinvestFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getDisinvestFee(10_000), 8);
    }

    function test_getBuyFee() public pure {
        assertEq(_pack(8, BUY_FEE_SHIFT).getBuyFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getBuyFee(10_000), 8);
    }

    function test_getSellFee() public pure {
        assertEq(_pack(8, SELL_FEE_SHIFT).getSellFee(10_000), 8);
        assertEq(INITIAL_CONFIG.getSellFee(10_000), 8);
    }

    function test_updateAdminConfig() public pure {
        uint256 base = INITIAL_CONFIG;
        uint256 adminPatch = (1 << 255) | (3 << 247);
        uint256 merged = base.updateAdminConfig(adminPatch);
        assertTrue(merged.isvaluegood());
        assertEq(merged.getBuyFee(10_000), base.getBuyFee(10_000));
    }

    function test_updateManagerConfig() public pure {
        uint256 base = INITIAL_CONFIG;
        uint256 managerPatch = _validFeeSplitConfig() |
            _pack(1, LIMIT_POWER_SHIFT) |
            _pack(90, SAFE_LINE_LOWER_SHIFT) |
            (1 << 252);
        uint256 merged = base.updateManagerConfig(managerPatch);
        assertEq(merged.getSafeLineLower(50_000), 45_000);
        assertTrue(merged.isFreeze());
        assertEq(merged.getBuyFee(10_000), base.getBuyFee(10_000));
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
        assertEq(merged.getLiquidFee(10_000), base.getLiquidFee(10_000));
    }

    function test_checkGoodConfig_valid() public pure {
        assertTrue(_validFeeSplitConfig().checkGoodConfig());
        assertTrue(INITIAL_CONFIG.checkGoodConfig());
    }

    function test_checkGoodConfig_invalid() public pure {
        uint256 bad = _pack(1, LIQUID_SHIFT);
        assertFalse(bad.checkGoodConfig());
        assertFalse(uint256(0).checkGoodConfig());
    }

    function test_initialConfig_allDefaults() public pure {
        assertTrue(INITIAL_CONFIG.checkGoodConfig());
        assertFalse(INITIAL_CONFIG.isvaluegood());
        assertFalse(INITIAL_CONFIG.isFreeze());
        assertFalse(INITIAL_CONFIG.isPromised());
        assertEq(INITIAL_CONFIG.getLiquidFee(10_000), 6_000);
        assertEq(INITIAL_CONFIG.getLimitPower(), 200);
        assertEq(INITIAL_CONFIG.getSafeLineUpper(50_000), 50_000);
        assertEq(INITIAL_CONFIG.getSafeLineLower(50_000), 30_000);
        assertEq(INITIAL_CONFIG.getPower(), 100);
        assertEq(INITIAL_CONFIG.getDisinvestChips(10_000), 2_000);
        assertEq(INITIAL_CONFIG.getBuyFee(10_000), 8);
    }
}
