// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Permit2} from "permit2/src/Permit2.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice v2.0 `initGood` with plain approve / EIP-2612 / Permit2 transfer paths.
contract testPermitInitGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    address internal constant PERMIT2 =
        0xa50eb0d081E986c280efF32dae089939Ea07bd22;

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 internal constant PERMIT_DETAILS_TYPEHASH =
        keccak256(
            "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
    bytes32 internal constant PERMIT_SINGLE_TYPEHASH =
        keccak256(
            "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

    uint256 internal constant INITIAL_CONFIG = TestConfigConstants.INITIAL_GOOD_CONFIG;

    uint256 internal constant CREATOR_KEY = 0xA121;
    uint256 internal constant OWNER_KEY = 0xA11CE;
    uint256 internal constant SPENDER_KEY = 0xB0B;

    uint128 internal constant INIT_VALUE = uint128(50_000 * 10 ** 12);
    uint128 internal constant INIT_QTY = uint128(50_000 * 10 ** 6);

    MyToken internal permitToken;
    Permit2 internal permit2Logic;

    uint256 internal creatorKey;
    address internal keyedCreator;
    address internal permitOwner;
    address internal permitSpender;

    function setUp() public override {
        creatorKey = CREATOR_KEY;
        keyedCreator = vm.addr(creatorKey);
        permitOwner = vm.addr(OWNER_KEY);
        permitSpender = vm.addr(SPENDER_KEY);

        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        marketcreator = payable(keyedCreator);

        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);
        permitToken = new MyToken("PTK", "PTK", 6);

        vm.startPrank(keyedCreator);
        TTSwap_Token tts_logic = new TTSwap_Token(address(usdt));
        tts_token_proxy = new TTSwap_Token_Proxy(
            keyedCreator,
            2 ** 255 + 10000,
            "TTSwap Token",
            "TTS",
            address(tts_logic)
        );
        tts_token = TTSwap_Token(payable(address(tts_token_proxy)));
        market = new TTSwap_Market(tts_token);
        market_proxy = new TTSwap_Market_Proxy(tts_token, address(market));
        market = TTSwap_Market(payable(address(market_proxy)));

        tts_token.setTokenAdmin(keyedCreator, true);
        tts_token.setTokenManager(keyedCreator, true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(keyedCreator, true);
        tts_token.setMarketManager(keyedCreator, true);
        tts_token.setStakeAdmin(keyedCreator, true);
        tts_token.setStakeManager(keyedCreator, true);
        vm.stopPrank();

        permit2Logic = new Permit2();
        vm.etch(PERMIT2, address(permit2Logic).code);
        vm.warp(10);
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _expectedGoodConfig() internal pure returns (uint256) {
        return TestConfigConstants.INITIAL_GOOD_CONFIG;
    }

    function _tokenKey(address token) internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: token, id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    function _encodeTransfer(
        uint8 transferType,
        bytes memory sigdata
    ) internal pure returns (bytes memory) {
        return abi.encode(T_GoodKeyLibrary.S_transferData(transferType, sigdata));
    }

    function _assertInitGoodState(
        uint256 goodId,
        address owner,
        bool isNative,
        address token,
        uint128 qty
    ) internal view {
        if (isNative) {
            assertEq(address(market).balance, qty, "market native balance");
        } else {
            assertEq(
                IERC20(token).balanceOf(address(market)),
                qty,
                "market token balance"
            );
        }

        S_GoodTmpState memory good_ = market.getGoodState(goodId);
        assertEq(good_.currentState, toTTSwapUINT256(qty, qty), "currentState");
        assertEq(good_.investState, toTTSwapUINT256(qty, INIT_VALUE), "investState");
        assertEq(good_.goodConfig, _expectedGoodConfig(), "goodConfig");
        assertEq(good_.owner, owner, "owner");

        uint256 proofId = _proofId(owner, goodId);
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, goodId, "proof good");
        assertEq(proof.state, toTTSwapUINT256(INIT_VALUE, INIT_VALUE), "proof state");
        assertEq(proof.shares, toTTSwapUINT256(qty, 0), "proof shares");
        assertEq(proof.invest, toTTSwapUINT256(qty, qty), "proof invest");
    }

    function _signEip2612(
        MyToken token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 signerKey
    ) internal view returns (T_GoodKeyLibrary.S_Permit memory permit) {
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                token.nonces(owner),
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(
            token.DOMAIN_SEPARATOR(),
            structHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        return T_GoodKeyLibrary.S_Permit(value, deadline, v, r, s);
    }

    function _signPermit2Single(
        address token,
        address,
        address spender,
        uint160 amount,
        uint256 deadline,
        uint256 signerKey
    ) internal view returns (T_GoodKeyLibrary.S_Permit2 memory permit) {
        IAllowanceTransfer.PermitSingle memory single = IAllowanceTransfer
            .PermitSingle({
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
                Permit2(PERMIT2).DOMAIN_SEPARATOR(),
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
        return T_GoodKeyLibrary.S_Permit2(amount, deadline, 0, v, r, s);
    }

    function _signPermit2Transfer(
        address token,
        address,
        address spender,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 signerKey
    ) internal view returns (T_GoodKeyLibrary.S_Permit2 memory permit) {
        bytes32 tokenPermissions = keccak256(
            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, amount)
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                Permit2(PERMIT2).DOMAIN_SEPARATOR(),
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
        return T_GoodKeyLibrary.S_Permit2(amount, deadline, nonce, v, r, s);
    }

    // ── baseline init paths ────────────────────────────────────────────────

    function testInitGood_erc20Approve() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);
        permitToken.approve(address(market), INIT_QTY);

        T_GoodKey memory key = _tokenKey(address(permitToken));
        market.initGood(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            defaultdata,
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_erc20_approve");
        _assertInitGoodState(key.toId(), keyedCreator, false, address(permitToken), INIT_QTY);
        vm.stopPrank();
    }

    function testInitGood_nativeMsgValue() public {
        vm.startPrank(keyedCreator);
        vm.deal(keyedCreator, 100 * INIT_QTY);

        T_GoodKey memory key = _nativeKey();
        market.initGood{value: INIT_QTY}(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            defaultdata,
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_native_msgvalue");
        _assertInitGoodState(key.toId(), keyedCreator, true, address(0), INIT_QTY);
        vm.stopPrank();
    }

    // ── EIP-2612 ───────────────────────────────────────────────────────────

    function testErc20Permit_standalone() public {
        deal(address(permitToken), permitOwner, 100_000, false);
        uint256 deadline = block.timestamp + 1 days;

        T_GoodKeyLibrary.S_Permit memory permit = _signEip2612(
            permitToken,
            permitOwner,
            permitSpender,
            1024,
            deadline,
            OWNER_KEY
        );

        vm.startPrank(permitSpender);
        permitToken.permit(
            permitOwner,
            permitSpender,
            permit.value,
            permit.deadline,
            permit.v,
            permit.r,
            permit.s
        );
        assertEq(permitToken.allowance(permitOwner, permitSpender), 1024);
        permitToken.transferFrom(permitOwner, users[2], 1000);
        assertEq(permitToken.balanceOf(users[2]), 1000);
        vm.stopPrank();
    }

    function testInitGood_eip2612Permit() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);

        T_GoodKeyLibrary.S_Permit memory permit = _signEip2612(
            permitToken,
            keyedCreator,
            address(market),
            INIT_QTY,
            block.timestamp + 10_000,
            creatorKey
        );

        T_GoodKey memory key = _tokenKey(address(permitToken));
        market.initGood(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            _encodeTransfer(2, abi.encode(permit)),
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_eip2612");
        _assertInitGoodState(key.toId(), keyedCreator, false, address(permitToken), INIT_QTY);
        vm.stopPrank();
    }

    // ── Permit2 allowance (type 3) ─────────────────────────────────────────

    function testPermit2_allowanceTransfer_standalone() public {
        vm.startPrank(users[3]);
        deal(address(permitToken), users[3], 100_000_000_000, false);
        permitToken.approve(PERMIT2, type(uint256).max);
        Permit2(PERMIT2).approve(
            address(permitToken),
            users[4],
            100_000_000_000,
            uint48(block.timestamp + 100_000)
        );
        vm.stopPrank();

        vm.startPrank(users[4]);
        Permit2(PERMIT2).transferFrom(
            users[3],
            users[4],
            100_000,
            address(permitToken)
        );
        assertEq(permitToken.balanceOf(users[4]), 100_000);
        vm.stopPrank();
    }

    function testInitGood_permit2Allowance() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);
        permitToken.approve(PERMIT2, INIT_QTY);
        Permit2(PERMIT2).approve(
            address(permitToken),
            address(market),
            INIT_QTY,
            uint48(block.timestamp + 100_000)
        );

        T_GoodKey memory key = _tokenKey(address(permitToken));
        market.initGood(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            _encodeTransfer(3, ""),
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_permit2_allowance");
        _assertInitGoodState(key.toId(), keyedCreator, false, address(permitToken), INIT_QTY);
        vm.stopPrank();
    }

    // ── Permit2 PermitSingle (type 4) ──────────────────────────────────────

    function testInitGood_permit2PermitSingle() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);
        permitToken.approve(PERMIT2, type(uint256).max);

        T_GoodKeyLibrary.S_Permit2 memory permit = _signPermit2Single(
            address(permitToken),
            keyedCreator,
            address(market),
            uint160(INIT_QTY),
            block.timestamp + 100_000,
            creatorKey
        );

        T_GoodKey memory key = _tokenKey(address(permitToken));
        market.initGood(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            _encodeTransfer(4, abi.encode(permit)),
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_permit2_single");
        _assertInitGoodState(key.toId(), keyedCreator, false, address(permitToken), INIT_QTY);
        vm.stopPrank();
    }

    // ── Permit2 signature transfer (type 5) ────────────────────────────────

    function testPermit2_signatureTransfer_standalone() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);
        permitToken.approve(PERMIT2, type(uint256).max);

        T_GoodKeyLibrary.S_Permit2 memory permit = _signPermit2Transfer(
            address(permitToken),
            keyedCreator,
            users[4],
            INIT_QTY,
            0,
            block.timestamp + 100_000,
            creatorKey
        );
        vm.stopPrank();

        vm.startPrank(users[4]);
        ISignatureTransfer(PERMIT2).permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: address(permitToken),
                    amount: INIT_QTY
                }),
                nonce: permit.nonce,
                deadline: permit.deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({
                to: users[4],
                requestedAmount: INIT_QTY
            }),
            keyedCreator,
            bytes.concat(permit.r, permit.s, bytes1(permit.v))
        );
        assertEq(permitToken.balanceOf(users[4]), INIT_QTY);
        vm.stopPrank();
    }

    function testInitGood_permit2SignatureTransfer() public {
        vm.startPrank(keyedCreator);
        deal(address(permitToken), keyedCreator, 100 * INIT_QTY, false);
        permitToken.approve(PERMIT2, type(uint256).max);

        T_GoodKeyLibrary.S_Permit2 memory permit = _signPermit2Transfer(
            address(permitToken),
            keyedCreator,
            address(market),
            INIT_QTY,
            0,
            block.timestamp + 10_000,
            creatorKey
        );

        T_GoodKey memory key = _tokenKey(address(permitToken));
        market.initGood(
            key,
            toTTSwapUINT256(INIT_VALUE, INIT_QTY),
            _encodeTransfer(5, abi.encode(permit)),
            keyedCreator,
            defaultdata
        );
        _snapMarket("init_good_permit2_sigtransfer");
        _assertInitGoodState(key.toId(), keyedCreator, false, address(permitToken), INIT_QTY);
        vm.stopPrank();
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}
