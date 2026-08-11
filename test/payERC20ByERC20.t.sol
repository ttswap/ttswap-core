// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice payGood: pay ERC20 USDT (good1) → receive ERC20 BTC (good2), exact gross output.
contract payERC20ByERC20 is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant PAY_OUT = uint128(1 * 10 ** 6);
    uint128 internal constant MAX_USDT_IN = uint128(6300 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
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
        usdt.mint(owner, 100_000_000);
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
        deal(address(btc), owner, 10 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.prank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
    }

    function _payBtcWithUsdt(
        address trader,
        address recipient,
        uint128 maxUsdtIn,
        uint128 btcOut
    ) internal returns (uint256 g1change, uint256 g2change) {
        usdt.approve(address(market), maxUsdtIn);
        return market.payGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(maxUsdtIn, btcOut),
            recipient,
            defaultdata,
            trader,
            defaultdata,
            0
        );
    }

    function testPayERC20ByERC20() public {
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100_000_000);

        uint256 usdtBefore = usdt.balanceOf(address(market));
        uint256 btcBefore = btc.balanceOf(address(market));
        uint256 userBtcBefore = btc.balanceOf(users[1]);

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _payBtcWithUsdt(
            users[1],
            users[1],
            MAX_USDT_IN,
            PAY_OUT
        );
        _snapMarket("pay_erc20_by_erc20_to_self_first");

        assertGt(g1change.amount1(), 0, "usdt input used");
        assertGt(g2change.amount1(), 0, "value moved on output side");
        assertGt(usdt.balanceOf(address(market)), usdtBefore, "market usdt increased");
        assertLt(btc.balanceOf(address(market)), btcBefore, "market btc decreased");
        assertEq(btc.balanceOf(users[1]), userBtcBefore + PAY_OUT, "user received btc");

        _warpToFreshRunSlot();
        _payBtcWithUsdt(users[1], users[1], MAX_USDT_IN * 2, PAY_OUT);
        _snapMarket("pay_erc20_by_erc20_to_self_second");
        vm.stopPrank();
    }

    function testPayERC20ByERC20ToOtherUser() public {
        address recipient = address(100);
        vm.startPrank(users[1]);
        usdt.mint(users[1], 100_000_000);

        uint256 recipientBtcBefore = btc.balanceOf(recipient);

        _warpToFreshRunSlot();
        _payBtcWithUsdt(users[1], recipient, MAX_USDT_IN, PAY_OUT);
        _snapMarket("pay_erc20_by_erc20_to_other_user_first");
        assertEq(btc.balanceOf(recipient), recipientBtcBefore + PAY_OUT, "recipient got btc");

        _warpToFreshRunSlot();
        _payBtcWithUsdt(users[1], recipient, MAX_USDT_IN * 2, PAY_OUT);
        _snapMarket("pay_erc20_by_erc20_to_other_user_second");
        vm.stopPrank();
    }
}
