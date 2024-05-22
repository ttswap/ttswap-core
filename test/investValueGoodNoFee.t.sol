// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";

contract investValueGoodNoFee is BaseSetup {
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
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 100000, false);
        btc.approve(address(market), 30000);
        uint256 _goodconfig = 2 ** 255;
        (metagood,) = market.initMetaGood(address(btc), toBalanceUINT256(20000, 20000), _goodconfig);

        // market.updatetoValueGood(metagood);
        vm.stopPrank();
    }

    function testinvestValueGood(uint256) public {
        vm.startPrank(users[2]);
        deal(market.getGoodState(metagood).erc20address, users[2], 100000, false);
        MyToken(market.getGoodState(metagood).erc20address).approve(address(market), 200000);

        snapStart("invest value good no fee first");
        market.investGood(metagood, 0, 20000, address(1));
        snapEnd();
        uint256 p_ = market.proofseq(S_ProofKey(users[2], metagood, 0).toId());
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        L_Proof.S_ProofState memory _s = market.getProofState(p_);
        assertEq(_s.state.amount0(), 20000, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 20000, "proof's quantity is error");

        assertEq(aa.currentState.amount0(), 40000, "currentState's value is error");
        assertEq(aa.currentState.amount1(), 40000, "currentState's quantity is error");

        assertEq(aa.investState.amount0(), 40000, "investState's value is error");
        assertEq(aa.investState.amount1(), 40000, "investState's quantity is error");
        console2.log(uint256(aa.feeQunitityState.amount0()), uint256(aa.feeQunitityState.amount1()));
        assertEq(aa.feeQunitityState.amount1(), 0, "feeQunitityState's feeamount is error");
        assertEq(aa.feeQunitityState.amount0(), 0, "feeQunitityState's contruct fee is error");

        assertEq(uint256(market.getGoodsFee(metagood, users[2])), 0, "customer fee");
        assertEq(uint256(market.getGoodsFee(metagood, marketcreator)), 0, "seller fee");
        assertEq(market.getGoodsFee(metagood, address(1)), 0, "gater fee");
        assertEq(market.getGoodsFee(metagood, address(2)), 0, "refer fee");
        snapStart("invest value good no fee second");
        market.investGood(metagood, 0, 20000, address(1));
        snapEnd();
        vm.stopPrank();
    }
}
