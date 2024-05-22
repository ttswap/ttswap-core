// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup3.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {
    T_BalanceUINT256, L_BalanceUINT256Library, toBalanceUINT256
} from "../Contracts/libraries/L_BalanceUINT256.sol";

import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {L_CurrencyLibrary} from "../Contracts/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract subgraph is Test, BaseSetup {
    using L_MarketConfigLibrary for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_CurrencyLibrary for address;
    using L_BalanceUINT256Library for T_BalanceUINT256;

    uint256 metagood;
    uint256 normalgoodbtc;
    uint256 normalgoodeth;
    uint256 metaproofid;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        initGood();
        investValueGood();
        investNormalGood();
        disInvestValueGood();
        disInvestNormalGood();
        buyGood();
        buyGoodforpay();
        collectprooffee1();
        goodInfo(1);
        goodInfo(2);
        proofInfo(1);
        proofInfo(2);
        collectprooffee2();
        goodInfo(1);
        goodInfo(2);
        proofInfo(1);
        proofInfo(2);
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 10000000 * 10 ** 6, false);
        usdt.approve(address(market), 10000000 * 10 ** 6);
        uint256 _goodConfig = 2 ** 255 + 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224;
        market.initMetaGood(address(usdt), toBalanceUINT256(1 * 10 ** 6 * 10 ** 6, 1 * 10 ** 6 * 10 ** 6), _goodConfig);
        vm.stopPrank();
    }

    function initGood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 65000 * 10 * 10 ** 6, false);
        usdt.approve(address(market), 65000 * 10 * 10 ** 6);

        deal(address(btc), marketcreator, 1000 * 10 ** 8, false);
        btc.approve(address(market), 1000 * 10 ** 8);

        uint256 _goodConfig = 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224;

        market.initGood(1, toBalanceUINT256(10 * 10 ** 8, 65000 * 10 * 10 ** 6), address(btc), _goodConfig, msg.sender);
        vm.stopPrank();
    }

    function investValueGood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 10000000000, false);
        usdt.approve(address(market), 10000000000);
        market.investGood(1, 0, 10000000000, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        vm.stopPrank();
    }

    function investNormalGood() public {
        vm.startPrank(marketcreator);

        deal(address(usdt), marketcreator, 100000000000000, false);
        usdt.approve(address(market), 100000000000000);

        deal(address(btc), marketcreator, 100000000, false);
        btc.approve(address(market), 100000000);
        market.investGood(2, 1, 100000000, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        vm.stopPrank();
    }

    function disInvestValueGood() public {
        vm.startPrank(marketcreator);

        market.disinvestGood(1, 0, 1000000000, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        vm.stopPrank();
    }

    function disInvestNormalGood() public {
        vm.startPrank(marketcreator);

        market.disinvestGood(2, 1, 1000000, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        vm.stopPrank();
    }

    function buyGood() public {
        vm.startPrank(marketcreator);

        market.buyGood(
            1,
            2,
            100000000,
            46278401901247631031018946610720476758016000,
            false,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        vm.stopPrank();
    }

    function buyGoodforpay() public {
        vm.startPrank(marketcreator);

        market.buyGoodForPay(
            1,
            2,
            1000000,
            46278401901247631031018946610720476758016000,
            0x0F18A2428C934db7b9E040F8Fc6e08975cBEf07a,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        vm.stopPrank();
    }

    function collectprooffee1() public {
        vm.startPrank(marketcreator);

        market.collectProofFee(1);
        vm.stopPrank();
    }

    function collectprooffee2() public {
        vm.startPrank(marketcreator);

        market.collectProofFee(2);
        vm.stopPrank();
    }

    function goodInfo(uint256 _good1) public view {
        console2.log(_good1, "************************");
        console2.log("price good1's value", market.getGoodState(_good1).currentState.amount0());
        console2.log("price good1's quantity", market.getGoodState(_good1).currentState.amount1());

        console2.log("price good1's invest value", market.getGoodState(_good1).investState.amount0());
        console2.log("price good1's invest quantity", market.getGoodState(_good1).investState.amount1());

        console2.log("price good1's fee", market.getGoodState(_good1).feeQunitityState.amount0());

        console2.log("price good1's contrunct fee", market.getGoodState(_good1).feeQunitityState.amount1());
        console2.log("price good1's goodConfig", market.getGoodState(_good1).goodConfig);
    }

    function proofInfo(uint256 _proofid) public view {
        console2.log(_proofid, "*********proof***************");
        console2.log("getProofState's state amount0", market.getProofState(_proofid).state.amount0());
        console2.log("getProofState's state amount1 ", market.getProofState(_proofid).state.amount1());

        console2.log("getProofState's invest amount0", market.getProofState(_proofid).invest.amount0());
        console2.log("getProofState's invest amount1", market.getProofState(_proofid).invest.amount1());

        console2.log("getProofState's valueinvest amount0", market.getProofState(_proofid).valueinvest.amount0());

        console2.log("getProofState's valueinvest amount1", market.getProofState(_proofid).valueinvest.amount1());

        console2.log("getProofState's currentgood", market.getProofState(_proofid).currentgood);

        console2.log("getProofState's valuegood", market.getProofState(_proofid).valuegood);
    }

    function showconfig(uint256 _goodConfig) public pure {
        console2.log("good goodConfig:isvaluegood:", _goodConfig.isvaluegood());
        console2.log("good goodConfig:getInvestFee:", uint256(_goodConfig.getInvestFee()));
        console2.log("good goodConfig:getDisinvestFee:", uint256(_goodConfig.getDisinvestFee()));
        console2.log("good goodConfig:getBuyFee:", uint256(_goodConfig.getBuyFee()));
        console2.log("good goodConfig:getSellFee:", uint256(_goodConfig.getSellFee()));
        console2.log("good goodConfig:getSwapChips:", uint256(_goodConfig.getSwapChips()));
    }

    function getcompareprice(uint256 good1, uint256 good2) public view {
        console2.log(
            market.getGoodState(good1).currentState.amount0() * market.getGoodState(good2).currentState.amount1(),
            market.getGoodState(good1).currentState.amount1() * market.getGoodState(good2).currentState.amount0()
        );
    }

    function testsub() public {
        emit log("1");
    }
}
