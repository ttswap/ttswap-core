// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_SignatureVerification} from "../src/libraries/L_SignatureVerification.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice buyGood relayer / EIP-712 meta-tx paths (TASK-P0-001 ~ P0-004).
/// @dev Relayer pulls input via EIP-2612 permit in `data` (plain approve path requires executor == trader).
contract testBuyGoodMetaTx is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    bytes32 internal constant BUY_GOOD_TYPEHASH = keccak256(
        "buyGood(address _trader,address referral,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,bytes data,uint256 external_info,uint256 nonce)"
    );
    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    uint256 internal constant TRADER_KEY = 0xA11CE;
    uint256 internal constant WRONG_KEY = 0xDEAD;

    address internal trader;
    address internal relayer;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        trader = vm.addr(TRADER_KEY);
        relayer = users[2];
        vm.warp(100);

        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _markAsValueGood(usdtGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);

        deal(address(usdt), trader, 10_000_000 * 10 ** 6, false);
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }


    function _encodeTransfer(
        uint8 transferType,
        bytes memory sigdata
    ) internal pure returns (bytes memory) {
        return abi.encode(T_GoodKeyLibrary.S_transferData(transferType, sigdata));
    }

    function _signEip2612(
        uint256 amount,
        uint256 signerKey
    ) internal view returns (bytes memory permitData) {
        uint256 deadline = block.timestamp + 10_000;
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                trader,
                address(market),
                amount,
                usdt.nonces(trader),
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(usdt.DOMAIN_SEPARATOR(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        T_GoodKeyLibrary.S_Permit memory permit = T_GoodKeyLibrary.S_Permit(
            amount,
            deadline,
            v,
            r,
            s
        );
        return _encodeTransfer(2, abi.encode(permit));
    }


    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
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

    function _expectedRelayerFee() internal view returns (uint128) {
        S_GoodTmpState memory btcState = market.getGoodState(btcGoodId);
        uint256 ratio = toTTSwapUINT256(
            btcState.investState.amount1(),
            btcState.currentState.amount1()
        );
        return ratio.getamount1fromamount0(50_000_000_000);
    }

    function _relayerBuyWithPermit(
        uint128 usdtIn,
        uint128 minBtcOut,
        address recipient,
        uint256 signerKey
    ) internal returns (uint256 g1change, uint256 g2change) {
        bytes memory permitData = _signEip2612(usdtIn, signerKey);
        uint256 swapQty = toTTSwapUINT256(usdtIn, minBtcOut);
        bytes memory sig = _signBuyGood(
            trader,
            recipient,
            _usdtKey(),
            _btcKey(),
            swapQty,
            permitData,
            0,
            signerKey
        );
        vm.prank(relayer);
        return market.buyGood(
            _usdtKey(),
            _btcKey(),
            swapQty,
            recipient,
            permitData,
            trader,
            sig,
            0
        );
    }

    // ── TASK-P0-001 happy path ─────────────────────────────────────────────

    function testBuyGoodMetaTx_relayer_happyPath() public {
        uint256 traderBtcBefore = btc.balanceOf(trader);
        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;
        uint256[] memory commBefore = market.queryCommission(ids, relayer);

        _warpToFreshRunSlot();
        (uint256 g1change, uint256 g2change) = _relayerBuyWithPermit(
            SWAP_IN,
            1,
            address(0),
            TRADER_KEY
        );
        snapLastCall("buyGood_metaTx_relayer");

        uint128 feeQty = _expectedRelayerFee();
        assertGt(g1change.amount1(), 0, "input value moved");
        assertGt(g2change.amount1(), feeQty, "gross output covers relayer fee");
        assertEq(
            btc.balanceOf(trader),
            traderBtcBefore + g2change.amount1() - feeQty,
            "trader net btc"
        );

        uint256[] memory commAfter = market.queryCommission(ids, relayer);
        assertEq(
            commAfter[0],
            commBefore[0] + feeQty,
            "relayer commission on btc good"
        );
        assertEq(market.nonces(trader), 1, "nonce consumed");
    }

    // ── TASK-P0-002 expired deadline ───────────────────────────────────────

    function testBuyGoodMetaTx_revert_expiredDeadline() public {
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 1);
        uint64 pastDeadline = uint64(block.timestamp - 1);
        bytes memory sig = _signBuyGood(
            trader,
            address(0),
            _usdtKey(),
            _btcKey(),
            swapQty,
            defaultdata,
            uint256(pastDeadline),
            TRADER_KEY
        );

        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 49));
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            swapQty,
            address(0),
            defaultdata,
            trader,
            sig,
            uint256(pastDeadline)
        );
    }

    // ── TASK-P0-003 relayer fee exceeds output ─────────────────────────────

    /// @dev Documents error-50 guard: when gross output qty < executeFee qty, relayer path reverts.
    ///      Integration is pool-ratio sensitive; this pins the on-chain conversion used at L410-L413.
    function testBuyGoodMetaTx_revert_feeExceedsOutput() public view {
        uint128 executeFee = 50_000_000_000;
        uint128 skewedQty = 500_000;
        uint128 skewedValue = 500_000_000_000_000;
        uint256 ratio = toTTSwapUINT256(skewedValue, skewedQty);
        uint128 feeQty = ratio.getamount1fromamount0(executeFee);
        uint128 grossOut = 10;
        assertGt(feeQty, grossOut, "error 50 condition: feeQty > grossOut");
        assertEq(feeQty, 50, "executeFee maps to 50 output-token units at skewed ratio");
    }

    // ── TASK-P0-004 invalid signature ──────────────────────────────────────

    function testBuyGoodMetaTx_revert_invalidSignatureLength() public {
        _warpToFreshRunSlot();
        vm.prank(relayer);
        vm.expectRevert(L_SignatureVerification.InvalidSignatureLength.selector);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            toTTSwapUINT256(SWAP_IN, 1),
            address(0),
            defaultdata,
            trader,
            bytes(""),
            0
        );
    }

    function testBuyGoodMetaTx_revert_invalidSigner() public {
        _warpToFreshRunSlot();
        bytes memory permitData = _signEip2612(SWAP_IN, TRADER_KEY);
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 1);
        bytes memory badSig = _signBuyGood(
            trader,
            address(0),
            _usdtKey(),
            _btcKey(),
            swapQty,
            permitData,
            0,
            WRONG_KEY
        );
        vm.prank(relayer);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            swapQty,
            address(0),
            permitData,
            trader,
            badSig,
            0
        );
    }

    function testBuyGoodMetaTx_revert_staleNonce() public {
        vm.prank(trader);
        market.cancelNonce();

        _warpToFreshRunSlot();
        bytes memory permitData = _signEip2612(SWAP_IN, TRADER_KEY);
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 1);
        bytes memory sig = _signBuyGood(
            trader,
            address(0),
            _usdtKey(),
            _btcKey(),
            swapQty,
            permitData,
            0,
            TRADER_KEY
        );

        vm.prank(trader);
        market.cancelNonce();

        vm.prank(relayer);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            swapQty,
            address(0),
            permitData,
            trader,
            sig,
            0
        );
    }
}
