// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, DSTest, console2} from "forge-std/Test.sol";
import {MyToken} from "../src/testtoken/ERC20.sol";
import "../Contracts/MarketManager.sol";
import {BaseSetup} from "./BaseSetup2.t.sol";
import {S_GoodKey, S_Ralate, S_ProofKey} from "../Contracts/libraries/L_Struct.sol";
import {
    T_BalanceUINT256, L_BalanceUINT256Library, toBalanceUINT256
} from "../Contracts/libraries/L_BalanceUINT256.sol";

import {L_ProofIdLibrary, L_Proof} from "../Contracts/libraries/L_Proof.sol";
import {L_GoodIdLibrary, L_Good} from "../Contracts/libraries/L_Good.sol";
import {L_CurrencyLibrary} from "../Contracts/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../Contracts/libraries/L_GoodConfig.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract collectNativeETHGood is Test, BaseSetup {
    using L_MarketConfigLibrary for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_CurrencyLibrary for address;
    using L_BalanceUINT256Library for T_BalanceUINT256;

    uint256 metagood;
    uint256 normalgoodbtc;
    uint256 normalgoodeth;

    uint256 metaproofid;

    function setUp() public override {
        BaseSetup.setUp();
        //goodInfo(metagood);
        //goodInfo(normalgoodbtc);
        //goodInfo(normalgoodeth);
    }

    function _testNativeETHInitNormalgood() public {
        vm.startPrank(marketcreator);
        uint256 sentBalance = 2 ether;
        address nativeCurrency = address(0);
        console2.log("1112", (2 ** 255) + 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224);
        vm.deal(marketcreator, 1000 ether);
        nativeCurrency.safeTransfer(address(1), sentBalance);
        console2.log("1111", marketcreator.balance);
        console2.log("1111", address(1).balance);
        usdt.mint(10000000 * 10 ** 6);
        usdt.approve(address(market), 10000000 * 10 ** 6);
        console2.log("users[3] approve market", usdt.allowance(users[3], address(market)));

        uint256 _goodConfig = (2 ** 255) + 8 * 2 ** 245 + 8 * 2 ** 238 + 8 * 2 ** 231 + 8 * 2 ** 224;
        console2.log("adabc", _goodConfig.isvaluegood());

        market.initMetaGood(
            nativeCurrency, toBalanceUINT256(1 * 10 ** 18, uint128(3000 * 10 ** usdt.decimals())), _goodConfig
        );
        vm.stopPrank();
    }

    function goodInfo(uint256 _good1) public view {
        console2.log(_good1, "************************");
        console2.log("price good1's value", market.getGoodState(_good1).currentState.amount0());
        console2.log("price good1's quantity", market.getGoodState(_good1).currentState.amount1());

        console2.log("price good1's invest value", market.getGoodState(_good1).investState.amount0());
        console2.log("price good1's invest quantity", market.getGoodState(_good1).investState.amount1());

        console2.log("price good1's fee", market.getGoodState(_good1).feeQunitityState.amount0());

        console2.log("price good1's contrunct fee", market.getGoodState(_good1).feeQunitityState.amount1());
    }

    function proofInfo(uint256 _proofid) public view {
        console2.log(_proofid, "*********proof***************");
        console2.log("getProofState's state amount0", market.getProofState(_proofid).state.amount0());
        console2.log("getProofState's state amount1 ", market.getProofState(_proofid).state.amount1());

        console2.log("getProofState's invest amount0", market.getProofState(_proofid).invest.amount0());
        console2.log("getProofState's invest amount1", market.getProofState(_proofid).invest.amount1());

        console2.log("getProofState's valueinvest amount0", market.getProofState(_proofid).valueinvest.amount0());

        console2.log("getProofState's valueinvest amount1", market.getProofState(_proofid).valueinvest.amount1());

        console2.log("getProofState's currentgood", market.getProofState(_proofid).currentgood);

        console2.log("getProofState's valuegood", market.getProofState(_proofid).valuegood);
    }

    function showconfig(uint256 _goodConfig) public pure {
        console2.log("good goodConfig:isvaluegood:", _goodConfig.isvaluegood());
        console2.log("good goodConfig:getInvestFee:", uint256(_goodConfig.getInvestFee()));
        console2.log("good goodConfig:getDisinvestFee:", uint256(_goodConfig.getDisinvestFee()));
        console2.log("good goodConfig:getBuyFee:", uint256(_goodConfig.getBuyFee()));
        console2.log("good goodConfig:getSellFee:", uint256(_goodConfig.getSellFee()));
        console2.log("good goodConfig:getSwapChips:", uint256(_goodConfig.getSwapChips()));
    }

    function getcompareprice(uint256 good1, uint256 good2) public view {
        console2.log(
            market.getGoodState(good1).currentState.amount0() * market.getGoodState(good2).currentState.amount1(),
            market.getGoodState(good1).currentState.amount1() * market.getGoodState(good2).currentState.amount0()
        );
    }
}
