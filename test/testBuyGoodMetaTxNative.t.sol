// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_SignatureVerification} from "../src/libraries/L_SignatureVerification.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice buyGood relayer path with a native-ETH input good (issue #330).
/// @dev The trader signs the trade; the relayer supplies `msg.value` and is
///      compensated via the executeFee commission. Previously the native
///      transferFrom leg required `executor == from`, so every relayer +
///      native-ETH swap reverted with TTSwapError(39).
contract testBuyGoodMetaTxNative is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    bytes32 internal constant BUY_GOOD_TYPEHASH = keccak256(
        "buyGood(address _trader,address referral,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,bytes data,uint256 external_info,uint256 nonce)"
    );

    uint128 internal constant NATIVE_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    uint256 internal constant TRADER_KEY = 0xA11CE;
    uint256 internal constant WRONG_KEY = 0xDEAD;

    address internal trader;
    address internal relayer;

    uint256 internal nativeGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        trader = vm.addr(TRADER_KEY);
        relayer = users[2];
        vm.deal(relayer, 10 ether);
        vm.warp(100);

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

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _signBuyGood(
        address _trader,
        address _referral,
        T_GoodKey memory key1,
        T_GoodKey memory key2,
        uint256 swapQuantity,
        bytes memory data,
        uint256 externalInfo,
        uint256 signerKey
    ) internal view returns (bytes memory sig) {
        uint256 nonce = market.nonces(_trader);
        bytes32 structHash = keccak256(
            abi.encode(
                BUY_GOOD_TYPEHASH,
                _trader,
                _referral,
                key1.toId(),
                key2.toId(),
                swapQuantity,
                keccak256(data),
                externalInfo,
                nonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    // ── relayer + native ETH input works with a valid trader signature ────

    function testBuyGoodMetaTxNative_relayer_happyPath() public {
        uint256 traderBtcBefore = btc.balanceOf(trader);
        uint256 relayerEthBefore = relayer.balance;
        uint256 marketEthBefore = address(market).balance;

        _warpToFreshRunSlot();
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 1);
        bytes memory sig = _signBuyGood(
            trader,
            address(0),
            _nativeKey(),
            _btcKey(),
            swapQty,
            defaultdata,
            0,
            TRADER_KEY
        );

        vm.prank(relayer);
        (uint256 g1change, uint256 g2change) = market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _btcKey(),
            swapQty,
            address(0),
            defaultdata,
            trader,
            sig,
            0
        );
        _snapMarket("buyGood_metaTx_native_relayer");

        assertGt(g1change.amount1(), 0, "native input value moved");
        assertGt(g2change.amount1(), 0, "btc gross output > 0");
        // Relayer fronts SWAP_IN wei of ETH; leftover budget is refunded.
        assertLt(relayer.balance, relayerEthBefore, "relayer supplied msg.value");
        assertGt(address(market).balance, marketEthBefore, "market kept the ETH input");
        // Trader receives gross output minus the relayer execution fee.
        assertGt(btc.balanceOf(trader), traderBtcBefore, "trader received btc");
        assertEq(market.nonces(trader), 1, "nonce consumed");
    }

    // ── relayer without a valid trader signature still cannot move funds ──

    function testBuyGoodMetaTxNative_revert_invalidSigner() public {
        _warpToFreshRunSlot();
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 1);
        bytes memory badSig = _signBuyGood(
            trader,
            address(0),
            _nativeKey(),
            _btcKey(),
            swapQty,
            defaultdata,
            0,
            WRONG_KEY
        );
        vm.prank(relayer);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _btcKey(),
            swapQty,
            address(0),
            defaultdata,
            trader,
            badSig,
            0
        );
    }

    // ── direct native-ETH trade still works (regression) ──────────────────

    function testBuyGoodMetaTxNative_direct_stillWorks() public {
        vm.deal(trader, 10 * SWAP_IN);
        uint256 traderBtcBefore = btc.balanceOf(trader);

        _warpToFreshRunSlot();
        vm.prank(trader);
        (uint256 g1change, uint256 g2change) = market.buyGood{value: SWAP_IN}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            trader,
            defaultdata,
            0
        );

        assertGt(g1change.amount1(), 0);
        assertGt(g2change.amount1(), 0);
        assertGt(btc.balanceOf(trader), traderBtcBefore);
    }
}
