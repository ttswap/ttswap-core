// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @dev Shared v2 pool setup for fuzz suites (TASK-P3-004).
abstract contract FuzzBase is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 internal constant SAFE_LINE_SHIFT = 204;
    uint256 internal constant SAFE_LINE_MASK = uint256(0x3FF) << SAFE_LINE_SHIFT;

    uint128 internal constant USDT_INIT_QTY = uint128(50_000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63_000 * 10 ** 12);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;
    uint256 internal fuzzTs = 1;

    address internal constant FUZZ_USER = address(0xBEEF);

    function _fuzzPoolSetUp() internal {
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
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

    function _warp() internal {
        vm.warp(fuzzTs);
        fuzzTs++;
        if (fuzzTs > 9) fuzzTs = 1;
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
        deal(address(btc), owner, 20 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(key, toTTSwapUINT256(value, qty), defaultdata, owner, defaultdata);
        goodId = key.toId();
        vm.stopPrank();
    }

    function _verifyGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setVerified(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _relaxSafeLine(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~SAFE_LINE_MASK) | (uint256(1023) << SAFE_LINE_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _decodeTTSwapError(bytes memory reason) internal pure returns (uint256 code) {
        if (reason.length < 36) return type(uint256).max;
        bytes4 selector;
        assembly {
            selector := mload(add(reason, 0x20))
            code := mload(add(reason, 0x24))
        }
        if (selector != bytes4(keccak256("TTSwapError(uint256)"))) {
            return type(uint256).max;
        }
    }
}
