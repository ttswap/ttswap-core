// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
/// @dev Exposes `T_GoodKey.transferFrom` for edge-case testing.
contract GoodKeyHarness {
    using T_GoodKeyLibrary for T_GoodKey;

    function transfer(
        T_GoodKey memory key,
        address from,
        address executor,
        uint128 amount,
        bytes calldata data
    ) external payable {
        key.transferFrom(from, executor, amount, data);
    }

    function balanceOf(T_GoodKey memory key, address who) external view returns (uint256) {
        return key.balanceof(who);
    }

    function toId(T_GoodKey memory key) external pure returns (uint256) {
        return key.toId();
    }
}

/// @notice T_GoodKey transfer edge cases (TASK-P2-010).
contract testGoodKeyTransfer is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;

    GoodKeyHarness internal harness;

    function setUp() public override {
        BaseSetup.setUp();
        harness = new GoodKeyHarness();
    }

    function testGoodKey_balanceof_erc20() public {
        deal(address(usdt), users[1], 1_000_000, false);
        uint256 bal = harness.balanceOf(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            users[1]
        );
        assertEq(bal, 1_000_000, "erc20 balance");
    }

    function testGoodKey_balanceof_native() public {
        vm.deal(users[1], 5 ether);
        uint256 bal = harness.balanceOf(
            T_GoodKey({ercType: 1, contractAddress: address(1), id: 0}),
            users[1]
        );
        assertEq(bal, 5 ether, "native balance");
    }

    function testGoodKey_transfer_revert_unsupportedErcType() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 2,
            contractAddress: address(usdt),
            id: 1
        });
        vm.expectRevert(T_GoodKeyLibrary.UnsupportedTransferType.selector);
        harness.transfer(key, users[1], users[1], 100, "");
    }

    function testGoodKey_transfer_revert_nativeExecutorMismatch() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(1),
            id: 0
        });
        vm.deal(users[1], 1 ether);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.transfer{value: 1 ether}(key, users[1], users[2], 1 ether, "");
    }

    function testGoodKey_transfer_revert_erc20ExecutorMismatch() public {
        deal(address(usdt), users[1], 1000, false);
        vm.prank(users[1]);
        usdt.approve(address(harness), 1000);

        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.transfer(key, users[1], users[2], 100, "");
    }

    function testGoodKey_toId_revert_unsupportedErcType() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 3,
            contractAddress: address(usdt),
            id: 1
        });
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 42));
        harness.toId(key);
    }
}
