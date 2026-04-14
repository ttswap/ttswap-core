// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey, S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
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

contract testInitGoodWithPrice is BaseSetup {
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    address metagood;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255) +
            1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(50000 * 10 ** 12, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        metagood = address(usdt);
        vm.stopPrank();
    }

    function testInitGoodWithPrice_basic() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 1 * 10 ** 8 + 1);

        uint256 btcQuantity = 1 * 10 ** 8;
        uint256 btcValue = 63000 * 10 ** 12;
        uint256 normalgoodconfig = 1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;

        assertEq(
            btc.balanceOf(users[1]),
            10 * 10 ** 8,
            "before initGoodWithPrice: btc user balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            0,
            "before initGoodWithPrice: btc market balance error"
        );

        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(uint128(btcValue), uint128(btcQuantity)),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        assertEq(
            btc.balanceOf(users[1]),
            10 * 10 ** 8 - btcQuantity,
            "after initGoodWithPrice: btc user balance error"
        );
        assertEq(
            btc.balanceOf(address(market)),
            btcQuantity,
            "after initGoodWithPrice: btc market balance error"
        );

        S_GoodTmpState memory btcGood = market.getGoodState(address(btc));
        assertEq(
            btcGood.currentState.amount0(),
            btcQuantity,
            "after initGoodWithPrice: currentState.amount0 (invest qty) error"
        );
        assertEq(
            btcGood.currentState.amount1(),
            btcQuantity,
            "after initGoodWithPrice: currentState.amount1 (current qty) error"
        );
        assertEq(
            btcGood.investState.amount0(),
            btcQuantity,
            "after initGoodWithPrice: investState.amount0 (shares) error"
        );
        assertEq(
            btcGood.investState.amount1(),
            btcValue,
            "after initGoodWithPrice: investState.amount1 (value) error"
        );
        assertEq(
            btcGood.owner,
            users[1],
            "after initGoodWithPrice: owner error"
        );

        uint256 proofId = S_ProofKey(users[1], address(btc), address(0)).toId();
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(
            proof.currentgood,
            address(btc),
            "after initGoodWithPrice: proof currentgood error"
        );
        assertEq(
            proof.valuegood,
            address(0),
            "after initGoodWithPrice: proof valuegood error"
        );
        assertEq(
            proof.shares.amount0(),
            btcQuantity,
            "after initGoodWithPrice: proof normal shares error"
        );
        assertEq(
            proof.shares.amount1(),
            0,
            "after initGoodWithPrice: proof value shares error"
        );
        assertEq(
            proof.state.amount0(),
            btcValue,
            "after initGoodWithPrice: proof virtual value error"
        );
        assertEq(
            proof.state.amount1(),
            btcValue,
            "after initGoodWithPrice: proof actual value error"
        );
        assertEq(
            proof.invest.amount0(),
            btcQuantity,
            "after initGoodWithPrice: proof virtual invest qty error"
        );
        assertEq(
            proof.invest.amount1(),
            btcQuantity,
            "after initGoodWithPrice: proof actual invest qty error"
        );
        assertEq(
            proof.valueinvest,
            0,
            "after initGoodWithPrice: proof valueinvest should be 0"
        );

        vm.stopPrank();
    }

    function testInitGoodWithPrice_revert_duplicate() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 2 * 10 ** 8 + 1);

        uint256 normalgoodconfig = 1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;

        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(uint128(63000 * 10 ** 12), uint128(1 * 10 ** 8)),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 5));
        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(uint128(63000 * 10 ** 12), uint128(1 * 10 ** 8)),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        vm.stopPrank();
    }

    function testInitGoodWithPrice_revert_quantityTooSmall() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 10 * 10 ** 8);

        uint256 normalgoodconfig = 1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 36));
        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(uint128(1000), uint128(100)),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        vm.stopPrank();
    }

    function testInitGoodWithPrice_thenOneTokenInvest() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 5 * 10 ** 8 + 1);

        uint128 btcQuantity = 1 * 10 ** 8;
        uint128 btcValue = uint128(63000 * 10 ** 12);
        uint256 normalgoodconfig = 1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;

        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(btcValue, btcQuantity),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        S_GoodTmpState memory btcGoodBefore = market.getGoodState(address(btc));
        assertEq(
            btcGoodBefore.currentState.amount0(),
            btcGoodBefore.currentState.amount1(),
            "after init: amount0 should equal amount1"
        );

        uint128 investQty = 1 * 10 ** 8;
        uint128 investPrice = btcValue;
        market.oneTokenInvest(
            address(btc),
            toTTSwapUINT256(investPrice, investQty),
            defaultdata,
            defaultdata,
            users[1]
        );

        S_GoodTmpState memory btcGoodAfter = market.getGoodState(address(btc));
        assertGe(
            btcGoodAfter.currentState.amount0(),
            btcGoodAfter.currentState.amount1(),
            "after oneTokenInvest: amount0 should >= amount1"
        );

        uint256 proofId = S_ProofKey(users[1], address(btc), address(0)).toId();
        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(
            proof.shares.amount0(),
            btcQuantity,
            "after oneTokenInvest: shares should increase"
        );

        vm.stopPrank();
    }

    function testInitGoodWithPrice_thenOneTokenInvest_revertHighPrice() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 5 * 10 ** 8 + 1);

        uint128 btcQuantity = 1 * 10 ** 8;
        uint128 btcValue = uint128(63000 * 10 ** 12);
        uint256 normalgoodconfig = 1 * 2 ** 217 +
            3 * 2 ** 211 +
            5 * 2 ** 204 +
            7 * 2 ** 197;

        market.initGoodWithPrice(
            address(btc),
            toTTSwapUINT256(btcValue, btcQuantity),
            normalgoodconfig,
            defaultdata,
            users[1],
            defaultdata
        );

        uint128 investQty = 1 * 10 ** 8;
        uint128 higherPrice = uint128(64000 * 10 ** 12);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 47));
        market.oneTokenInvest(
            address(btc),
            toTTSwapUINT256(higherPrice, investQty),
            defaultdata,
            defaultdata,
            users[1]
        );

        vm.stopPrank();
    }
}
