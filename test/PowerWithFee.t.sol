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


contract PowerWithFee is BaseSetup {
   
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
        market.modifyGoodConfig(metagood, 5933383818<<223);//2**32+6*2**28+ 1*2**24+ 5*2**21+7*2**16+7*2**11+2*2**6+10
        market.updateGoodConfig(metagood, 220627572776168201641469195996245156569363466678014923256774000640); //5*2**187
        uint256 normalproof = S_ProofKey(marketcreator, metagood, address(0)).toId();
        S_ProofState memory _proof = market.getProofState(normalproof);
         assertEq(_proof.shares.amount0(), 50000000000, "before invest:proof value error");
        assertEq(_proof.shares.amount1(), 0, "before invest:proof value error");
        assertEq(_proof.state.amount0(), 50000000000, "before invest:proof value error");
        assertEq(_proof.state.amount1(), 50000000000, "before invest:proof value error");
        assertEq(_proof.invest.amount0(), 50000000000, "before invest:proof quantity error");
        assertEq(_proof.invest.amount1(), 50000000000, "before invest:proof quantity error");
        console2.log('goodConfig.amount1.before',market.getGoodState(metagood).goodConfig.amount1());
        console2.log('investState.amount0.before',market.getGoodState(metagood).investState.amount0());
        market.investGood{value: 50000000000}(metagood, address(0), 50000 * 10 ** 6, defaultdata, defaultdata);
        console2.log('limitpower',market.getGoodState(metagood).goodConfig.getLimitPower());
        console2.log('power',market.getGoodState(metagood).goodConfig.getPower());
        console2.log('goodConfig.amount1',market.getGoodState(metagood).goodConfig.amount1());
        console2.log('investState.amount0',market.getGoodState(metagood).investState.amount0());
        _proof = market.getProofState(normalproof);
        assertEq(_proof.shares.amount0(), 299875000000, "after invest:proof normal shares error");
        assertEq(_proof.shares.amount1(), 0, "after invest:proof value error");
        assertEq(_proof.state.amount0(), 299875000000, "after invest:proof virtual value error");
        assertEq(_proof.state.amount1(), 99975000000, "after invest:proof actual value error");
        assertEq(_proof.invest.amount0(), 299875000000, "after invest:proof quantity error");
        assertEq(_proof.invest.amount1(), 99975000000, "after invest:proof quantity error");
        assertEq(_proof.valueinvest.amount0(), 0, "after invest:proof quantity error");
        assertEq(_proof.valueinvest.amount1(), 0, "after invest:proof quantity error");
        vm.stopPrank();
    }

    function testDistinvestProof11() public {
        vm.startPrank(marketcreator);
        uint256 normalproof;
        normalproof = S_ProofKey(marketcreator, metagood, address(0)).toId();
        S_ProofState memory _proof = market.getProofState(normalproof);
        assertEq(_proof.shares.amount0(), 299875000000, "before invest:proof value error");
        assertEq(_proof.shares.amount1(), 0, "before invest:proof value error");
        assertEq(_proof.state.amount0(), 299875000000, "before invest:proof value error");
        assertEq(_proof.state.amount1(), 99975000000, "before invest:proof value error");
        assertEq(_proof.invest.amount0(), 299875000000, "before invest:proof quantity error");
        assertEq(_proof.invest.amount1(), 99975000000, "before invest:proof quantity error");
        assertEq(_proof.valueinvest.amount0(), 0, "before invest:proof quantity error");
        assertEq(_proof.valueinvest.amount1(), 0, "before invest:proof quantity error");

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
              assertEq(
            good_.goodConfig.amount1(),
            199900000000,
            "before disinvest nativeeth good:actual value error"
        );
        assertEq(
            good_.currentState.amount0(),
            299900000000,
            "before disinvest nativeeth good:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            299900000000,
            "before disinvest nativeeth good:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            299875000000,
            "before disinvest nativeeth good:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            299875000000,
            "before disinvest nativeeth good:metagood investState amount1 error"
        );
       

        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_first");
        good_ = market.getGoodState(metagood);
        assertEq(
            good_.goodConfig.amount1(),
            193233889120,
            "after disinvest nativeeth good:actual value error"
        );
        assertEq(
            good_.currentState.amount0(),
            289902166320,
            "after disinvest nativeeth good:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            289902166320,
            "after disinvest nativeeth good:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            289875000000,
            "after disinvest nativeeth good:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            289875000000,
            "after disinvest nativeeth good:metagood investState amount1 error"
        );
        

        _proof = market.getProofState(normalproof);
        assertEq(_proof.shares.amount0(), 289875000000, "after invest:proof value error");
        assertEq(_proof.shares.amount1(), 0, "after invest:proof value error");
        assertEq(_proof.state.amount0(), 289875000000, "after invest:proof value error");
        assertEq(_proof.state.amount1(), 96641110880, "after invest:proof value error");
        assertEq(_proof.invest.amount0(), 289875000000, "after invest:proof quantity error");
        assertEq(_proof.invest.amount1(), 96641110880, "after invest:proof quantity error");
        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_second");

        market.disinvestProof(normalproof, 10000 * 10 ** 6, address(0));
        snapLastCall("disinvest_own_nativeeth_valuegood_three");
        vm.stopPrank();
    }
}
