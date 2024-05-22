// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey, S_Ralate} from "../Contracts/libraries/L_Struct.sol";
import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {T_BalanceUINT256, toBalanceUINT256} from "../Contracts/libraries/L_BalanceUINT256.sol";

import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {L_MarketConfigLibrary} from "../Contracts/libraries/L_MarketConfig.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract buyGoodNoFee is BaseSetup {
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

        console2.log("12121", metagood);
        L_Good.S_GoodTmpState memory aa = market.getGoodState(metagood);
        console2.log("12121", aa.goodConfig.isvaluegood());
        (normalgood,) = market.initGood(metagood, toBalanceUINT256(20000, 20000), token, _goodConfig, msg.sender);
        vm.stopPrank();
    }

    function testBuyGood(uint256) public {
        vm.startPrank(users[6]);
        deal(address(usdt), users[6], 100000, false);
        usdt.approve(address(market), 100000);
        L_Good.S_GoodTmpState memory s1 = market.getGoodState(metagood);
        GoodUtil.showGood(s1);
        L_Good.S_GoodTmpState memory s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s2);

        uint128 goodid2Quanitity_;

        uint128 goodid2FeeQuanitity_;
        snapStart("buygood without fee without chips first");
        (goodid2Quanitity_, goodid2FeeQuanitity_) = market.buyGood(
            normalgoodusdt, metagood, 10000, T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)), false, msg.sender
        );
        snapEnd();
        console2.log(goodid2Quanitity_, goodid2FeeQuanitity_);
        s1 = market.getGoodState(metagood);
        s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s1);
        GoodUtil.showGood(s2);
        console2.log(goodid2Quanitity_, goodid2FeeQuanitity_);
        market.buyGood(
            normalgoodusdt, metagood, 10000, T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)), false, msg.sender
        );
        s1 = market.getGoodState(metagood);
        s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s1);
        GoodUtil.showGood(s2);
        snapStart("buygood without fee without chips second");
        (goodid2Quanitity_, goodid2FeeQuanitity_) = market.buyGood(
            normalgoodusdt, metagood, 10, T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)), false, msg.sender
        );
        snapEnd();
    }
}
