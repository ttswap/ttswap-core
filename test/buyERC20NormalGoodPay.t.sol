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

import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";

contract buyERC20NormalGoodPay is BaseSetup {
   
    using L_TTSwapUINT256Library for uint256;
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
            defaultdata
        );
        normalgoodbtc = address(btc);
        vm.stopPrank();
    }

    function testBuyERC20GoodPayWithoutChips() public {
        vm.startPrank(users[1]);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);
        assertEq(btc.balanceOf(users[1]), 900000000, "before buy erc20_normalgood:btc users[1] account  balance error");
        assertEq(
            usdt.balanceOf(users[1]), 49937000000000, "before buy erc20_normalgood:usdt users[1] account  balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before buy erc20_normalgood:usdt address(market) account  balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before buy erc20_normalgood:btc address(market) account  balance error"
        );

        market.buyGood(metagood, normalgoodbtc, 6300 * 10 ** 6, 101, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_without_chips_first");
        assertEq(
            usdt.balanceOf(users[1]), 49943300000000, "after buy erc20_normalgood:usdt users[1] account  balance error1"
        );
        assertEq(btc.balanceOf(users[1]), 889986996, "after buy erc20_normalgood:btc users[1] account  balance error");
        assertEq(
            btc.balanceOf(address(market)), 110013004, "after buy erc20_normalgood:btc market account  balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            106700000000,
            "after buy erc20_normalgood:usdt market account  balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState.amount0(), 119298110000, "after buy erc20_normalgood:metagood currentState amount0 error"
        );
        assertEq(
            good_.currentState.amount1(), 106689290000, "after buy erc20_normalgood:metagood currentState amount1 error"
        );

        assertEq(
            good_.feeQuantityState.amount0(),
            10710000,
            "after buy erc20_normalgood:metagood feeQuantityState amount0 error"
        );
        assertEq(
            good_.feeQuantityState.amount1(), 0, "after buy erc20_normalgood:metagood feeQuantityState amount1 error"
        );

        market.buyGood(metagood, normalgoodbtc, 6300 * 10 ** 6, 199, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_without_chips_second");
        market.buyGood(metagood, normalgoodbtc, 6300 * 10 ** 6, 199, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_without_chips_three");
        vm.stopPrank();
    }

    function testBuyERC20GoodWithChips() public {
        vm.startPrank(users[1]);
        uint256 goodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 2 * 2 ** 216 + 3 * 2 ** 206;
        market.updateGoodConfig(normalgoodbtc, goodconfig);

        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);

        assertEq(btc.balanceOf(users[1]), 900000000, "before buy erc20_normalgood:btc users[1] account  balance error");

        assertEq(
            usdt.balanceOf(users[1]), 49937000000000, "before buy erc20_normalgood:usdt users[1] account  balance error"
        );

        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before buy erc20_normalgood:usdt address(market) account  balance error"
        );

        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before buy erc20_normalgood:btc address(market) account  balance error"
        );

        market.buyGood(metagood, normalgoodbtc, 63000000, 101, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_first_1chips");

        market.buyGood(metagood, normalgoodbtc, 63000000, 101, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_1chips");

        market.buyGood(metagood, normalgoodbtc, 6300 * 10 ** 6, 112, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_12chips");

        market.buyGood(metagood, normalgoodbtc, 1000000000, 102, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_2chips");
        vm.stopPrank();
    }

    function testBuyERC20GoodWithChipswithRefere() public {
        vm.startPrank(users[1]);
        uint256 goodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 2 * 2 ** 216 + 3 * 2 ** 206;
        market.updateGoodConfig(normalgoodbtc, goodconfig);

        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);

        assertEq(btc.balanceOf(users[1]), 900000000, "before buy erc20_normalgood:btc users[1] account  balance error");

        assertEq(
            usdt.balanceOf(users[1]), 49937000000000, "before buy erc20_normalgood:usdt users[1] account  balance error"
        );

        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before buy erc20_normalgood:usdt address(market) account  balance error"
        );

        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before buy erc20_normalgood:btc address(market) account  balance error"
        );

        market.buyGood(metagood, normalgoodbtc, 63000000, 110, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_first_1chips_refere");

        market.buyGood(metagood, normalgoodbtc, 63000000, 101, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_1chips_refere");

        market.buyGood(metagood, normalgoodbtc, 6300 * 10 ** 6, 112, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_12chips_refere");

        market.buyGood(metagood, normalgoodbtc, 1000000000, 102, users[1], defaultdata);
        snapLastCall("pay_erc20_normal_good_chips_second_2chips_refere");
        vm.stopPrank();
    }
}
