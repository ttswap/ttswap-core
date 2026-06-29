// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {CurrencyHarness} from "../src/test/CurrencyHarness.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {TTSwapUINT256ToUint128Overflow} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice L_Currency direct tests (TASK-P3-006).
contract testL_Currency is BaseSetup {
    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    uint256 internal constant SIGNER_KEY = 0xA11CE;

    CurrencyHarness internal harness;

    function setUp() public override {
        BaseSetup.setUp();
        harness = new CurrencyHarness();
    }

    function _encodePermit(uint256 amount) internal view returns (bytes memory detail) {
        address owner = vm.addr(SIGNER_KEY);
        uint256 deadline = block.timestamp + 10_000;
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                address(harness),
                amount,
                usdt.nonces(owner),
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(usdt.DOMAIN_SEPARATOR(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        L_CurrencyLibrary.S_Permit memory permit = L_CurrencyLibrary.S_Permit(
            amount,
            deadline,
            v,
            r,
            s
        );
        detail = abi.encode(
            L_CurrencyLibrary.S_transferData(2, abi.encode(permit))
        );
    }

    function testL_Currency_balanceof_erc20AndNative() public {
        deal(address(usdt), users[1], 5000, false);
        vm.deal(users[1], 2 ether);
        assertEq(harness.balanceOf(address(usdt), users[1]), 5000, "erc20");
        assertEq(harness.balanceOf(address(1), users[1]), 2 ether, "native");
    }

    function testL_Currency_pullErc20_happyPath() public {
        deal(address(usdt), users[1], 1000, false);
        vm.startPrank(users[1]);
        usdt.approve(address(harness), 1000);
        harness.pullErc20(address(usdt), users[1], 600, defaultdata);
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(harness)), 600, "received");
    }

    function testL_Currency_pullErc20_revert_executorMismatch() public {
        deal(address(usdt), users[1], 1000, false);
        vm.prank(users[1]);
        usdt.approve(address(harness), 1000);
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullErc20Executor(address(usdt), users[1], users[2], 100, defaultdata);
    }

    function testL_Currency_pullErc20_revert_insufficientAllowance() public {
        deal(address(usdt), users[1], 1000, false);
        vm.prank(users[1]);
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        harness.pullErc20(address(usdt), users[1], 100, defaultdata);
    }

    function testL_Currency_pushErc20_happyPath() public {
        deal(address(usdt), address(harness), 500, false);
        harness.pushErc20(address(usdt), users[3], 300);
        assertEq(usdt.balanceOf(users[3]), 300, "recipient");
    }

    function testL_Currency_pushNative_happyPath() public {
        vm.deal(address(harness), 1 ether);
        harness.seedNative{value: 1 ether}(1 ether);
        harness.pushNative(users[3], 0.4 ether);
        assertEq(users[3].balance, 0.4 ether, "native recipient");
    }

    function testL_Currency_pullNative_happyPath() public {
        vm.deal(users[1], 1 ether);
        vm.prank(users[1]);
        harness.pullNative{value: 0.5 ether}(users[1], 0.5 ether, defaultdata);
        assertEq(address(harness).balance, 0.5 ether, "native pulled");
    }

    function testL_Currency_pullNative_revert_executorMismatch() public {
        vm.deal(users[2], 1 ether);
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullNative{value: 0.1 ether}(users[1], 0.1 ether, defaultdata);
    }

    function testL_Currency_pullErc20_eip2612Permit() public {
        address owner = vm.addr(SIGNER_KEY);
        deal(address(usdt), owner, 2000, false);
        bytes memory detail = _encodePermit(800);
        harness.pullErc20(address(usdt), owner, 800, detail);
        assertEq(usdt.balanceOf(address(harness)), 800, "permit pull");
    }

    function testL_Currency_pullErc20_revert_unsupportedTransferType() public {
        deal(address(usdt), users[1], 100, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(9, bytes(""))
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 42));
        harness.pullErc20(address(usdt), users[1], 50, detail);
    }

    function testL_Currency_pullErc20_revert_permit2ExecutorMismatch() public {
        deal(address(usdt), users[1], 1000, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(3, bytes(""))
        );
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullErc20Executor(address(usdt), users[1], users[2], 100, detail);
    }

    function testL_Currency_pullErc20_revert_amountExceedsUint128() public {
        deal(address(usdt), users[1], 1, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(3, bytes(""))
        );
        uint256 huge = uint256(type(uint128).max) + 1;
        vm.expectRevert(TTSwapUINT256ToUint128Overflow.selector);
        harness.pullErc20(address(usdt), users[1], huge, detail);
    }

    function testL_Currency_pullErc20_revert_expiredPermit() public {
        address owner = vm.addr(SIGNER_KEY);
        deal(address(usdt), owner, 2000, false);
        uint256 deadline = block.timestamp - 1;
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                address(harness),
                800,
                usdt.nonces(owner),
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(usdt.DOMAIN_SEPARATOR(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(
                2,
                abi.encode(
                    L_CurrencyLibrary.S_Permit(800, deadline, v, r, s)
                )
            )
        );
        vm.expectRevert(L_CurrencyLibrary.ERC20PermitFailed.selector);
        harness.pullErc20(address(usdt), owner, 800, detail);
    }
}
