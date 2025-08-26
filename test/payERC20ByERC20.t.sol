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

contract payERC20ByERC20 is BaseSetup {
   
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
    function testPayERC20NormalGood() public {
        vm.startPrank(users[1]);
        usdt.transfer(address(100), 1);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);
        assertEq(btc.balanceOf(users[1]), 900000000, "before pay erc20_normalgood:btc users[1] account  balance error");
        assertEq(
            usdt.balanceOf(users[1]), 49936999999999, "before pay erc20_normalgood:usdt users[1] account  balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before pay erc20_normalgood:usdt address(market) account  balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before pay erc20_normalgood:btc address(market) account  balance error"
        );
        S_GoodTmpState memory metagoodkeystate = market.getGoodState(metagood);
        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                113000000000 ,
                112993700000
            ).amount0(),
            "before pay erc20 normalgood:metagoodkey currentState error"
        );

          assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                113000000000 ,
                112993700000
            ).amount1(),
            "before  pay erc20  normalgood:metagoodkey currentState amount1 error"
        );
        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "before  pay erc20  normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "before  pay erc20  normalgood:metagoodkey investState error"
        );

        S_GoodTmpState memory normalgoodkeystate = market.getGoodState(normalgoodbtc);
        assertEq(
            normalgoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                100000000 ,
                100000000
            ).amount0(),
            "before pay erc20 normalgood:normalgoodkey currentState error"
        );

          assertEq(
            normalgoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                100000000 ,
                100000000
            ).amount1(),
            "before  pay erc20  normalgood:normalgoodkey currentState amount1 error"
        );
        assertEq(
            normalgoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount0(),
            "before  pay erc20  normalgood:normalgoodkey investState error"
        );
        assertEq(
            normalgoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount1(),
            "before  pay erc20  normalgood:normalgoodkey investState error"
        );

        market.buyGood(metagood, normalgoodbtc, toTTSwapUINT256(6300 * 10 ** 6,1*10**6), 0, users[1], defaultdata);
        snapLastCall("pay_erc20_by_erc20_to_self_first");
        assertEq(
            usdt.balanceOf(address(market)),
            113635645701,
            "after pay erc20_normalgood:usdt address(market) account  balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            99000000,
            "after pay erc20_normalgood:btc address(market) account  balance error"
        );
        metagoodkeystate = market.getGoodState(metagood);
        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                113000444640,
                113628901061
            ).amount0(),
            "after  pay erc20  normalgood:metagoodkey currentState error"
        );

          assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                  113000444640,
                113628901061
            ).amount1(),
            "after  pay erc20  normalgood:metagoodkey currentState amount1 error"
        );
        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "after  pay erc20  normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "after  pay erc20  normalgood:metagoodkey investState error"
        );
        normalgoodkeystate = market.getGoodState(normalgoodbtc);
        assertEq(
            normalgoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                100000500 ,
                98999500
            ).amount0(),
            "after pay erc20 normalgood:normalgoodkey currentState error"
        );

          assertEq(
            normalgoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                100000500 ,
                98999500
            ).amount1(),
            "after  pay erc20  normalgood:normalgoodkey currentState amount1 error"
        );
        assertEq(
            normalgoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount0(),
            "after  pay erc20  normalgood:normalgoodkey investState error"
        );
        assertEq(
            normalgoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount1(),
            "after  pay erc20  normalgood:normalgoodkey investState error"
        );
        market.buyGood(metagood, normalgoodbtc, toTTSwapUINT256(16300 * 10 ** 6,1*10**6), 0, users[1], defaultdata);
        snapLastCall("pay_erc20_by_erc20_to_self_second");

        vm.stopPrank();
    }
    function testPayERC20NormalGoodToOtherUser() public {
        vm.startPrank(users[1]);
        usdt.transfer(address(100), 1);
        usdt.approve(address(market), 800000 * 10 ** 6 + 1);
        btc.approve(address(market), 10 * 10 ** 8 + 1);
        assertEq(btc.balanceOf(users[1]), 900000000, "before pay erc20_normalgood:btc users[1] account  balance error");
        assertEq(
            usdt.balanceOf(users[1]), 49936999999999, "before pay erc20_normalgood:usdt users[1] account  balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            113000000000,
            "before pay erc20_normalgood:usdt address(market) account  balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            100000000,
            "before pay erc20_normalgood:btc address(market) account  balance error"
        );
        S_GoodTmpState memory metagoodkeystate = market.getGoodState(metagood);
        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                113000000000 ,
                112993700000
            ).amount0(),
            "before pay erc20 normalgood:metagoodkey currentState error"
        );

          assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                113000000000 ,
                112993700000
            ).amount1(),
            "before  pay erc20  normalgood:metagoodkey currentState amount1 error"
        );
        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "before  pay erc20  normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "before  pay erc20  normalgood:metagoodkey investState error"
        );

        S_GoodTmpState memory normalgoodkeystate = market.getGoodState(normalgoodbtc);
        assertEq(
            normalgoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                100000000 ,
                100000000
            ).amount0(),
            "before pay erc20 normalgood:normalgoodkey currentState error"
        );

          assertEq(
            normalgoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                100000000 ,
                100000000
            ).amount1(),
            "before  pay erc20  normalgood:normalgoodkey currentState amount1 error"
        );
        assertEq(
            normalgoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount0(),
            "before  pay erc20  normalgood:normalgoodkey investState error"
        );
        assertEq(
            normalgoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount1(),
            "before  pay erc20  normalgood:normalgoodkey investState error"
        );

        market.buyGood(metagood, normalgoodbtc, toTTSwapUINT256(6300 * 10 ** 6,1*10**6), 0, address(100), defaultdata);
        snapLastCall("pay_erc20_by_erc20_to_other_user_first");
        assertEq(
            usdt.balanceOf(address(market)),
            113635645701,
            "after pay erc20_normalgood:usdt address(market) account  balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            99000000,
            "after pay erc20_normalgood:btc address(market) account  balance error"
        );
        metagoodkeystate = market.getGoodState(metagood);
        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                113000444640,
                113628901061
            ).amount0(),
            "after  pay erc20  normalgood:metagoodkey currentState error"
        );

          assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                  113000444640,
                113628901061
            ).amount1(),
            "after  pay erc20  normalgood:metagoodkey currentState amount1 error"
        );
        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "after  pay erc20  normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "after  pay erc20  normalgood:metagoodkey investState error"
        );
        normalgoodkeystate = market.getGoodState(normalgoodbtc);
        assertEq(
            normalgoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                100000500 ,
                98999500
            ).amount0(),
            "after pay erc20 normalgood:normalgoodkey currentState error"
        );

          assertEq(
            normalgoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                100000500 ,
                98999500
            ).amount1(),
            "after  pay erc20  normalgood:normalgoodkey currentState amount1 error"
        );
        assertEq(
            normalgoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount0(),
            "after  pay erc20  normalgood:normalgoodkey investState error"
        );
        assertEq(
            normalgoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                100000000,
                62993700000
            ).amount1(),
            "after  pay erc20  normalgood:normalgoodkey investState error"
        );
        market.buyGood(metagood, normalgoodbtc, toTTSwapUINT256(16300 * 10 ** 6,1*10**6), 0, address(100), defaultdata);
        snapLastCall("pay_erc20_by_erc20_to_other_user_second");

        vm.stopPrank();
    }

       
}
