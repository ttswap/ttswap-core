// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TransientHarness, RejectEthReceiver} from "../src/test/TransientHarness.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P3-02: L_Transient ETH refund / depth branches.
contract testL_Transient is BaseSetup {
    TransientHarness internal harness;

    function setUp() public override {
        BaseSetup.setUp();
        harness = new TransientHarness();
    }

    function testTransient_nestedDepth_refundsOnceAtEnd() public {
        vm.deal(users[1], 1 ether);
        uint256 userBalBefore = users[1].balance;
        vm.prank(users[1]);
        harness.nested{value: 1 ether}(3);
        assertEq(users[1].balance, userBalBefore, "full refund after nested exit");
    }

    function testTransient_decreaseValue_revert_excess() public {
        vm.deal(address(harness), 1 ether);
        harness.seedValue{value: 0.5 ether}(0.5 ether);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 30));
        harness.decreaseValue(1 ether);
    }

    function testTransient_refundReceiverRevert() public {
        RejectEthReceiver reject = new RejectEthReceiver(harness);
        vm.deal(address(reject), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 31));
        reject.triggerRefund{value: 1 ether}();
    }
}
