// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Native ETH value-good leverage (power) without invest fee.
/// @dev Isolated contract — only one native pool per market deployment.
contract testPowerWithoutFee is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal constant POWER_SHIFT = TestConfigConstants.POWER_SHIFT;
    uint256 internal constant LIMIT_POWER_SHIFT = TestConfigConstants.LIMIT_POWER_SHIFT;
    uint256 internal constant INVEST_FEE_SHIFT = 148;

    uint128 internal constant INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant INVEST_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant DISINVEST_SHARES = uint128(10_000 * 10 ** 6);

    /// @dev Stored field 5 → getPower/getLimitPower = 500 (5× virtual mint).
    uint256 internal constant POWER_FIELD = 5;

    uint256 internal nativeValueGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        nativeValueGoodId = _initNativeValueGood(
            marketcreator,
            INIT_VALUE,
            INIT_QTY
        );
        _markAsValueGood(nativeValueGoodId);
        _verifyGood(nativeValueGoodId);
        _setLimitPower(nativeValueGoodId, POWER_FIELD);
        _setOwnerPower(nativeValueGoodId, marketcreator, POWER_FIELD);
        _setOwnerInvestFee(nativeValueGoodId, marketcreator, 0);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _proofId(address owner) internal view returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: nativeValueGoodId}).toId();
    }


    function _initNativeValueGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 20 * qty);
        T_GoodKey memory key = _nativeKey();
        market.initGood{value: qty}(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setLimitPower(uint256 goodId, uint256 field) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << LIMIT_POWER_SHIFT)) |
            (field << LIMIT_POWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerPower(uint256 goodId, address owner, uint256 field) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << POWER_SHIFT)) | (field << POWER_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerInvestFee(uint256 goodId, address owner, uint256 field) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x3f) << INVEST_FEE_SHIFT)) |
            (field << INVEST_FEE_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _investNative(address trader, uint128 qty) internal {
        vm.deal(trader, 20 * qty);
        _warpToFreshRunSlot();
        market.investGood{value: qty}(
            _nativeKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _disinvest(address trader, uint128 shares) internal {
        market.disinvestProof(
            _proofId(trader),
            shares,
            address(0),
            trader,
            defaultdata
        );
    }

    // ── invest with leverage ───────────────────────────────────────────────

    function testInvest_powerWithoutFee_initProof() public view {
        uint256 proofId = _proofId(marketcreator);
        S_ProofState memory proof = market.getProofState(proofId);

        assertEq(proof.shares.amount0(), INIT_QTY, "init shares");
        assertEq(proof.state.amount0(), INIT_VALUE, "init virtual value");
        assertEq(proof.state.amount1(), INIT_VALUE, "init actual value");
        assertEq(proof.invest.amount0(), INIT_QTY, "init virtual qty");
        assertEq(proof.invest.amount1(), INIT_QTY, "init actual qty");
    }

    function testInvest_powerWithoutFee_leverage() public {
        vm.startPrank(marketcreator);
        S_GoodTmpState memory before_ = market.getGoodState(nativeValueGoodId);
        uint256 proofId = _proofId(marketcreator);
        S_ProofState memory proofBefore = market.getProofState(proofId);

        _investNative(marketcreator, INVEST_QTY);
        _snapMarket("power_without_fee_invest");

        S_GoodTmpState memory after_ = market.getGoodState(nativeValueGoodId);
        S_ProofState memory proofAfter = market.getProofState(proofId);

        assertEq(
            market.getGoodState(nativeValueGoodId).goodConfig.getPower(),
            500,
            "power=500"
        );
        assertEq(
            market.getGoodState(nativeValueGoodId).goodConfig.getLimitPower(),
            500,
            "limitPower=500"
        );

        uint128 actualDelta = after_.currentState.amount0() - before_.currentState.amount0();
        uint128 virtualDelta = after_.currentState.amount1() - before_.currentState.amount1();

        assertEq(actualDelta, INVEST_QTY, "full actual deposit");
        assertGt(virtualDelta, actualDelta, "leverage mints extra virtual");
        assertGe(virtualDelta, (actualDelta * 400) / 100, "~5x virtual increment");

        assertGt(proofAfter.shares.amount0(), proofBefore.shares.amount0(), "shares grew");
        assertGt(proofAfter.state.amount0(), proofBefore.state.amount0(), "virtual value grew");
        assertGt(proofAfter.state.amount1(), proofBefore.state.amount1(), "actual value grew");
        assertGt(after_.goodConfig.amount1(), before_.goodConfig.amount1(), "VQ tracked");
        vm.stopPrank();
    }

    // ── disinvest after leveraged invest ───────────────────────────────────

    function testDisinvest_powerWithoutFee_partial() public {
        vm.startPrank(marketcreator);
        _investNative(marketcreator, INVEST_QTY);

        uint256 proofId = _proofId(marketcreator);
        S_ProofState memory proofBefore = market.getProofState(proofId);
        S_GoodTmpState memory goodBefore = market.getGoodState(nativeValueGoodId);
        uint256 ethBefore = marketcreator.balance;

        _disinvest(marketcreator, DISINVEST_SHARES);
        _snapMarket("power_without_fee_disinvest_first");

        S_ProofState memory proofAfter = market.getProofState(proofId);
        S_GoodTmpState memory goodAfter = market.getGoodState(nativeValueGoodId);

        assertGt(marketcreator.balance, ethBefore, "received eth");
        assertLt(proofAfter.shares.amount0(), proofBefore.shares.amount0(), "shares reduced");
        assertLt(goodAfter.currentState.amount1(), goodBefore.currentState.amount1(), "pool virtual down");
        assertLt(goodAfter.goodConfig.amount1(), goodBefore.goodConfig.amount1(), "V reduced");

        _disinvest(marketcreator, DISINVEST_SHARES);
        _snapMarket("power_without_fee_disinvest_second");
        _disinvest(marketcreator, DISINVEST_SHARES);
        _snapMarket("power_without_fee_disinvest_third");

        assertGt(proofAfter.shares.amount0(), DISINVEST_SHARES, "still has shares after first");
        vm.stopPrank();
    }

    function testDisinvest_powerWithoutFee_consecutive() public {
        vm.startPrank(marketcreator);
        _investNative(marketcreator, INVEST_QTY);

        uint256 proofId = _proofId(marketcreator);
        uint128 sharesBefore = market.getProofState(proofId).shares.amount0();
        uint256 ethBefore = marketcreator.balance;

        for (uint256 i = 0; i < 3; i++) {
            _disinvest(marketcreator, DISINVEST_SHARES);
        }
        _snapMarket("power_without_fee_disinvest_x3");

        assertEq(
            market.getProofState(proofId).shares.amount0(),
            sharesBefore - 3 * DISINVEST_SHARES,
            "shares deducted linearly"
        );
        assertGt(marketcreator.balance, ethBefore, "cumulative eth payout");
        vm.stopPrank();
    }
}
