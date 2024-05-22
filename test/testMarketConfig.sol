// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-gas-snapshot/GasSnapshot.sol";
import "forge-std/Test.sol";
import {L_MarketConfigLibrary} from "../Contracts/libraries/L_MarketConfig.sol";

contract testMarketConfig is Test, GasSnapshot {
    using L_MarketConfigLibrary for uint256;

    uint256 marketconfig;

    function setUp() public {}

    function test_getLiquidFee() public {
        uint256 a_min = 1 * 2 ** 250;
        uint256 a_mid = 1 * 2 ** 255;
        uint256 a_max = 63 * 2 ** 250;
        snapStart("marketconfig get liquid");
        assertEq(a_min.getLiquidFee(), 1);
        snapEnd();
        assertEq(a_mid.getLiquidFee(), 32);
        assertEq(a_max.getLiquidFee(), 63);
        snapStart("marketconfig compute liquid fee");
        assertEq(a_min.getLiquidFee(100), 1);
        snapEnd();
        assertEq(a_mid.getLiquidFee(100), 32);
        assertEq(a_max.getLiquidFee(100), 63);
    }

    function test_getSellerFee() public {
        uint256 a_min = 1 * 2 ** 244;
        uint256 a_mid = 1 * 2 ** 249;
        uint256 a_max = 63 * 2 ** 244;
        assertEq(a_min.getSellerFee(), 1);
        assertEq(a_mid.getSellerFee(), 32);
        assertEq(a_max.getSellerFee(), 63);
        assertEq(a_min.getSellerFee(100), 1);
        assertEq(a_mid.getSellerFee(100), 32);
        assertEq(a_max.getSellerFee(100), 63);
    }

    function test_getGaterFee() public {
        uint256 a_min = 1 * 2 ** 238;
        uint256 a_mid = 1 * 2 ** 243;
        uint256 a_max = 63 * 2 ** 238;
        assertEq(a_min.getGaterFee(), 1);
        assertEq(a_mid.getGaterFee(), 32);
        assertEq(a_max.getGaterFee(), 63);
        assertEq(a_min.getGaterFee(100), 1);
        assertEq(a_mid.getGaterFee(100), 32);
        assertEq(a_max.getGaterFee(100), 63);
    }

    function test_getReferFee() public {
        uint256 a_min = 1 * 2 ** 232;
        uint256 a_mid = 1 * 2 ** 237;
        uint256 a_max = 63 * 2 ** 232;
        assertEq(a_min.getReferFee(), 1);
        assertEq(a_mid.getReferFee(), 32);
        assertEq(a_max.getReferFee(), 63);
        assertEq(a_min.getReferFee(100), 1);
        assertEq(a_mid.getReferFee(100), 32);
        assertEq(a_max.getReferFee(100), 63);
    }

    function test_getCustomerFee() public {
        uint256 a_min = 1 * 2 ** 226;
        uint256 a_mid = 1 * 2 ** 231;
        uint256 a_max = 63 * 2 ** 226;
        assertEq(a_min.getCustomerFee(), 1);
        assertEq(a_mid.getCustomerFee(), 32);
        assertEq(a_max.getCustomerFee(), 63);
        assertEq(a_min.getCustomerFee(100), 1);
        assertEq(a_mid.getCustomerFee(100), 32);
        assertEq(a_max.getCustomerFee(100), 63);
    }

    function test_checkAllocate() public {
        uint256 a = 50 * 2 ** 250;
        a += 25 * 2 ** 244;
        a += 15 * 2 ** 238;
        a += 5 * 2 ** 232;
        a += 5 * 2 ** 226;
        assertEq(a.checkAllocate(), true);

        a = 51 * 2 ** 250;
        a += 25 * 2 ** 244;
        a += 15 * 2 ** 238;
        a += 5 * 2 ** 232;
        a += 5 * 2 ** 226;
        assertEq(a.checkAllocate(), false);
    }

    function test_getPlatFee() public {
        uint256 a_min = 1 * 2 ** 221;
        uint256 a_mid = 1 * 2 ** 225;
        uint256 a_max = 31 * 2 ** 221;
        uint256 bb = 100;
        assertEq(a_min.getPlatFee(), 1);
        assertEq(a_mid.getPlatFee(), 16);
        assertEq(a_max.getPlatFee(), 31);
        assertEq(a_min.getPlatFee256(bb), 1);
        assertEq(a_mid.getPlatFee256(bb), 16);
        assertEq(a_max.getPlatFee256(bb), 31);
    }
}
