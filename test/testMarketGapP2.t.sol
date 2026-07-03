// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_SignatureVerification} from "../src/libraries/L_SignatureVerification.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice P2: cancelNonce, setReferral, refreshPromise no-op, commission edges.
contract testMarketGapP2 is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    bytes32 internal constant PROMISE_TOPIC =
        keccak256("e_getPromiseProof(uint256,uint256)");
    bytes32 internal constant REFERRAL_TOPIC =
        keccak256("e_addreferral(address,address)");
    bytes32 internal constant BUY_GOOD_TYPEHASH = keccak256(
        "buyGood(address _trader,address referral,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,bytes data,uint256 external_info,uint256 nonce)"
    );

    uint256 internal constant TRADER_KEY = 0xA11CE;
    uint128 internal constant SWAP_IN = uint128(50 * 10 ** 6);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood();
        btcGoodId = _initBtcGood();
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
        _markAsValueGood(usdtGoodId);
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _signBuyGood(
        address trader,
        address referral,
        T_GoodKey memory key1,
        T_GoodKey memory key2,
        uint256 swapQty,
        bytes memory data,
        uint256 extInfo,
        uint256 signerKey
    ) internal view returns (bytes memory sig) {
        bytes32 structHash = keccak256(
            abi.encode(
                BUY_GOOD_TYPEHASH,
                trader,
                referral,
                key1.toId(),
                key2.toId(),
                swapQty,
                keccak256(data),
                extInfo,
                market.nonces(trader)
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    function _initUsdtGood() internal returns (uint256 goodId) {
        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 100_000_000);
        usdt.approve(address(market), 50_000 * 10 ** 6);
        T_GoodKey memory key = _usdtKey();
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

    function _initBtcGood() internal returns (uint256 goodId) {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 ** 9, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(63_000 * 10 ** 12, 1 * 10 ** 8),
            defaultdata,
            users[1],
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _promiseGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setPromised(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    // ── P2-03 cancelNonce ──────────────────────────────────────────────────

    function testCancelNonce_incrementsCallerNonce() public {
        assertEq(market.nonces(users[1]), 0, "initial");
        vm.prank(users[1]);
        market.cancelNonce();
        _snapMarket("cancelNonce");
        assertEq(market.nonces(users[1]), 1, "incremented");
        assertEq(market.nonces(users[2]), 0, "other user isolated");
    }

    function testCancelNonce_invalidatesSignedBuyGood() public {
        address trader = vm.addr(TRADER_KEY);
        deal(address(usdt), trader, 10_000_000 * 10 ** 6, false);

        _warpToFreshRunSlot();
        uint256 swapQty = toTTSwapUINT256(SWAP_IN, 0);
        bytes memory sig = _signBuyGood(
            trader,
            address(0),
            _usdtKey(),
            _btcKey(),
            swapQty,
            defaultdata,
            0,
            TRADER_KEY
        );

        vm.prank(trader);
        market.cancelNonce();

        vm.prank(users[2]);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        market.buyGood(
            _usdtKey(),
            _btcKey(),
            swapQty,
            address(0),
            defaultdata,
            trader,
            sig,
            0
        );
        _snapMarket("buyGood_revert_staleNonce_after_cancel");
    }

    // ── P2-02 setReferral ──────────────────────────────────────────────────

    function testSetReferral_revert_noCallMintPermission() public {
        vm.prank(users[3]);
        tts_token.setReferral(users[4], users[5]);
        assertEq(tts_token.getreferral(users[4]), address(0), "unchanged");
    }

    function testSetReferral_revert_userEqualsReferral() public {
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(marketcreator, true);
        tts_token.setReferral(users[4], users[4]);
        vm.stopPrank();
        assertEq(tts_token.getreferral(users[4]), address(0), "self refer blocked");
    }

    function testSetReferral_doesNotOverwriteExisting() public {
        address first = users[5];
        address second = users[6];
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(marketcreator, true);
        tts_token.setReferral(users[4], first);
        tts_token.setReferral(users[4], second);
        vm.stopPrank();
        assertEq(tts_token.getreferral(users[4]), first, "first wins");
    }

    function testSetReferral_emitsOnce() public {
        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(marketcreator, true);
        vm.recordLogs();
        tts_token.setReferral(users[4], users[5]);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == REFERRAL_TOPIC) count++;
        }
        assertEq(count, 1, "single referral event");
        vm.stopPrank();
    }

    // ── P2-05 refreshPromise no-op ─────────────────────────────────────────

    function testRefreshPromise_noEmit_whenNotPromised() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 ** 8, false);
        btc.approve(address(market), 10 ** 8);
        _warpToFreshRunSlot();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, 10 ** 8),
            defaultdata,
            defaultdata,
            users[1]
        );
        _snapMarket("investGood_refreshPromise_noEmit_notPromised");
        uint256 proofId = _proofId(users[1], btcGoodId);

        vm.recordLogs();
        market.refreshPromise(proofId);
        _snapMarket("refreshPromise_noEmit_notPromised");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics[0] != PROMISE_TOPIC, "no promise event");
        }
        vm.stopPrank();
    }

    function testRefreshPromise_noEmit_whenGoodOwnerNotCaller() public {
        _promiseGood(usdtGoodId);

        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 10_000 * 10 ** 6, false);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, 1000 * 10 ** 6),
            defaultdata,
            defaultdata,
            users[1]
        );
        _snapMarket("investGood_refreshPromise_noEmit_notOwner");
        uint256 proofId = _proofId(users[1], usdtGoodId);

        vm.recordLogs();
        market.refreshPromise(proofId);
        _snapMarket("refreshPromise_noEmit_notOwner");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics[0] != PROMISE_TOPIC, "no emit when not good owner");
        }
        vm.stopPrank();
    }
}
