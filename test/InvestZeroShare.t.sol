// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for #323/#318: a leveraged invest too small to mint one
///         share must revert instead of being accepted — the deposit and its
///         virtual excess would become unowned pool property and can later
///         brick the good (investQty == 0, Q == virtualQty > 0 → getInvestPower
///         divides by zero).
contract InvestZeroShare is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    uint256 internal constant POWER_SHIFT = TestConfigConstants.POWER_SHIFT;
    uint256 internal constant LIMIT_POWER_SHIFT =
        TestConfigConstants.LIMIT_POWER_SHIFT;

    uint256 internal usdtGoodId;

    uint128 internal constant INIT_QTY = uint128(500000 * 10 ** 6);
    uint128 internal constant INIT_VALUE = uint128(1e23);
    uint128 internal constant LP2_INVEST = uint128(500000 * 10 ** 6);
    uint128 internal constant DUST_INVEST = uint128(1 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, INIT_QTY, INIT_VALUE);
        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 600000);
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

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setLimitPower(uint256 goodId, uint256 limitField) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << LIMIT_POWER_SHIFT)) |
            (limitField << LIMIT_POWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerPower(uint256 goodId, address owner, uint256 powerField) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << POWER_SHIFT)) | (powerField << POWER_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _investUsdt(address trader, uint128 qty) internal {
        usdt.approve(address(market), qty);
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    /// @dev Reproduces the #323 setup: fee-accreted share ratio > 1 plus 31x
    ///      leverage makes a 1-token deposit mint 0 shares.
    function testZeroShareInvest_reverts() public {
        // LP2 invests at 1x to push the share ratio above 1.
        vm.startPrank(users[4]);
        usdt.mint(users[4], 600000);
        _warpToFreshRunSlot();
        _investUsdt(users[4], LP2_INVEST);
        vm.stopPrank();

        // Raise leverage ceiling (manager) and owner power to 31x.
        _setLimitPower(usdtGoodId, 31);
        _setOwnerPower(usdtGoodId, marketcreator, 31);

        // Attacker's 1-raw-unit leveraged deposit mints zero shares (verified
        // on unfixed code: shares.amount0 == 0) and must revert instead.
        vm.startPrank(users[5]);
        usdt.mint(users[5], 10);
        usdt.approve(address(market), 1);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 38));
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, 1),
            defaultdata,
            defaultdata,
            users[5]
        );
        vm.stopPrank();
    }

    /// @dev Control: a normal-size invest on the same leveraged config still works.
    function testNormalInvest_stillWorks() public {
        vm.startPrank(users[4]);
        usdt.mint(users[4], 600000);
        _warpToFreshRunSlot();
        _investUsdt(users[4], LP2_INVEST);
        vm.stopPrank();

        _setLimitPower(usdtGoodId, 31);
        _setOwnerPower(usdtGoodId, marketcreator, 31);

        vm.startPrank(users[5]);
        usdt.mint(users[5], 2000);
        _warpToFreshRunSlot();
        _investUsdt(users[5], 1000 * 10 ** 6);
        vm.stopPrank();
    }
}
