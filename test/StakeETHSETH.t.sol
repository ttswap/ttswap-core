// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import { S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

import {IERC20} from "../src/interfaces/IERC20.sol";

import {rocketpoolmock} from "../src/test/rocketpoolmock.sol";
import {TTSwap_StakeETH} from "../src/TTSwap_StakeETH.sol";
import {TTSwap_StakeETH_Proxy} from "../src/TTSwap_StakeETH_Proxy.sol";
import {IRocketTokenRETH} from "../src/interfaces/IRocketTokenRETH.sol";
import {IRocketStorage} from "../src/interfaces/IRocketStorage.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

contract StakeETHSETH is BaseSetup {
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;

    address metagood;
    address normalgoodusdt;
    address normalgoodeth;
    rocketpoolmock reth1 = rocketpoolmock(payable(0x7322c24752f79c05FFD1E2a6FCB97020C1C264F1)); //hoodi address
    address payable reth = payable(0x7322c24752f79c05FFD1E2a6FCB97020C1C264F1); //hoodi address
    MyToken weth1;
    address payable weth = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address payable sweth = payable(address(3));
    address payable seth = payable(address(2));
    TTSwap_StakeETH ttswapstake;

    function setUp() public override {
        BaseSetup.setUp();
        initRethToken();
        TTSwap_StakeETH ttswapstake2 = new TTSwap_StakeETH(
        market, tts_token, IRocketTokenRETH(reth), IRocketStorage(reth)
        );
        TTSwap_StakeETH_Proxy ttswapstake_proxy=new TTSwap_StakeETH_Proxy(address(ttswapstake2),tts_token);
        ttswapstake=TTSwap_StakeETH(payable(address(ttswapstake_proxy)));
        weth1 = new MyToken("WETH", "WETH", 18);
        vm.etch(weth, address(weth1).code);
        initmetagood();

        // investOwnERC20ValueGood();
    }

    function initRethToken() public {
        reth1 = new rocketpoolmock("Reth", "Reth", 18);
        vm.etch(reth, address(reth1).code);
        IRocketStorage(reth).setAddress(
            keccak256(abi.encodePacked("contract.address", "rocketDAOProtocolSettingsDeposit")), address(reth)
        );
        IRocketStorage(reth).setAddress(
            keccak256(abi.encodePacked("contract.address", "rocketDepositPool")), address(reth)
        );

        // vm.etch(reth, rocketpoolmock("Reth", "Reth", 18));
    }

    function initmetagood() public {
        deal(marketcreator, 1000 * 10 ** 18);
        vm.startPrank(marketcreator);
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        assertEq(address(market).balance, 0, "init1 metagood market eth error");
        market.initMetaGood{value: 100 * 10 ** 18}(
            address(1), toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata
        );

        assertEq(address(market).balance, 100 * 10 ** 18, "init2 metagood market eth error");

        _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        market.initMetaGood{value: 100 * 10 ** 18}(
            seth, toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata
        );
        assertEq(address(market).balance, 200 * 10 ** 18, "init3 metagood market eth error");
        deal(reth, marketcreator, 1000 * 10 ** 18, false);
        rocketpoolmock(reth).approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(reth, toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata);

        market.changeReStakingContrat(address(ttswapstake));

        deal(weth, marketcreator, 200 * 10 ** 18, false);
        MyToken(weth).approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(sweth, toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata);

        deal(address(tts_token), marketcreator, 200 * 10 ** 18, false);
        tts_token.approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(
            address(tts_token), toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata
        );
        vm.stopPrank();
    }

    function testStakeSWETH() public {
        vm.startPrank(marketcreator);
        assertEq(marketcreator.balance, 800000000000000000000, "init  marketcreater eth error");
        assertEq(address(market).balance, 200000000000000000000, "init market eth error");
        assertEq(address(reth).balance, 0, "init reth eth error");

        assertEq(ttswapstake.totalState().amount0(), 0, "1after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 0, "1after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 0, "1after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 0, "1after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 0, "1after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 0, "1after ttswapstake.totalStake error");
        market.stakeETH(seth, 10 * 10 ** 18);
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "2after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "2after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 10000000000000000000, "2after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "2after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 0, "2after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 0, "2after ttswapstake.totalStake error");
        assertEq(marketcreator.balance, 800000000000000000000, "after stake eth error");
        assertEq(address(market).balance, 190 * 10 ** 18, "after stake error");
        assertEq(address(reth).balance, 0, "after stake error");
        assertEq(address(ttswapstake).balance, 10 * 10 ** 18, "after stake error");

        assertEq(IERC20(reth).balanceOf(address(ttswapstake)), 0, "after stake error");
        ttswapstake.stakeRocketPoolETH(2 * 10 ** 18);
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "3after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "3after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 10000000000000000000, "3after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "3after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 2000000000000000000, "3after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 8000000000000000000, "3after ttswapstake.totalStake error");
        assertEq(marketcreator.balance, 800000000000000000000, "after stake eth error");
        assertEq(address(market).balance, 190 * 10 ** 18, "after stake error");
        assertEq(address(reth).balance, 2000000000000000000, "after stake error");
        assertEq(address(ttswapstake).balance, 8 * 10 ** 18, "after stake error");

        assertEq(IERC20(reth).balanceOf(address(ttswapstake)), 2000000000000000000, "after stake error");

        rocketpoolmock(reth).addreward{value: 1 * 10 ** 18}();
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "4after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "4after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 10000000000000000000, "4after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "4after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 2000000000000000000, "4after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 8000000000000000000, "4after ttswapstake.totalStake error");
        assertEq(address(reth).balance, 3000000000000000000, "after reward error");
        assertEq(marketcreator.balance, 799000000000000000000, "after reward eth error");

        assertEq(address(reth).balance, 3000000000000000000, "after reward error");
        assertEq(marketcreator.balance, 799000000000000000000, "after reward eth error");
        assertEq(address(ttswapstake).balance, 8000000000000000000, "after ttswapstake stake error");
        assertEq(address(market).balance, 190000000000000000000, "after stake market error");

        market.syncReward(seth);

        assertEq(address(ttswapstake).balance, 7000000000000000000, "after reth syncReward  ttswapstake error");
        assertEq(address(market).balance, 190888888888888888889, "after syncReward market error");
        assertEq(address(reth).balance, 3000000000000000000, "after reth syncReward error");

        assertEq(marketcreator.balance, 799111111111111111111, "after  syncReward  marketcreator eth error");
        assertEq(address(ttswapstake).balance, 7000000000000000000, "after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "5after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "5after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 9090909090909090910, "5after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "5after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 3000000000000000000, "5after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "5after ttswapstake.totalStake error");
        assertEq(address(reth).balance, 3000000000000000000, "5after reth syncReward error");

        rocketpoolmock(reth).addreward{value: 1 * 10 ** 18}();
        assertEq(address(market).balance, 190888888888888888889, "66after syncReward market error");
        assertEq(address(reth).balance, 4000000000000000000, "66after reth syncReward error");
        assertEq(marketcreator.balance, 798111111111111111111, "66after  syncReward  marketcreator eth error");
        assertEq(address(ttswapstake).balance, 7000000000000000000, "66after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "66after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "66after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 9090909090909090910, "66after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "66after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 3000000000000000000, "66after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "66after ttswapstake.totalStake error");

        ttswapstake.unstakeRocketPoolETH(1 * 10 ** 18);

        assertEq(address(market).balance, 190888888888888888889, "6after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "6after reth syncReward error");
        assertEq(marketcreator.balance, 798111111111111111111, "6after  syncReward  marketcreator eth error");
        assertEq(address(ttswapstake).balance, 9000000000000000000, "6after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "6after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 12000000000000000000, "6after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 9090909090909090910, "6after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "6after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "6after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 9000000000000000000, "6after ttswapstake.totalStake error");

        market.syncReward(seth);
        assertEq(address(market).balance, 192666666666666666667, "7after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "7after reth syncReward error");
        assertEq(marketcreator.balance, 798333333333333333333, "7after  syncReward  marketcreator eth error");
        assertEq(address(ttswapstake).balance, 7000000000000000000, "7after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 7575757575757575759, "7after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "7after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 7575757575757575759, "7after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 10000000000000000000, "7after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "7after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "7after ttswapstake.totalStake error");

        market.unstakeETH(seth, 1 * 10 ** 18);

        assertEq(address(market).balance, 194555555555555555555, "8after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "8after reth syncReward error");
        assertEq(marketcreator.balance, 798444444444444444443, "8after  syncReward  marketcreator eth error");
        assertEq(address(ttswapstake).balance, 5000000000000000002, "8after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 6818181818181818184, "8after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 9000000000000000002, "8after ttswapstake.totalState error");
        assertEq(ttswapstake.sethState().amount0(), 6818181818181818184, "8after ttswapstake.sethState error");
        assertEq(ttswapstake.sethState().amount1(), 9000000000000000002, "8after ttswapstake.sethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "8after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 5000000000000000002, "8after ttswapstake.totalStake error");
        deal(address(tts_token), address(ttswapstake), 10 ** 18, false);
        ttswapstake.collectTTSReward();

        vm.stopPrank();
    }
}
