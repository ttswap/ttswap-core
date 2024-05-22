// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {T_BalanceUINT256, toBalanceUINT256} from "../Contracts/libraries/L_BalanceUINT256.sol";

import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract disinvestValueGoodFee is BaseSetup {
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodConfigLibrary for uint256;

    uint256 metagood;
    uint256 normalgoodusdt;
    uint256 normalgoodeth;
    uint256 valueProof;
    uint256 normalProofusdt;
    uint256 normalProofeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        valueProof = investValueGood();
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 100000, false);
        btc.approve(address(market), 30000);
        uint256 _goodConfig = 1 * 2 ** 255 + 8 * 2 ** 245 + 8 * 2 ** 235;
        (metagood,) = market.initMetaGood(address(btc), toBalanceUINT256(20000, 20000), _goodConfig);

        //market.updatetoValueGood(metagood);

        uint256 _marketConfig = (50 << 250) + (5 << 244) + (10 << 238) + (15 << 232) + (20 << 226) + (20 << 220);
        market.setMarketConfig(_marketConfig);
        console2.log(_goodConfig.isvaluegood(), "1");
        console2.log(_goodConfig.getInvestFee(), "2");
        console2.log(_goodConfig.getDisinvestFee(), "3");
        snapStart("update Good Config");
        market.updateGoodConfig(metagood, _goodConfig);
        snapEnd();
        vm.stopPrank();
    }

    function investValueGood() public returns (uint256 p_) {
        vm.startPrank(users[2]);
        deal(market.getGoodState(metagood).erc20address, users[2], 200000, false);
        MyToken(market.getGoodState(metagood).erc20address).approve(address(market), 100000);

        market.investGood(metagood, 0, 20000, address(1));
        p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        L_Proof.S_ProofState memory _s = market.getProofState(p_);
        assertEq(_s.state.amount0(), 19984, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 19984, "proof's quantity is error");

        assertEq(aa.currentState.amount0(), 39984, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 39984, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 39984, "investState's value is error");
        assertEq(aa.investState.amount1(), 39984, "investState's quantity is error");
        console2.log(uint256(aa.feeQunitityState.amount0()), uint256(aa.feeQunitityState.amount1()));
        assertEq(aa.feeQunitityState.amount0(), 8, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee is error");

        vm.stopPrank();
    }

    function testdisinvestvaluegood(uint256 aquanity) public {
        console2.log("111", aquanity);
        vm.startPrank(users[2]);
        vm.assume(aquanity > 1 && aquanity < 1000);
        uint128 quanity = uint128(aquanity);

        snapStart("disinvest Value Good With Fee first");
        (L_Good.S_GoodDisinvestReturn memory result,,) = market.disinvestGood(metagood, 0, quanity, address(1));
        snapEnd();
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        assertEq(result.actualDisinvestValue, aquanity, "disinvest proof 's value is error");
        assertEq(result.actualDisinvestQuantity, aquanity, "disinvest proof 's quantity is error");
        assertEq(aa.currentState.amount0(), 39984 - quanity, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 39984 - quanity, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 39984 - quanity, "investState's value is error");
        assertEq(aa.investState.amount1(), 39984 - quanity, "investState's quantity is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee  is error");
        assertEq(aa.feeQunitityState.amount0(), 8, "feeQunitityState's feeamount is error");
        console2.log(uint256(aa.feeQunitityState.amount0()), uint256(aa.feeQunitityState.amount1()));
        snapStart("disinvest Value Good With Fee second");
        (result,,) = market.disinvestGood(metagood, 0, 10, address(1));
        snapEnd();
        vm.stopPrank();
    }

    function testdisinvestvalueproof(uint256 aquanity) public {
        vm.startPrank(users[2]);

        vm.assume(aquanity > 1 && aquanity < 1000);
        uint128 quanity = uint128(aquanity);
        uint256 p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        snapStart("disinvest Value Proof with fee first");
        (L_Good.S_GoodDisinvestReturn memory result,) = market.disinvestProof(p_, quanity, address(1));
        snapEnd();
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);

        console2.log(quanity);
        assertEq(result.actualDisinvestValue, aquanity, "disinvest proof 's value is error");
        assertEq(result.actualDisinvestQuantity, aquanity, "disinvest proof 's quantity is error");
        assertEq(aa.currentState.amount0(), 39984 - quanity, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 39984 - quanity, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 39984 - quanity, "investState's value is error");
        assertEq(aa.investState.amount1(), 39984 - quanity, "investState's quantity is error");
        assertEq(aa.feeQunitityState.amount0(), 8, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee is error");
        snapStart("disinvest Value Proof with fee second");
        (result,) = market.disinvestProof(p_, 10, address(1));
        snapEnd();
        vm.stopPrank();
    }

    function testdisinvestvalueproof1() public {
        vm.startPrank(users[2]);

        uint128 quanity = 10000;
        uint256 p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        L_Proof.S_ProofState memory _s = market.getProofState(p_);
        console2.log("proof value", _s.state.amount0());
        console2.log("proof invest quanity", _s.invest.amount1());
        (L_Good.S_GoodDisinvestReturn memory result,) = market.disinvestProof(p_, quanity, address(1));
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);

        console2.log(quanity);
        assertEq(result.actualDisinvestValue, 10000, "disinvest proof 's value is error");
        assertEq(result.actualDisinvestQuantity, 10000, "disinvest proof 's quantity is error");
        assertEq(aa.currentState.amount0(), 39984 - quanity, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 39984 - quanity, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 39984 - quanity, "investState's value is error");
        assertEq(aa.investState.amount1(), 39984 - quanity, "investState's quantity is error");
        assertEq(aa.feeQunitityState.amount0(), 6, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's contruct fee is error");
        vm.stopPrank();
    }

    function testdisinvestvalueproof2() public {
        vm.startPrank(users[2]);

        uint128 quanity = 500;
        uint256 p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        (L_Good.S_GoodDisinvestReturn memory result,) = market.disinvestProof(p_, quanity, address(1));

        (result,) = market.disinvestProof(p_, quanity, address(1));

        vm.stopPrank();
    }
}
