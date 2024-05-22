// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {T_BalanceUINT256, toBalanceUINT256} from "../Contracts/libraries/L_BalanceUINT256.sol";

import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {L_MarketConfigLibrary} from "../Contracts/libraries/L_MarketConfig.sol";

contract disinvestNormalGoodNoFee is BaseSetup {
    using L_MarketConfigLibrary for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 metagood;
    uint256 normalgoodusdt;
    uint256 normalgoodeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        normalgoodusdt = initNormalGood(address(usdt));
        normalgoodeth = initNormalGood(address(eth));
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 100000, false);
        btc.approve(address(market), 30000);

        uint256 _goodConfig = 2 ** 255;
        (metagood,) = market.initMetaGood(address(btc), toBalanceUINT256(20000, 20000), _goodConfig);

        //market.updatetoValueGood(metagood);
        vm.stopPrank();
    }

    function initNormalGood(address token) public returns (uint256 normalgood) {
        vm.startPrank(users[3]);
        deal(address(btc), users[3], 100000, false);
        btc.approve(address(market), 20000);
        deal(token, users[3], 100000, false);
        MyToken(token).approve(address(market), 20000);

        uint256 _goodConfig = 0;
        (normalgood,) = market.initGood(metagood, toBalanceUINT256(20000, 20000), token, _goodConfig, msg.sender);
        vm.stopPrank();
    }

    function testdisinvestNormalGood(uint256) public {
        vm.startPrank(users[3]);
        L_Good.S_GoodTmpState memory normal = market.getGoodState(normalgoodusdt);
        L_Good.S_GoodTmpState memory meta = market.getGoodState(metagood);
        deal(meta.erc20address, users[3], 100000, false);
        deal(normal.erc20address, users[3], 100000, false);
        MyToken(meta.erc20address).approve(address(market), 20000);
        MyToken(normal.erc20address).approve(address(market), 20000);

        snapStart("disinvest Normal good without fee first");
        market.disinvestGood(normalgoodusdt, metagood, 10000, address(1));
        snapEnd();
        // market.investGood(normalgoodusdt,metagood, 10000, _ralate);
        uint256 p_ = market.proofseq(S_ProofKey(users[3], normalgoodusdt, metagood).toId());
        L_Good.S_GoodTmpState memory aa = market.getGoodState(normalgoodusdt);
        L_Proof.S_ProofState memory _s = market.getProofState(p_);

        assertEq(_s.state.amount0(), 10000, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 10000, "proof's quantity is error");

        assertEq(aa.currentState.amount0(), 10000, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 10000, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 10000, "investState's value is error");
        assertEq(aa.investState.amount1(), 10000, "investState's quantity is error");
        console2.log(uint256(aa.feeQunitityState.amount0()), uint256(aa.feeQunitityState.amount1()));
        assertEq(aa.feeQunitityState.amount0(), 0, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee is error");

        assertEq(uint256(market.getGoodsFee(metagood, users[3])), 0, "customer fee");
        assertEq(uint256(market.getGoodsFee(metagood, marketcreator)), 0, "seller fee");
        assertEq(market.getGoodsFee(metagood, address(1)), 0, "gater fee");
        assertEq(market.getGoodsFee(metagood, address(2)), 0, "refer fee");
        snapStart("disinvest Normal good without fee second");
        market.disinvestGood(normalgoodusdt, metagood, 1, address(1));
        snapEnd();
        vm.stopPrank();
    }

    function testdisinvestNormalProof(uint256) public {
        vm.startPrank(users[3]);
        L_Good.S_GoodTmpState memory normal = market.getGoodState(normalgoodusdt);
        L_Good.S_GoodTmpState memory meta = market.getGoodState(metagood);
        deal(meta.erc20address, users[3], 100000, false);
        deal(normal.erc20address, users[3], 100000, false);
        MyToken(meta.erc20address).approve(address(market), 20000);
        MyToken(normal.erc20address).approve(address(market), 20000);

        uint256 p_ = market.proofseq(S_ProofKey(users[3], normalgoodusdt, metagood).toId());
        snapStart("disinvest Normal proof without fee first");
        market.disinvestProof(p_, 10000, address(1));
        snapEnd();
        // market.investGood(normalgoodusdt,metagood, 10000, _ralate);

        L_Good.S_GoodTmpState memory aa = market.getGoodState(normalgoodusdt);
        L_Proof.S_ProofState memory _s = market.getProofState(p_);

        assertEq(_s.state.amount0(), 10000, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 10000, "proof's quantity is error");

        assertEq(aa.currentState.amount0(), 10000, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 10000, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 10000, "investState's value is error");
        assertEq(aa.investState.amount1(), 10000, "investState's quantity is error");
        console2.log(uint256(aa.feeQunitityState.amount0()), uint256(aa.feeQunitityState.amount1()));
        assertEq(aa.feeQunitityState.amount0(), 0, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee is error");

        assertEq(uint256(market.getGoodsFee(metagood, users[3])), 0, "customer fee");
        assertEq(uint256(market.getGoodsFee(metagood, marketcreator)), 0, "seller fee");
        assertEq(market.getGoodsFee(metagood, address(1)), 0, "gater fee");
        assertEq(market.getGoodsFee(metagood, address(2)), 0, "refer fee");
        snapStart("disinvest Normal proof without fee second");
        market.disinvestProof(p_, 100, address(1));
        snapEnd();
        vm.stopPrank();
    }

    function testdisinvestNormalProof1(uint256) public {
        vm.startPrank(users[3]);
        L_Good.S_GoodTmpState memory normal = market.getGoodState(normalgoodusdt);
        L_Good.S_GoodTmpState memory meta = market.getGoodState(metagood);
        deal(meta.erc20address, users[3], 100000, false);
        deal(normal.erc20address, users[3], 100000, false);
        MyToken(meta.erc20address).approve(address(market), 20000);
        MyToken(normal.erc20address).approve(address(market), 20000);

        uint256 p_ = market.proofseq(S_ProofKey(users[3], normalgoodusdt, metagood).toId());
        market.disinvestProof(p_, 5000, address(1));
        // market.investGood(normalgoodusdt,metagood, 10000, _ralate);

        vm.stopPrank();
    }

    function testdisinvestNormalGood1(uint256) public {
        vm.startPrank(users[3]);
        L_Good.S_GoodTmpState memory normal = market.getGoodState(normalgoodusdt);
        L_Good.S_GoodTmpState memory meta = market.getGoodState(metagood);
        deal(meta.erc20address, users[3], 100000, false);
        deal(normal.erc20address, users[3], 100000, false);
        MyToken(meta.erc20address).approve(address(market), 20000);
        MyToken(normal.erc20address).approve(address(market), 20000);
        market.disinvestGood(normalgoodusdt, metagood, 5000, address(1));
        // market.disinvestGood(normalgoodusdt,metagood, 10000, _ralate);
        market.disinvestGood(normalgoodusdt, metagood, 5000, address(1));
        vm.stopPrank();
    }
}
