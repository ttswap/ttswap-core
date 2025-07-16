// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import { S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

import {Permit2} from "permit2/src/Permit2.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import "forge-gas-snapshot/src/GasSnapshot.sol";

contract testPermitInitMetaGood is Test, GasSnapshot {
    using L_ProofIdLibrary for S_ProofKey;

    using L_TTSwapUINT256Library for uint256;
    using ECDSA for bytes32;

    address metagood;

    MyToken internal kkkk;

    uint256 internal ownerPrivateKey;
    uint256 internal spenderPrivateKey;

    address internal owner;
    address internal spender;
    uint256 internal marketcreatorkey;

    bytes32 private _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    address payable[8] internal users;
    MyToken btc;
    MyToken usdt;
    MyToken eth;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Token tts_token;
    bytes internal constant defaultdata = bytes("");

    event debuggdata(bytes);

    Permit2 aabbpermit;

    function setUp() public virtual {
        marketcreatorkey = 0xA121;
        marketcreator = vm.addr(marketcreatorkey);
        aabbpermit = new Permit2();
    
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);
        vm.startPrank(marketcreator);
        TTSwap_Token tts_token_logic = new TTSwap_Token(address(usdt), marketcreator,  2 ** 255 + 10000);
        TTSwap_Token_Proxy tts_token_proxy=new TTSwap_Token_Proxy(address(usdt), marketcreator,  2 ** 255 + 10000,"TTSwap Token","TTS",address(tts_token_logic));
        tts_token=TTSwap_Token(payable(address(tts_token_proxy)));

        TTSwap_Market market2 = new TTSwap_Market();
        TTSwap_Market_Proxy market_proxy=new TTSwap_Market_Proxy(tts_token,address(market2));
        market= TTSwap_Market( payable(address(market_proxy)));

        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        kkkk = new MyToken("USDT", "USDT", 6);

        ownerPrivateKey = 0xA11CE;
        spenderPrivateKey = 0xB0B;

        owner = vm.addr(ownerPrivateKey);
        spender = vm.addr(spenderPrivateKey);
    }

    struct SimplePermit {
        uint8 transfertype;
        bytes detail;
    }

    function testinitNativeMetaGoodaddress1() public {
        vm.startPrank(marketcreator);
        address nativeCurrency = address(1);
        uint256 goodconfig = 2 ** 255;
        vm.deal(marketcreator, 100000 * 10 ** 6);
        assertEq(
            marketcreator.balance,
            100000 * 10 ** 6,
            "before initial metagood:marketcreator account initial balance error"
        );
        assertEq(usdt.balanceOf(address(market)), 0, "before initial metagood:market account initial balance error");

        market.initMetaGood{value: 50000 * 10 ** 6}(
            nativeCurrency,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            goodconfig,
            abi.encode(L_CurrencyLibrary.S_transferData(1, ""))
        );
        snapLastCall("init_nativeerc20_metagood");
        metagood = nativeCurrency;
        assertEq(
            marketcreator.balance,
            100000 * 10 ** 6 - 50000 * 10 ** 6,
            "after initial metagood:marketcreator account initial balance error"
        );
        assertEq(
            address(market).balance, 50000 * 10 ** 6, "after initial metagood:market account initial balance error"
        );

        S_GoodTmpState memory good_ = market.getGoodState(metagood);
        assertEq(
            good_.currentState,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            "after initial metagood:metagood currentState error"
        );
        assertEq(
            good_.investState,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            "after initial metagood:metagood investState error"
        );
        assertEq(good_.feeQuantityState, 0, "after initial metagood:metagood feequnitity error");

        assertEq(good_.goodConfig,79981855509707585827258856034506993808549382592029871491215273511520529547264, "after initial metagood:metagood goodConfig error");

        assertEq(good_.owner, marketcreator, "after initial metagood:metagood marketcreator error");

        uint256 metaproof = S_ProofKey(marketcreator, metagood, address(0)).toId();
        S_ProofState memory _proof1 = market.getProofState(metaproof);
        assertEq(_proof1.state.amount0(), 50000 * 10 ** 6, "after initial:proof value error");
        assertEq(_proof1.invest.amount1(), 50000 * 10 ** 6, "after initial:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 0, "after initial:proof quantity error");

        vm.stopPrank();
    }

    function testinitMetaGoodtype1() public {
        vm.startPrank(marketcreator);
        uint256 goodconfig = 2 ** 255;
        usdt.mint(marketcreator, 100000);
        usdt.approve(address(market), 50000 * 10 ** 6);

        assertEq(
            usdt.balanceOf(marketcreator),
            100000 * 10 ** 6,
            "before initial metagood:marketcreator account initial balance error"
        );
        assertEq(usdt.balanceOf(address(market)), 0, "before initial metagood:market account initial balance error");

        market.initMetaGood(address(usdt), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), goodconfig, defaultdata);
        snapLastCall("init_erc20_metagood");
        metagood = address(usdt);
        assertEq(
            usdt.balanceOf(marketcreator),
            100000 * 10 ** 6 - 50000 * 10 ** 6,
            "after initial metagood:marketcreator account initial balance error"
        );
        assertEq(
            usdt.balanceOf(address(market)),
            50000 * 10 ** 6,
            "after initial metagood:market account initial balance error"
        );

        assertEq(
            market.getGoodState(metagood).currentState,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            "after initial metagood:metagood currentState error"
        );
        assertEq(
            market.getGoodState(metagood).investState,
            toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6),
            "after initial metagood:metagood investState error"
        );
        assertEq(market.getGoodState(metagood).feeQuantityState, 0, "after initial metagood:metagood feequnitity error");

        assertEq(market.getGoodState(metagood).goodConfig, 79981855509707585827258856034506993808549382592029871491215273511520529547264, "after initial metagood:metagood goodConfig error");

        assertEq(
            market.getGoodState(metagood).owner, marketcreator, "after initial metagood:metagood marketcreator error"
        );

        uint256 metaproof = S_ProofKey(marketcreator, metagood, address(0)).toId();
        S_ProofState memory _proof1 = market.getProofState(metaproof);
        assertEq(_proof1.state.amount0(), 50000 * 10 ** 6, "after initial:proof value error");
        assertEq(_proof1.invest.amount1(), 50000 * 10 ** 6, "after initial:proof quantity error");
        assertEq(_proof1.valueinvest.amount1(), 0, "after initial:proof quantity error");

        vm.stopPrank();
    }

    function testERC20permit() public {
        deal(address(kkkk), owner, 100000, false);
        uint256 bltim = block.timestamp;

        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, 1024, 0, bltim));

        bytes32 digest = kkkk.DOMAIN_SEPARATOR().toTypedDataHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.startPrank(spender);
        assertEq(kkkk.allowance(owner, spender), 0);
        assertEq(kkkk.nonces(owner), 0);
        kkkk.permit(owner, spender, 1024, bltim, v, r, s);
        vm.sleep(1);
        assertEq(kkkk.nonces(owner), 1);
        assertEq(kkkk.allowance(owner, spender), 1024);

        assertEq(0, kkkk.balanceOf(users[2]), "before trnasferform error");
        kkkk.transferFrom(owner, users[2], 1000);
        assertEq(1000, kkkk.balanceOf(users[2]), "after trnasferform error");
        vm.stopPrank();
    }

    struct S_Permit2 {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function testERC20permitinitmetagood() public {
        deal(address(kkkk), marketcreator, 50000 * 10 ** 7, false);
        uint256 bltim = block.timestamp + 10000;
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH, marketcreator, address(market), 50000 * 10 ** 6, kkkk.nonces(marketcreator), bltim
            )
        );

        bytes32 digest = kkkk.DOMAIN_SEPARATOR().toTypedDataHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, digest);
        //kkkk.permit(owner, address(this), 100e18, 1 days, v, r, s);

        S_Permit2 memory ef = S_Permit2(50000 * 10 ** 6, bltim, v, r, s);

        SimplePermit memory sp = SimplePermit(2, abi.encode(ef));
        vm.startPrank(marketcreator);
        market.initMetaGood(address(kkkk), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, abi.encode(sp));
        vm.stopPrank();
    }

    function testERC20permitinitmetagood2() public {
        deal(address(kkkk), marketcreator, 50000 * 10 ** 7, false);
        uint256 bltim = block.timestamp + 10000;
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH, marketcreator, address(market), 50000 * 10 ** 8, kkkk.nonces(marketcreator), bltim
            )
        );

        console2.log(1, kkkk.allowance(marketcreator, address(market)));

        bytes32 digest = kkkk.DOMAIN_SEPARATOR().toTypedDataHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, digest);
        //kkkk.permit(owner, address(this), 100e18, 1 days, v, r, s);

        S_Permit2 memory ef = S_Permit2(50000 * 10 ** 8, bltim, v, r, s);

        SimplePermit memory sp = SimplePermit(2, abi.encode(ef));
        vm.startPrank(marketcreator);
        market.initMetaGood(address(kkkk), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, abi.encode(sp));

        console2.log(2, kkkk.allowance(marketcreator, address(market)));
        vm.stopPrank();
    }

    function testPermit2AllownanceApprove() public {
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);
        vm.startPrank(users[3]);
        deal(address(kkkk), users[3], 100000000000, false);
        kkkk.approve(targetAddr, 100000000000);
        uint256 blt = block.timestamp;

        console2.log(1, 1);
        Permit2(targetAddr).approve(address(kkkk), users[4], 100000000000, uint48(blt + 100000));
        console2.log(1, 2);
        vm.stopPrank();
        vm.startPrank(users[4]);
        assertEq(100000000000, kkkk.balanceOf(users[3]), "before kkkk balanceof users3");
        assertEq(0, kkkk.balanceOf(users[4]), "before kkkk balanceof users4");
        Permit2(targetAddr).transferFrom(users[3], users[4], 100000, address(kkkk));

        assertEq(100000000000 - 100000, kkkk.balanceOf(users[3]), "after kkkk balanceof users3");
        assertEq(100000, kkkk.balanceOf(users[4]), "after kkkk balanceof users4");
        vm.stopPrank();
    }

    function testPermit2AllownanceApproveInitMetaGood() public {
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);
        vm.startPrank(marketcreator);
        deal(address(kkkk), marketcreator, 50000 * 10 ** 6, false);
        kkkk.approve(targetAddr, 50000 * 10 ** 6);
        uint256 blt = block.timestamp;

        console2.log(1, 1);
        Permit2(targetAddr).approve(address(kkkk), address(market), 50000 * 10 ** 6, uint48(blt + 100000));
        console2.log(1, 2);

        SimplePermit memory sp = SimplePermit(3, abi.encode(0));
        assertEq(0, kkkk.balanceOf(address(market)), "before trnasferform error");
        console2.log(3, kkkk.balanceOf(address(market)));
        market.initMetaGood(address(kkkk), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, abi.encode(sp));
        console2.log(4, kkkk.balanceOf(address(market)));
        assertEq(50000 * 10 ** 6, kkkk.balanceOf(address(market)), "after trnasferform error");

        vm.stopPrank();
    }
    /// @notice The permit data for a token

    struct PermitDetails {
        // ERC20 token address
        address token;
        // the maximum amount allowed to spend
        uint160 amount;
        // timestamp at which a spender's token allowances become invalid
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }

    /// @notice The permit message signed for a single token allowance
    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    function testPermit2AllownancePermitInitMetaGood() public {
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);
        vm.startPrank(marketcreator);
        deal(address(kkkk), marketcreator, 50000 * 10 ** 6, false);
        kkkk.approve(targetAddr, 50000 * 10 ** 6);
        uint256 blt = block.timestamp;

        console2.log(1, 2);

        bytes32 _PERMIT_SINGLE_TYPEHASH = keccak256(
            "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
        bytes32 _PERMIT_DETAILS_TYPEHASH =
            keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

        (,, uint48 nonce) = Permit2(targetAddr).allowance(owner, address(kkkk), address(market));

        console2.log(uint256(nonce), 3);
        IAllowanceTransfer.PermitSingle memory _pd = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(kkkk),
                amount: uint160(50000 * 10 ** 6),
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(market),
            sigDeadline: uint48(blt + 100000)
        });
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, _pd.details));
        bytes32 domainSeparator = Permit2(targetAddr).DOMAIN_SEPARATOR();
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, _pd.spender, _pd.sigDeadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, msgHash);

        S_Permit memory ef = S_Permit(50000 * 10 ** 6, uint48(blt + 100000), 0, v, r, s);
        SimplePermit memory sp = SimplePermit(4, abi.encode(ef));
        assertEq(0, kkkk.balanceOf(address(market)), "before trnasferform error");
        console2.log(3, kkkk.balanceOf(address(market)));
        market.initMetaGood(address(kkkk), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, abi.encode(sp));
        console2.log(4, kkkk.balanceOf(address(market)));
        assertEq(50000 * 10 ** 6, kkkk.balanceOf(address(market)), "after trnasferform error");

        vm.stopPrank();
    }

    struct S_Permit {
        uint256 value;
        uint256 deadline;
        uint256 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function testPermit2Permit() public {
        // 获取permit2合约的代码复制到固定地址
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);

        vm.startPrank(marketcreator);
        // 铸造代币
        deal(address(kkkk), marketcreator, 50000 * 10 ** 6, false);
        // 授权给permit2合约
        kkkk.approve(targetAddr, 50000 * 10 ** 6);
        //获取当前的时间截
        uint256 blt = block.timestamp;

        //构建传递参数
        ISignatureTransfer.PermitTransferFrom memory _pd = ISignatureTransfer.PermitTransferFrom(
            ISignatureTransfer.TokenPermissions({token: address(kkkk), amount: uint256(50000 * 10 ** 6)}),
            uint256(0), //nonce  (random/(2**8))<<8+permit2().nonceBitmap(marketor,random/(2**8))  random是一个随机数
            uint256(blt + 100000)
        );
        bytes32 _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

        bytes32 _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, _pd.permitted));
        bytes32 domainSeparator = Permit2(targetAddr).DOMAIN_SEPARATOR();
        //打包数据
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, users[4], _pd.nonce, _pd.deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, msgHash);
        vm.stopPrank();

        vm.startPrank(users[4]);

        ISignatureTransfer.SignatureTransferDetails memory bb =
            ISignatureTransfer.SignatureTransferDetails({to: users[4], requestedAmount: 50000 * 10 ** 6});

        assertEq(0, kkkk.balanceOf(users[4]), "before trnasferform error");
        console2.log(3, kkkk.balanceOf(users[4]));
        ISignatureTransfer(targetAddr).permitTransferFrom(_pd, bb, marketcreator, bytes.concat(r, s, bytes1(v)));
        console2.log(4, kkkk.balanceOf(users[4]));
        assertEq(50000 * 10 ** 6, kkkk.balanceOf(users[4]), "after trnasferform error");
        vm.stopPrank();
    }

    function testPermit2Permit2() public {
        // 获取permit2合约的代码复制到固定地址
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);

        vm.startPrank(marketcreator);
        // 铸造代币
        deal(address(kkkk), marketcreator, 100000 * 10 ** 6, false);
        // 授权给permit2合约
        kkkk.approve(targetAddr, 100000 * 10 ** 6);
        //获取当前的时间截
        uint256 blt = block.timestamp;

        //构建传递参数
        ISignatureTransfer.PermitTransferFrom memory _pd = ISignatureTransfer.PermitTransferFrom(
            ISignatureTransfer.TokenPermissions({token: address(kkkk), amount: uint256(50000 * 10 ** 6)}),
            uint256(0), //nonce  (random/(2**8))<<8+permit2().nonceBitmap(marketor,random/(2**8))  random是一个随机数
            uint256(blt + 100000)
        );
        bytes32 _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

        bytes32 _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, _pd.permitted));
        bytes32 domainSeparator = Permit2(targetAddr).DOMAIN_SEPARATOR();
        //打包数据
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, users[5], _pd.nonce, _pd.deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, msgHash);

        ISignatureTransfer.PermitTransferFrom memory _pd2 = ISignatureTransfer.PermitTransferFrom(
            ISignatureTransfer.TokenPermissions({token: address(kkkk), amount: uint256(50000 * 10 ** 6)}),
            2, //nonce  (random/(2**8))<<8+permit2().nonceBitmap(marketor,random/(2**8))  random是一个随机数
            uint256(blt + 100000)
        );

        bytes32 tokenPermissions2 = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, _pd2.permitted));
        //打包数据
        bytes32 msgHash2 = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions2, users[5], _pd2.nonce, _pd2.deadline)
                )
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(marketcreatorkey, msgHash2);
        vm.stopPrank();

        vm.startPrank(users[5]);

        ISignatureTransfer.SignatureTransferDetails memory bb =
            ISignatureTransfer.SignatureTransferDetails({to: users[5], requestedAmount: 50000 * 10 ** 6});

        assertEq(0, kkkk.balanceOf(users[5]), "before trnasferform error");
        console2.log(3, kkkk.balanceOf(users[5]));
        ISignatureTransfer(targetAddr).permitTransferFrom(_pd, bb, marketcreator, bytes.concat(r, s, bytes1(v)));

        ISignatureTransfer(targetAddr).permitTransferFrom(_pd2, bb, marketcreator, bytes.concat(r2, s2, bytes1(v2)));
        console2.log(4, kkkk.balanceOf(users[5]));

        vm.stopPrank();
    }

    function testPermit2PermitInitMetaGood() public {
        bytes memory code = address(aabbpermit).code;
        address targetAddr = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(targetAddr, code);
        vm.startPrank(marketcreator);
        deal(address(kkkk), marketcreator, 50000 * 10 ** 6, false);
        kkkk.approve(targetAddr, 50000 * 10 ** 6);
        uint256 blt = block.timestamp;

        ISignatureTransfer.PermitTransferFrom memory _pd = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(kkkk), amount: uint256(50000 * 10 ** 6)}),
            nonce: uint256(0),
            deadline: uint256(blt + 10000)
        });
        bytes32 _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

        bytes32 _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, _pd.permitted));
        bytes32 domainSeparator = Permit2(targetAddr).DOMAIN_SEPARATOR();
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, address(market), _pd.nonce, _pd.deadline
                    )
                )
            )
        );
        console2.log(555, address(market));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, msgHash);

        S_Permit memory ef = S_Permit(50000 * 10 ** 6, _pd.deadline, _pd.nonce, v, r, s);
        SimplePermit memory sp = SimplePermit(5, abi.encode(ef));
        assertEq(0, kkkk.balanceOf(address(market)), "before trnasferform error");
        market.initMetaGood(address(kkkk), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, abi.encode(sp));
        console2.log(4, kkkk.balanceOf(address(market)));
        assertEq(50000 * 10 ** 6, kkkk.balanceOf(address(market)), "after trnasferform error");
        vm.stopPrank();
    }
}
