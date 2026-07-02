// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "../BaseSetup.t.sol";
import {TTSwap_Market} from "../../src/TTSwap_Market.sol";
import {I_TTSwap_Token} from "../../src/interfaces/I_TTSwap_Token.sol";
import {I_TTSwap_Market} from "../../src/interfaces/I_TTSwap_Market.sol";
import {IMulticall_v4} from "../../src/interfaces/IMulticall_v4.sol";
import {S_GoodTmpState} from "../../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {TTSwapError} from "../../src/libraries/L_Error.sol";
import {TTSwap_Market_Proxy} from "../../src/TTSwap_Market_Proxy.sol";
import {TestConfigConstants} from "../TestConfigConstants.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../../src/libraries/L_TTSwapUINT256.sol";

/// @dev Positive control: multicall without outer `msgValue` re-arms ETH budget (C-01).
contract VulnerableMulticallMarket is TTSwap_Market {
    constructor(I_TTSwap_Token _ttsToken) TTSwap_Market(_ttsToken) {}

    function multicallVulnerable(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (!success) {
                assembly {
                    revert(add(result, 0x20), mload(result))
                }
            }
            results[i] = result;
        }
    }
}

/// @notice C-01 verification against production `TTSwap_Market.multicall` (msgValue + guardedEntry).
contract C01_MulticallProduction is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    uint256 internal nativeGoodId;
    uint256 internal btcGoodId;
    uint256 internal usdtGoodId;

    uint128 internal constant NATIVE_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant ETH_PER_SWAP = uint128(50 * 10 ** 6);

    address internal trader;

    function setUp() public override {
        BaseSetup.setUp();
        trader = users[1];

        vm.warp(0);
        nativeGoodId = _initNativeGood(
            marketcreator,
            NATIVE_INIT_QTY,
            NATIVE_INIT_VALUE
        );
        btcGoodId = _initBtcGood(users[2], BTC_INIT_VALUE, BTC_INIT_QTY);
        usdtGoodId = _initUsdtGood(users[3], USDT_INIT_QTY, USDT_INIT_VALUE);
        _markAsValueGood(nativeGoodId);
        _relaxSafeLine(nativeGoodId);
        _relaxSafeLine(btcGoodId);
        _relaxSafeLine(usdtGoodId);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
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

    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 1000000);
        usdt.approve(address(market), type(uint256).max);
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
        vm.prank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
    }

    function _encodeBuyGood(
        T_GoodKey memory keyIn,
        T_GoodKey memory keyOut,
        uint128 ethIn,
        address _trader
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            I_TTSwap_Market.buyGood,
            (
                keyIn,
                keyOut,
                toTTSwapUINT256(ethIn, 1),
                address(0),
                defaultdata,
                _trader,
                defaultdata,
                uint256(0)
            )
        );
    }

    function _multicallMarket() internal view returns (IMulticall_v4) {
        return IMulticall_v4(payable(address(market)));
    }

    /// @dev Production `multicall` + outer `msgValue` should not re-arm ETH budget on subcall #2.
    ///      Second full-ETH swap must fail with insufficient transient budget (error 30).
    function test_C01_production_multicall_blocks_second_full_eth_swap() public {
        vm.deal(trader, 10 * ETH_PER_SWAP);

        bytes[] memory calls = new bytes[](2);
        calls[0] = _encodeBuyGood(
            _nativeKey(),
            _btcKey(),
            ETH_PER_SWAP,
            trader
        );
        calls[1] = _encodeBuyGood(
            _nativeKey(),
            _usdtKey(),
            ETH_PER_SWAP,
            trader
        );

        vm.startPrank(trader);
        _warpToFreshRunSlot();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 30));
        _multicallMarket().multicall{value: ETH_PER_SWAP}(calls);
        _snapMarket("multicall_revert_second_full_eth_swap");
        vm.stopPrank();
    }

    /// @dev Splitting one ETH budget across two subcalls is the intended multicall pattern.
    function test_C01_production_multicall_split_budget_succeeds() public {
        vm.deal(trader, 10 * ETH_PER_SWAP);
        uint128 half = ETH_PER_SWAP / 2;

        uint256 btcBefore = btc.balanceOf(trader);
        uint256 usdtBefore = usdt.balanceOf(trader);
        S_GoodTmpState memory nativeBefore = market.getGoodState(nativeGoodId);

        bytes[] memory calls = new bytes[](2);
        calls[0] = _encodeBuyGood(_nativeKey(), _btcKey(), half, trader);
        calls[1] = _encodeBuyGood(_nativeKey(), _usdtKey(), half, trader);

        vm.startPrank(trader);
        _warpToFreshRunSlot();
        _multicallMarket().multicall{value: ETH_PER_SWAP}(calls);
        _snapMarket("multicall_split_budget");
        vm.stopPrank();

        assertGt(btc.balanceOf(trader), btcBefore, "received BTC");
        assertGt(usdt.balanceOf(trader), usdtBefore, "received USDT");

        uint128 nativeQtyDelta = market.getGoodState(nativeGoodId).currentState
            .amount1() - nativeBefore.currentState.amount1();
        assertApproxEqAbs(
            nativeQtyDelta,
            ETH_PER_SWAP,
            1_000_000,
            "native pool credited once for the shared budget"
        );
    }

    /// @dev Native pool must not be credited 2x when only one ETH budget is supplied.
    function test_C01_production_multicall_no_double_accounting_on_forced_batch() public {
        vm.deal(trader, 10 * ETH_PER_SWAP);

        S_GoodTmpState memory nativeBefore = market.getGoodState(nativeGoodId);
        uint256 marketEthBefore = address(market).balance;

        bytes[] memory calls = new bytes[](2);
        calls[0] = _encodeBuyGood(
            _nativeKey(),
            _btcKey(),
            ETH_PER_SWAP,
            trader
        );
        calls[1] = _encodeBuyGood(
            _nativeKey(),
            _usdtKey(),
            ETH_PER_SWAP,
            trader
        );

        vm.startPrank(trader);
        _warpToFreshRunSlot();
        vm.expectRevert();
        _multicallMarket().multicall{value: ETH_PER_SWAP}(calls);
        _snapMarket("multicall_revert_no_double_accounting");
        vm.stopPrank();

        uint128 nativeQtyDelta = market.getGoodState(nativeGoodId).currentState
            .amount1() - nativeBefore.currentState.amount1();

        assertLt(
            nativeQtyDelta,
            ETH_PER_SWAP * 2,
            "batch must not persist 2x native credit"
        );
        assertLe(
            address(market).balance - marketEthBefore,
            ETH_PER_SWAP,
            "market received at most one ETH budget"
        );
    }

    /// @dev Positive control: multicall without outer `msgValue` re-arms ETH budget (C-01 exploit).
    function test_C01_vulnerable_multicall_double_accounts_native_pool() public {
        VulnerableMulticallMarket logic = new VulnerableMulticallMarket(tts_token);
        VulnerableMulticallMarket vulnerable = VulnerableMulticallMarket(
            payable(address(new TTSwap_Market_Proxy(tts_token, address(logic))))
        );

        vm.startPrank(marketcreator);
        tts_token.setCallMintTTS(address(vulnerable), true);
        vm.stopPrank();

        vm.warp(0);
        uint256 vulnNativeId = _initNativeGoodOn(
            vulnerable,
            marketcreator,
            NATIVE_INIT_QTY,
            NATIVE_INIT_VALUE
        );
        _initBtcGoodOn(vulnerable, users[2], BTC_INIT_VALUE, BTC_INIT_QTY);
        _initUsdtGoodOn(vulnerable, users[3], USDT_INIT_QTY, USDT_INIT_VALUE);
        vm.startPrank(marketcreator);
        vulnerable.modifyGoodByAdmin(vulnNativeId, (1 << 255), marketcreator, defaultdata);
        uint256 cfg = vulnerable.getGoodState(vulnNativeId).goodConfig;
        cfg =
            (cfg & ~SAFE_LINE_MASK) |
            (uint256(255) << TestConfigConstants.SAFE_LINE_UPPER_SHIFT) |
            (uint256(1) << TestConfigConstants.SAFE_LINE_LOWER_SHIFT);
        vulnerable.modifyGoodByManager(vulnNativeId, cfg, marketcreator, defaultdata);
        vm.stopPrank();

        vm.deal(trader, 10 * ETH_PER_SWAP);
        S_GoodTmpState memory nativeBefore = vulnerable.getGoodState(vulnNativeId);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            I_TTSwap_Market.buyGood,
            (
                _nativeKey(),
                _btcKey(),
                toTTSwapUINT256(ETH_PER_SWAP, 1),
                address(0),
                defaultdata,
                trader,
                defaultdata,
                uint256(0)
            )
        );
        calls[1] = abi.encodeCall(
            I_TTSwap_Market.buyGood,
            (
                _nativeKey(),
                _usdtKey(),
                toTTSwapUINT256(ETH_PER_SWAP, 1),
                address(0),
                defaultdata,
                trader,
                defaultdata,
                uint256(0)
            )
        );

        vm.startPrank(trader);
        _warpToFreshRunSlot();
        vulnerable.multicallVulnerable{value: ETH_PER_SWAP}(calls);
        _snapMarket("multicall_vulnerable_double_account");
        vm.stopPrank();

        uint128 nativeQtyDelta = vulnerable.getGoodState(vulnNativeId).currentState
            .amount1() - nativeBefore.currentState.amount1();
        assertGe(
            nativeQtyDelta,
            ETH_PER_SWAP * 2 - 1_000_000,
            "C-01: one ETH budget credited twice to native pool"
        );
    }

    function _initNativeGoodOn(
        TTSwap_Market target,
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 10 * qty);
        T_GoodKey memory key = _nativeKey();
        target.initGood{value: qty}(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initBtcGoodOn(
        TTSwap_Market target,
        address owner,
        uint128 value,
        uint128 qty
    ) internal {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * qty, false);
        btc.approve(address(target), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        target.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        vm.stopPrank();
    }

    function _initUsdtGoodOn(
        TTSwap_Market target,
        address owner,
        uint128 qty,
        uint128 value
    ) internal {
        vm.startPrank(owner);
        usdt.mint(owner, 1000000);
        usdt.approve(address(target), type(uint256).max);
        T_GoodKey memory key = _usdtKey();
        target.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        vm.stopPrank();
    }

    /// @dev Control: standalone single swap still works on production market.
    function test_C01_production_single_buyGood_baseline() public {
        vm.deal(trader, 10 * ETH_PER_SWAP);
        vm.startPrank(trader);
        _warpToFreshRunSlot();
        market.buyGood{value: ETH_PER_SWAP}(
            _nativeKey(),
            _btcKey(),
            toTTSwapUINT256(ETH_PER_SWAP, 1),
            address(0),
            defaultdata,
            trader,
            defaultdata,
            0
        );
        _snapMarket("buyGood_native_btc_baseline");
        vm.stopPrank();
    }
}
