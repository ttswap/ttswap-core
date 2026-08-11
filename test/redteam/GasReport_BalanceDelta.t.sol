// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {MyToken} from "../../src/test/MyToken.sol";

/// @dev Isolated A/B via forge --gas-report.
contract GasReport_BalanceDelta is Test {
    MyToken internal t;
    address internal a = address(0xA11CE);
    uint256 internal constant AMT = 100e18;

    function setUp() public {
        t = new MyToken("T", "T", 18);
        deal(address(t), a, 1_000_000e18, true);
        vm.prank(a);
        t.approve(address(this), type(uint256).max);

        // Warm: token code, allowance, both balance slots.
        t.transferFrom(a, address(this), 1e18);
        t.balanceOf(address(this));
        t.balanceOf(a);
    }

    function test_gas_A_transferFrom_plain() public {
        t.transferFrom(a, address(this), AMT);
    }

    function test_gas_B_transferFrom_with_delta() public {
        uint256 before_ = t.balanceOf(address(this));
        t.transferFrom(a, address(this), AMT);
        uint256 after_ = t.balanceOf(address(this));
        require(after_ - before_ >= AMT, "delta");
    }
}
