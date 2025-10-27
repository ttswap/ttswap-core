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


contract disinvestERC20OtherNormalGood is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodbtc;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        initbtcgood();
        investOwnERC20NormalGood();
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
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 1 * 10 ** 8 + 1);
        deal(address(usdt), users[1], 50000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000000 * 10 ** 6 + 1);
        assertEq(usdt.balanceOf(address(market)), 50000 * 10 ** 6, "befor init erc20 good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood(
            metagood,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(btc),
            normalgoodconfig,
            defaultdata,
            defaultdata,users[1],defaultdata
        );
        normalgoodbtc = address(btc);
        vm.stopPrank();
    }

    function investOwnERC20NormalGood() public {
        vm.startPrank(users[2]);

        deal(address(btc), users[2], 10 * 10 ** 8, false);
        deal(address(usdt), users[2], 50000000 * 10 ** 6, false);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);
        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[2],defaultdata);
        vm.stopPrank();
    }

    function testDistinvestProof() public {
        vm.startPrank(users[2]);
        uint256 normalproof;
        normalproof = S_ProofKey(users[2], normalgoodbtc, metagood).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            _proof1.shares.amount0(),
            99990000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            62987398396,
            "before invest:proof value shares error"
        );
        assertEq(_proof1.state.amount0(), 62987400630, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 62987400630, "before invest:proof value error");
        assertEq(
            _proof1.invest.amount1(),
            99990000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.invest.amount0(),
            99990000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount1(),
            62990910279,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount0(),
            62990910279,
            "before invest:proof quantity error"
        );


        S_GoodTmpState memory good_ = market.getGoodState(normalgoodbtc);
        assertEq(
            good_.currentState.amount0(),
            200000000,
            "before disinvest erc20 good:normalgoodbtc currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            200000000,
            "before disinvest erc20 good:normalgoodbtc currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            199990000,
            "before disinvest erc20 good:normalgoodbtc investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            125981100630,
            "before disinvest erc20 good:normalgoodbtc investState amount1 error"
        );
       
        normalproof = S_ProofKey(users[2], normalgoodbtc, metagood).toId();

        market.disinvestProof(normalproof, 1 * 10 ** 5, address(0),users[2],defaultdata);
        snapLastCall("disinvest_other_erc20_normalgood_first");
        good_ = market.getGoodState(normalgoodbtc);
        assertEq(
            good_.currentState.amount0(),
            199900025,
            "after disinvest erc20 good:normalgoodbtc currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            199900025,
            "after disinvest erc20 good:normalgoodbtc currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            199890000,
            "after disinvest erc20 good:normalgoodbtc investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(), 125918106930, "after disinvest erc20 good:normalgoodbtc investState amount1 error"
        );
        

         _proof1 = market.getProofState(normalproof);
        assertEq(
            _proof1.shares.amount0(),
            99890000,
            "before invest:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            62924404699,
            "before invest:proof value shares error"
        );
        assertEq(_proof1.state.amount0(), 62924406930, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 62924406930, "before invest:proof value error");
        assertEq(
            _proof1.invest.amount1(),
            99890000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.invest.amount0(),
            99890000,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount1(),
            62927913069,
            "before invest:proof quantity error"
        );
        assertEq(
            _proof1.valueinvest.amount0(),
            62927913069,
            "before invest:proof quantity error"
        );

        market.disinvestProof(normalproof, 1 * 10 ** 5, address(0),users[2],defaultdata);
        snapLastCall("disinvest_other_erc20_normalgood_second");

        market.disinvestProof(normalproof, 1 * 10 ** 5, address(0),users[2],defaultdata);
        snapLastCall("disinvest_other_erc20_normalgood_three");
        vm.stopPrank();
    }
}
