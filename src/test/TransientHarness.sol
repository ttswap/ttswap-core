// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {L_Transient} from "../libraries/L_Transient.sol";

/// @dev Exposes `L_Transient` for unit tests.
contract TransientHarness {
    function nested(uint256 levels) external payable {
        L_Transient.checkbefore();
        if (levels > 1) {
            this.nested{value: 0}(levels - 1);
        }
        L_Transient.checkafter();
    }

    function refundCaller() external payable {
        L_Transient.checkbefore();
        L_Transient.checkafter();
    }

    function seedValue(uint256 amount) external payable {
        L_Transient.increaseValue(amount);
    }

    function decreaseValue(uint256 amount) external {
        L_Transient.decreaseValue(amount);
    }

    function readValue() external view returns (uint256) {
        return L_Transient.getValue();
    }

    function readDepth() external view returns (uint256) {
        return L_Transient.getDepth();
    }

    function setLock(uint256 lock) external {
        L_Transient.set(lock);
    }

    function readLock() external view returns (uint256) {
        return L_Transient.get();
    }

    function setValue(uint256 amount) external {
        L_Transient.setValue(amount);
    }

    function clearDepth() external {
        L_Transient.clearDepth();
    }

    function lockRoundTrip(uint256 lock) external returns (uint256) {
        L_Transient.set(lock);
        return L_Transient.get();
    }

    function valueRoundTrip(uint256 seed, uint256 take) external returns (uint256) {
        L_Transient.setValue(seed);
        L_Transient.decreaseValue(take);
        return L_Transient.getValue();
    }
}

contract RejectEthReceiver {
    TransientHarness public harness;

    constructor(TransientHarness _harness) {
        harness = _harness;
    }

    function triggerRefund() external payable {
        harness.refundCaller{value: msg.value}();
    }

    receive() external payable {
        revert();
    }
}
