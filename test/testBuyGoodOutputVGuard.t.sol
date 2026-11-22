// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for #315: `L_Good.buyGoodOutput` had no lower guard on
/// pool value V (unlike `payGoodInput`'s `current_value < 10000` check).
/// With V in 1..99 the V/100 chunk size is 0 -> unbounded loop (OOG);
/// with V == 0 -> division-by-zero panic. The fix reverts TTSwapError(56).
contract testBuyGoodOutputVGuard is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    uint128 internal constant BTC_QTY = uint128(5 * 10 ** 14);
    uint128 internal constant BTC_VALUE = uint128(5 * 10 ** 14);
    uint128 internal constant USDT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BUYIN_BTC = uint128(25 * 10 ** 13);
    uint128 internal constant DUST_SHARES = 50;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initGood(marketcreator, _usdtKey(), USDT_QTY, USDT_VALUE, address(usdt));
        btcGoodId = _initGood(users[1], _btcKey(), BTC_QTY, BTC_VALUE, address(btc));
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
        vm.startPrank(users[2]);
        deal(address(btc), users[2], BUYIN_BTC);
        btc.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        (uint256 g1, uint256 g2) = market.buyGood(
            _btcKey(), _usdtKey(),
            toTTSwapUINT256(BUYIN_BTC, 1),
            address(0), defaultdata, users[2], defaultdata, uint256(0)
        );
        assertGt(g1.amount1(), 0, "setup buy-in must export value");
        assertGt(g2.amount1(), 0, "setup buy-in must pay out");
        deal(address(usdt), users[2], uint256(1 * 10 ** 12));
        usdt.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _initGood(
        address owner,
        T_GoodKey memory key,
        uint128 qty,
        uint128 value,
        address token
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(token, owner, qty);
        MyToken(payable(token)).approve(address(market), type(uint256).max);
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _setDisinvestChipsZero() internal {
        vm.startPrank(users[1]);
        uint256 cfg = market.getGoodState(btcGoodId).goodConfig;
        uint256 newCfg = cfg & ~(uint256(0xFF) << 160);
        market.modifyGoodByGoodOwner(btcGoodId, newCfg, users[1], defaultdata);
        vm.stopPrank();
    }

    function _disinvestBtc(uint128 shares) internal {
        uint256 proofId = S_ProofKey(users[1], btcGoodId).toId();
        vm.startPrank(users[1]);
        market.disinvestProof(proofId, shares, address(0), users[1], defaultdata);
        vm.stopPrank();
    }

    function _brickBtcToDustV() internal {
        _setDisinvestChipsZero();
        _disinvestBtc(BTC_QTY - DUST_SHARES);
        assertEq(market.getGoodState(btcGoodId).investState.amount1(), DUST_SHARES, "V must be dust (50)");
        assertGe(market.getGoodState(btcGoodId).currentState.amount1(), 10000, "Q must stay >= 10000");
    }

    function _buyUsdtForBtc() internal {
        _warpToFreshRunSlot();
        vm.startPrank(users[2]);
        market.buyGood(
            _usdtKey(), _btcKey(),
            toTTSwapUINT256(uint128(1 * 10 ** 9), 1),
            address(0), defaultdata, users[2], defaultdata, uint256(0)
        );
        vm.stopPrank();
    }

    /// @dev Dust V (1..99): used to be an unbounded loop eating all gas; now a clean revert.
    function testBuyIntoDustValueGood_reverts56_notOOG() public {
        _brickBtcToDustV();
        _warpToFreshRunSlot();
        vm.startPrank(users[2]);
        uint256 gasBefore = gasleft();
        (bool success, bytes memory ret) = address(market).call(
            abi.encodeCall(
                market.buyGood,
                (_usdtKey(), _btcKey(), toTTSwapUINT256(uint128(1 * 10 ** 9), 1),
                 address(0), defaultdata, users[2], defaultdata, uint256(0))
            )
        );
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        assertFalse(success, "buy into dust-V good must fail");
        assertEq(bytes4(ret), TTSwapError.selector, "must revert TTSwapError, not OOG/panic");
        assertLt(gasUsed, 3_000_000, "clean revert must not burn the whole gas budget");
    }

    /// @dev V == 0: used to panic(0x12) on division by zero; now a clean revert.
    function testBuyIntoZeroValueGood_reverts56_notPanic() public {
        _setDisinvestChipsZero();
        _disinvestBtc(BTC_QTY);
        assertEq(market.getGoodState(btcGoodId).investState.amount1(), 0, "V must be 0");
        assertGe(market.getGoodState(btcGoodId).currentState.amount1(), 10000, "Q stays high");
        _warpToFreshRunSlot();
        vm.startPrank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 56));
        market.buyGood(
            _usdtKey(), _btcKey(),
            toTTSwapUINT256(uint128(1 * 10 ** 9), 1),
            address(0), defaultdata, users[2], defaultdata, uint256(0)
        );
        vm.stopPrank();
    }

    /// @dev Control: the same buy succeeds on a healthy good.
    function testBuySucceedsOnHealthyGood() public {
        _buyUsdtForBtc();
    }
}
