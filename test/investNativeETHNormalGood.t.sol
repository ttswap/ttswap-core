// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import { S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";


contract investNativeETHNormalGood is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address nativeeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        initnativeethgood();
    }

    function initmetagood() public {
        BaseSetup.setUp();
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initMetaGood(address(usdt), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), _goodconfig, defaultdata);
        metagood = address(usdt);
        vm.stopPrank();
    }

    function initnativeethgood() public {
        vm.startPrank(users[1]);
        deal(users[1], 10 * 10 ** 8);
        deal(address(usdt), users[1], 50000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000000 * 10 ** 6 + 1);
        assertEq(usdt.balanceOf(address(market)), 50000 * 10 ** 6, "befor init erc20 good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood{value: 100000000}(
            metagood,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(1),
            normalgoodconfig,
            defaultdata,
            defaultdata
        );
        nativeeth = address(1);
        vm.stopPrank();
    }

    function testinvestOwnNativeETHNormalGood() public {
        vm.startPrank(users[1]);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);

        uint256 normalproof;
        normalproof = S_ProofKey(users[1], nativeeth, metagood).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            users[1].balance, 900000000, "before invest nativeeth_normalgood:btc users[1] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(users[1]),
            49937000000000,
            "before invest nativeeth_normalgood:usdt users[1] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before invest nativeeth_normalgood:usdt address(market) account invest balance error"
        );
        assertEq(
            address(market).balance,
            100000000,
            "before invest nativeeth_normalgood:btc address(market) account invest balance error"
        );
        assertEq(_proof1.state.amount0(), 62993700000, "before invest:proof value error");
        assertEq(_proof1.invest.amount1(), 100000000, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 62993700000, "before invest:proof quantity error");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_own_nativeeth_normalgood_first");
        assertEq(
            users[1].balance, 800000000, "after invest nativeeth_normalgood:btc users[1] account invest balance error"
        );
        assertEq(
            address(market).balance,
            200000000,
            "after invest nativeeth_normalgood:btc market account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            175993700000,
            "after invest nativeeth_normalgood:usdt market account invest balance error"
        );

        assertEq(
            usdt.balanceOf(users[1]),
            49874006300000,
            "after invest nativeeth_normalgood:usdt users[1] account invest balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            175981100630,
            "after invest nativeeth_normalgood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            175981100630,
            "after invest nativeeth_normalgood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            175981100630,
            "after invest nativeeth_normalgood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            175981100630,
            "after invest nativeeth_normalgood:metagood investState amount1 error"
        );
        assertEq(
            good_.feeQuantityState.amount0(),
            16111252,
            "after invest nativeeth_normalgood:metagood feeQuantityState amount0 error"
        );
        assertEq(
            good_.feeQuantityState.amount1(),
            3511882,
            "after invest nativeeth_normalgood:metagood feeQuantityState amount1 error"
        );

        assertEq(
            good_.goodConfig,
            uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "after invest nativeeth_normalgood:metagood goodConfig error"
        );

        assertEq(good_.owner, marketcreator, "after invest nativeeth_normalgood:metagood marketcreator error");

        normalproof = S_ProofKey(users[1], nativeeth, metagood).toId();
        _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.state.amount0(), 125981100630, "after invest:proof value error");
        assertEq(_proof1.invest.amount0(), 0, "after invest:cur contruct fee error");
        assertEq(_proof1.invest.amount1(), 199990000, "after invest:cur quantity error");
        assertEq(_proof1.valueinvest.amount0(), 3511882, "after invest:value contrunt fee quantity error");
        assertEq(_proof1.valueinvest.amount1(), 125981100630, "after invest:value  quantity error");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_own_nativeeth_normalgood_second");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_own_nativeeth_normalgood_three");

        vm.stopPrank();
    }

    function testinvestotherNativeETHNormalGood() public {
        vm.startPrank(users[4]);
        deal(address(usdt), users[4], 800000 * 10 ** 6, false);
        deal(users[4], 10 * 10 ** 8);
        usdt.approve(address(market), 800000 * 10 ** 6);

        uint256 normalproof = S_ProofKey(users[4], nativeeth, metagood).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            users[4].balance, 1000000000, "before invest nativeeth_normalgood:btc users[4] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(users[4]),
            800000000000,
            "before invest nativeeth_normalgood:usdt users[4] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before invest nativeeth_normalgood:usdt address(market) account invest balance error"
        );
        assertEq(
            address(market).balance,
            100000000,
            "before invest nativeeth_normalgood:btc address(market) account invest balance error"
        );
        assertEq(_proof1.state.amount0(), 0, "before invest:proof value error");
        assertEq(_proof1.invest.amount1(), 0, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 0, "before invest:proof quantity error");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_other_nativeeth_normalgood_first");

        assertEq(
            users[4].balance, 900000000, "after invest nativeeth_normalgood:btc users[4] account invest balance error"
        );
        assertEq(
            address(market).balance,
            200000000,
            "after invest nativeeth_normalgood:btc market account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            175993700000,
            "after invest nativeeth_normalgood:usdt market account invest balance error"
        );

        assertEq(
            usdt.balanceOf(users[4]),
            737006300000,
            "after invest nativeeth_normalgood:usdt users[4] account invest balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            175981100630,
            "after invest nativeeth_normalgood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            175981100630,
            "after invest nativeeth_normalgood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            175981100630,
            "after invest nativeeth_normalgood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            175981100630,
            "after invest nativeeth_normalgood:metagood investState amount1 error"
        );
        assertEq(
            good_.feeQuantityState.amount0(),
            16111252,
            "after invest nativeeth_normalgood:metagood feeQuantityState amount0 error"
        );
        assertEq(
            good_.feeQuantityState.amount1(),
            3511882,
            "after invest nativeeth_normalgood:metagood feeQuantityState amount1 error"
        );

        assertEq(
            good_.goodConfig,
             uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "after invest nativeeth_normalgood:metagood goodConfig error"
        );

        assertEq(good_.owner, marketcreator, "after invest nativeeth_normalgood:metagood marketcreator error");

        normalproof = S_ProofKey(users[4], nativeeth, metagood).toId();
        _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.state.amount0(), 62987400630, "after invest:proof value error");
        assertEq(_proof1.invest.amount0(), 0, "after invest:cur contruct fee error");
        assertEq(_proof1.invest.amount1(), 99990000, "after invest:cur quantity error");
        assertEq(_proof1.valueinvest.amount0(), 3511882, "after invest:value contrunt fee quantity error");
        assertEq(_proof1.valueinvest.amount1(), 62987400630, "after invest:value  quantity error");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_other_nativeeth_normalgood_second");

        market.investGood{value: 100000000}(nativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        snapLastCall("invest_other_nativeeth_normalgood_three");

        vm.stopPrank();
    }
}
