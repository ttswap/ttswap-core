// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, Vm} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

contract testInitMetaGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    bytes32 internal constant INIT_GOOD_TOPIC =
        keccak256(
            "e_initGood(uint256,uint256,uint256,uint256,uint256,address)"
        );

    uint256 internal constant INITIAL_CONFIG = TestConfigConstants.INITIAL_GOOD_CONFIG;

    uint256 goodId;

    function setUp() public override {
        BaseSetup.setUp();
        // initial_config lastRunSlot defaults to 0
        vm.warp(10);
    }

    function _expectedGoodConfig() internal pure returns (uint256) {
        return TestConfigConstants.INITIAL_GOOD_CONFIG;
    }

    function _proofIdFromInitGoodEvent() internal returns (uint256 proofId) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == INIT_GOOD_TOPIC) {
                return uint256(logs[i - 1].topics[1]);
            }
        }
        revert("e_initGood not found");
    }

    function testinitMetaGood() public {
        vm.startPrank(marketcreator);
        T_GoodKey memory usdtKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        uint128 initialValue = uint128(50000 * 10 ** 12);
        uint128 initialQty = uint128(50000 * 10 ** 6);

        usdt.mint(marketcreator, 100000);
        usdt.approve(address(market), initialQty);

        assertEq(
            usdt.balanceOf(marketcreator),
            100000 * 10 ** 6,
            "before initGood: marketcreator balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            0,
            "before initGood: market balance error"
        );

        vm.recordLogs();
        market.initGood(
            usdtKey,
            toTTSwapUINT256(initialValue, initialQty),
            defaultdata,
            marketcreator,
            defaultdata
        );
        _snapMarket("init_ERC20_metagood");
        goodId = usdtKey.toId();

        assertEq(
            usdt.balanceOf(marketcreator),
            100000 * 10 ** 6 - initialQty,
            "after initGood: marketcreator balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            initialQty,
            "after initGood: market balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(goodId);
        assertEq(
            good_.currentState,
            toTTSwapUINT256(initialQty, initialQty),
            "after initGood: currentState error"
        );
        assertEq(
            good_.investState,
            toTTSwapUINT256(initialQty, initialValue),
            "after initGood: investState error"
        );
        assertEq(
            good_.goodConfig,
            _expectedGoodConfig(),
            "after initGood: goodConfig error"
        );
        assertEq(
            good_.owner,
            marketcreator,
            "after initGood: owner error"
        );

        uint256 proofId = _proofIdFromInitGoodEvent();
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(
            proof.currentgood,
            goodId,
            "after initGood: proof currentgood error"
        );
        assertEq(
            proof.state,
            toTTSwapUINT256(initialValue, initialValue),
            "after initGood: proof state error"
        );
        assertEq(
            proof.shares,
            toTTSwapUINT256(initialQty, 0),
            "after initGood: proof shares error"
        );
        assertEq(
            proof.invest,
            toTTSwapUINT256(initialQty, initialQty),
            "after initGood: proof invest error"
        );

        vm.stopPrank();
    }

    function testinitNativeMetaGood() public {
        vm.startPrank(marketcreator);
        T_GoodKey memory nativeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        uint128 initialValue = uint128(50000 * 10 ** 12);
        uint128 initialQty = uint128(50000 * 10 ** 6);

        vm.deal(marketcreator, 100000 * 10 ** 6);
        assertEq(
            marketcreator.balance,
            100000 * 10 ** 6,
            "before initGood: marketcreator balance error"
        );
        assertEq(
            address(market).balance,
            0,
            "before initGood: market balance error"
        );

        vm.recordLogs();
        market.initGood{value: initialQty}(
            nativeKey,
            toTTSwapUINT256(initialValue, initialQty),
            defaultdata,
            marketcreator,
            defaultdata
        );
        _snapMarket("init_NativeETH_metagood");
        goodId = nativeKey.toId();

        assertEq(
            marketcreator.balance,
            100000 * 10 ** 6 - initialQty,
            "after initGood: marketcreator balance error"
        );
        assertEq(
            address(market).balance,
            initialQty,
            "after initGood: market balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(goodId);
        assertEq(
            good_.currentState,
            toTTSwapUINT256(initialQty, initialQty),
            "after initGood: currentState error"
        );
        assertEq(
            good_.investState,
            toTTSwapUINT256(initialQty, initialValue),
            "after initGood: investState error"
        );
        assertEq(
            good_.goodConfig,
            _expectedGoodConfig(),
            "after initGood: goodConfig error"
        );
        assertEq(
            good_.owner,
            marketcreator,
            "after initGood: owner error"
        );

        uint256 proofId = _proofIdFromInitGoodEvent();
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(
            proof.currentgood,
            goodId,
            "after initGood: proof currentgood error"
        );
        assertEq(
            proof.state,
            toTTSwapUINT256(initialValue, initialValue),
            "after initGood: proof state error"
        );
        assertEq(
            proof.shares,
            toTTSwapUINT256(initialQty, 0),
            "after initGood: proof shares error"
        );
        assertEq(
            proof.invest,
            toTTSwapUINT256(initialQty, initialQty),
            "after initGood: proof invest error"
        );

        vm.stopPrank();
    }
}
