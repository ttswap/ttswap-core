// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    lowerprice
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Market view helpers (TASK-P2-001 ~ P2-004).
contract testMarketViews is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant BTC_INVEST = uint128(1 * 10 ** 8);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
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
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
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
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }


    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    // ── TASK-P2-001 ishigher ───────────────────────────────────────────────

    function testIshigher_comparePrices() public {
        S_GoodTmpState memory usdtState = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory btcState = market.getGoodState(btcGoodId);

        uint256 usdtRatio = toTTSwapUINT256(
            usdtState.investState.amount1(),
            usdtState.currentState.amount1()
        );
        uint256 btcRatio = toTTSwapUINT256(
            btcState.investState.amount1(),
            btcState.currentState.amount1()
        );

        uint256 compare = toTTSwapUINT256(1, 1);
        bool libResult = lowerprice(usdtRatio, btcRatio, compare);
        assertEq(
            market.ishigher(usdtGoodId, btcGoodId, compare),
            libResult,
            "ishigher matches lowerprice"
        );
        assertTrue(btcState.investState.amount1() > usdtState.investState.amount1(), "btc pricier");
    }

    // ── TASK-P2-002 getRecentGoodState ─────────────────────────────────────

    function testGetRecentGoodState() public {
        (uint256 s1, uint256 s2) = market.getRecentGoodState(usdtGoodId, btcGoodId);

        S_GoodTmpState memory usdtState = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory btcState = market.getGoodState(btcGoodId);

        assertEq(
            s1,
            toTTSwapUINT256(
                usdtState.investState.amount1(),
                usdtState.currentState.amount1()
            ),
            "usdt packed state"
        );
        assertEq(
            s2,
            toTTSwapUINT256(
                btcState.investState.amount1(),
                btcState.currentState.amount1()
            ),
            "btc packed state"
        );
    }

    // ── TASK-P2-003 queryCommission view ─────────────────────────────────────

    function testQueryCommission_view_zeroAndAccrued() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;

        assertEq(market.queryCommission(ids, users[3])[0], 0, "no commission initially");

        vm.startPrank(users[1]);
        _warpToFreshRunSlot();
        btc.approve(address(market), BTC_INVEST);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[1]
        );
        _snapMarket("investGood_queryCommission_setup");
        market.disinvestProof(
            _proofId(users[1], btcGoodId),
            BTC_INVEST / 4,
            users[3],
            users[1],
            defaultdata
        );
        _snapMarket("disinvestProof_queryCommission_setup");
        vm.stopPrank();

        assertGt(market.queryCommission(ids, users[3])[0], 1, "gate commission accrued");
        assertGt(market.queryCommission(ids, address(0))[0], 1, "platform commission accrued");
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }
}
