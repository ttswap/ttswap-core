// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
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


contract disinvestNativeETHOtherNormalGood is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodnativeeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        initbtcgood();
        investOwnNativeETHNormalGood();
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

    function initbtcgood() public {
        vm.startPrank(users[1]);
        deal(users[1], 10 * 10 ** 8);
        deal(address(usdt), users[1], 50000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000000 * 10 ** 6 + 1);
        assertEq(usdt.balanceOf(address(market)), 50000 * 10 ** 6, "befor init nativeeth good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood{value: 1 * 10 ** 8}(
            metagood,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(1),
            normalgoodconfig,
            defaultdata,
            defaultdata
        );
        normalgoodnativeeth = address(1);
        vm.stopPrank();
    }

    function investOwnNativeETHNormalGood() public {
        vm.startPrank(users[2]);

        deal(users[2], 10 * 10 ** 8);
        deal(address(usdt), users[2], 50000000 * 10 ** 6, false);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);
        market.investGood{value: 1 * 10 ** 8}(normalgoodnativeeth, metagood, 1 * 10 ** 8, defaultdata, defaultdata);
        vm.stopPrank();
    }

    function testDistinvestProof() public {
        vm.startPrank(users[2]);
        uint256 normalproof;
        normalproof = S_ProofKey(users[2], normalgoodnativeeth, metagood).toId();
        S_ProofState memory _proof = market.getProofState(normalproof);
        assertEq(_proof.state.amount0(), 62987400630, "before disinvest:proof value error");
        assertEq(_proof.invest.amount1(), 99990000, "before disinvest:proof quantity error");

        assertEq(_proof.invest.amount0(), 0, "before disinvest:proof contruct error");
        assertEq(_proof.valueinvest.amount1(), 62987400630, "before disinvest:proof valueinvest quantity error");

        assertEq(_proof.valueinvest.amount0(), 3511882, "before disinvest:proof  valueinvest contruct error");

        S_GoodTmpState memory good_ = market.getGoodState(normalgoodnativeeth);
        assertEq(
            good_.currentState.amount0(),
            125981100630,
            "before disinvest nativeeth good:normalgoodnativeeth currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            199990000,
            "before disinvest nativeeth good:normalgoodnativeeth currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            125981100630,
            "before disinvest nativeeth good:normalgoodnativeeth investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            199990000,
            "before disinvest nativeeth good:normalgoodnativeeth investState amount1 error"
        );
        assertEq(
            good_.feeQuantityState.amount0(),
            10000,
            "before disinvest nativeeth good:normalgoodnativeeth feeQuantityState amount0 error"
        );
        assertEq(
            good_.feeQuantityState.amount1(),
            0,
            "before disinvest nativeeth good:normalgoodnativeeth feeQuantityState amount1 error"
        );
        normalproof = S_ProofKey(users[2], normalgoodnativeeth, metagood).toId();

        market.disinvestProof(normalproof, 1 * 10 ** 5, address(0));
        snapLastCall("disinvest_other_nativeeth_normalgood_first");
        good_ = market.getGoodState(normalgoodnativeeth);
        assertEq(
            good_.currentState.amount0(),
            125918106930,
            "after disinvest nativeeth good:normalgoodnativeeth currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            199890000,
            "after disinvest nativeeth good:normalgoodnativeeth currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            125918106930,
            "after disinvest nativeeth good:normalgoodnativeeth investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            199890000,
            "after disinvest nativeeth good:normalgoodnativeeth investState amount1 error"
        );
        assertEq(
            good_.feeQuantityState.amount0(),
            10025,
            "after disinvest nativeeth good:normalgoodnativeeth feeQuantityState amount0 error"
        );
        assertEq(
            good_.feeQuantityState.amount1(),
            0,
            "after disinvest nativeeth good:normalgoodnativeeth feeQuantityState amount1 error"
        );

        _proof = market.getProofState(normalproof);
        assertEq(_proof.state.amount0(), 62924406930, "after disinvest:proof value error");
        assertEq(_proof.invest.amount1(), 99890000, "after disinvest:proof quantity error");
        assertEq(_proof.invest.amount0(), 0, "after disinvest:proof contruct error");
        market.disinvestProof(normalproof, 1 * 10 ** 6, address(0));
        snapLastCall("disinvest_other_nativeeth_normalgood_second");

        market.disinvestProof(normalproof, 1 * 10 ** 6, address(0));
        snapLastCall("disinvest_other_nativeeth_normalgood_three");
        vm.stopPrank();
    }
}
