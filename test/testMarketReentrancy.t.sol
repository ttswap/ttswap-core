// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @dev ERC20 that re-enters `buyGood` during `transferFrom` to market.
contract ReentrantERC20 is MyToken {
    TTSwap_Market internal market;
    T_GoodKey internal keyOut;
    bool internal reentering;
    bool internal hookEnabled;

    function enableHook() external {
        hookEnabled = true;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        TTSwap_Market market_,
        T_GoodKey memory keyOut_
    ) MyToken(name_, symbol_, decimals_) {
        market = market_;
        keyOut = keyOut_;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (hookEnabled && !reentering && to == address(market)) {
            reentering = true;
            market.buyGood(
                T_GoodKey({ercType: 1, contractAddress: address(this), id: 0}),
                keyOut,
                toTTSwapUINT256(uint128(1 * 10 ** 6), 0),
                address(0),
                "",
                from,
                "",
                0
            );
        }
        return super.transferFrom(from, to, amount);
    }
}

/// @notice guardedEntry reentrancy guard (TASK-P2-005). v2 has no public `multicall`;
/// nested `buyGood` reverts with error 3 and surfaces as `ERC20TransferFailed` on the outer swap.
contract testMarketReentrancy is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    ReentrantERC20 internal reToken;
    uint256 internal reGoodId;
    uint256 internal btcGoodId;
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);

        btcGoodId = _initBtcGood(users[1]);
        _verifyGood(btcGoodId);
        _relaxSafeLine(btcGoodId);

        reToken = new ReentrantERC20(
            "RE",
            "RE",
            6,
            market,
            _btcKey()
        );
        reGoodId = _initReGood();
        _verifyGood(reGoodId);
        _relaxSafeLine(reGoodId);
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }


    function _initBtcGood(address owner) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 ** 9, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(63_000 * 10 ** 12, 1 * 10 ** 8),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initReGood() internal returns (uint256 goodId) {
        vm.startPrank(marketcreator);
        deal(address(reToken), marketcreator, 100_000_000 * 10 ** 6, false);
        reToken.approve(address(market), type(uint256).max);
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(reToken),
            id: 0
        });
        market.initGood(
            key,
            toTTSwapUINT256(50_000 * 10 ** 12, 50_000 * 10 ** 6),
            defaultdata,
            marketcreator,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function testGuardedEntry_revert_reentrancy() public {
        reToken.enableHook();
        vm.startPrank(users[2]);
        deal(address(reToken), users[2], 10_000 * 10 ** 6, false);
        reToken.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        market.buyGood(
            T_GoodKey({ercType: 1, contractAddress: address(reToken), id: 0}),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 0),
            address(0),
            defaultdata,
            users[2],
            defaultdata,
            0
        );
        _snapMarket("buyGood_revert_reentrancy");
        vm.stopPrank();
    }
}
