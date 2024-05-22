pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_ProofKey, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {T_BalanceUINT256, toBalanceUINT256} from "../Contracts/libraries/L_BalanceUINT256.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";
import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";

contract testinvestGood is BaseSetup {
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;

    uint256 metagood;

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
        GoodUtil.showGood(market.getGoodState(metagood));
        uint256 normalproof = market.proofseq(S_ProofKey(msg.sender, metagood, 0).toId());
        ProofUtil.showproof(market.getProofState(normalproof));
        vm.stopPrank();
    }

    function testinitNormalGood() public {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 100000, false);
        btc.approve(address(market), 10000);
        console2.log(btc.balanceOf(users[1]));
        deal(address(usdt), users[1], 100000, false);
        usdt.approve(address(market), 10000);
        console2.log(usdt.balanceOf(users[1]));
        snapStart("init normalgood");
        market.initGood(metagood, toBalanceUINT256(1000, 1000), address(usdt), 1, msg.sender);
        snapEnd();
        vm.stopPrank();
    }
}
