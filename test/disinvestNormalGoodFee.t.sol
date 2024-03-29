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

contract disinvestNormalGoodFee is BaseSetup {
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
        normalgoodeth = initNormalGood(address(eth));
    }

    function initmetagood() public {
        S_GoodKey memory goodkey = S_GoodKey({
            erc20address: T_Currency.wrap(address(btc)),
            owner: marketcreator
        });
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 100000, false);
        btc.approve(address(market), 30000);

        uint256 _goodConfig = 2 ** 255 + 8 * 2 ** 244 + 8 * 2 ** 234;
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
        uint256 _marketConfig = (50 << 250) +
            (5 << 244) +
            (10 << 238) +
            (10 << 232) +
            (25 << 226) +
            (20 << 220);
        console2.log(_marketConfig);

        market.setMarketConfig(_marketConfig);
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

        uint256 _goodConfig = 8 * 2 ** 244 + 8 * 2 ** 234;
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

    function testdisinvestNormalGood(uint256) public {
        vm.startPrank(users[3]);

        L_Ralate.S_Ralate memory _ralate = L_Ralate.S_Ralate({
            gater: address(1),
            refer: address(3)
        });
        snapStart("disinvest normal good with fee first");
        market.disinvestNormalGood(normalgoodusdt, metagood, 10000, _ralate);
        snapEnd();
        // market.investNormalGood(normalgoodusdt,metagood, 10000, _ralate);
        T_ProofId p_ = S_ProofKey(users[3], normalgoodusdt, metagood).toId();
        S_GoodState memory aa = market.getGoodState(normalgoodusdt);
        S_ProofState memory _s = market.getProofState(p_);

        assertEq(_s.state.amount0(), 10000, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 10000, "proof's quantity is error");

        assertEq(
            aa.currentState.amount0(),
            10000,
            "currentState's value is error"
        );
        assertEq(
            aa.currentState.amount1(),
            10000,
            "currentState's quantity is error"
        );

        assertEq(
            aa.investState.amount0(),
            10000,
            "investState's value is error"
        );
        assertEq(
            aa.investState.amount1(),
            10000,
            "investState's quantity is error"
        );
        console2.log(
            uint256(aa.feeQunitityState.amount0()),
            uint256(aa.feeQunitityState.amount1())
        );
        assertEq(
            aa.feeQunitityState.amount0(),
            2,
            "feeQunitityState's feeamount is error"
        );
        assertEq(
            aa.feeQunitityState.amount1(),
            0,
            "feeQunitityState's contruct fee is error"
        );

        assertEq(
            uint256(market.getGoodsFee(metagood, users[3])),
            2,
            "customer fee"
        );
        assertEq(
            uint256(market.getGoodsFee(metagood, marketcreator)),
            0,
            "seller fee"
        );
        assertEq(market.getGoodsFee(metagood, address(1)), 0, "gater fee");
        assertEq(market.getGoodsFee(metagood, address(2)), 0, "refer fee");
        snapStart("disinvest normal good with fee second");
        market.disinvestNormalGood(normalgoodusdt, metagood, 10, _ralate);
        snapEnd();
        vm.stopPrank();
    }

    function testdisinvestNormalProof(uint256) public {
        vm.startPrank(users[3]);
        deal(
            T_Currency.unwrap(market.getGoodState(metagood).erc20address),
            users[3],
            100000,
            false
        );
        deal(
            T_Currency.unwrap(market.getGoodState(normalgoodusdt).erc20address),
            users[3],
            100000,
            false
        );
        MyToken(T_Currency.unwrap(market.getGoodState(metagood).erc20address))
            .approve(address(market), 20000);
        MyToken(
            T_Currency.unwrap(market.getGoodState(normalgoodusdt).erc20address)
        ).approve(address(market), 20000);
        L_Ralate.S_Ralate memory _ralate = L_Ralate.S_Ralate({
            gater: address(1),
            refer: address(3)
        });
        T_ProofId p_ = S_ProofKey(users[3], normalgoodusdt, metagood).toId();
        snapStart("disinvest normal proof with fee first");
        market.disinvestNormalProof(p_, 10000, _ralate);
        snapEnd();
        // market.investNormalGood(normalgoodusdt,metagood, 10000, _ralate);

        S_GoodState memory aa = market.getGoodState(normalgoodusdt);
        S_ProofState memory _s = market.getProofState(p_);

        assertEq(_s.state.amount0(), 10000, "proof's value is error");
        assertEq(_s.invest.amount0(), 0, "proof's contruct quantity is error");
        assertEq(_s.invest.amount1(), 10000, "proof's quantity is error");

        assertEq(
            aa.currentState.amount0(),
            10000,
            "currentState's value is error"
        );
        assertEq(
            aa.currentState.amount1(),
            10000,
            "currentState's quantity is error"
        );

        assertEq(
            aa.investState.amount0(),
            10000,
            "investState's value is error"
        );
        assertEq(
            aa.investState.amount1(),
            10000,
            "investState's quantity is error"
        );
        console2.log(
            uint256(aa.feeQunitityState.amount0()),
            uint256(aa.feeQunitityState.amount1())
        );
        assertEq(
            aa.feeQunitityState.amount0(),
            2,
            "feeQunitityState's feeamount is error"
        );
        assertEq(
            aa.feeQunitityState.amount1(),
            0,
            "feeQunitityState's contruct fee is error"
        );

        assertEq(
            uint256(market.getGoodsFee(metagood, users[3])),
            2,
            "customer fee"
        );
        assertEq(
            uint256(market.getGoodsFee(metagood, marketcreator)),
            0,
            "seller fee"
        );
        assertEq(market.getGoodsFee(metagood, address(1)), 0, "gater fee");
        assertEq(market.getGoodsFee(metagood, address(2)), 0, "refer fee");
        snapStart("disinvest normal proof with fee second");
        market.disinvestNormalProof(p_, 10, _ralate);
        snapEnd();
        vm.stopPrank();
    }
}
