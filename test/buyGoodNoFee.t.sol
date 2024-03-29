pragma solidity ^0.8.13;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodKey} from "../Contracts/types/S_GoodKey.sol";
import {T_GoodId, L_GoodIdLibrary} from "../Contracts/types/T_GoodId.sol";
import {T_BalanceUINT256, toBalanceUINT256} from "../Contracts/types/T_BalanceUINT256.sol";
import {S_ProofKey, S_ProofState} from "../Contracts/types/S_ProofKey.sol";
import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {L_MarketConfigLibrary} from "../Contracts/libraries/L_MarketConfig.sol";
import {L_Ralate} from "../Contracts/libraries/L_Ralate.sol";
import {GoodUtil} from "./util/GoodUtil.sol";
import {L_Ralate} from "../Contracts/libraries/L_Ralate.sol";

contract buyGoodNoFee is BaseSetup {
    using L_MarketConfigLibrary for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;

    T_GoodId metagood;
    T_GoodId normalgoodusdt;
    T_GoodId normalgoodeth;

    function setUp() public override {
        BaseSetup.setUp();
        initmetagood();
        normalgoodusdt = initNormalGood(address(usdt));
    }

    function initmetagood() public {
        S_GoodKey memory goodkey = S_GoodKey({
            erc20address: T_Currency.wrap(address(btc)),
            owner: marketcreator
        });
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 100000, false);
        btc.approve(address(market), 30000);

        uint256 _goodConfig = 2 ** 255;
        market.initMetaGood(
            goodkey,
            toBalanceUINT256(20000, 20000),
            _goodConfig
        );
        metagood = S_GoodKey({
            erc20address: T_Currency.wrap(address(btc)),
            owner: marketcreator
        }).toId();
        //market.updatetoValueGood(metagood);
        vm.stopPrank();
    }

    function initNormalGood(
        address token
    ) public returns (T_GoodId normalgood) {
        vm.startPrank(users[3]);
        deal(address(btc), users[3], 100000, false);
        btc.approve(address(market), 20000);
        deal(token, users[3], 100000, false);
        MyToken(token).approve(address(market), 20000);
        uint256 _goodConfig = 0;
        normalgood = S_GoodKey({
            erc20address: T_Currency.wrap(address(token)),
            owner: users[3]
        }).toId();
        market.initNormalGood(
            metagood,
            toBalanceUINT256(20000, 20000),
            T_Currency.wrap(token),
            _goodConfig
        );
        vm.stopPrank();
    }

    function testBuyGood() public {
        vm.startPrank(users[6]);
        deal(address(usdt), users[6], 100000, false);
        usdt.approve(address(market), 100000);
        L_Ralate.S_Ralate memory _ralate = L_Ralate.S_Ralate({
            gater: address(1),
            refer: address(3)
        });
        S_GoodState memory s1 = market.getGoodState(metagood);
        GoodUtil.showGood(s1);
        S_GoodState memory s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s2);

        uint128 goodid2Quanitity_;

        uint128 goodid2FeeQuanitity_;
        snapStart("buygood without fee without chips first");
        (goodid2Quanitity_, goodid2FeeQuanitity_) = market.buyGood(
            normalgoodusdt,
            metagood,
            10000,
            T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)),
            false,
            _ralate
        );
        snapEnd();
        console2.log(goodid2Quanitity_, goodid2FeeQuanitity_);
        s1 = market.getGoodState(metagood);
        s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s1);
        GoodUtil.showGood(s2);
        console2.log(goodid2Quanitity_, goodid2FeeQuanitity_);
        market.buyGood(
            normalgoodusdt,
            metagood,
            10000,
            T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)),
            false,
            _ralate
        );
        s1 = market.getGoodState(metagood);
        s2 = market.getGoodState(normalgoodusdt);
        GoodUtil.showGood(s1);
        GoodUtil.showGood(s2);
        snapStart("buygood without fee without chips second");
        (goodid2Quanitity_, goodid2FeeQuanitity_) = market.buyGood(
            normalgoodusdt,
            metagood,
            10,
            T_BalanceUINT256.unwrap(toBalanceUINT256(2, 1)),
            false,
            _ralate
        );
        snapEnd();
    }
}
