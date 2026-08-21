// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {TTSwap_Market} from "../../src/TTSwap_Market.sol";
import {S_ProofState, S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";

/// @dev Reentry bot for RT-34: tries to re-spend the native ETH budget while
///      the market is mid-transfer / mid-refund inside one tx.
contract RTRefundReenter {
    using T_GoodKeyLibrary for T_GoodKey;

    TTSwap_Market internal market;
    bool public failDuringTransfer;
    bool public failDuringRefund;
    uint256 internal _payCount;

    constructor(TTSwap_Market _market) {
        market = _market;
    }

    function attack() external payable {
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            market.payGood,
            (
                key,
                key,
                toTTSwapUINT256(0, uint128(msg.value / 2)),
                address(this),
                bytes(""),
                address(this),
                bytes(""),
                0
            )
        );
        market.multicall{value: msg.value}(calls);
    }

    receive() external payable {
        _payCount += 1;
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        // Try to pull 0.25 ether from the native good with NO fresh budget.
        try
            market.payGood(
                key,
                key,
                toTTSwapUINT256(0, 0.25 ether),
                address(this),
                bytes(""),
                address(this),
                bytes(""),
                0
            )
        {} catch {
            if (_payCount == 1) failDuringTransfer = true;
            else failDuringRefund = true;
        }
    }
}

/// @notice Sixth-wave red team. Fresh hunts on current tree:
///         RT-32 zombie shares after dust closeout (double claim),
///         RT-33 first-stake-after-full-unwind div0 (negative),
///         RT-34 multicall native refund reentry (negative).
contract RT_SixthWave is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);

    address internal attacker;
    address internal victim;
    uint256 internal usdtGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        attacker = users[4];
        victim = users[5];
        vm.warp(100);
        usdtGoodId = _initUsdt(marketcreator, USDT_INIT_VALUE, USDT_INIT_QTY);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _initUsdt(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(usdt), owner, 100 * uint256(qty), false);
        usdt.approve(address(market), type(uint256).max);
        market.initGood(
            _usdtKey(),
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = _usdtKey().toId();
        vm.stopPrank();
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-32 (FIXED): dust closeout burns proofShares0 (full position) when a
    // partial request is dust-valued. No leftover zero-backed shares.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT32_partial_dust_burns_all_shares_no_zombies() public {
        // 1. Attacker takes a small position: 2 USDT.
        uint128 investQty = uint128(2_000_000);
        deal(address(usdt), attacker, investQty, false);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, investQty),
            defaultdata,
            defaultdata,
            attacker
        );
        vm.stopPrank();

        uint256 proofId = _proofId(attacker, usdtGoodId);
        S_ProofState memory p0 = market.getProofState(proofId);
        uint128 shares = p0.shares.amount0();
        emit log_named_uint("RT32 attacker shares", shares);

        // 2. Pool principal per share appreciates ~4x (welfare donation).
        uint128 welfare = uint128(150_000 * 10 ** 6);
        deal(address(usdt), victim, welfare, false);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        market.goodWelfare(usdtGoodId, welfare, defaultdata, victim, defaultdata);
        vm.stopPrank();

        // 3. Partial dust-valued slice force-closes the WHOLE position
        //    (shares burned = proofShares0). No zombies.
        uint128 slice = 600_000;
        uint256 balBefore = usdt.balanceOf(attacker);
        vm.prank(attacker);
        market.disinvestProof(proofId, slice, address(0), attacker, defaultdata);
        uint256 payout = usdt.balanceOf(attacker) - balBefore;
        emit log_named_uint("RT32 dust-slice force-close payout", payout);

        S_ProofState memory p1 = market.getProofState(proofId);
        assertEq(p1.shares, 0, "all shares burned, no zombies");
        assertEq(p1.invest, 0, "invest zeroed");
        assertEq(p1.state, 0, "state zeroed");
        assertGt(payout, investQty, "fair full-exit payout, not slice-only");

        // 4. Nothing left to claim a second time.
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 41));
        market.disinvestProof(proofId, 1, address(0), attacker, defaultdata);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-33: stake/unstake full unwind, then re-stake. If pool1 could be
    // non-zero while stake1==0, the next stake would div0-revert (DoS).
    // Negative result expected: full exits zero both legs together.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT33_first_stake_after_full_unwind_no_div0() public {
        _markAsValueGood(usdtGoodId);

        uint128 investQty = uint128(100 * 10 ** 6);
        deal(address(usdt), attacker, 2 * uint256(investQty), false);
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

        // Full unwind must zero the staked-value leg (stakestate.amount1).
        assertEq(
            tts_token.stakestate().amount1(),
            0,
            "stake1 not zero after full unwind"
        );

        // stake1 == 0 now. Re-stake must not div0-revert (pool1==0 guard).
        bool ok = market.investGood(
            _usdtKey(),
            _packInvest(usdtGoodId, investQty),
            defaultdata,
            defaultdata,
            attacker
        );
        vm.stopPrank();
        assertTrue(ok, "re-stake after full unwind reverted");
        assertGt(
            tts_token.stakestate().amount1(),
            0,
            "stake did not record new value"
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RT-34: one msg.value inside multicall — try to re-spend the native
    // budget from receive() during (a) the output safeTransfer and (b) the
    // leftover refund. Expected negative: (a) lock=2 blocks, (b) budget is
    // zeroed before refund so the reentry has nothing to spend.
    // ─────────────────────────────────────────────────────────────────────────

    function test_RT34_multicall_native_refund_reentry_blocked() public {
        // Native good: 1 ETH deep, declared value 1e18.
        T_GoodKey memory nativeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        vm.startPrank(marketcreator);
        vm.deal(marketcreator, 10 ether);
        market.initGood{value: 1 ether}(
            nativeKey,
            toTTSwapUINT256(uint128(1 ether), uint128(1 ether)),
            defaultdata,
            marketcreator,
            defaultdata
        );
        vm.stopPrank();

        RTRefundReenter bot = new RTRefundReenter(market);
        uint256 poolBefore = address(market).balance;

        bot.attack{value: 1 ether}();

        assertTrue(bot.failDuringTransfer(), "reentry during transfer not blocked");
        assertTrue(bot.failDuringRefund(), "reentry during refund not blocked");
        assertEq(address(bot).balance, 1 ether, "bot extracted extra native");
        // Self-payment nets to zero: pool native reserves untouched.
        assertEq(address(market).balance, poolBefore, "native accounting drift");
    }
}
