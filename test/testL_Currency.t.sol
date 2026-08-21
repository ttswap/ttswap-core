// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Permit2} from "permit2/src/Permit2.sol";
import {CurrencyHarness} from "../src/test/CurrencyHarness.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {L_CurrencyLibrary, dai, _permit2} from "../src/libraries/L_Currency.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {TTSwapUINT256ToUint128Overflow} from "../src/libraries/L_TTSwapUINT256.sol";

contract DaiPermitToken {
    bytes32 public constant PERMIT_TYPEHASH =
        0xea2aa0a1be11a07ed86d443cc6239f7997d1ba1628e2a7273ee94a9cd2bf3b8f;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Dai Stablecoin")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(expiry == 0 || block.timestamp <= expiry, "expired");
        require(nonce == nonces[holder]++, "nonce");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(PERMIT_TYPEHASH, holder, spender, nonce, expiry, allowed)
                )
            )
        );
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == holder, "sig");
        allowance[holder][spender] = allowed ? type(uint256).max : 0;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract FalseReturnToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}

contract RejectEth {
    receive() external payable {
        revert();
    }
}

/// @notice L_Currency direct tests (TASK-P3-006) plus transfer-type / failure edges.
contract testL_Currency is Test {
    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
    bytes32 internal constant PERMIT_DETAILS_TYPEHASH = keccak256(
        "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );
    bytes32 internal constant PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    uint256 internal constant SIGNER_KEY = 0xA11CE;

    CurrencyHarness internal harness;
    MyToken internal usdt;
    address internal user1;
    address internal user2;
    address internal user3;
    bytes internal defaultdata;

    function setUp() public {
        usdt = new MyToken("USDT", "USDT", 6);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        defaultdata = bytes("");
        harness = new CurrencyHarness();
        vm.etch(_permit2, address(new Permit2()).code);
        vm.warp(10);
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

    function _encodeType(uint8 transferType, bytes memory sigdata)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(L_CurrencyLibrary.S_transferData(transferType, sigdata));
    }

    function _signPermit2Single(
        address token,
        address spender,
        uint160 amount,
        uint256 deadline,
        uint256 signerKey
    ) internal view returns (L_CurrencyLibrary.S_Permit2 memory permit) {
        IAllowanceTransfer.PermitSingle memory single = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token,
                amount: amount,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: spender,
            sigDeadline: deadline
        });
        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_DETAILS_TYPEHASH,
                single.details.token,
                single.details.amount,
                single.details.expiration,
                single.details.nonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                Permit2(_permit2).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_SINGLE_TYPEHASH,
                        permitHash,
                        single.spender,
                        single.sigDeadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        return L_CurrencyLibrary.S_Permit2(amount, deadline, 0, v, r, s);
    }

    function _signPermit2Transfer(
        address token,
        address spender,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 signerKey
    ) internal view returns (L_CurrencyLibrary.S_Permit2 memory permit) {
        bytes32 tokenPermissions = keccak256(
            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, amount)
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                Permit2(_permit2).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH,
                        tokenPermissions,
                        spender,
                        nonce,
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        return L_CurrencyLibrary.S_Permit2(amount, deadline, nonce, v, r, s);
    }

    function testL_Currency_balanceof_erc20AndNative() public {
        deal(address(usdt), user1, 5000, false);
        vm.deal(user1, 2 ether);
        assertEq(harness.balanceOf(address(usdt), user1), 5000, "erc20");
        assertEq(harness.balanceOf(address(1), user1), 2 ether, "native");
    }

    function testL_Currency_isNative() public view {
        assertTrue(harness.isNative(address(1)));
        assertFalse(harness.isNative(address(usdt)));
    }

    function testL_Currency_pullErc20_happyPath() public {
        deal(address(usdt), user1, 1000, false);
        vm.startPrank(user1);
        usdt.approve(address(harness), 1000);
        harness.pullErc20(address(usdt), user1, 600, defaultdata);
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(harness)), 600, "received");
    }

    function testL_Currency_pullErc20To_explicitRecipient() public {
        deal(address(usdt), user1, 1000, false);
        vm.startPrank(user1);
        usdt.approve(address(harness), 400);
        harness.pullErc20To(address(usdt), user1, user3, user1, 400, defaultdata);
        vm.stopPrank();
        assertEq(usdt.balanceOf(user3), 400, "explicit to");
    }

    function testL_Currency_pullErc20_revert_executorMismatch() public {
        deal(address(usdt), user1, 1000, false);
        vm.prank(user1);
        usdt.approve(address(harness), 1000);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullErc20Executor(address(usdt), user1, user2, 100, defaultdata);
    }

    function testL_Currency_pullErc20_revert_insufficientAllowance() public {
        deal(address(usdt), user1, 1000, false);
        vm.prank(user1);
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        harness.pullErc20(address(usdt), user1, 100, defaultdata);
    }

    function testL_Currency_pushErc20_happyPath() public {
        deal(address(usdt), address(harness), 500, false);
        harness.pushErc20(address(usdt), user3, 300);
        assertEq(usdt.balanceOf(user3), 300, "recipient");
    }

    function testL_Currency_pushErc20_revert_falseReturn() public {
        FalseReturnToken token = new FalseReturnToken();
        token.mint(address(harness), 100);
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        harness.pushErc20(address(token), user3, 50);
    }

    function testL_Currency_pushErc20_revert_noCode() public {
        vm.expectRevert(L_CurrencyLibrary.ERC20TransferFailed.selector);
        harness.pushErc20(address(0xBEEF), user3, 1);
    }

    function testL_Currency_pushNative_happyPath() public {
        vm.deal(address(harness), 1 ether);
        harness.seedNative{value: 1 ether}(1 ether);
        harness.pushNative(user3, 0.4 ether);
        assertEq(user3.balance, 0.4 ether, "native recipient");
    }

    function testL_Currency_pushNative_revert_rejected() public {
        RejectEth sink = new RejectEth();
        vm.deal(address(harness), 1 ether);
        vm.expectRevert(L_CurrencyLibrary.NativeETHTransferFailed.selector);
        harness.pushNative(address(sink), 0.1 ether);
    }

    function testL_Currency_pullNative_happyPath() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        harness.pullNative{value: 0.5 ether}(user1, 0.5 ether, defaultdata);
        assertEq(address(harness).balance, 0.5 ether, "native pulled");
    }

    function testL_Currency_pullNative_revert_executorMismatch() public {
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullNative{value: 0.1 ether}(user1, 0.1 ether, defaultdata);
    }

    function testL_Currency_pullErc20_eip2612Permit() public {
        address owner = vm.addr(SIGNER_KEY);
        deal(address(usdt), owner, 2000, false);
        bytes memory detail = _encodePermit(800);
        harness.pullErc20(address(usdt), owner, 800, detail);
        assertEq(usdt.balanceOf(address(harness)), 800, "permit pull");
    }

    function testL_Currency_pullErc20_daiPermit() public {
        DaiPermitToken impl = new DaiPermitToken();
        vm.etch(dai, address(impl).code);
        address owner = vm.addr(SIGNER_KEY);
        DaiPermitToken(dai).mint(owner, 2_000);
        uint256 deadline = block.timestamp + 10_000;
        uint256 nonce = DaiPermitToken(dai).nonces(owner);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DaiPermitToken(dai).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        DaiPermitToken(dai).PERMIT_TYPEHASH(),
                        owner,
                        address(harness),
                        nonce,
                        deadline,
                        true
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        bytes memory detail = _encodeType(
            2,
            abi.encode(L_CurrencyLibrary.S_Permit(2_000, deadline, v, r, s))
        );
        harness.pullErc20(dai, owner, 800, detail);
        assertEq(DaiPermitToken(dai).balanceOf(address(harness)), 800, "dai permit");
    }

    function testL_Currency_pullErc20_permit2Allowance() public {
        deal(address(usdt), user1, 1_000, false);
        vm.startPrank(user1);
        usdt.approve(_permit2, type(uint256).max);
        Permit2(_permit2).approve(
            address(usdt),
            address(harness),
            600,
            uint48(block.timestamp + 100_000)
        );
        harness.pullErc20(address(usdt), user1, 600, _encodeType(3, bytes("")));
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(harness)), 600, "p2 allowance");
    }

    function testL_Currency_pullErc20_permit2PermitSingle() public {
        address owner = vm.addr(SIGNER_KEY);
        deal(address(usdt), owner, 2_000, false);
        vm.prank(owner);
        usdt.approve(_permit2, type(uint256).max);
        L_CurrencyLibrary.S_Permit2 memory permit = _signPermit2Single(
            address(usdt),
            address(harness),
            900,
            block.timestamp + 100_000,
            SIGNER_KEY
        );
        harness.pullErc20(address(usdt), owner, 900, _encodeType(4, abi.encode(permit)));
        assertEq(usdt.balanceOf(address(harness)), 900, "p2 permit");
    }

    function testL_Currency_pullErc20_permit2SignatureTransfer() public {
        address owner = vm.addr(SIGNER_KEY);
        deal(address(usdt), owner, 2_000, false);
        vm.prank(owner);
        usdt.approve(_permit2, type(uint256).max);
        L_CurrencyLibrary.S_Permit2 memory permit = _signPermit2Transfer(
            address(usdt),
            address(harness),
            700,
            0,
            block.timestamp + 100_000,
            SIGNER_KEY
        );
        harness.pullErc20(address(usdt), owner, 700, _encodeType(5, abi.encode(permit)));
        assertEq(usdt.balanceOf(address(harness)), 700, "p2 sig transfer");
    }

    function testL_Currency_toUint160_happyAndOverflow() public view {
        assertEq(harness.toUint160(123), 123);
    }

    function testL_Currency_toUint160_revert_overflow() public {
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 52));
        harness.toUint160(uint256(type(uint160).max) + 1);
    }

    function testL_Currency_pullErc20_revert_unsupportedTransferType() public {
        deal(address(usdt), user1, 100, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(9, bytes(""))
        );
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 42));
        harness.pullErc20(address(usdt), user1, 50, detail);
    }

    function testL_Currency_pullErc20_revert_permit2ExecutorMismatch() public {
        deal(address(usdt), user1, 1000, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(3, bytes(""))
        );
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        harness.pullErc20Executor(address(usdt), user1, user2, 100, detail);
    }

    function testL_Currency_pullErc20_revert_amountExceedsUint128() public {
        deal(address(usdt), user1, 1, false);
        bytes memory detail = abi.encode(
            L_CurrencyLibrary.S_transferData(3, bytes(""))
        );
        uint256 huge = uint256(type(uint128).max) + 1;
        vm.expectRevert(TTSwapUINT256ToUint128Overflow.selector);
        harness.pullErc20(address(usdt), user1, huge, detail);
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
