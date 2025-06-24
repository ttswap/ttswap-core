pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_ProofKey, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";

contract testInitNormalGood is BaseSetup {
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    address metagoodkey;

    function setUp() public override {
        BaseSetup.setUp();
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 100000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initMetaGood(address(usdt), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), _goodconfig, defaultdata);
        metagoodkey = address(usdt);
        vm.stopPrank();
    }

    function testinitNormalGood() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 1 * 10 ** 8 + 1);
        deal(address(usdt), users[1], 100000 * 10 ** 6, false);
        usdt.approve(address(market), 63000 * 10 ** 6 + 1);

        assertEq(usdt.balanceOf(address(market)), 50000 * 10 ** 6, "befor init erc20 good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood(
            metagoodkey,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(btc),
            normalgoodconfig,
            defaultdata,
            defaultdata
        );
        snapLastCall("init_erc20_normalgood");

        //normal good
        address normalgoodkey = address(btc);

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6 + 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(btc.balanceOf(address(market)), 1 * 10 ** 8, "after initial normal good, balance of market error");

        assertEq(
            usdt.balanceOf(users[1]),
            100000 * 10 ** 6 - 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(
            btc.balanceOf(users[1]), 10 * 10 ** 8 - 1 * 10 ** 8, "after initial normal good, balance of market error"
        );

        S_GoodTmpState memory metagoodkeystate = market.getGoodState(metagoodkey);
        assertEq(
            metagoodkeystate.goodConfig,
            uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "1after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(
            metagoodkeystate.currentState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey currentState error"
        );
        assertEq(
            metagoodkeystate.investState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.feeQuantityState,
            toTTSwapUINT256(((63000 * 10 ** 6) / 10000), 0),
            "after initial normalgood:metagoodkey feequnitity error"
        );

        assertEq(
            metagoodkeystate.goodConfig,
            uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "2after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(metagoodkeystate.owner, marketcreator, "after initial normalgood:metagoodkey marketcreator error");

        ////////////////////////////////////////
        S_GoodTmpState memory normalgoodstate = market.getGoodState(normalgoodkey);
        assertEq(
            normalgoodstate.currentState.amount0(),
            63000 * 10 ** 6 - (63000 * 10 ** 6) / 10000,
            "after initial normalgood:normalgood currentState amount0()"
        );

        assertEq(
            normalgoodstate.currentState.amount1(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount1()"
        );
        assertEq(
            normalgoodstate.investState,
            toTTSwapUINT256(63000 * 10 ** 6 - 63000 * 10 ** 2, 1 * 10 ** 8),
            "after initial normalgood:normalgood investState error"
        );
        assertEq(normalgoodstate.feeQuantityState, 0, "after initial normalgood:normalgood feequnitity error");

        assertEq(
            normalgoodstate.goodConfig,
            1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197+25600258*2**229,
            "after initial normalgood:normalgood goodConfig error"
        );

        assertEq(normalgoodstate.owner, users[1], "after initial normalgood:normalgood owner error");

        ///////////////////////////
        uint256 normalproof = S_ProofKey(users[1], normalgoodkey, metagoodkey).toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.state.amount0(), 63000 * 10 ** 6 - 63000 * 10 ** 2, "after initial:proof value error");
        assertEq(_proof1.invest.amount1(), 1 * 10 ** 8, "after initial:proof quantity error");

        vm.stopPrank();
    }

    function testinitNativeETHNormalGood() public {
        vm.startPrank(users[1]);
        deal(users[1], 10 * 10 ** 8);
        deal(address(usdt), users[1], 100000 * 10 ** 6, false);
        usdt.approve(address(market), 63000 * 10 ** 6 + 1);
        assertEq(users[1].balance, 10 * 10 ** 8, "befor init erc20 good, balance of users[1] error");
        assertEq(address(market).balance, 0, "befor init erc20 good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood{value: 1 * 10 ** 8}(
            metagoodkey,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(1),
            normalgoodconfig,
            defaultdata,
            defaultdata
        );
        snapLastCall("init_nativeETH_normalgood");
        vm.stopPrank();

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6 + 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(address(market).balance, 1 * 10 ** 8, "after initial normal good, balance of market error");

        assertEq(
            usdt.balanceOf(users[1]),
            100000 * 10 ** 6 - 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(users[1].balance, 10 * 10 ** 8 - 1 * 10 ** 8, "after initial normal good, balance of market error");

        S_GoodTmpState memory metagoodkeystate = market.getGoodState(metagoodkey);
        assertEq(
            metagoodkeystate.currentState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey currentState error"
        );
        assertEq(
            metagoodkeystate.investState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.feeQuantityState,
            toTTSwapUINT256(((63000 * 10 ** 2)), 0),
            "after initial normalgood:metagoodkey feequnitity error"
        );

        assertEq(
            metagoodkeystate.goodConfig,
             uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "4after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(metagoodkeystate.owner, marketcreator, "after initial normalgood:metagoodkey marketcreator error");

        address normalgoodkey = address(1);

        ////////////////////////////////////////
        S_GoodTmpState memory normalgoodstate = market.getGoodState(normalgoodkey);
        assertEq(
            normalgoodstate.currentState.amount0(),
            63000 * 10 ** 6 - ((63000 * 10 ** 6) / 10000),
            "after initial normalgood:normalgood currentState amount0()"
        );

        assertEq(
            normalgoodstate.currentState.amount1(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount1()"
        );
        assertEq(normalgoodstate.feeQuantityState, 0, "after initial normalgood:normalgood feequnitity error");

        assertEq(
            normalgoodstate.goodConfig,
            1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197+25600258*2**229,
            "after initial normalgood:normalgood goodConfig error"
        );

        assertEq(normalgoodstate.owner, users[1], "after initial normalgood:normalgood owner error");

        ///////////////////////////

        uint256 normalproof = S_ProofKey(users[1], normalgoodkey, metagoodkey).toId();

        S_ProofState memory _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.state.amount0(), 63000 * 10 ** 6 - 63000 * 10 ** 2, "after initial:proof value error");
        assertEq(_proof1.invest.amount1(), 1 * 10 ** 8, "after initial:proof normal error");
        assertEq(
            _proof1.valueinvest.amount1(), 63000 * 10 ** 6 - 63000 * 10 ** 2, "after initial:proof value quantity error"
        );
    }

    function testinitSETHNormalGood() public {
        vm.startPrank(users[1]);
        deal(users[1], 10 * 10 ** 8);
        deal(address(usdt), users[1], 100000 * 10 ** 6, false);
        usdt.approve(address(market), 63000 * 10 ** 6 + 1);
        assertEq(users[1].balance, 10 * 10 ** 8, "befor init erc20 good, balance of users[1] error");
        assertEq(address(market).balance, 0, "befor init erc20 good, balance of market error");
        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initGood{value: 1 * 10 ** 8}(
            metagoodkey,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(2),
            normalgoodconfig,
            defaultdata,
            defaultdata
        );
        snapLastCall("init_nativeETH_normalgood");
        vm.stopPrank();

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6 + 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(address(market).balance, 1 * 10 ** 8, "after initial normal good, balance of market error");

        assertEq(
            usdt.balanceOf(users[1]),
            100000 * 10 ** 6 - 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(users[1].balance, 10 * 10 ** 8 - 1 * 10 ** 8, "after initial normal good, balance of market error");

        S_GoodTmpState memory metagoodkeystate = market.getGoodState(metagoodkey);
        assertEq(
            metagoodkeystate.currentState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey currentState error"
        );
        assertEq(
            metagoodkeystate.investState,
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2, 50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ),
            "after initial normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.feeQuantityState,
            toTTSwapUINT256(((63000 * 10 ** 2)), 0),
            "after initial normalgood:metagoodkey feequnitity error"
        );

        assertEq(
            metagoodkeystate.goodConfig,
             uint256(1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197 + 92709122 *2** 229),
            "3after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(metagoodkeystate.owner, marketcreator, "after initial normalgood:metagoodkey marketcreator error");

        address normalgoodkey = address(2);

        ////////////////////////////////////////
        S_GoodTmpState memory normalgoodstate = market.getGoodState(normalgoodkey);
        assertEq(
            normalgoodstate.currentState.amount0(),
            63000 * 10 ** 6 - ((63000 * 10 ** 6) / 10000),
            "after initial normalgood:normalgood currentState amount0()"
        );

        assertEq(
            normalgoodstate.currentState.amount1(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount1()"
        );
        assertEq(normalgoodstate.feeQuantityState, 0, "after initial normalgood:normalgood feequnitity error");

        assertEq(
            normalgoodstate.goodConfig,
            1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197+25600258*2**229,
            "1after initial normalgood:normalgood goodConfig error"
        );

        assertEq(normalgoodstate.owner, users[1], "after initial normalgood:normalgood owner error");

        ///////////////////////////

        uint256 normalproof = S_ProofKey(users[1], normalgoodkey, metagoodkey).toId();

        S_ProofState memory _proof1 = market.getProofState(normalproof);
        assertEq(_proof1.state.amount0(), 63000 * 10 ** 6 - 63000 * 10 ** 2, "after initial:proof value error");
        assertEq(_proof1.invest.amount1(), 1 * 10 ** 8, "after initial:proof normal error");
        assertEq(
            _proof1.valueinvest.amount1(), 63000 * 10 ** 6 - 63000 * 10 ** 2, "after initial:proof value quantity error"
        );
    }
}
