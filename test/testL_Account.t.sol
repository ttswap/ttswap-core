// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_Account} from "../src/libraries/L_Account.sol";

contract AccountHarness {
    function getGoodNumber(uint256 goodId) external view returns (bytes32) {
        return L_Account.getGoodNumber(goodId);
    }

    function setAddBalance(uint256 goodId) external {
        L_Account.setAddBalance(goodId);
    }
}

contract testL_Account is Test {
    AccountHarness internal h;

    function setUp() public {
        h = new AccountHarness();
    }

    function testL_Account_getGoodNumber() public view {
        assertEq(h.getGoodNumber(1), bytes32(uint256(keccak256(abi.encode(uint256(1))))));
        assertTrue(h.getGoodNumber(1) != h.getGoodNumber(2));
    }

    function testL_Account_setAddBalance_noop() public {
        h.setAddBalance(1);
    }
}
