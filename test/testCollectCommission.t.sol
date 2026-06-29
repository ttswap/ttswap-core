// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice v2.0 `queryCommission` / `collectCommission` integration tests.
contract testCollectCommission is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    bytes32 internal constant COLLECT_TOPIC =
        keccak256("e_collectcommission(uint256[],uint256[],address)");

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);

    uint128 internal constant BTC_INVEST = uint128(1 * 10 ** 8);
    uint128 internal constant USDT_USER_INVEST = uint128(10_000 * 10 ** 6);
    uint128 internal constant USDT_SWAP_IN = uint128(50 * 10 ** 6);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    address internal gate;

    function setUp() public override {
        BaseSetup.setUp();
        gate = users[3];
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);

        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);

        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);
        vm.stopPrank();
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }


    function _goodIds(uint256 a, uint256 b) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
    }

    function _singleId(uint256 id) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = id;
    }

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 1000000);
        usdt.approve(address(market), qty);
        T_GoodKey memory key = _usdtKey();
        market.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initBtcGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 20 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
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


    function _investBtc(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        btc.approve(address(market), qty);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _investUsdt(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        usdt.approve(address(market), qty);
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _partialShares(uint256 proofId) internal view returns (uint128) {
        return _partialDisinvestShares(proofId);
    }

    /// @dev Disinvest with gate accrues gate + platform commission on the good.
    function _disinvestWithGate(
        address trader,
        uint256 goodId,
        address gate_
    ) internal {
        uint256 proofId = _proofId(trader, goodId);
        _warpToFreshRunSlot();
        market.disinvestProof(
            proofId,
            _partialShares(proofId),
            gate_,
            trader,
            defaultdata
        );
    }

    function _query(uint256[] memory ids, address recipient)
        internal
        returns (uint256[] memory)
    {
        return market.queryCommission(ids, recipient);
    }

    function _collect(address trader, uint256[] memory ids) internal {
        market.collectCommission(ids, trader, defaultdata);
    }

    function _accrueBtcGateCommission() internal {
        vm.startPrank(users[1]);
        _disinvestWithGate(users[1], btcGoodId, gate);
        vm.stopPrank();
    }

    // ── query ──────────────────────────────────────────────────────────────

    function testQueryCommission_gate_afterDisinvest() public {
        _accrueBtcGateCommission();

        uint256[] memory fees = _query(_singleId(btcGoodId), gate);
        assertGt(fees[0], 1, "gate commission accrued");
    }

    function testQueryCommission_platform_afterDisinvest() public {
        _accrueBtcGateCommission();

        uint256[] memory fees = _query(_singleId(btcGoodId), address(0));
        assertGt(fees[0], 1, "platform commission accrued");
    }

    function testQueryCommission_multiGood() public {
        vm.startPrank(users[2]);
        deal(address(usdt), users[2], 20 * USDT_USER_INVEST, false);
        usdt.approve(address(market), type(uint256).max);
        _investUsdt(users[2], USDT_USER_INVEST);
        _disinvestWithGate(users[2], usdtGoodId, gate);
        vm.stopPrank();

        _accrueBtcGateCommission();

        uint256[] memory fees = _query(_goodIds(usdtGoodId, btcGoodId), gate);
        assertGt(fees[0], 1, "usdt gate commission");
        assertGt(fees[1], 1, "btc gate commission");
    }

    // ── collect happy path ─────────────────────────────────────────────────

    function testCollectCommission_gate_singleGood() public {
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        uint256 btcBefore = btc.balanceOf(gate);
        uint256[] memory before_ = _query(_singleId(btcGoodId), gate);

        _collect(gate, _singleId(btcGoodId));
        snapLastCall("collect_commission_gate_btc");

        assertGt(btc.balanceOf(gate), btcBefore, "gate received btc");
        uint256[] memory after_ = _query(_singleId(btcGoodId), gate);
        assertEq(after_[0], 1, "sentinel 1 remains");
        assertLt(after_[0], before_[0], "commission drained");
        vm.stopPrank();
    }

    function testCollectCommission_gate_multiGood() public {
        vm.startPrank(users[2]);
        deal(address(usdt), users[2], 20 * USDT_USER_INVEST, false);
        usdt.approve(address(market), type(uint256).max);
        _investUsdt(users[2], USDT_USER_INVEST);
        _disinvestWithGate(users[2], usdtGoodId, gate);
        vm.stopPrank();
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        uint256 usdtBefore = usdt.balanceOf(gate);
        uint256 btcBefore = btc.balanceOf(gate);

        _collect(gate, _goodIds(usdtGoodId, btcGoodId));
        snapLastCall("collect_commission_gate_multi");

        assertGt(usdt.balanceOf(gate), usdtBefore, "gate received usdt");
        assertGt(btc.balanceOf(gate), btcBefore, "gate received btc");
        vm.stopPrank();
    }

    function testCollectCommission_marketAdmin_platform() public {
        _accrueBtcGateCommission();

        vm.startPrank(marketcreator);
        uint256[] memory before_ = _query(_singleId(btcGoodId), address(0));
        assertGt(before_[0], 1, "platform pool has balance");

        _collect(marketcreator, _singleId(btcGoodId));
        snapLastCall("collect_commission_admin_platform");

        uint256[] memory after_ = _query(_singleId(btcGoodId), address(0));
        assertEq(after_[0], 1, "platform sentinel");
        vm.stopPrank();
    }

    function testCollectCommission_owner_operatorFee() public {
        vm.startPrank(users[2]);
        deal(address(btc), users[2], 10 * BTC_INVEST, false);
        btc.approve(address(market), type(uint256).max);
        _investBtc(users[2], BTC_INVEST);

        usdt.mint(users[2], 1000000);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(USDT_SWAP_IN, 0),
            users[4],
            defaultdata,
            users[2],
            defaultdata,
            0
        );

        _disinvestWithGate(users[2], btcGoodId, gate);
        vm.stopPrank();

        vm.startPrank(users[1]);
        uint256[] memory before_ = _query(_singleId(btcGoodId), users[1]);
        if (before_[0] > 1) {
            uint256 btcBefore = btc.balanceOf(users[1]);
            _collect(users[1], _singleId(btcGoodId));
            assertGt(btc.balanceOf(users[1]), btcBefore, "owner collected fee");
            assertEq(_query(_singleId(btcGoodId), users[1])[0], 1, "owner sentinel");
        }
        vm.stopPrank();
    }

    function testCollectCommission_idempotent() public {
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        _collect(gate, _singleId(btcGoodId));
        uint256 balAfterFirst = btc.balanceOf(gate);
        _collect(gate, _singleId(btcGoodId));
        assertEq(btc.balanceOf(gate), balAfterFirst, "second collect no payout");
        vm.stopPrank();
    }

    function testCollectCommission_zeroBalance_ok() public {
        vm.startPrank(users[2]);
        uint256 before_ = btc.balanceOf(users[2]);
        _collect(users[2], _singleId(btcGoodId));
        assertEq(btc.balanceOf(users[2]), before_, "no commission no transfer");
        vm.stopPrank();
    }

    function testCollectCommission_emptyArray() public {
        vm.startPrank(gate);
        uint256[] memory empty = new uint256[](0);
        _collect(gate, empty);
        vm.stopPrank();
    }

    function testCollectCommission_emitsEvent() public {
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        vm.recordLogs();
        _collect(gate, _singleId(btcGoodId));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == COLLECT_TOPIC) {
                found = true;
                break;
            }
        }
        assertTrue(found, "e_collectcommission emitted");
        vm.stopPrank();
    }

    // ── revert guards ──────────────────────────────────────────────────────

    function testCollectCommission_revert_traderMismatch() public {
        vm.startPrank(gate);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.collectCommission(_singleId(btcGoodId), users[2], defaultdata);
        vm.stopPrank();
    }

    function testCollectCommission_revert_tooManyGoods() public {
        uint256[] memory ids = new uint256[](101);
        for (uint256 i = 0; i < 101; i++) {
            ids[i] = btcGoodId;
        }
        vm.startPrank(gate);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 21));
        _collect(gate, ids);
        vm.stopPrank();
    }

    function testQueryCommission_revert_tooManyGoods() public {
        uint256[] memory ids = new uint256[](101);
        for (uint256 i = 0; i < 101; i++) {
            ids[i] = btcGoodId;
        }
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 21));
        market.queryCommission(ids, gate);
    }

    // ── referral path (TASK-P1-008) ────────────────────────────────────────

    function testCollectCommission_referralPath() public {
        address trader = users[2];
        address referral = users[4];

        vm.startPrank(trader);
        deal(address(btc), trader, 10 * BTC_INVEST, false);
        btc.approve(address(market), type(uint256).max);
        _investBtc(trader, BTC_INVEST);

        usdt.mint(trader, 1000000);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(USDT_SWAP_IN, 0),
            referral,
            defaultdata,
            trader,
            defaultdata,
            0
        );
        assertEq(tts_token.getreferral(trader), referral, "referral linked");

        _disinvestWithGate(trader, btcGoodId, address(0));
        vm.stopPrank();

        uint256[] memory fees = _query(_singleId(btcGoodId), referral);
        assertGt(fees[0], 1, "referral commission accrued");

        vm.startPrank(referral);
        uint256 btcBefore = btc.balanceOf(referral);
        _collect(referral, _singleId(btcGoodId));
        snapLastCall("collect_commission_referral");

        assertGt(btc.balanceOf(referral), btcBefore, "referral received btc");
        assertEq(_query(_singleId(btcGoodId), referral)[0], 1, "referral sentinel");
        vm.stopPrank();
    }

    function testCollectCommission_duplicateGoodIds() public {
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        uint256 btcBefore = btc.balanceOf(gate);
        uint256[] memory dup = new uint256[](2);
        dup[0] = btcGoodId;
        dup[1] = btcGoodId;
        _collect(gate, dup);
        assertGt(btc.balanceOf(gate), btcBefore, "first entry pays out");
        assertEq(_query(_singleId(btcGoodId), gate)[0], 1, "sentinel after duplicate pass");
        vm.stopPrank();
    }

    function testCollectCommission_oneUnitSentinelNotWithdrawn() public {
        _accrueBtcGateCommission();

        vm.startPrank(gate);
        uint256 btcBefore = btc.balanceOf(gate);
        uint256[] memory fees = _query(_singleId(btcGoodId), gate);
        assertGt(fees[0], 1, "accrued above sentinel");
        _collect(gate, _singleId(btcGoodId));
        assertEq(_query(_singleId(btcGoodId), gate)[0], 1, "sentinel remains");
        assertEq(btc.balanceOf(gate), btcBefore + fees[0] - 1, "only above sentinel moved");
        vm.stopPrank();
    }

    function testQueryCommission_zeroRecipientPlatform() public {
        _accrueBtcGateCommission();
        uint256[] memory fees = _query(_singleId(btcGoodId), address(0));
        assertGt(fees[0], 1, "platform pool tracked at zero address key");
    }
}
