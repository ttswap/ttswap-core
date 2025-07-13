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
import {WETH} from "solmate/src/tokens/WETH.sol";
import {IRocketTokenRETH} from "../src/interfaces/IRocketTokenRETH.sol";
import {IRocketStorage} from "../src/interfaces/IRocketStorage.sol";

contract StakeETHSWETH is BaseSetup {
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
        uint256 _goodconfig = (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        vm.startPrank(marketcreator);

        deal(reth, marketcreator, 1000 * 10 ** 18, false);
        rocketpoolmock(reth).approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(reth, toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata);
        market.changeReStakingContrat(address(ttswapstake));

        deal(marketcreator, 200 * 10 ** 18);
        MyToken(weth).deposit{value: 200 * 10 ** 18}();
        MyToken(weth).approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(sweth, toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata);

        deal(address(tts_token), marketcreator, 200 * 10 ** 18, false);
        tts_token.approve(address(market), 100 * 10 ** 18);
        market.initMetaGood(
            address(tts_token), toTTSwapUINT256(157000 * 10 ** 6, 100 * 10 ** 18), _goodconfig, defaultdata
        );
        vm.stopPrank();
    }

    function testStakeETH() public {
        vm.startPrank(marketcreator);
        assertEq(IERC20(weth).balanceOf(marketcreator), 100000000000000000000, "init  marketcreater weth error");
        assertEq(IERC20(weth).balanceOf(address(market)), 100000000000000000000, "init market eth error");
        assertEq(IERC20(weth).balanceOf(address(reth)), 0, "init reth eth error");

        assertEq(ttswapstake.totalState().amount0(), 0, "1after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 0, "1after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 0, "1after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 0, "1after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 0, "1after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 0, "1after ttswapstake.totalStake error");
        market.stakeETH(sweth, 10 * 10 ** 18);
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "2after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "2after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 10000000000000000000, "2after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "2after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 0, "2after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 0, "2after ttswapstake.totalStake error");
        assertEq(IERC20(weth).balanceOf(marketcreator), 100000000000000000000, "a2fter stake eth error");
        assertEq(IERC20(weth).balanceOf(address(market)), 90000000000000000000, "2after stake error");
        assertEq(IERC20(weth).balanceOf(address(reth)), 0, "after stake error");
        assertEq(address(ttswapstake).balance, 10 * 10 ** 18, "2after stake weth error");

        assertEq(IERC20(reth).balanceOf(address(ttswapstake)), 0, "2after stake reth error");
        ttswapstake.stakeRocketPoolETH(2 * 10 ** 18);
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "3after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "3after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 10000000000000000000, "3after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "3after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 2000000000000000000, "3after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 8000000000000000000, "3after ttswapstake.totalStake error");
        assertEq(IERC20(weth).balanceOf(marketcreator), 100000000000000000000, "3after stake weth error");
        assertEq(IERC20(weth).balanceOf(address(market)), 90 * 10 ** 18, "after stake error");
        assertEq(address(reth).balance, 2000000000000000000, "3after stake error");
        assertEq(address(ttswapstake).balance, 8 * 10 ** 18, "3after stake error");

        assertEq(IERC20(reth).balanceOf(address(ttswapstake)), 2000000000000000000, "3after stake error");
        deal(marketcreator, 1 * 10 ** 18);
        rocketpoolmock(reth).addreward{value: 1 * 10 ** 18}();
        assertEq(ttswapstake.totalState().amount0(), 10000000000000000000, "4after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "4after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 10000000000000000000, "4after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "4after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 2000000000000000000, "4after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 8000000000000000000, "4after ttswapstake.totalStake error");
        assertEq(address(reth).balance, 3000000000000000000, "4after reward error");
        assertEq(IERC20(weth).balanceOf(marketcreator), 100000000000000000000, "4after reward eth error");

        assertEq(address(reth).balance, 3000000000000000000, "4after reward error");

        assertEq(address(ttswapstake).balance, 8000000000000000000, "4after ttswapstake stake error");
        assertEq(IERC20(weth).balanceOf(address(market)), 90000000000000000000, "4after stake market error");

        market.syncReward(sweth);

        assertEq(address(ttswapstake).balance, 7000000000000000000, "5after reth syncReward  ttswapstake error");
        assertEq(IERC20(weth).balanceOf(address(market)), 90888888888888888889, "5after syncReward market error");
        assertEq(address(reth).balance, 3000000000000000000, "5after reth syncReward error");

        assertEq(
            IERC20(weth).balanceOf(marketcreator), 100111111111111111111, "5after  syncReward  marketcreator eth error"
        );
        assertEq(address(ttswapstake).balance, 7000000000000000000, "5after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "5after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "5after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 9090909090909090910, "5after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "5after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 3000000000000000000, "5after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "5after ttswapstake.totalStake error");
        assertEq(address(reth).balance, 3000000000000000000, "5after reth syncReward error");

        deal(marketcreator, 1 * 10 ** 18);
        rocketpoolmock(reth).addreward{value: 1 * 10 ** 18}();
        assertEq(IERC20(weth).balanceOf(address(market)), 90888888888888888889, "66after syncReward market error");
        assertEq(address(reth).balance, 4000000000000000000, "66after reth syncReward error");
        assertEq(
            IERC20(weth).balanceOf(marketcreator), 100111111111111111111, "66after  syncReward  marketcreator eth error"
        );
        assertEq(address(ttswapstake).balance, 7000000000000000000, "66after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "66after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "66after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 9090909090909090910, "66after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "66after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 3000000000000000000, "66after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "66after ttswapstake.totalStake error");

        ttswapstake.unstakeRocketPoolETH(1 * 10 ** 18);

        assertEq(IERC20(weth).balanceOf(address(market)), 90888888888888888889, "6after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "6after reth syncReward error");
        assertEq(
            IERC20(weth).balanceOf(marketcreator), 100111111111111111111, "6after  syncReward  marketcreator eth error"
        );
        assertEq(address(ttswapstake).balance, 9000000000000000000, "6after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 9090909090909090910, "6after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 12000000000000000000, "6after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 9090909090909090910, "6after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "6after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "6after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 9000000000000000000, "6after ttswapstake.totalStake error");

        market.syncReward(sweth);
        assertEq(IERC20(weth).balanceOf(address(market)), 92666666666666666667, "7after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "7after reth syncReward error");
        assertEq(
            IERC20(weth).balanceOf(marketcreator), 100333333333333333333, "7after  syncReward  marketcreator eth error"
        );
        assertEq(address(ttswapstake).balance, 7000000000000000000, "7after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 7575757575757575759, "7after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 10000000000000000000, "7after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 7575757575757575759, "7after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 10000000000000000000, "7after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "7after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 7000000000000000000, "7after ttswapstake.totalStake error");

        market.unstakeETH(sweth, 1 * 10 ** 18);

        assertEq(IERC20(weth).balanceOf(address(market)), 94555555555555555555, "8after syncReward market error");
        assertEq(address(reth).balance, 2000000000000000000, "8after reth syncReward error");
        assertEq(
            IERC20(weth).balanceOf(address(marketcreator)),
            100444444444444444443,
            "8after  syncReward  marketcreator eth error"
        );
        assertEq(address(ttswapstake).balance, 5000000000000000002, "8after syncReward ttswapstake error");
        assertEq(ttswapstake.totalState().amount0(), 6818181818181818184, "8after ttswapstake.totalState error");
        assertEq(ttswapstake.totalState().amount1(), 9000000000000000002, "8after ttswapstake.totalState error");
        assertEq(ttswapstake.swethState().amount0(), 6818181818181818184, "8after ttswapstake.swethState error");
        assertEq(ttswapstake.swethState().amount1(), 9000000000000000002, "8after ttswapstake.swethState error");
        assertEq(ttswapstake.totalStake().amount0(), 1000000000000000000, "8after ttswapstake.totalStake error");
        assertEq(ttswapstake.totalStake().amount1(), 5000000000000000002, "8after ttswapstake.totalStake error");
        deal(address(tts_token), address(ttswapstake), 10 ** 18, false);
        ttswapstake.collectTTSReward();

        vm.stopPrank();
    }
}
