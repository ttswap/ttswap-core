// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

contract investValueGoodWithPowerWithoutFee is BaseSetup {
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
    }

    function initmetagood() public {
        deal(marketcreator, 1000000 * 10 ** 6);
        vm.startPrank(marketcreator);
        uint256 _goodconfig = (2 ** 255) +
            1 *
            2 ** 217 +
            3 *
            2 ** 211 +
            5 *
            2 ** 204 +
            7 *
            2 ** 197;
        market.initMetaGood{value: 50000 * 10 ** 6}(
            address(1),
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        metagood = address(1);
        vm.stopPrank();
    }

    function testInvestERC20ValueGoodWithPowerWithoutFee() public {
        vm.startPrank(marketcreator);
        market.modifyGoodConfig(metagood, 5933383818 << 223); //2**32+6*2**28+ 1*2**24+ 5*2**21+7*2**16+7*2**11+2*2**6+10
        market.updateGoodConfig(
            metagood,
            980797146154168869349342097376197877515993038197505392640
        ); //5*2**187
        uint256 normalproof = S_ProofKey(marketcreator, metagood, address(0))
            .toId();
        S_ProofState memory _proof = market.getProofState(normalproof);
        assertEq(
            _proof.shares.amount0(),
            50000000000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof.shares.amount1(),
            0,
            "before invest:proof value shares error"
        );
        assertEq(
            _proof.state.amount0(),
            50000000000,
            "before invest:proof value error"
        );
        assertEq(
            _proof.state.amount1(),
            50000000000,
            "before invest:proof value error"
        );
        assertEq(
            _proof.invest.amount0(),
            50000000000,
            "before invest:proof share error"
        );
        assertEq(
            _proof.invest.amount1(),
            50000000000,
            "before invest:proof quantity error"
        );
        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.goodConfig.amount0(),
            235045548696005107428893671859226148864,
            "after invest metagood:metagood goodConfig amount0 error"
        );
        assertEq(
            good_.goodConfig.amount1(),
            0,
            "after invest metagood:metagood goodConfig amount1 error"
        );
        assertEq(
            good_.currentState.amount0(),
            50000000000,
            "after invest metagood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            50000000000,
            "after invest metagood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            50000000000,
            "after invest metagood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            50000000000,
            "after invest metagood:metagood investState amount1 error"
        );
        market.investGood{value: 50000000000}(
            metagood,
            address(0),
            50000 * 10 ** 6,
            defaultdata,
            defaultdata
        );
        snapLastCall("invest_own_erc20_valuegood_with_power_without_fee_first");
        good_ = market.getGoodState(metagood);
        assertEq(
            good_.goodConfig.amount0(),
            235045548696005107428893671859226148864,
            "after invest metagood:metagood goodConfig amount0 error"
        );
        assertEq(
            good_.goodConfig.amount1(),
            200000000000,
            "after invest metagood:metagood goodConfig amount1 error"
        );
        assertEq(
            good_.currentState.amount0(),
            300000000000,
            "after invest metagood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            300000000000,
            "after invest metagood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            300000000000,
            "after invest metagood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            300000000000,
            "after invest metagood:metagood investState amount1 error"
        );
        _proof = market.getProofState(normalproof);
        assertEq(
            _proof.shares.amount0(),
            300000000000,
            "after invest:proof normal shares error"
        );
        assertEq(
            _proof.shares.amount1(),
            0,
            "after invest:proof value shares error"
        );
        assertEq(
            _proof.state.amount0(),
            300000000000,
            "after invest:proof value error"
        );
        assertEq(
            _proof.state.amount1(),
            100000000000,
            "after invest:proof value error"
        );
        assertEq(
            _proof.invest.amount0(),
            300000000000,
            "after invest:proof share error"
        );
        assertEq(
            _proof.invest.amount1(),
            100000000000,
            "after invest:proof quantity error"
        );
        vm.stopPrank();
    }

    function testInvestERC20ValueGoodWithPowerWithFee() public {
        vm.startPrank(marketcreator);
        uint256 _goodconfig = 79981855578818984530741847599767577980563253776224576862486865638440826830848; //((2 ** 255) + 8 * 2 ** 217 + 8 * 2 ** 211 + 8 * 2 ** 204 + 8 * 2 ** 197)+5*2**187+20*2**177+(6*2**22+ 1*2**18+ 5*2**15+8*2**10+8*2**5+2)*2**229+5*2**223;

        market.modifyGoodConfig(metagood, _goodconfig); //2**32+6*2**28+ 1*2**24+ 5*2**21+7*2**16+7*2**11+2*2**6+10
        market.updateGoodConfig(metagood, _goodconfig); //5*2**187
        uint256 normalproof = S_ProofKey(marketcreator, metagood, address(0))
            .toId();
        S_ProofState memory _proof = market.getProofState(normalproof);
        assertEq(
            _proof.shares.amount0(),
            50000000000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof.shares.amount1(),
            0,
            "before invest:proof value shares error"
        );
        assertEq(
            _proof.state.amount0(),
            50000000000,
            "before invest:proof value error"
        );
        assertEq(
            _proof.state.amount1(),
            50000000000,
            "before invest:proof value error"
        );
        assertEq(
            _proof.invest.amount0(),
            50000000000,
            "before invest:proof share error"
        );
        assertEq(
            _proof.invest.amount1(),
            50000000000,
            "before invest:proof quantity error"
        );
        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.goodConfig.amount0(),
            235045548502964441738117234425444958208,
            "after invest metagood:metagood goodConfig amount0 error"
        );
        assertEq(
            good_.goodConfig.amount1(),
            0,
            "after invest metagood:metagood goodConfig amount1 error"
        );
        assertEq(
            good_.currentState.amount0(),
            50000000000,
            "after invest metagood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            50000000000,
            "after invest metagood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            50000000000,
            "after invest metagood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            50000000000,
            "after invest metagood:metagood investState amount1 error"
        );
        market.investGood{value: 50000000000}(
            metagood,
            address(0),
            50000 * 10 ** 6,
            defaultdata,
            defaultdata
        );
        snapLastCall("invest_own_erc20_valuegood_with_power_with_fee_first");
        good_ = market.getGoodState(metagood);
        assertEq(
            good_.goodConfig.amount0(),
            235045548502964441738117234425444958208,
            "after invest metagood:metagood goodConfig amount0 error"
        );
        assertEq(
            good_.goodConfig.amount1(),
            199200000000,
            "after invest metagood:metagood goodConfig amount1 error"
        );
        assertEq(
            good_.currentState.amount0(),
            299200000000,
            "after invest metagood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            299200000000,
            "after invest metagood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            299000000000,
            "after invest metagood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            299000000000,
            "after invest metagood:metagood investState amount1 error"
        );
        _proof = market.getProofState(normalproof);
        assertEq(
            _proof.shares.amount0(),
            299000000000,
            "after invest:proof normal shares error"
        );
        assertEq(
            _proof.shares.amount1(),
            0,
            "after invest:proof value shares error"
        );
        assertEq(
            _proof.state.amount0(),
            299000000000,
            "after invest:proof value error"
        );
        assertEq(
            _proof.state.amount1(),
            99800000000,
            "after invest:proof value error"
        );
        assertEq(
            _proof.invest.amount0(),
            299000000000,
            "after invest:proof share error"
        );
        assertEq(
            _proof.invest.amount1(),
            99800000000,
            "after invest:proof quantity error"
        );
        vm.stopPrank();
    }
}
