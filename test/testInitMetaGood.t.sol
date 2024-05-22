// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";

import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract testInitMetaGood is BaseSetup {
    using L_ProofIdLibrary for S_ProofKey;
    using L_GoodIdLibrary for S_GoodKey;

    uint256 metagood;

    function setUp() public override {
        BaseSetup.setUp();
    }

    function testinitMetaGood() public {
        vm.startPrank(marketcreator);
        uint256 goodconfig = 2 ** 255;
        btc.mint(100000);
        btc.approve(address(market), 30000);
        snapStart("init metagood");
        console2.log("aa:", btc.balanceOf(marketcreator));
        (metagood,) = market.initMetaGood(address(btc), toBalanceUINT256(20000, 20000), goodconfig);
        snapEnd();

        L_Good.S_GoodTmpState memory good_ = market.getGoodState(metagood);
        GoodUtil.showGood(good_);
        uint256 normalproof = market.proofseq(S_ProofKey(marketcreator, metagood, 0).toId());
        ProofUtil.showproof(market.getProofState(normalproof));
        vm.stopPrank();
    }
}
