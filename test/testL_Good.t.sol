// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {GoodHarness} from "../src/test/GoodHarness.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {T_GoodKey} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Direct `L_Good` coverage without compiling `TTSwap_Market`.
contract testL_Good is Test {
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    GoodHarness internal h;
    address internal alice;
    address internal gate;
    address internal refer;

    uint128 internal constant QTY = 2_000_000_000_000_000;
    uint128 internal constant VAL = 2_000_000_000_000_000;

    function setUp() public {
        h = new GoodHarness();
        alice = makeAddr("alice");
        gate = makeAddr("gate");
        refer = makeAddr("refer");
        vm.prank(alice);
        h.init(
            1,
            toTTSwapUINT256(VAL, QTY),
            T_GoodKey({ercType: 1, contractAddress: address(0x11), id: 7})
        );
        h.relaxSafeLine(1);
        h.updateOwner(1, _ownerFullExit());
        vm.prank(alice);
        h.init(
            2,
            toTTSwapUINT256(VAL, QTY),
            T_GoodKey({ercType: 1, contractAddress: address(0x22), id: 0})
        );
        h.relaxSafeLine(2);
        h.updateOwner(2, _ownerFullExit());
    }

    function testL_Good_init_andViews() public view {
        assertEq(h.ownerOf(1), alice);
        T_GoodKey memory key = h.toGoodKey(1);
        assertEq(key.ercType, 1);
        assertEq(key.contractAddress, address(0x11));
        assertEq(key.id, 7);
        uint256 st = h.getGoodState(1);
        assertEq(st.amount0(), VAL);
        assertEq(st.amount1(), QTY);
        assertGt(h.getBalanceLimit(1), 0);
        assertEq(h.currentState(1).amount0(), QTY);
        assertEq(h.investState(1).amount1(), VAL);
    }

    function testL_Good_updateConfig_ownerManagerAdminLock() public {
        uint256 ownerPatch = (uint256(1) << TestConfigConstants.POWER_SHIFT) |
            (uint256(0) << TestConfigConstants.DISINVEST_CHIPS_SHIFT);
        h.updateOwner(1, ownerPatch);
        assertEq(h.goodConfig(1).getPower(), 100);

        uint256 tooMuchPower = uint256(15) << TestConfigConstants.POWER_SHIFT;
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 23));
        h.updateOwner(1, tooMuchPower);

        uint256 mgr = _validFeeSplit() | (uint256(1) << TestConfigConstants.LIMIT_POWER_SHIFT);
        h.updateManager(1, mgr);
        assertEq(h.goodConfig(1).getLimitPower(), 100);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 24));
        h.updateManager(1, uint256(1) << TestConfigConstants.LIQUID_SHIFT);

        h.updateAdmin(1, uint256(1) << 255);
        assertTrue(h.goodConfig(1).isvaluegood());

        h.lockGood(1);
        assertTrue(h.goodConfig(1).isFreeze());
    }

    function testL_Good_buyAndPay_crossPool() public {
        uint256 inChange = h.buyInput(1, 1_000_000_000_000);
        assertGt(inChange.amount1(), 0);
        uint256 outChange = h.buyOutput(2, uint128(inChange.amount1()));
        assertGt(outChange.amount1(), 0);

        uint256 payOut = h.payOutput(2, 1_000_000_000);
        assertGt(payOut.amount1(), 0);
        uint256 payIn = h.payInput(1, uint128(payOut.amount1()));
        assertGt(payIn.amount1(), 0);
    }

    function testL_Good_buyInput_revert_tinyPool() public {
        vm.prank(alice);
        h.init(
            9,
            toTTSwapUINT256(5_000, 5_000),
            T_GoodKey({ercType: 1, contractAddress: address(0x99), id: 0})
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.buyInput(9, 100);
    }

    function testL_Good_investThenDisinvest() public {
        L_Good.S_GoodInvestReturn memory inv = h.invest(1, 2_000_000_000_000, 100);
        assertGt(inv.investShare, 0);
        assertGe(inv.investValue, 1_000_000_000_000);

        uint128 shares = uint128(h.proofShares(1).amount0());
        (L_Good.S_GoodDisinvestReturn memory r, ) = h.disinvest(
            1,
            shares / 4,
            address(0),
            address(0),
            alice
        );
        assertGt(r.actualDisinvestQuantity, 0);
        assertGt(h.commissionOf(1, alice), 0);
    }

    function testL_Good_disinvest_dustBurnsAllShares() public {
        uint128 shares = uint128(h.proofShares(1).amount0());
        (L_Good.S_GoodDisinvestReturn memory r, ) = h.disinvest(1, 1, address(0), address(0), alice);
        assertEq(r.shares, shares, "dust closeout burns all");
        assertEq(h.proofShares(1).amount0(), 0);
    }

    function testL_Good_disinvest_feeSplitWithReferral() public {
        h.invest(1, 5_000_000_000_000, 100);
        h.buyInput(1, 50_000_000_000);
        uint128 shares = uint128(h.proofShares(1).amount0()) / 8;
        h.disinvest(1, shares, gate, refer, alice);
        assertGt(h.commissionOf(1, alice), 0);
        assertGt(h.commissionOf(1, refer), 0);
        assertGt(h.commissionOf(1, address(0)), 0);
    }

    function testL_Good_disinvest_gaterNoReferral() public {
        h.invest(1, 5_000_000_000_000, 100);
        h.buyInput(1, 50_000_000_000);
        uint128 shares = uint128(h.proofShares(1).amount0()) / 8;
        h.disinvest(1, shares, gate, address(0), alice);
        assertGt(h.commissionOf(1, alice), 0);
        assertGt(h.commissionOf(1, gate), 0);
    }

    function testL_Good_disinvest_referralNoOwnerNoGater() public {
        h.invest(1, 5_000_000_000_000, 100);
        h.buyInput(1, 50_000_000_000);
        h.setOwner(1, address(0));
        uint128 shares = uint128(h.proofShares(1).amount0()) / 8;
        h.disinvest(1, shares, address(0), refer, alice);
        assertGt(h.commissionOf(1, refer), 0);
        assertGt(h.commissionOf(1, address(0)), 0);
    }

    function testL_Good_disinvest_revert_tooManyShares() public {
        uint128 shares = uint128(h.proofShares(1).amount0());
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 41));
        h.disinvest(1, shares + 1, address(0), address(0), alice);
    }

    function testL_Good_buyInput_chunkedAndSafeline() public {
        uint256 inChange = h.buyInput(1, uint128(QTY / 10));
        assertGt(inChange.amount1(), 0);

        vm.prank(alice);
        h.init(
            3,
            toTTSwapUINT256(VAL, QTY),
            T_GoodKey({ercType: 1, contractAddress: address(0x33), id: 0})
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        h.buyInput(3, 1_000_000_000_000);
    }

    function testL_Good_payInput_revert_tinyValue() public {
        vm.prank(alice);
        h.init(
            4,
            toTTSwapUINT256(5_000, 5_000_000_000_000_000),
            T_GoodKey({ercType: 1, contractAddress: address(0x44), id: 0})
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.payInput(4, 100);
    }

    function testL_Good_invest_revert_dustValueAndZeroShare() public {
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.invest(1, 0, 100);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 38));
        h.invest(1, 10_000, 100);
    }

    function testL_Good_disinvest_revert_chipsAndUnderfee() public {
        uint256 chips20 = _ownerFullExit() |
            (uint256(20) << TestConfigConstants.DISINVEST_CHIPS_SHIFT);
        h.updateOwner(1, chips20);
        uint128 half = uint128(h.proofShares(1).amount0()) / 2;
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 26));
        h.disinvest(1, half, address(0), address(0), alice);

        h.updateOwner(1, _ownerFullExit());
        h.setCurrentState(1, toTTSwapUINT256(1, QTY));
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 34));
        h.disinvest(1, 1_000_000_000_000, address(0), address(0), alice);
    }

    function testL_Good_outputLegs_tinyQAndChunked() public {
        uint256 outChange = h.buyOutput(1, uint128(VAL / 10));
        assertGt(outChange.amount1(), 0);
        uint256 payChange = h.payOutput(2, uint128(QTY / 20));
        assertGt(payChange.amount1(), 0);

        h.setCurrentState(1, toTTSwapUINT256(QTY, 5_000));
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.buyOutput(1, 1);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.payOutput(1, 1);
    }

    function testL_Good_outputSafeline_payInputAndOverflow() public {
        uint256 payIn = h.payInput(2, uint128(VAL / 10));
        assertGt(payIn.amount1(), 0);

        vm.prank(alice);
        h.init(
            5,
            toTTSwapUINT256(VAL, QTY),
            T_GoodKey({ercType: 1, contractAddress: address(0x55), id: 0})
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.buyOutput(5, uint128((VAL * 7) / 10));
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        h.payOutput(5, uint128(QTY / 2));
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        h.payInput(5, uint128(VAL / 10));

        h.updateOwner(1, _ownerFullExit());
        uint256 chips20 = _ownerFullExit() |
            (uint256(20) << TestConfigConstants.DISINVEST_CHIPS_SHIFT);
        h.updateOwner(1, chips20);
        h.setProof(
            1,
            toTTSwapUINT256(1_000, 0),
            toTTSwapUINT256(VAL / 100, VAL / 100),
            toTTSwapUINT256(QTY / 2, QTY / 100)
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 27));
        h.disinvest(1, 1_000, address(0), address(0), alice);

        vm.prank(alice);
        h.init(
            6,
            toTTSwapUINT256(VAL, QTY),
            T_GoodKey({ercType: 1, contractAddress: address(0x66), id: 0})
        );
        h.updateOwner(6, _ownerFullExit());
        h.setCurrentState(6, toTTSwapUINT256(QTY, QTY / 2));
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        h.disinvest(6, 1_000_000_000_000, address(0), address(0), alice);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 18));
        h.invest(1, uint128(uint256(1) << 109), 100);
    }

    function _ownerFullExit() internal pure returns (uint256) {
        return
            (uint256(1) << TestConfigConstants.POWER_SHIFT) |
            (uint256(8) << TestConfigConstants.INVEST_FEE_SHIFT) |
            (uint256(8) << TestConfigConstants.DISINVEST_FEE_SHIFT) |
            (uint256(8) << TestConfigConstants.BUY_FEE_SHIFT) |
            (uint256(8) << TestConfigConstants.SELL_FEE_SHIFT);
    }

    function _validFeeSplit() internal pure returns (uint256) {
        return
            (uint256(6) << TestConfigConstants.LIQUID_SHIFT) |
            (uint256(1) << TestConfigConstants.OPERATOR_SHIFT) |
            (uint256(5) << TestConfigConstants.GATE_SHIFT) |
            (uint256(8) << TestConfigConstants.REFER_SHIFT) |
            (uint256(8) << TestConfigConstants.CUSTOMER_SHIFT) |
            (uint256(2) << TestConfigConstants.PLATFORM_SHIFT);
    }
}
