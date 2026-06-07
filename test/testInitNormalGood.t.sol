// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";
contract testInitNormalGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    bytes32 internal constant INIT_GOOD_TOPIC =
        keccak256(
            "e_initGood(uint256,uint256,uint256,uint256,uint256,uint256,address)"
        );

    uint256 internal constant INITIAL_CONFIG =
        0x000c350810450000000000842882040800000000000000000000000000000000;

    uint256 internal metaGoodId;
    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant INIT_VALUE = uint128(63000 * 10 ** 12);

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(10);

        vm.startPrank(marketcreator);
        T_GoodKey memory usdtKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        uint128 metaQty = uint128(50000 * 10 ** 6);
        uint128 metaValue = uint128(50000 * 10 ** 12);

        usdt.mint(marketcreator, 100000);
        usdt.approve(address(market), metaQty);
        market.initGood(
            usdtKey,
            toTTSwapUINT256(metaValue, metaQty),
            defaultdata,
            marketcreator,
            defaultdata
        );
        metaGoodId = usdtKey.toId();
        vm.stopPrank();
    }

    function _expectedGoodConfig() internal view returns (uint256) {
        uint256 runSlot = (block.timestamp % 4095) % 10;
        uint256 mask = 0x00000000000000007ff800000000000000000000000000000000000000000000;
        return (INITIAL_CONFIG & ~mask) | (runSlot << 179);
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

    function _assertGoodState(
        uint256 goodId,
        address owner,
        uint128 qty,
        uint128 value
    ) internal view {
        S_GoodTmpState memory good_ = market.getGoodState(goodId);
        assertEq(
            good_.currentState,
            toTTSwapUINT256(qty, qty),
            "currentState error"
        );
        assertEq(
            good_.investState,
            toTTSwapUINT256(qty, value),
            "investState error"
        );
        assertEq(
            good_.goodConfig,
            _expectedGoodConfig(),
            "goodConfig error"
        );
        assertEq(good_.owner, owner, "owner error");
    }

    function _assertProofState(
        uint256 proofId,
        uint256 goodId,
        uint128 qty,
        uint128 value
    ) internal view {
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, goodId, "proof currentgood error");
        assertEq(
            proof.state,
            toTTSwapUINT256(value, value),
            "proof state error"
        );
        assertEq(
            proof.shares,
            toTTSwapUINT256(qty, 0),
            "proof shares error"
        );
        assertEq(
            proof.invest,
            toTTSwapUINT256(qty, qty),
            "proof invest error"
        );
    }

    function testinitNormalGood() public {
        vm.startPrank(users[1]);
        T_GoodKey memory btcKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(btc),
            id: 0
        });
        uint256 btcGoodId = btcKey.toId();

        deal(address(btc), users[1], 10 * BTC_QTY, false);
        btc.approve(address(market), BTC_QTY);

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "before initGood: metagood balance unchanged"
        );
        assertEq(
            btc.balanceOf(address(market)),
            0,
            "before initGood: market btc balance error"
        );

        vm.recordLogs();
        market.initGood(
            btcKey,
            toTTSwapUINT256(INIT_VALUE, BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        snapLastCall("init_ERC20_By_ERC20");

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "after initGood: metagood balance unchanged"
        );
        assertEq(
            btc.balanceOf(address(market)),
            BTC_QTY,
            "after initGood: market btc balance error"
        );
        assertEq(
            btc.balanceOf(users[1]),
            9 * BTC_QTY,
            "after initGood: user btc balance error"
        );

        _assertGoodState(btcGoodId, users[1], BTC_QTY, INIT_VALUE);

        S_GoodTmpState memory metaState = market.getGoodState(metaGoodId);
        assertEq(
            metaState.currentState,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            "after initGood: metagood currentState unchanged"
        );

        uint256 proofId = _proofIdFromInitGoodEvent();
        _assertProofState(proofId, btcGoodId, BTC_QTY, INIT_VALUE);

        vm.stopPrank();
    }

    function testinitNativeETHNormalGood() public {
        vm.startPrank(users[1]);
        T_GoodKey memory nativeKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        uint256 nativeGoodId = nativeKey.toId();

        vm.deal(users[1], 10 * BTC_QTY);
        assertEq(
            address(market).balance,
            0,
            "before initGood: market eth balance error"
        );

        vm.recordLogs();
        market.initGood{value: BTC_QTY}(
            nativeKey,
            toTTSwapUINT256(INIT_VALUE, BTC_QTY),
            defaultdata,
            users[1],
            defaultdata
        );
        snapLastCall("init_NativeETH_By_ERC20");

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "after initGood: metagood balance unchanged"
        );
        assertEq(
            address(market).balance,
            BTC_QTY,
            "after initGood: market eth balance error"
        );
        assertEq(
            users[1].balance,
            9 * BTC_QTY,
            "after initGood: user eth balance error"
        );

        _assertGoodState(nativeGoodId, users[1], BTC_QTY, INIT_VALUE);

        uint256 proofId = _proofIdFromInitGoodEvent();
        _assertProofState(proofId, nativeGoodId, BTC_QTY, INIT_VALUE);

        vm.stopPrank();
    }
}
