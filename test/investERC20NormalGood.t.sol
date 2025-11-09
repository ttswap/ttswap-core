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


contract investERC20NormalGood is BaseSetup {
   
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    address metagood;
    address normalgoodusdt;
    address normalgoodbtc;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        initbtcgood();
    }

    function initmetagood() public {
        BaseSetup.setUp();
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initMetaGood(address(usdt), toTTSwapUINT256(50000 * 10 ** 12, 50000 * 10 ** 6), _goodconfig, defaultdata);
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

    function testinvestOwnERC20NormalGood() public {
        vm.startPrank(users[1]);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);

        uint256 normalproof;
        normalproof = S_ProofKey(users[1], normalgoodbtc, metagood).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            btc.balanceOf(users[1]),
            900000000,
            "before invest erc20_normalgood:btc users[1] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(users[1]),
            49937000000000,
            "before invest erc20_normalgood:usdt users[1] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before invest erc20_normalgood:usdt address(market) account invest balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before invest erc20_normalgood:btc address(market) account invest balance error"
        );
        assertEq(_proof1.shares.amount0(), 100000000, "before invest:proof normal shares error");
        assertEq(_proof1.shares.amount1(), 62993700000, "before invest:proof value shares error");
        assertEq(_proof1.state.amount0(), 62993700000000000, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 62993700000000000, "before invest:proof value error");
        assertEq(_proof1.invest.amount1(), 100000000, "before invest:proof quantity error");
        assertEq(_proof1.invest.amount0(), 100000000, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 62993700000, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount0(), 62993700000, "before invest:proof quantity error");

        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[1],defaultdata);
        snapLastCall("invest_own_erc20_normalgood_first");
        assertEq(
            btc.balanceOf(users[1]),
            800000000,
            "after invest erc20_normalgood:btc users[1] account invest balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            200000000,
            "after invest erc20_normalgood:btc market account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            175997210000,
            "after invest erc20_normalgood:usdt market account invest balance error"
        );

        assertEq(
            usdt.balanceOf(users[1]),
            49874002790000,
            "after invest erc20_normalgood:usdt users[1] account invest balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            175997210000,
            "after invest erc20_normalgood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            175997210000,
            "after invest erc20_normalgood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            175981098396,
            "after invest erc20_normalgood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            175981098396391524,
            "after invest erc20_normalgood:metagood investState amount1 error"
        );
       

        assertEq(
            good_.goodConfig,
             uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "after invest erc20_normalgood:metagood goodConfig error"
        );

        assertEq(good_.owner, marketcreator, "after invest erc20_normalgood:metagood marketcreator error");

        _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.shares.amount0(), 199990000, "after invest:proof normal shares error");
        assertEq(_proof1.shares.amount1(), 125981098396, "after invest:proof value shares error");
        assertEq(_proof1.state.amount0(), 125981100630000000, "after invest:proof value error");
        assertEq(_proof1.state.amount1(), 125981100630000000, "after invest:proof value error");
        assertEq(_proof1.invest.amount1(), 199990000, "after invest:proof quantity error");
        assertEq(_proof1.invest.amount0(), 199990000, "after invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 125984610279, "after invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount0(), 125984610279, "after invest:proof quantity error");

        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[1],defaultdata);
        snapLastCall("invest_own_erc20_normalgood_second");

        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[1],defaultdata);
        snapLastCall("invest_own_erc20_normalgood_three");

        vm.stopPrank();
    }

    function testinvestotherERC20NormalGood() public {
        vm.startPrank(users[4]);
        deal(address(usdt), users[4], 800000 * 10 ** 6, false);
        deal(address(btc), users[4], 10 * 10 ** 8, false);
        usdt.approve(address(market), 800000 * 10 ** 6);
        btc.approve(address(market), 10 * 10 ** 8);

        uint256 normalproof = S_ProofKey(users[4], normalgoodbtc, metagood).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);

        assertEq(
            btc.balanceOf(users[4]),
            1000000000,
            "before invest erc20_normalgood:btc users[4] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(users[4]),
            800000000000,
            "before invest erc20_normalgood:usdt users[4] account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before invest erc20_normalgood:usdt address(market) account invest balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before invest erc20_normalgood:btc address(market) account invest balance error"
        );
        assertEq(_proof1.shares.amount0(), 0, "before invest:proof normal shares error");
        assertEq(_proof1.shares.amount1(), 0, "before invest:proof value shares error");
        assertEq(_proof1.state.amount0(), 0, "before invest:proof value error");
        assertEq(_proof1.state.amount1(), 0, "before invest:proof value error");
        assertEq(_proof1.invest.amount1(), 0, "before invest:proof quantity error");
        assertEq(_proof1.invest.amount0(), 0, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 0, "before invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount0(), 0, "before invest:proof quantity error");


        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[4],defaultdata);
        snapLastCall("invest_other_erc20_normalgood_first");
        normalproof = 3;
        assertEq(
            btc.balanceOf(users[4]),
            900000000,
            "after invest erc20_normalgood:btc users[4] account invest balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            200000000,
            "after invest erc20_normalgood:btc market account invest balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            175997210000,
            "after invest erc20_normalgood:usdt market account invest balance error"
        );

        assertEq(
            usdt.balanceOf(users[4]),
            737002790000,
            "after invest erc20_normalgood:usdt users[4] account invest balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(),
            175997210000,
            "after invest erc20_normalgood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(),
            175997210000,
            "after invest erc20_normalgood:metagood currentState amount1 error"
        );
        assertEq(
            good_.investState.amount0(),
            175981098396,
            "after invest erc20_normalgood:metagood investState amount0 error"
        );
        assertEq(
            good_.investState.amount1(),
            175981098396391524,
            "after invest erc20_normalgood:metagood investState amount1 error"
        );
       

        assertEq(
            good_.goodConfig,
             uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "after invest erc20_normalgood:metagood goodConfig error"
        );

        assertEq(good_.owner, marketcreator, "after invest erc20_normalgood:metagood marketcreator error");

        normalproof = S_ProofKey(users[4], normalgoodbtc, metagood).toId();
        console2.log("111111", normalproof);
        _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.shares.amount0(), 99990000, "after invest:proof normal shares error");
        assertEq(_proof1.shares.amount1(), 62987398396, "after invest:proof value shares error");
        assertEq(_proof1.state.amount0(), 62987400630000000, "after invest:proof value error");
        assertEq(_proof1.state.amount1(), 62987400630000000, "after invest:proof value error");
        assertEq(_proof1.invest.amount1(), 99990000, "after invest:proof quantity error");
        assertEq(_proof1.invest.amount0(), 99990000, "after invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 62990910279, "after invest:proof quantity error");
        assertEq(_proof1.valueinvest.amount0(), 62990910279, "after invest:proof quantity error");

        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[4],defaultdata);
        snapLastCall("invest_other_erc20_normalgood_second");

        market.investGood(normalgoodbtc, metagood, 1 * 10 ** 8, defaultdata, defaultdata,users[4],defaultdata);
        snapLastCall("invest_other_erc20_normalgood_three");
        vm.stopPrank();
    }
}
