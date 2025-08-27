// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
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


contract disinvestNativeETHOwnValueGood is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        investOwnERC20ValueGood();
    }

    function initmetagood() public {
        deal(marketcreator, 1000000 * 10 ** 6);
        vm.startPrank(marketcreator);
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initMetaGood{value: 50000 * 10 ** 6}(
            address(1), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), _goodconfig, defaultdata
        );
        metagood = address(1);
        vm.stopPrank();
    }

    function investOwnERC20ValueGood() public {
        vm.startPrank(marketcreator);
        market.investGood{value: 50000000000}(metagood, address(0), 50000 * 10 ** 6, defaultdata, defaultdata);
        vm.stopPrank();
    }

    function testDistinvestProof() public {
        vm.startPrank(marketcreator);
        uint256 normalproof;
        normalproof = S_ProofKey(marketcreator, metagood, address(0)).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            _proof1.shares.amount0(),
            99995000000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            0,
            "before invest:proof value shares error"
        );
        assertEq(_proof1.state.amount0(), 99995000000, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 99995000000, "before invest:proof value error");
        assertEq(
            _proof1.invest.amount1(),
            99995000000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.invest.amount0(),
            99995000000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount1(),
            0,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount0(),
            0,
            "before invest:proof quantity error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            100000000000,
            "before disinvest nativeeth good:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            100000000000,
            "before disinvest nativeeth good:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            99995000000,
            "before disinvest nativeeth good:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            99995000000,
            "before disinvest nativeeth good:metagood investState amount1 error"
        );
        

        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_first");
        good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            90002499975,
            "after disinvest nativeeth good:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            89999499975,
            "after disinvest nativeeth good:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            89995000000,
            "after disinvest nativeeth good:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            89995000000,
            "after disinvest nativeeth good:metagood investState amount1 error"
        );
        

        _proof1 = market.getProofState(normalproof);
        assertEq(
            _proof1.shares.amount0(),
            89995000000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            0,
            "before invest:proof value shares error"
        );
        assertEq(_proof1.state.amount0(), 89995000000, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 89995000000, "before invest:proof value error");
        assertEq(
            _proof1.invest.amount1(),
            89995000000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.invest.amount0(),
            89995000000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount1(),
            0,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount0(),
            0,
            "before invest:proof quantity error"
        );
        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_second");

        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_three");
        vm.stopPrank();
    }
}
