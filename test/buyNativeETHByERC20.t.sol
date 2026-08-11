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

/// @notice buyGood: pay ERC20 USDT (good1) → receive Native ETH (good2).
contract buyNativeETHByERC20 is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal usdtGoodId;
    uint256 internal nativeGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant NATIVE_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        nativeGoodId = _initNativeGood(users[1], NATIVE_INIT_VALUE, NATIVE_INIT_QTY);
        _verifyGood(usdtGoodId);
        _verifyGood(nativeGoodId);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(nativeGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 100000);
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

    function _initNativeGood(
        address owner,
        uint128 value,
        uint128 qty
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


    /// @dev Admin marks USDT pool as value good (bit 255).
    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }


    function _buyEthWithUsdt(
        address trader,
        uint128 usdtIn,
        uint128 minEthOut,
        address referral
    ) internal returns (uint256 g1change, uint256 g2change) {
        usdt.approve(address(market), usdtIn);
        return market.buyGood(
            _usdtKey(),
            _nativeKey(),
            toTTSwapUINT256(usdtIn, minEthOut),
            referral,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    // ── happy path ─────────────────────────────────────────────────────────

    function testBuyNativeETHByERC20() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 1000000);
        usdt.approve(address(market), type(uint256).max);

        uint256 usdtBefore = usdt.balanceOf(address(market));
        uint256 ethBefore = address(market).balance;
        uint256 userEthBefore = users[1].balance;
        uint256 userUsdtBefore = usdt.balanceOf(users[1]);

        S_GoodTmpState memory usdtBeforeState = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory nativeBeforeState = market.getGoodState(nativeGoodId);
        assertTrue(usdtBeforeState.goodConfig.isvaluegood(), "usdt is value good");        assertFalse(nativeBeforeState.goodConfig.isvaluegood(), "native is normal good");

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _buyEthWithUsdt(
            users[1],
            SWAP_IN,
            1,
            address(0)
        );
        _snapMarket("buy_NativeETH_by_erc20_first");

        assertGt(g1change.amount1(), 0, "usdt value moved");
        assertGt(g2change.amount1(), 0, "eth output > 0");
        assertGt(usdt.balanceOf(address(market)), usdtBefore, "market usdt increased");
        assertLt(address(market).balance, ethBefore, "market eth decreased");
        assertGt(users[1].balance, userEthBefore, "user received eth");
        assertLt(usdt.balanceOf(users[1]), userUsdtBefore, "user spent usdt");

        S_GoodTmpState memory usdtAfter = market.getGoodState(usdtGoodId);
        S_GoodTmpState memory nativeAfter = market.getGoodState(nativeGoodId);
        assertGt(
            usdtAfter.currentState.amount1(),
            usdtBeforeState.currentState.amount1(),
            "usdt qty grew"
        );
        assertLt(
            nativeAfter.currentState.amount1(),
            nativeBeforeState.currentState.amount1(),
            "native qty shrank"
        );

        vm.stopPrank();
    }

    function testBuyNativeETHByERC20_consecutive() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 1000000);
        usdt.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        _buyEthWithUsdt(users[1], SWAP_IN, 1, address(0));
        _snapMarket("buy_NativeETH_by_erc20_first");

        _warpToFreshRunSlot();
        _buyEthWithUsdt(users[1], SWAP_IN, 1, address(0));
        _snapMarket("buy_NativeETH_by_erc20_second");
        vm.stopPrank();
    }

    function testBuyNativeETHByERC20WithRefer() public {
        address referral = address(100);
        vm.startPrank(users[1]);
        usdt.mint(users[1], 1000000);
        usdt.approve(address(market), type(uint256).max);

        _warpToFreshRunSlot();
        _buyEthWithUsdt(users[1], SWAP_IN, 1, referral);
        _snapMarket("buy_NativeETH_by_erc20_first_with_refer");

        _warpToFreshRunSlot();
        _buyEthWithUsdt(users[1], SWAP_IN, 1, referral);
        _snapMarket("buy_NativeETH_by_erc20_second_with_exists_refer_reject_add");

        _warpToFreshRunSlot();
        _buyEthWithUsdt(users[1], SWAP_IN, 1, address(0));
        _snapMarket("buy_NativeETH_by_erc20_second_with_exists_refer");
        vm.stopPrank();
    }

    // ── revert cases ───────────────────────────────────────────────────────

    function testBuyNativeETHByERC20_revert_sameGood() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100000);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 9));
        market.buyGood(
            _usdtKey(),
            _usdtKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    function testBuyNativeETHByERC20_revert_slippage() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100000);
        usdt.approve(address(market), SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 15));
        market.buyGood(
            _usdtKey(),
            _nativeKey(),
            toTTSwapUINT256(SWAP_IN, type(uint128).max / 2),
            address(0),
            defaultdata,
            users[1],
            defaultdata,
            0
        );
        vm.stopPrank();
    }

    function testBuyNativeETHByERC20_revert_insufficientAllowance() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100000);
        _warpToFreshRunSlot();
        vm.expectRevert();
        market.buyGood(
            _usdtKey(),
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

    function testBuyNativeETHByERC20_revert_frozenGood() public {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(usdtGoodId).goodConfig.setFreeze(true);
        market.modifyGoodByManager(usdtGoodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();

        vm.startPrank(users[1]);
        usdt.mint(users[1], 100000);
        usdt.approve(address(market), SWAP_IN);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.buyGood(
            _usdtKey(),
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
}
