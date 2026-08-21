// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_Transient} from "../src/libraries/L_Transient.sol";
import {MyToken} from "../src/test/MyToken.sol";

/// @dev Exposes `T_GoodKey` for edge-case testing.
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

    function pullNative(
        T_GoodKey memory key,
        address from,
        uint128 amount,
        bytes calldata data
    ) external payable {
        L_Transient.increaseValue(msg.value);
        key.transferFrom(from, msg.sender, amount, data);
    }

    function push(
        T_GoodKey memory key,
        address to,
        uint256 amount,
        uint256 limitamount
    ) external {
        key.safeTransfer(to, amount, limitamount);
    }

    function balanceOf(T_GoodKey memory key, address who) external view returns (uint256) {
        return key.balanceof(who);
    }

    function toId(T_GoodKey memory key) external pure returns (uint256) {
        return key.toId();
    }

    function composedata(T_GoodKey memory key) external pure returns (uint256) {
        return key.composedata();
    }

    function isNative(T_GoodKey memory key) external pure returns (bool) {
        return key.isNative();
    }

    function toUint160(uint256 amount) external pure returns (uint160) {
        return T_GoodKeyLibrary.to_uint160(amount);
    }
}

/// @notice T_GoodKey transfer edge cases (TASK-P2-010).
contract testGoodKeyTransfer is Test {
    using T_GoodKeyLibrary for T_GoodKey;

    GoodKeyHarness internal harness;
    MyToken internal usdt;
    address internal user1;
    address internal user2;

    function setUp() public {
        usdt = new MyToken("USDT", "USDT", 6);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        harness = new GoodKeyHarness();
    }

    function _erc20Key() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function testGoodKey_balanceof_erc20() public {
        deal(address(usdt), user1, 1_000_000, false);
        uint256 bal = harness.balanceOf(_erc20Key(), user1);
        assertEq(bal, 1_000_000, "erc20 balance");
    }

    function testGoodKey_balanceof_native() public {
        vm.deal(user1, 5 ether);
        uint256 bal = harness.balanceOf(_nativeKey(), user1);
        assertEq(bal, 5 ether, "native balance");
    }

    function testGoodKey_balanceof_revert_unsupportedErcType() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 2,
            contractAddress: address(usdt),
            id: 1
        });
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 42));
        harness.balanceOf(key, user1);
    }

    function testGoodKey_toId_nativeAndErc20() public view {
        assertEq(harness.toId(_nativeKey()), uint256(uint160(address(1))));
        assertEq(harness.toId(_erc20Key()), uint256(uint160(address(usdt))));
        assertTrue(harness.isNative(_nativeKey()));
        assertFalse(harness.isNative(_erc20Key()));
        assertEq(
            harness.composedata(_erc20Key()),
            uint256(uint160(address(usdt))) + (uint256(1) << 160)
        );
    }

    function testGoodKey_transfer_erc20HappyPath() public {
        deal(address(usdt), user1, 1000, false);
        vm.startPrank(user1);
        usdt.approve(address(harness), 400);
        harness.transfer(_erc20Key(), user1, user1, 400, "");
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(harness)), 400);
    }

    function testGoodKey_transfer_nativeHappyPath() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        harness.pullNative{value: 0.5 ether}(_nativeKey(), user1, 0.4 ether, "");
        assertEq(address(harness).balance, 0.5 ether);
    }

    function testGoodKey_push_erc20HappyPath() public {
        deal(address(usdt), address(harness), 500, false);
        harness.push(_erc20Key(), user2, 200, 0);
        assertEq(usdt.balanceOf(user2), 200);
    }

    function testGoodKey_push_revert_safeLine() public {
        deal(address(usdt), address(harness), 100, false);
        vm.expectRevert(T_GoodKeyLibrary.SafelineLowerTransferFailed.selector);
        harness.push(_erc20Key(), user2, 80, 50);
    }

    function testGoodKey_push_nativeHappyPath() public {
        vm.deal(address(harness), 1 ether);
        harness.push(_nativeKey(), user2, 0.3 ether, 0);
        assertEq(user2.balance, 0.3 ether);
    }

    function testGoodKey_toUint160_revert_overflow() public {
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 52));
        harness.toUint160(uint256(type(uint160).max) + 1);
    }

    function testGoodKey_transfer_revert_unsupportedErcType() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 2,
            contractAddress: address(usdt),
            id: 1
        });
        vm.expectRevert(T_GoodKeyLibrary.UnsupportedTransferType.selector);
        harness.transfer(key, user1, user1, 100, "");
    }

    function testGoodKey_transfer_revert_nativeExecutorMismatch() public {
        vm.deal(user1, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.transfer{value: 1 ether}(_nativeKey(), user1, user2, 1 ether, "");
    }

    function testGoodKey_transfer_revert_erc20ExecutorMismatch() public {
        deal(address(usdt), user1, 1000, false);
        vm.prank(user1);
        usdt.approve(address(harness), 1000);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.transfer(_erc20Key(), user1, user2, 100, "");
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
