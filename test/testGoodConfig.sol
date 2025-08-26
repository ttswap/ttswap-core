// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

contract testGoodConfig is Test {
    using L_GoodConfigLibrary for uint256;


    function test_isvaluegood() public pure {
        uint256 a_min = 1 * 2 ** 255;
        assertEq(a_min.isvaluegood(), true);
        a_min = 0 * 2 ** 255;
        assertEq(a_min.isvaluegood(), false);
        uint256 bb=92676354<<229;
        assertEq(bb.isvaluegood(), true);
    }

    function test_getliquild() public pure {
        uint256 a_min = 1*2 ** 251;
        uint256 a_mid = 3 * 2 ** 251;
        uint256 a_max = 7 * 2 ** 251;
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        // assertEq(a_min.getDisinvestFee(), 1);
        // assertEq(a_mid.getDisinvestFee(), 32);
        // assertEq(a_max.getDisinvestFee(), 63);
        assertEq(a_min.getLiquidFee(10000), 1000);
        assertEq(a_mid.getLiquidFee(10000), 3000);
        assertEq(a_max.getLiquidFee(10000), 7000);
        assertEq(bb.getLiquidFee(10000), 6000);
        assertEq(cc.getLiquidFee(10000), 6000);
    }

    function test_getOperatorFee() public pure {
        uint256 a_min = 1*2 ** 247;
        uint256 a_mid = 7 * 2 ** 247;
        uint256 a_max = 15 * 2 ** 247;
        // assertEq(a_min.getDisinvestFee(), 1);
        // assertEq(a_mid.getDisinvestFee(), 32);
        // assertEq(a_max.getDisinvestFee(), 63);
        assertEq(a_min.getOperatorFee(10000), 200);
        assertEq(a_mid.getOperatorFee(10000), 1400);
        assertEq(a_max.getOperatorFee(10000), 3000);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getOperatorFee(10000), 200);
        assertEq(cc.getOperatorFee(10000), 200);
    }

    function test_getGateFee() public pure {
        uint256 a_min = 1*2 ** 244;
        uint256 a_mid = 3 * 2 ** 244;
        uint256 a_max = 7 * 2 ** 244;
        // assertEq(a_min.getDisinvestFee(), 1);
        // assertEq(a_mid.getDisinvestFee(), 32);
        // assertEq(a_max.getDisinvestFee(), 63);
        assertEq(a_min.getGateFee(10000), 400);
        assertEq(a_mid.getGateFee(10000), 1200);
        assertEq(a_max.getGateFee(10000), 2800);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getGateFee(10000), 1600);
        assertEq(cc.getGateFee(10000), 1600);
    }


    function test_getReferFee() public pure {
        uint256 a_min = 1 * 2 ** 239;
        uint256 a_mid = 15 * 2 ** 239;
        uint256 a_max = 31 * 2 ** 239;
        assertEq(a_min.getReferFee(10000), 100);
        assertEq(a_mid.getReferFee(10000), 1500);
        assertEq(a_max.getReferFee(10000), 3100);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getReferFee(10000), 800);
        assertEq(cc.getReferFee(10000), 800);
    }

    function test_getCustomerFee() public pure {
        uint256 a_min = 1 * 2 ** 234;
        uint256 a_mid = 15 * 2 ** 234;
        uint256 a_max = 31 * 2 ** 234;
        assertEq(a_min.getCustomerFee(10000), 100);
        assertEq(a_mid.getCustomerFee(10000), 1500);
        assertEq(a_max.getCustomerFee(10000), 3100);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getCustomerFee(10000), 800);
        assertEq(cc.getCustomerFee(10000), 800);
    }


    function test_getPlatformFee128() public pure {
        uint256 a_min = 1 * 2 ** 229;
        uint256 a_mid = 15 * 2 ** 229;
        uint256 a_max = 31 * 2 ** 229;
        assertEq(a_min.getPlatformFee128(10000), 100);
        assertEq(a_mid.getPlatformFee128(10000), 1500);
        assertEq(a_max.getPlatformFee128(10000), 3100);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getPlatformFee128(10000), 200);
        assertEq(cc.getPlatformFee128(10000), 200);
    }

        function test_getPlatformFee256() public pure {
        uint256 a_min = 1 * 2 ** 229;
        uint256 a_mid = 15 * 2 ** 229;
        uint256 a_max = 31 * 2 ** 229;
        assertEq(a_min.getPlatformFee256(10000), 100);
        assertEq(a_mid.getPlatformFee256(10000), 1500);
        assertEq(a_max.getPlatformFee256(10000), 3100);
        uint256 bb=92676354<<229;
        uint256 cc=25567490<<229;
        assertEq(bb.getPlatformFee256(10000), 200);
        assertEq(cc.getPlatformFee256(10000), 200);
    }

    function test_getLimitPower() public pure {
        uint256 a_min = 1 * 2 ** 223;
        uint256 a_mid = 15 * 2 ** 223;
        uint256 a_max = 63 * 2 ** 223;
        assertEq(a_min.getLimitPower(), 1);
        assertEq(a_mid.getLimitPower(), 15);
        assertEq(a_max.getLimitPower(), 63);
    }

    function test_checkout()public pure {
        uint aa =92709122<<229;
        assertEq(aa.checkGoodConfig(), true);
        aa =25600258<<229;
        assertEq(aa.checkGoodConfig(), true);
        aa =25600257<<229;
        assertEq(aa.checkGoodConfig(), false);
    }

    function test_getInvestFee() public pure {
        uint256 a_min = 1 * 2 ** 217;
        uint256 a_mid = 32 * 2 ** 217;
        uint256 a_max = 63 * 2 ** 217;
        // assertEq(a_min.getInvestFee(), 1);
        // assertEq(a_mid.getInvestFee(), 32);
        // assertEq(a_max.getInvestFee(), 63);
        assertEq(a_min.getInvestFee(10000), 1);
        assertEq(a_mid.getInvestFee(10000), 32);
        assertEq(a_max.getInvestFee(10000), 63);
    }

    function test_getDisinvestFee() public pure {
        uint256 a_min = 2 ** 211;
        uint256 a_mid = 32 * 2 ** 211;
        uint256 a_max = 63 * 2 ** 211;
        // assertEq(a_min.getDisinvestFee(), 1);
        // assertEq(a_mid.getDisinvestFee(), 32);
        // assertEq(a_max.getDisinvestFee(), 63);
        assertEq(a_min.getDisinvestFee(10000), 1);
        assertEq(a_mid.getDisinvestFee(10000), 32);
        assertEq(a_max.getDisinvestFee(10000), 63);
    }

    function test_getBuyFee() public pure {
        uint256 a_min = 1 * 2 ** 204;
        uint256 a_mid = 64 * 2 ** 204;
        uint256 a_max = 127 * 2 ** 204;
        // assertEq(a_min.getBuyFee(), 1);
        // assertEq(a_mid.getBuyFee(), 64);
        // assertEq(a_max.getBuyFee(), 127);
        assertEq(a_min.getBuyFee(10000), 1);
        assertEq(a_mid.getBuyFee(10000), 64);
        assertEq(a_max.getBuyFee(10000), 127);
    }

    function test_getSellFee() public pure {
        uint256 a_min = 1 * 2 ** 197;
        uint256 a_mid = 64 * 2 ** 197;
        uint256 a_max = 127 * 2 ** 197;
        // assertEq(a_min.getSellFee(), 1);
        // assertEq(a_mid.getSellFee(), 64);
        // assertEq(a_max.getSellFee(), 127);
        assertEq(a_min.getSellFee(10000), 1);
        assertEq(a_mid.getSellFee(10000), 64);
        assertEq(a_max.getSellFee(10000), 127);
    }

    function test_getPower() public pure {
        uint256 a_min = 1 * 2 ** 187;
        uint256 a_mid = 15 * 2 ** 187;
        uint256 a_max = 63 * 2 ** 187;
        uint256 a_max2 = 127 * 2 ** 187;
        assertEq(a_min.getPower(), 1);
        assertEq(a_mid.getPower(), 15);
        assertEq(a_max.getPower(), 63);
        assertEq(a_max2.getPower(), 63);
    }

    function test_getDisinvestChips() public pure {
        uint256 a_min = 1 * 2 ** 177;
        uint256 a_mid = 2 * 2 ** 177;
        uint256 a_max = 1023 * 2 ** 177;
        // assertEq(a_min.getDisinvestChips(), 1);
        // assertEq(a_mid.getDisinvestChips(), 2);
        // assertEq(a_max.getDisinvestChips(), 1023);
        assertEq(a_min.getDisinvestChips(10000), 10000);
        assertEq(a_mid.getDisinvestChips(10000), 5000);
        assertEq(a_max.getDisinvestChips(10000), 9);
    }

}
