// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup2.t.sol";
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

contract collectValueProofFee is Test, BaseSetup {
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
        //goodInfo(metagood);
        normalgoodbtc = initNormalGood(address(btc), 100, 64000);
        showconfig(market.getGoodState(metagood).goodConfig);
        //goodInfo(metagood);
        normalgoodeth = initNormalGood(address(eth), 100, 3100);
        //goodInfo(metagood);
        //goodInfo(normalgoodbtc);
        //goodInfo(normalgoodeth);
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 100000 * 10 ** 6, false);
        usdt.approve(address(market), 30000 * 10 ** 6);
        uint256 _goodConfig = 2 ** 255 + 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224;
        (metagood, metaproofid) =
            market.initMetaGood(address(usdt), toBalanceUINT256(20000 * 10 ** 6, 20000 * 10 ** 6), _goodConfig);

        //market.updatetoValueGood(metagood);
        uint256 _marketConfig = (50 << 250) + (5 << 244) + (10 << 238) + (10 << 232) + (25 << 226) + (20 << 220);
        console2.log(_marketConfig);

        market.setMarketConfig(_marketConfig);
        vm.stopPrank();
    }

    function initNormalGood(address token, uint128 amount, uint128 price) public returns (uint256 normalgood) {
        vm.startPrank(users[3]);
        uint128 decimals = uint128(10 ** MyToken(token).decimals());
        deal(token, users[3], amount * decimals, false);
        MyToken(token).approve(address(market), amount * decimals);
        deal(address(usdt), users[3], amount * price * 10 ** usdt.decimals(), false);
        console2.log("usdt approve", amount * price * 10 ** usdt.decimals());
        usdt.approve(address(market), amount * price * 10 ** usdt.decimals());
        console2.log("users[3] approve market", usdt.allowance(users[3], address(market)));

        uint256 _goodConfig = 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224;

        (normalgood,) = market.initGood(
            metagood,
            toBalanceUINT256(amount * decimals, uint128(amount * price * 10 ** usdt.decimals())),
            token,
            _goodConfig,
            msg.sender
        );
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

    function testBuy(uint256 aa) public {
        address alice = address(20);
        vm.startPrank(alice);
        deal(address(usdt), alice, 10000000 * 10 ** 6, false);
        usdt.approve(address(market), 10000000 * 10 ** 6);
        getcompareprice(metagood, normalgoodbtc);
        market.buyGood(
            metagood,
            normalgoodbtc,
            10000000000,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        getcompareprice(metagood, normalgoodbtc);
        console2.log("btc :", btc.balanceOf(alice));
        assertEq(market.getGoodState(metagood).currentState.amount0(), 6714640000000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 6734624000000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 6724632000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 6724632000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 2811613398, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 123613398, "metagood's feeQunitityState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount0(),
            6404872000000,
            "normalgoodbtc's currentState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount1(),
            9984375000,
            "normalgoodbtc's currentState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount0(),
            6394880000000,
            "normalgoodbtc's investState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount1(), 10000000000, "normalgoodbtc's investState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount0(),
            6250,
            "normalgoodbtc's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount1(), 0, "normalgoodbtc's feeQunitityState amount1"
        );
        console2.log(aa);
        vm.stopPrank();
    }

    function testBuyForPay(uint256 aa) public {
        address alice = address(20);
        address xx = address(21);
        vm.startPrank(alice);
        deal(address(usdt), alice, 10000000 * 10 ** 6, false);
        usdt.approve(address(market), 1000000 * 10 ** 6);

        console2.log(aa);
        deal(address(btc), xx, 1, false);
        market.buyGoodForPay(
            metagood,
            normalgoodbtc,
            1000000,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            xx,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        console2.log("btc:", btc.balanceOf(alice));
        console2.log("btc:", btc.balanceOf(xx));
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        assertEq(market.getGoodState(metagood).currentState.amount0(), 6723992512000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 6725271488000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 6724632000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 6724632000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 2807869193, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 123613398, "metagood's feeQunitityState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount0(),
            6395519488000,
            "normalgoodbtc's currentState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount1(),
            9999000000,
            "normalgoodbtc's currentState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount0(),
            6394880000000,
            "normalgoodbtc's investState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount1(), 10000000000, "normalgoodbtc's investState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount0(),
            400,
            "normalgoodbtc's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount1(), 0, "normalgoodbtc's feeQunitityState amount1"
        );
        market.buyGoodForPay(
            metagood,
            normalgoodbtc,
            1000000,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            xx,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        vm.stopPrank();
    }

    function testinvestvaluegood() public {
        address alice = address(20);
        vm.startPrank(alice);
        deal(address(usdt), alice, 10000000 * 10 ** 6, false);
        usdt.approve(address(market), 1000000 * 10 ** 6);

        goodInfo(metagood);
        market.investGood(metagood, 0, 1000000 * 10 ** 6, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);

        goodInfo(metagood);
        assertEq(market.getGoodState(metagood).currentState.amount0(), 7723832000000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 7723832000000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 7723832000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 7723832000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 3624791216, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 540791216, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testdisinvestvaluegood() public {
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        proofInfo(metaproofid);
        (L_Good.S_GoodDisinvestReturn memory aa,,) =
            market.disinvestGood(metagood, 0, 10000 * 10 ** 6, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        console2.log("profit", aa.profit);
        console2.log("actual_fee", aa.actual_fee);
        console2.log("actualDisinvestValue", aa.actualDisinvestValue);
        console2.log("actualDisinvestQuantity", aa.actualDisinvestQuantity);
        goodInfo(metagood);
        proofInfo(metaproofid);
        assertEq(market.getGoodState(metagood).currentState.amount0(), 6704640000000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 6724624000000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 6714632000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 6714632000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 2811432332, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 123613398, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testdisinvestvalueproof() public {
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        proofInfo(metaproofid);
        (L_Good.S_GoodDisinvestReturn memory aa,) =
            market.disinvestProof(metaproofid, 10000 * 10 ** 6, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        console2.log("profit", aa.profit);
        console2.log("actual_fee", aa.actual_fee);
        console2.log("actualDisinvestValue", aa.actualDisinvestValue);
        console2.log("actualDisinvestQuantity", aa.actualDisinvestQuantity);
        goodInfo(metagood);
        proofInfo(metaproofid);
        assertEq(market.getGoodState(metagood).currentState.amount0(), 6704640000000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 6724624000000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 6714632000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 6714632000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 2811432332, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 123613398, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testcollectValueProofFee() public {
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        proofInfo(metaproofid);
        snapStart("collectValueProofFee");
        market.collectProofFee(1);
        snapEnd();
        goodInfo(metagood);
        proofInfo(metaproofid);
        assertEq(market.getGoodState(metagood).currentState.amount0(), 6714640000000, "metagood's currentState amount0");
        assertEq(market.getGoodState(metagood).currentState.amount1(), 6734624000000, "metagood's currentState amount1");
        assertEq(market.getGoodState(metagood).investState.amount0(), 6724632000000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 6724632000000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 2811613398, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 131975531, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testinvestNormalgood() public {
        address alice = address(20);
        vm.startPrank(alice);
        deal(address(usdt), alice, 100 * 65000 * 10 ** 6, false);
        usdt.approve(address(market), 100 * 65000 * 10 ** 6);
        deal(address(btc), alice, 100 * 10 ** 8, false);
        btc.approve(address(market), 100 * 10 ** 8);

        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        console2.log("--------------");
        market.investGood(normalgoodbtc, metagood, 100 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);

        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        assertEq(
            market.getGoodState(metagood).currentState.amount0(), 13114396096000, "metagood's currentState amount0"
        );
        assertEq(
            market.getGoodState(metagood).currentState.amount1(), 13114396096000, "metagood's currentState amount1"
        );
        assertEq(market.getGoodState(metagood).investState.amount0(), 13114396096000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 13114396096000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 8033367485, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 2791415485, "metagood's feeQunitityState amount1"
        );

        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount0(),
            12784644096000,
            "normalgoodbtc's currentState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).currentState.amount1(),
            19992000000,
            "normalgoodbtc's currentState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount0(),
            12784644096000,
            "normalgoodbtc's investState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).investState.amount1(), 19992000000, "normalgoodbtc's investState amount1"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount0(),
            4000000,
            "normalgoodbtc's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(normalgoodbtc).feeQunitityState.amount1(), 0, "normalgoodbtc's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testdisinvestnormalgoodaa() public {
        uint256 normalproofid;
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 10000 * 65000 * 10 ** 6, false);
        usdt.approve(address(market), 10000 * 65000 * 10 ** 6);
        deal(address(btc), marketcreator, 10000 * 10 ** 8, false);
        btc.approve(address(market), 10000 * 10 ** 8);

        console2.log("--------------");
        (,, normalproofid) =
            market.investGood(normalgoodbtc, metagood, 100 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(4);
        (L_Good.S_GoodDisinvestReturn memory aa,, uint256 kk) =
            market.disinvestGood(normalgoodbtc, metagood, 10 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        console2.log("profit", aa.profit);
        console2.log("actual_fee", aa.actual_fee);
        console2.log("actualDisinvestValue", aa.actualDisinvestValue);
        console2.log("actualDisinvestQuantity", aa.actualDisinvestQuantity);
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(kk);
        assertEq(
            market.getGoodState(metagood).currentState.amount0(), 12464916096000, "metagood's currentState amount0"
        );
        assertEq(
            market.getGoodState(metagood).currentState.amount1(), 12484900096000, "metagood's currentState amount1"
        );
        assertEq(market.getGoodState(metagood).investState.amount0(), 12474908096000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 12474908096000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 7901242233, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 2524421682, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testdisinvestnormalproof() public {
        uint256 normalproofid;
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 10000 * 65000 * 10 ** 6, false);
        usdt.approve(address(market), 10000 * 65000 * 10 ** 6);
        deal(address(btc), marketcreator, 10000 * 10 ** 8, false);
        btc.approve(address(market), 10000 * 10 ** 8);

        console2.log("--------------");
        (,, normalproofid) =
            market.investGood(normalgoodbtc, metagood, 100 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(4);
        (L_Good.S_GoodDisinvestReturn memory aa,) =
            market.disinvestProof(4, 10 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        console2.log("profit", aa.profit);
        console2.log("actual_fee", aa.actual_fee);
        console2.log("actualDisinvestValue", aa.actualDisinvestValue);
        console2.log("actualDisinvestQuantity", aa.actualDisinvestQuantity);
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(4);
        assertEq(
            market.getGoodState(metagood).currentState.amount0(), 12464916096000, "metagood's currentState amount0"
        );
        assertEq(
            market.getGoodState(metagood).currentState.amount1(), 12484900096000, "metagood's currentState amount1"
        );
        assertEq(market.getGoodState(metagood).investState.amount0(), 12474908096000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 12474908096000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 7901242233, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 2524421682, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function testcollectNormalProofFee() public {
        uint256 normalproofid;
        address alice = address(20);
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 10000 * 65000 * 10 ** 6, false);
        usdt.approve(address(market), 10000 * 65000 * 10 ** 6);
        deal(address(btc), marketcreator, 10000 * 10 ** 8, false);
        btc.approve(address(market), 10000 * 10 ** 8);

        console2.log("--------------");
        (,, normalproofid) =
            market.investGood(normalgoodbtc, metagood, 100 * 10 ** 8, 0x45A0eA517208a68c68A0f7D894d0D126649a75a9);
        deal(address(usdt), marketcreator, 20000000 * 10 ** 6, false);
        usdt.approve(address(market), 2000000 * 10 ** 6);

        market.buyGood(
            metagood,
            normalgoodbtc,
            10000 * 10 ** 6,
            65000 * 10 ** 6 * 2 ** 128 + 1 * 10 ** 8,
            true,
            0x45A0eA517208a68c68A0f7D894d0D126649a75a9
        );
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(4);

        snapStart("collectNormalProofFee");
        market.collectProofFee(4);
        snapEnd();
        goodInfo(metagood);
        goodInfo(normalgoodbtc);
        proofInfo(4);
        assertEq(
            market.getGoodState(metagood).currentState.amount0(), 13104404096000, "metagood's currentState amount0"
        );
        assertEq(
            market.getGoodState(metagood).currentState.amount1(), 13124388096000, "metagood's currentState amount1"
        );
        assertEq(market.getGoodState(metagood).investState.amount0(), 13114396096000, "metagood's investState amount0");
        assertEq(market.getGoodState(metagood).investState.amount1(), 13114396096000, "metagood's investState amount1");
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount0(), 8037367485, "metagood's feeQunitityState amount0"
        );
        assertEq(
            market.getGoodState(metagood).feeQunitityState.amount1(), 4039682563, "metagood's feeQunitityState amount1"
        );
        console2.log("usdt:", usdt.balanceOf(alice));
    }

    function getcompareprice(uint256 good1, uint256 good2) public view {
        console2.log(
            market.getGoodState(good1).currentState.amount0() * market.getGoodState(good2).currentState.amount1(),
            market.getGoodState(good1).currentState.amount1() * market.getGoodState(good2).currentState.amount0()
        );
    }
}
