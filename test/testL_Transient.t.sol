// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {TransientHarness, RejectEthReceiver} from "../src/test/TransientHarness.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P3-02: L_Transient ETH refund / depth / lock branches.
contract testL_Transient is Test {
    TransientHarness internal harness;
    address internal user1;

    function setUp() public {
        harness = new TransientHarness();
        user1 = makeAddr("user1");
    }

    function testTransient_nestedDepth_refundsOnceAtEnd() public {
        vm.deal(user1, 1 ether);
        uint256 userBalBefore = user1.balance;
        vm.prank(user1);
        harness.nested{value: 1 ether}(3);
        assertEq(user1.balance, userBalBefore, "full refund after nested exit");
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

    function testTransient_lockAndValueRoundTrip() public {
        assertEq(harness.lockRoundTrip(2), 2);
        assertEq(harness.lockRoundTrip(0), 0);
        assertEq(harness.valueRoundTrip(123, 23), 100);
        harness.clearDepth();
        assertEq(harness.readDepth(), 0);
    }

    function testTransient_nestedKeepsBudgetUntilOuterExit() public {
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        harness.nested{value: 1 ether}(2);
        assertEq(harness.readDepth(), 0);
        assertEq(harness.readValue(), 0);
    }
}
