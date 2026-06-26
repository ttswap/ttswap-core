// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice buyGood: pay Native ETH (good1) → receive ERC20 BTC (good2).
contract buyERC20ByNativeETH is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal nativeGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant NATIVE_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        nativeGoodId = _initNativeGood(marketcreator, NATIVE_INIT_QTY, NATIVE_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _verifyGood(nativeGoodId);
        _verifyGood(btcGoodId);
        _markAsValueGood(nativeGoodId);
        _relaxSafeLine(nativeGoodId);
        _relaxSafeLine(btcGoodId);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initNativeGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 10 * qty);
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

    function _initBtcGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * qty, false);
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


    /// @dev Admin marks the payment-side pool as a value good (bit 255).
    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }


    function _buyBtcWithEth(
        address trader,
        uint128 ethIn,
        uint128 minBtcOut,
        address referral
    ) internal returns (uint256 g1change, uint256 g2change) {
        return market.buyGood{value: ethIn}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(ethIn, minBtcOut),
            referral,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    // ── happy path ─────────────────────────────────────────────────────────

    function testBuyERC20ByNativeETH() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], 10 * SWAP_IN);

        uint256 ethBefore = address(market).balance;
        uint256 btcBefore = btc.balanceOf(address(market));
        uint256 userBtcBefore = btc.balanceOf(users[1]);
        uint256 userEthBefore = users[1].balance;

        S_GoodTmpState memory nativeBefore = market.getGoodState(nativeGoodId);
        S_GoodTmpState memory btcBeforeState = market.getGoodState(btcGoodId);
        assertTrue(nativeBefore.goodConfig.isvaluegood(), "native is value good");        assertFalse(btcBeforeState.goodConfig.isvaluegood(), "btc is normal good");

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _buyBtcWithEth(
            users[1],
            SWAP_IN,
            1,
            address(0)
        );
        snapLastCall("buy_erc20_by_NativeETH_first");

        assertGt(g1change.amount1(), 0, "input value moved");
        assertGt(g2change.amount1(), 0, "btc output > 0");
        assertGt(address(market).balance, ethBefore, "market eth increased");
        assertLt(btc.balanceOf(address(market)), btcBefore, "market btc decreased");
        assertGt(btc.balanceOf(users[1]), userBtcBefore, "user received btc");
        assertLt(users[1].balance, userEthBefore, "user spent eth");

        S_GoodTmpState memory nativeAfter = market.getGoodState(nativeGoodId);
        S_GoodTmpState memory btcAfter = market.getGoodState(btcGoodId);
        assertGt(
            nativeAfter.currentState.amount1(),
            nativeBefore.currentState.amount1(),
            "native qty grew"
        );
        assertLt(
            btcAfter.currentState.amount1(),
            btcBeforeState.currentState.amount1(),
            "btc qty shrank"
        );

        vm.stopPrank();
    }

    function testBuyERC20ByNativeETH_consecutive() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], 10 * SWAP_IN);

        _warpToFreshRunSlot();
        _buyBtcWithEth(users[1], SWAP_IN, 1, address(0));
        snapLastCall("buy_erc20_by_NativeETH_first");

        _warpToFreshRunSlot();
        _buyBtcWithEth(users[1], SWAP_IN, 1, address(0));
        snapLastCall("buy_erc20_by_NativeETH_second");
        vm.stopPrank();
    }

    function testBuyERC20ByNativeETHWithRefer() public {
        address referral = address(100);
        vm.startPrank(users[1]);
        vm.deal(users[1], 20 * SWAP_IN);

        _warpToFreshRunSlot();
        _buyBtcWithEth(users[1], SWAP_IN, 1, referral);
        snapLastCall("buy_erc20_by_NativeETH_first_with_refer");

        _warpToFreshRunSlot();
        _buyBtcWithEth(users[1], SWAP_IN, 1, referral);
        snapLastCall("buy_erc20_by_NativeETH_second_with_exists_refer_reject_add");

        _warpToFreshRunSlot();
        _buyBtcWithEth(users[1], SWAP_IN, 1, address(0));
        snapLastCall("buy_erc20_by_NativeETH_second_with_exists_refer");
        vm.stopPrank();
    }

    // ── revert cases ───────────────────────────────────────────────────────

    function testBuyERC20ByNativeETH_revert_sameGood() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 9));
        market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _nativeKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    function testBuyERC20ByNativeETH_revert_slippage() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 15));
        market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, type(uint128).max / 2),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    function testBuyERC20ByNativeETH_revert_traderMismatch() public {
        vm.startPrank(users[1]);
        vm.deal(users[1], SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert();
        market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            users[2],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

}
