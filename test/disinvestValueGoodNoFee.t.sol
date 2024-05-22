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

import {L_Proof, L_ProofIdLibrary} from "../Contracts/libraries/L_Proof.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract disinvestValueGoodNoFee is BaseSetup {
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;

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
        uint256 _goodconfig = 2 ** 255;
        (metagood,) = market.initMetaGood(address(btc), toBalanceUINT256(20000, 20000), _goodconfig);

        //market.updatetoValueGood(metagood);
        vm.stopPrank();
    }

    function investValueGood() public returns (uint256 p_) {
        vm.startPrank(users[2]);
        deal(market.getGoodState(metagood).erc20address, users[2], 200000, false);
        MyToken(market.getGoodState(metagood).erc20address).approve(address(market), 100000);

        market.investGood(metagood, 0, 20000, address(1));
        p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        vm.stopPrank();
    }

    function testdisinvestvaluegood(uint256 aquanity) public {
        vm.startPrank(users[2]);
        vm.assume(aquanity > 1 && aquanity < 1000);
        uint128 quanity = uint128(aquanity);

        snapStart("disinvest Value good No Fee first");
        (L_Good.S_GoodDisinvestReturn memory result,,) = market.disinvestGood(metagood, 0, quanity, address(1));
        snapEnd();
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        assertEq(result.actualDisinvestValue, aquanity, "disinvest proof 's value is error");
        assertEq(result.actualDisinvestQuantity, aquanity, "disinvest proof 's quantity is error");
        assertEq(aa.currentState.amount0(), 40000 - quanity, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 40000 - quanity, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 40000 - quanity, "investState's value is error");
        assertEq(aa.investState.amount1(), 40000 - quanity, "investState's quantity is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount0(), 0, "feeQunitityState's contruct fee is error");
        snapStart("disinvest Value good No Fee second");
        (result,,) = market.disinvestGood(metagood, 0, quanity, address(1));
        snapEnd();

        vm.stopPrank();
    }

    function testdisinvestvalueproof(uint256 aquanity) public {
        vm.startPrank(users[2]);

        vm.assume(aquanity > 1 && aquanity < 1000);
        uint128 quanity = uint128(aquanity);
        uint256 p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());

        snapStart("disinvest Value proof No Fee first");
        (L_Good.S_GoodDisinvestReturn memory result,) = market.disinvestProof(p_, quanity, address(1));
        snapEnd();
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        assertEq(result.actualDisinvestValue, aquanity, "disinvest proof 's value is error");
        assertEq(result.actualDisinvestQuantity, aquanity, "disinvest proof 's quantity is error");
        assertEq(aa.currentState.amount0(), 40000 - quanity, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 40000 - quanity, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 40000 - quanity, "investState's value is error");
        assertEq(aa.investState.amount1(), 40000 - quanity, "investState's quantity is error");
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount0(), 0, "feeQunitityState's contruct fee is error");
        snapStart("disinvest Value proof No Fee second");
        (result,) = market.disinvestProof(p_, 10, address(1));
        snapEnd();
        vm.stopPrank();
    }
}
