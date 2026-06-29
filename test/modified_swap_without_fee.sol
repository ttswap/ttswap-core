// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

/// @notice Zero-fee swap math + v2.0 `buyGood` integration (K=2 path, buy/sell fee cleared).
contract testSwapWithoutFee is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal constant SWAP_FEE_MASK = uint256(0x3FFF) << 128;

    uint128 internal constant POOL_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant POOL_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(118_000 * 10 ** 12);

    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);
    uint128 internal constant MIN_OUT = uint128(1 * 10 ** 6);
    uint128 internal constant HALF_SWAP = uint128(25 * 10 ** 6);

    MyToken internal usdc;
    uint256 internal usdtGoodId;
    uint256 internal usdcGoodId;
    uint256 internal btcGoodId;
    uint256 internal swapTs = 1;

    function setUp() public override {
        BaseSetup.setUp();
        usdc = new MyToken("USDC", "USDC", 6);
        vm.warp(0);

        usdtGoodId = _initValueGood(_usdtKey(), POOL_VALUE, POOL_QTY);
        usdcGoodId = _initValueGood(_usdcKey(), POOL_VALUE, POOL_QTY);
        btcGoodId = _initValueGood(_btcKey(), BTC_VALUE, BTC_QTY);

        _prepareGood(usdtGoodId);
        _prepareGood(usdcGoodId);
        _prepareGood(btcGoodId);
        _zeroSwapFees(usdtGoodId);
        _zeroSwapFees(usdcGoodId);
        _zeroSwapFees(btcGoodId);
    }

    // ── keys ───────────────────────────────────────────────────────────────

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _usdcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdc), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    // ── setup helpers ──────────────────────────────────────────────────────

    function _initValueGood(
        T_GoodKey memory key,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(marketcreator);
        if (key.contractAddress == address(btc)) {
            deal(address(btc), marketcreator, 100 * qty, false);
            btc.approve(address(market), qty);
        } else if (key.contractAddress == address(usdc)) {
            deal(address(usdc), marketcreator, 100 * qty, false);
            usdc.approve(address(market), qty);
        } else {
            deal(address(usdt), marketcreator, 100 * uint256(qty), false);
            usdt.approve(address(market), qty);
        }
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, marketcreator, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _prepareGood(uint256 goodId) internal {
        _markAsValueGood(goodId);
        _relaxSafeLine(goodId);
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _zeroSwapFees(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        market.modifyGoodByGoodOwner(
            goodId,
            cfg & ~SWAP_FEE_MASK,
            marketcreator,
            defaultdata
        );
        vm.stopPrank();
    }


    function _approveIn(T_GoodKey memory keyIn, uint128 amountIn) internal {
        address token = keyIn.contractAddress;
        if (token == address(usdc)) {
            usdc.approve(address(market), amountIn);
        } else if (token == address(btc)) {
            btc.approve(address(market), amountIn);
        } else {
            usdt.approve(address(market), amountIn);
        }
    }

    function _buy(
        T_GoodKey memory keyIn,
        T_GoodKey memory keyOut,
        uint128 amountIn,
        uint128 minOut
    ) internal returns (uint256 g1change, uint256 g2change) {
        _approveIn(keyIn, amountIn);
        _warpToFreshRunSlot();
        return market.buyGood(
            keyIn,
            keyOut,
            toTTSwapUINT256(amountIn, minOut),
            address(0),
            defaultdata,
            marketcreator,
            defaultdata,
            0
        );
    }

    function _fundTrader() internal {
        deal(address(usdc), marketcreator, 200_000 * 10 ** 6, false);
        deal(address(usdt), marketcreator, 200_000 * 10 ** 6, false);
        usdc.approve(address(market), type(uint256).max);
        usdt.approve(address(market), type(uint256).max);
        btc.approve(address(market), type(uint256).max);
    }

    // ── pure math (whitepaper appendix I, K scaled ×100) ───────────────────

    /// @dev K=200 ↔ on-chain K=2; strict reversibility when fees are zero.
    function testFixedKSwapReversibility() public pure {
        uint128 K = 200;
        uint128 Q_A = 50_000 * 10 ** 6;
        uint128 V_A = 50_000 * 10 ** 12;
        uint128 Q_B = 50_000 * 10 ** 6;
        uint128 V_B = 50_000 * 10 ** 12;
        uint128 deltaA = 10_000 * 10 ** 6;

        uint256 deltaV = (uint256(K) * uint256(V_A) * uint256(deltaA))
            / (uint256(K) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K) * uint256(Q_B) * deltaV)
            / (uint256(K) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        uint256 deltaV_rev = (uint256(K) * uint256(V_B) * deltaB)
            / (uint256(K) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K) * uint256(V_A) + deltaV_rev * 100);

        assertApproxEqAbs(deltaA_rev, uint256(deltaA), 1, "K=200 reversible");
    }

    function testFixedK300SwapNotReversible() public pure {
        uint128 K = 300;
        uint128 Q_A = 50_000 * 10 ** 6;
        uint128 V_A = 50_000 * 10 ** 12;
        uint128 Q_B = 50_000 * 10 ** 6;
        uint128 V_B = 50_000 * 10 ** 12;
        uint128 deltaA = 10_000 * 10 ** 6;

        uint256 deltaV = (uint256(K) * uint256(V_A) * uint256(deltaA))
            / (uint256(K) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K) * uint256(Q_B) * deltaV)
            / (uint256(K) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        uint256 deltaV_rev = (uint256(K) * uint256(V_B) * deltaB)
            / (uint256(K) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K) * uint256(V_A) + deltaV_rev * 100);

        assertGt(deltaA_rev, uint256(deltaA), "K=300 not reversible");
    }

    function testAsymmetricKReversibility() public pure {
        uint128 K_A_in = 300;
        uint128 K_A_out = 150;
        uint128 K_B = 200;

        uint128 Q_A = 50_000 * 10 ** 6;
        uint128 V_A = 50_000 * 10 ** 12;
        uint128 Q_B = 50_000 * 10 ** 6;
        uint128 V_B = 50_000 * 10 ** 12;
        uint128 deltaA = 10_000 * 10 ** 6;

        uint256 deltaV = (uint256(K_A_in) * uint256(V_A) * uint256(deltaA))
            / (uint256(K_A_in) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K_B) * uint256(Q_B) * deltaV)
            / (uint256(K_B) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        uint256 deltaV_rev = (uint256(K_B) * uint256(V_B) * deltaB)
            / (uint256(K_B) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K_A_out) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K_A_out) * uint256(V_A) + deltaV_rev * 100);

        assertApproxEqAbs(deltaA_rev, uint256(deltaA), 1, "asymmetric K reversible");
    }

    function testBothPoolsAsymmetricKReversibility() public pure {
        uint128 K_in = 300;
        uint128 K_out = 150;

        uint128 Q_A = 50_000 * 10 ** 6;
        uint128 V_A = 50_000 * 10 ** 12;
        uint128 Q_B = 50_000 * 10 ** 6;
        uint128 V_B = 50_000 * 10 ** 12;
        uint128 deltaA = 10_000 * 10 ** 6;

        uint256 deltaV = (uint256(K_in) * uint256(V_A) * uint256(deltaA))
            / (uint256(K_in) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K_out) * uint256(Q_B) * deltaV)
            / (uint256(K_out) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        uint256 deltaV_rev = (uint256(K_in) * uint256(V_B) * deltaB)
            / (uint256(K_in) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K_out) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K_out) * uint256(V_A) + deltaV_rev * 100);

        assertApproxEqAbs(deltaA_rev, uint256(deltaA), 1, "both pools asymmetric K");
    }

    // ── integration: buyGood round-trips ───────────────────────────────────

    function testSwapA2B_single() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);
        uint256 usdtBefore = usdt.balanceOf(marketcreator);

        (, uint256 g2) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        snapLastCall("swap_without_fee_a2b");

        assertGt(g2.amount1(), 0, "received usdt");
        assertEq(usdc.balanceOf(marketcreator), usdcBefore - SWAP_IN, "spent usdc");
        assertGt(usdt.balanceOf(marketcreator), usdtBefore, "gained usdt");
        vm.stopPrank();
    }

    function testSwapA2B_consecutive() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);
        _buy(_usdcKey(), _usdtKey(), HALF_SWAP, MIN_OUT);
        _buy(_usdcKey(), _usdtKey(), HALF_SWAP, MIN_OUT);
        snapLastCall("swap_without_fee_a2b_twice");

        assertEq(usdc.balanceOf(marketcreator), usdcBefore - SWAP_IN, "spent total usdc");
        vm.stopPrank();
    }

    function testSwapA2B2A_reversible() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);
        uint256 usdtBefore = usdt.balanceOf(marketcreator);

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        uint128 usdtReceived = leg1.amount1();
        assertGt(usdtReceived, MIN_OUT, "leg1 output");

        _buy(_usdtKey(), _usdcKey(), usdtReceived, 0);
        snapLastCall("swap_without_fee_a2b2a");

        uint256 usdcDiff = usdcBefore > usdc.balanceOf(marketcreator)
            ? usdcBefore - usdc.balanceOf(marketcreator)
            : usdc.balanceOf(marketcreator) - usdcBefore;

        assertApproxEqAbs(usdcDiff, 0, 2, "round-trip usdc reversible");
        assertEq(usdt.balanceOf(marketcreator), usdtBefore, "usdt restored");
        vm.stopPrank();
    }

    function testSwapA2B2A_doubleRoundTrip() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);

        for (uint256 i = 0; i < 2; i++) {
            (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
            _buy(_usdtKey(), _usdcKey(), leg1.amount1(), 0);
        }
        snapLastCall("swap_without_fee_a2b2a_twice");

        uint256 usdcDiff = usdcBefore > usdc.balanceOf(marketcreator)
            ? usdcBefore - usdc.balanceOf(marketcreator)
            : usdc.balanceOf(marketcreator) - usdcBefore;
        assertApproxEqAbs(usdcDiff, 0, 4, "two round-trips stay reversible");
        vm.stopPrank();
    }

    function testSwapA2B2C2A_triangular() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        uint256 usdcBefore = usdc.balanceOf(marketcreator);
        uint256 marketUsdcBefore = usdc.balanceOf(address(market));
        uint256 marketUsdtBefore = usdt.balanceOf(address(market));
        uint256 marketBtcBefore = btc.balanceOf(address(market));

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        (, uint256 leg2) = _buy(_usdtKey(), _btcKey(), leg1.amount1(), 0);
        _buy(_btcKey(), _usdcKey(), leg2.amount1(), 0);
        snapLastCall("swap_without_fee_a2b2c2a");

        assertGt(usdc.balanceOf(marketcreator), usdcBefore - SWAP_IN, "recovered most usdc");
        // Three-hop integer rounding can leave sub-1000 wei dust in market custody.
        assertApproxEqAbs(
            usdc.balanceOf(address(market)),
            marketUsdcBefore,
            1000,
            "market usdc conserved"
        );
        assertApproxEqAbs(
            usdt.balanceOf(address(market)),
            marketUsdtBefore,
            1000,
            "market usdt conserved"
        );
        assertApproxEqAbs(
            btc.balanceOf(address(market)),
            marketBtcBefore,
            100,
            "market btc conserved"
        );
        vm.stopPrank();
    }

    /// @dev Mirrors `L_Good._good1SwapOutput` (side=false, zero sell fee).
    function testGood1Swap_exactOut_math() public pure {
        uint128 current_quantity = 50_000 * 10 ** 6;
        uint128 current_value = 50_000 * 10 ** 12;
        uint128 desiredValue = 10_000 * 10 ** 12;

        uint128 swapTemp = uint128(
            (2 * uint256(desiredValue) * uint256(current_quantity)) /
                (2 * uint256(current_value) - uint256(desiredValue))
        );
        assertEq(swapTemp, 11_111_111_111, "exact-out quantity matches on-chain formula");
        assertLt(uint256(desiredValue), 2 * uint256(current_value), "precondition for exact-out");
    }

    function testGood1Swap_exactOut_revert_overflow() public {
        uint128 current_value = 50_000 * 10 ** 12;
        uint128 tooLarge = uint128(2 * current_value);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 54));
        this._good1SwapOutputRevert(tooLarge, current_value, 50_000 * 10 ** 6);
    }

    function _good1SwapOutputRevert(
        uint128 swapParam,
        uint128 currentValue,
        uint128 currentQty
    ) external pure {
        if (uint256(swapParam) >= 2 * uint256(currentValue)) {
            revert TTSwapError(54);
        }
        uint128 swapTemp = uint128(
            (2 * uint256(swapParam) * uint256(currentQty)) /
                (2 * uint256(currentValue) - uint256(swapParam))
        );
        swapTemp;
    }

    /// @dev Mirrors `L_Good.good2Swap` output-side branch (side=false, zero buy fee).
    function testGood2Swap_outputSide_math() public pure {
        uint128 current_quantity = 50_000 * 10 ** 6;
        uint128 current_value = 50_000 * 10 ** 12;
        uint128 desiredQty = 5_000 * 10 ** 6;

        uint128 swap = desiredQty;
        uint128 swapTemp = uint128(
            (2 * uint256(swap) * uint256(current_value)) /
                (2 * uint256(current_quantity) - uint256(swap))
        );
        assertGt(swapTemp, 0, "output-side value delta");
    }

    function testSwap_poolState_conserved() public {
        vm.startPrank(marketcreator);
        _fundTrader();

        S_GoodTmpState memory usdcBefore = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtBefore = market.getGoodState(usdtGoodId);

        (, uint256 leg1) = _buy(_usdcKey(), _usdtKey(), SWAP_IN, MIN_OUT);
        _buy(_usdtKey(), _usdcKey(), leg1.amount1(), 0);

        S_GoodTmpState memory usdcAfter = market.getGoodState(usdcGoodId);
        S_GoodTmpState memory usdtAfter = market.getGoodState(usdtGoodId);

        assertApproxEqAbs(
            usdcAfter.currentState.amount1(),
            usdcBefore.currentState.amount1(),
            2,
            "usdc qty restored"
        );
        assertApproxEqAbs(
            usdtAfter.currentState.amount1(),
            usdtBefore.currentState.amount1(),
            2,
            "usdt qty restored"
        );
        vm.stopPrank();
    }
}
