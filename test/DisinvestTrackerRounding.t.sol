// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression test for issue #310: `investGood` tops up the
///         `goodConfig.amount1` (`virtualQty`) tracker by
///         `investQuantity - netDeposit`, while `disinvestGood` removes
///         `proofInvest0 - proofInvest1`. The proof used to store
///         `investQuantity * 100 / enpower` (recomputed "real" qty) which can
///         differ from the net deposit by wei when `enpower` is not a multiple
///         of 100, so a full disinvest underflowed the tracker with
///         `TTSwapUINT256SubOverflow`.
contract DisinvestTrackerRounding is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
    }

    // ── helpers ────────────────────────────────────────────────────────────

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

    /// @dev Mirrors `L_Good.getInvestPower` for off-chain assertion.
    function _enpower(uint256 goodId) internal view returns (uint128) {
        S_GoodTmpState memory s = market.getGoodState(goodId);
        uint256 cfg = s.goodConfig;
        uint128 maxpower = cfg.getPower();
        uint128 virtualQty = cfg.amount1();
        uint128 currentQ = s.currentState.amount1() - virtualQty;
        uint128 investQty = s.currentState.amount0();
        uint128 limit;
        if (currentQ < investQty) {
            limit = (currentQ * maxpower) / investQty;
        } else {
            limit = (investQty * maxpower) / currentQ;
        }
        return limit < 100 ? 100 : limit;
    }

    function _swapUsdtForBtc(address trader, uint128 usdtIn) internal {
        _warpToFreshRunSlot();
        vm.prank(trader);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(usdtIn, 1),
            trader,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    /// @dev Smallest gross deposit whose net quantity makes the legacy proof
    ///         rounding (`investQuantity * 100 / enpower`) differ from the net
    ///         deposit — the exact desync that bricked full disinvests.
    function _findMismatchedGross(uint256 cfg, uint128 enpower)
        internal
        pure
        returns (uint128 gross)
    {
        for (uint256 g = 5_000; g < 20_000_000; g++) {
            uint128 fee = cfg.getInvestFee(uint128(g));
            uint128 net = uint128(g) - fee;
            uint128 iq = (net * enpower) / 100;
            uint128 real = (iq * 100) / enpower;
            if (real < net) return uint128(g);
        }
        revert("no mismatched gross found");
    }

    // ── regression ─────────────────────────────────────────────────────────

    function test_fullDisinvest_afterSwap_nonRoundPower() public {
        // Raise the good-owner power cap to the manager limit (200).
        vm.startPrank(users[1]);
        market.modifyGoodByGoodOwner(
            btcGoodId,
            uint256(2) << TestConfigConstants.POWER_SHIFT,
            users[1],
            defaultdata
        );
        vm.stopPrank();

        // Swap USDT -> BTC to skew `current_quantity` vs `invest_quantity` so
        // `getInvestPower` returns a non-multiple-of-100 leverage factor.
        deal(address(usdt), users[2], 500 * 10 ** 6, false);
        vm.prank(users[2]);
        usdt.approve(address(market), type(uint256).max);
        uint128 enpower;
        for (uint256 i; i < 8; i++) {
            _swapUsdtForBtc(users[2], uint128(10 * 10 ** 6) << i);
            enpower = _enpower(btcGoodId);
            if (enpower % 100 != 0) break;
        }
        require(enpower % 100 != 0, "could not reach non-round enpower");

        uint256 cfg = market.getGoodState(btcGoodId).goodConfig;
        uint128 virtualQtyBefore = cfg.amount1();
        uint128 gross = _findMismatchedGross(cfg, enpower);

        deal(address(btc), users[2], 20 * gross, false);
        vm.startPrank(users[2]);
        btc.approve(address(market), gross);
        _warpToFreshRunSlot();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, gross),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();

        uint256 proofId = S_ProofKey({owner: users[2], currentgood: btcGoodId})
            .toId();
        uint128 shares = market.getProofState(proofId).shares.amount0();
        assertGt(shares, 0, "invest minted shares");

        // Full exit: on the unfixed code this reverts with
        // `TTSwapUINT256SubOverflow` inside `L_Good.disinvestGood`.
        _warpToFreshRunSlot();
        vm.prank(users[2]);
        market.disinvestProof(proofId, shares, address(0), users[2], defaultdata);

        // The virtualQty tracker must return to its pre-invest value.
        uint256 cfgAfter = market.getGoodState(btcGoodId).goodConfig;
        assertEq(
            cfgAfter.amount1(),
            virtualQtyBefore,
            "virtualQty tracker not restored after full disinvest"
        );
    }
}
