// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {TTSwap_Market} from "../../src/TTSwap_Market.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {S_ProofKey} from "../../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary} from "../../src/libraries/L_Proof.sol";
import {toTTSwapUINT256} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @notice Runtime evidence: Proxy freeze + disableUpgrade bricks forever;
///         owner lockGood blocks disinvest.
contract C04_ProxyBrick is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal usdtGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 100_000_000);
        uint128 qty = uint128(50_000 * 10 ** 6);
        usdt.approve(address(market), qty);
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        market.initGood(
            key,
            toTTSwapUINT256(uint128(50_000 * 10 ** 12), qty),
            defaultdata,
            marketcreator,
            defaultdata
        );
        usdtGoodId = key.toId();
        vm.stopPrank();
    }

    /// @dev Manager freezes impl=0, then DAO disables upgrade → market permanently dead.
    function test_C04_freeze_then_disableUpgrade_permanent_brick() public {
        address beforeImpl = market_proxy.implementation();
        assertTrue(beforeImpl != address(0), "pre: impl live");
        assertTrue(market_proxy.upgradeable(), "pre: upgradeable");

        vm.prank(marketcreator);
        market_proxy.freezeMarket();
        assertEq(market_proxy.implementation(), address(0), "frozen");

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.getGoodState(usdtGoodId);

        vm.prank(marketcreator);
        market_proxy.disableUpgrade();
        assertFalse(market_proxy.upgradeable(), "upgrade locked off");

        TTSwap_Market newImpl = new TTSwap_Market(tts_token);
        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        market_proxy.upgrade(address(newImpl));

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.getGoodState(usdtGoodId);
    }

    /// @dev Good owner lockGood freezes LP exit via disinvestProof.
    function test_C04_owner_lockGood_blocks_disinvest() public {
        address lp = users[1];
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });

        vm.startPrank(lp);
        usdt.mint(lp, 50_000_000);
        usdt.approve(address(market), type(uint256).max);
        vm.roll(block.number + 1);
        market.investGood(
            key,
            _packInvest(usdtGoodId, uint128(20_000_000)),
            defaultdata,
            defaultdata,
            lp
        );
        _snapMarket("test_C04_owner_lockGood_blocks_disinvest1");
        uint256 lpProof = S_ProofKey({owner: lp, currentgood: usdtGoodId}).toId();
        vm.stopPrank();

        vm.prank(marketcreator);
        market.lockGood(usdtGoodId, marketcreator, defaultdata);
        _snapMarket("test_C04_owner_lockGood_blocks_disinvest2");

        vm.prank(lp);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.disinvestProof(lpProof, 1, address(0), lp, defaultdata);
        _snapMarket("test_C04_owner_lockGood_blocks_disinvest3");
    }
}
