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
