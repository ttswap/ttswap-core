pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";
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
        uint256 _goodconfig = (2 ** 255) +
            1 *
            2 ** 217 +
            3 *
            2 ** 211 +
            5 *
            2 ** 204 +
            7 *
            2 ** 197;
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        metagoodkey = address(usdt);
        vm.stopPrank();
    }

    function testinitNormalGood() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 1 * 10 ** 8 + 1);
        deal(address(usdt), users[1], 100000 * 10 ** 6, false);
        usdt.approve(address(market), 63000 * 10 ** 6 + 1);

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "befor init erc20 good, balance of market error"
        );
        uint256 normalgoodconfig = 1 *
            2 ** 217 +
            3 *
            2 ** 211 +
            5 *
            2 ** 204 +
            7 *
            2 ** 197;
        market.initGood(
            metagoodkey,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(btc),
            normalgoodconfig,
            defaultdata,
            defaultdata,
            users[1],
            defaultdata
        );
        snapLastCall("init_ERC20_By_ERC20");

        //normal good
        address normalgoodkey = address(btc);

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6 + 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(
            btc.balanceOf(address(market)),
            1 * 10 ** 8,
            "after initial normal good, balance of market error"
        );

        assertEq(
            usdt.balanceOf(users[1]),
            100000 * 10 ** 6 - 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(
            btc.balanceOf(users[1]),
            10 * 10 ** 8 - 1 * 10 ** 8,
            "after initial normal good, balance of market error"
        );

        S_GoodTmpState memory metagoodkeystate = market.getGoodState(
            metagoodkey
        );
        assertEq(
            metagoodkeystate.goodConfig.amount0(),
            uint256(
                1 *
                    2 ** 217 +
                    3 *
                    2 ** 211 +
                    5 *
                    2 ** 204 +
                    7 *
                    2 ** 197 +
                    92709122 *
                    2 ** 229
            ).amount0(),
            "1after initial normalgood:metagoodkey goodConfig "
        );

        assertEq(
            metagoodkeystate.goodConfig.amount1(),
            0,
            "1after initial normalgood:metagoodkey goodConfig amount1 error"
        );

        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6,
                50000 * 10 ** 6 + 63000 * 10 ** 6 
            ).amount0(),
            "1after initial normalgood:metagoodkey currentState amount0 error"
        );

        assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
               50000 * 10 ** 6 + 63000 * 10 ** 6,
                50000 * 10 ** 6 + 63000 * 10 ** 6 
            ).amount1(),
            "1after initial normalgood:metagoodkey currentState amount1 error"
        );

        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "1after initial normalgood:metagoodkey investState amount0 error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
               50000 * 10 ** 6 + 63000 * 10 ** 6- 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "1after initial normalgood:metagoodkey investState amount1 error"
        );

        assertEq(
            metagoodkeystate.goodConfig,
            uint256(
                1 *
                    2 ** 217 +
                    3 *
                    2 ** 211 +
                    5 *
                    2 ** 204 +
                    7 *
                    2 ** 197 +
                    92709122 *
                    2 ** 229
            ),
            "2after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(
            metagoodkeystate.owner,
            marketcreator,
            "after initial normalgood:metagoodkey marketcreator error"
        );

        ////////////////////////////////////////
        S_GoodTmpState memory normalgoodstate = market.getGoodState(
            normalgoodkey
        );
        assertEq(
            normalgoodstate.currentState.amount0(),
            100000000,
            "after initial normalgood:normalgood currentState amount0()"
        );

        assertEq(
            normalgoodstate.currentState.amount1(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount1()"
        );
        assertEq(
            normalgoodstate.investState.amount0(),
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6).amount0(),
            "after initial normalgood:normalgood investState error"
        );

        assertEq(
            normalgoodstate.investState.amount1(),
            toTTSwapUINT256(1 * 10 ** 8, 62993700000).amount1(),
            "after initial normalgood:normalgood investState amount1 error"
        );
        assertEq(
            normalgoodstate.goodConfig,
            1 *
                2 ** 217 +
                3 *
                2 ** 211 +
                5 *
                2 ** 204 +
                7 *
                2 ** 197 +
                25600258 *
                2 ** 229,
            "after initial normalgood:normalgood goodConfig error"
        );

        assertEq(
            normalgoodstate.owner,
            users[1],
            "after initial normalgood:normalgood owner error"
        );

        ///////////////////////////
        uint256 normalproof = S_ProofKey(users[1], normalgoodkey, metagoodkey)
            .toId();
        S_ProofState memory _proof1 = market.getProofState(normalproof);
        assertEq(
            _proof1.shares.amount0(),
            1 * 10 ** 8,
            "after initial:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            62993700000,
            "after initial:proof value shares error"
        );
        assertEq(
            _proof1.state.amount0(),
            63000 * 10 ** 6 - 63000 * 10 ** 2,
            "after initial:proof virtual value error"
        );
        assertEq(
            _proof1.state.amount1(),
            63000 * 10 ** 6 - 63000 * 10 ** 2,
            "after initial:proof actual value error"
        );
        assertEq(
            _proof1.invest.amount0(),
            1 * 10 ** 8,
            "after initial:normal good share error"
        );

        assertEq(
            _proof1.invest.amount1(),
            1 * 10 ** 8,
            "after initial:normal good quantity error"
        );

        assertEq(
            _proof1.valueinvest.amount0(),
            62993700000,
            "after initial:proof value good share error"
        );

        assertEq(
            _proof1.valueinvest.amount1(),
            62993700000,
            "after initial:proof value good quantity error"
        );

        vm.stopPrank();
    }

    function testinitNativeETHNormalGood() public {
        vm.startPrank(users[1]);
        deal(users[1], 10 * 10 ** 8);
        deal(address(usdt), users[1], 100000 * 10 ** 6, false);
        usdt.approve(address(market), 63000 * 10 ** 6 + 1);
        assertEq(
            users[1].balance,
            10 * 10 ** 8,
            "befor init erc20 good, balance of users[1] error"
        );
        assertEq(
            address(market).balance,
            0,
            "befor init erc20 good, balance of market error"
        );
        uint256 normalgoodconfig = 1 *
            2 ** 217 +
            3 *
            2 ** 211 +
            5 *
            2 ** 204 +
            7 *
            2 ** 197;
        market.initGood{value: 1 * 10 ** 8}(
            metagoodkey,
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(1),
            normalgoodconfig,
            defaultdata,
            defaultdata,
            users[1],
            defaultdata
        );
        snapLastCall("init_NativeETH_By_ERC20");
        vm.stopPrank();

        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6 + 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(
            address(market).balance,
            1 * 10 ** 8,
            "after initial normal good, balance of market error"
        );

        assertEq(
            usdt.balanceOf(users[1]),
            100000 * 10 ** 6 - 63000 * 10 ** 6,
            "after initial normal good, balance of market error"
        );

        assertEq(
            users[1].balance,
            10 * 10 ** 8 - 1 * 10 ** 8,
            "after initial normal good, balance of market error"
        );

        S_GoodTmpState memory metagoodkeystate = market.getGoodState(
            metagoodkey
        );
        assertEq(
            metagoodkeystate.currentState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6,
                50000 * 10 ** 6 + 63000 * 10 ** 6 
            ).amount0(),
            "after initial normalgood:metagoodkey currentState error"
        );

        assertEq(
            metagoodkeystate.currentState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6,
                50000 * 10 ** 6 + 63000 * 10 ** 6 
            ).amount1(),
            "after initial normalgood:metagoodkey currentState amount1 error"
        );
        assertEq(
            metagoodkeystate.investState.amount0(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount0(),
            "after initial normalgood:metagoodkey investState error"
        );
        assertEq(
            metagoodkeystate.investState.amount1(),
            toTTSwapUINT256(
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2,
                50000 * 10 ** 6 + 63000 * 10 ** 6 - 63000 * 10 ** 2
            ).amount1(),
            "after initial normalgood:metagoodkey investState error"
        );

        assertEq(
            metagoodkeystate.goodConfig,
            uint256(
                1 *
                    2 ** 217 +
                    3 *
                    2 ** 211 +
                    5 *
                    2 ** 204 +
                    7 *
                    2 ** 197 +
                    92709122 *
                    2 ** 229
            ),
            "4after initial normalgood:metagoodkey goodConfig error"
        );

        assertEq(
            metagoodkeystate.owner,
            marketcreator,
            "after initial normalgood:metagoodkey marketcreator error"
        );

        address normalgoodkey = address(1);

        ////////////////////////////////////////
        S_GoodTmpState memory normalgoodstate = market.getGoodState(
            normalgoodkey
        );
        assertEq(
            normalgoodstate.currentState.amount0(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount0()"
        );

        assertEq(
            normalgoodstate.currentState.amount1(),
            1 * 10 ** 8,
            "after initial normalgood:normalgood currentState amount1()"
        );

        assertEq(
            normalgoodstate.goodConfig,
            1 *
                2 ** 217 +
                3 *
                2 ** 211 +
                5 *
                2 ** 204 +
                7 *
                2 ** 197 +
                25600258 *
                2 ** 229,
            "after initial normalgood:normalgood goodConfig error"
        );

        assertEq(
            normalgoodstate.owner,
            users[1],
            "after initial normalgood:normalgood owner error"
        );

        ///////////////////////////

        uint256 normalproof = S_ProofKey(users[1], normalgoodkey, metagoodkey)
            .toId();

        S_ProofState memory _proof1 = market.getProofState(normalproof);
         assertEq(
            _proof1.shares.amount0(),
            1 * 10 ** 8,
            "after initial:proof normal shares error"
        );
        assertEq(
            _proof1.shares.amount1(),
            62993700000,
            "after initial:proof value shares error"
        );
        assertEq(
            _proof1.state.amount0(),
            63000 * 10 ** 6 - 63000 * 10 ** 2,
            "after initial:proof virtual value error"
        );
        assertEq(
            _proof1.state.amount1(),
            63000 * 10 ** 6 - 63000 * 10 ** 2,
            "after initial:proof actual value error"
        );
        assertEq(
            _proof1.invest.amount0(),
            1 * 10 ** 8,
            "after initial:normal good share error"
        );

        assertEq(
            _proof1.invest.amount1(),
            1 * 10 ** 8,
            "after initial:normal good quantity error"
        );

        assertEq(
            _proof1.valueinvest.amount0(),
            62993700000,
            "after initial:proof value good share error"
        );

        assertEq(
            _proof1.valueinvest.amount1(),
            62993700000,
            "after initial:proof value good quantity error"
        );
    }
}
