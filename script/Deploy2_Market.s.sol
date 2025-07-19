// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";
import {Permit2} from "permit2/src/Permit2.sol";
import {MyToken} from "../src/test/Mytoken.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";

bytes32 constant SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3af2663da51c10215000000));

Permit2 constant permit2 = Permit2(0xa2c1d0a26c7be612008bd1F265A84EcDaF5d9Eba);

contract DeployMarket is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        MyToken UsdtToken = new MyToken("USDT", "USDT", 6);

        UsdtToken.mint(msg.sender, 200000);
        UsdtToken.approve(address(permit2), 100000 * 10 ** 6);
        console2.log("USDT Token Deployed:", address(UsdtToken));
        MyToken BTCToken = new MyToken("BTC", "BTC", 6);
        console2.log("BTC Token Deployed:", address(BTCToken));

        BTCToken.mint(msg.sender, 200000);
        BTCToken.approve(address(permit2), 100000 * 10 ** 6);

        TTSwap_Token ttstoken = new TTSwap_Token(
            
        );

        TTSwap_Token_Proxy ttstoken_proxy = new TTSwap_Token_Proxy(
            address(UsdtToken),
            msg.sender,
            57896044618658097711785492504343953926634992332820282019728792003956564819968,
            "TTSwap Token",
            "TTS",
            address(ttstoken)
        );

        TTSwap_Market ttsmarket = new TTSwap_Market(
            
        );

        TTSwap_Market_Proxy ttsmarket_proxy = new TTSwap_Market_Proxy(
            TTSwap_Token(payable(address(ttstoken_proxy))),
            address(ttsmarket)
        );


        ttstoken.setTokenAdmin(msg.sender,true);
        ttstoken.setTokenManager(msg.sender,true);
        ttstoken.setCallMintTTS(address(ttsmarket), true);
        ttstoken.setMarketAdmin(msg.sender,true);

        UsdtToken.approve(address(ttsmarket), 10000000000000);

        ttsmarket.initMetaGood(
            address(UsdtToken), toTTSwapUINT256(50000 * 10 ** 6, 50000 * 10 ** 6), 2 ** 255, defaultdata
        );

        uint256 bltim = block.timestamp;
        bytes32 structHash1 =
            keccak256(abi.encode(_PERMIT_TYPEHASH, msg.sender, address(ttsmarket), 1 * 10 ** 8, 0, bltim));

        bytes32 digest1 = toTypedDataHash(UsdtToken.DOMAIN_SEPARATOR(), structHash1);
        (uint8 v1, bytes32 r1, bytes32 s1) =
            vm.sign(0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6, digest1);
        S_Permit2 memory ef1 = S_Permit2(1 * 10 ** 8, bltim, v1, r1, s1);
        SimplePermit memory sp1 = SimplePermit(2, abi.encode(ef1));

        bytes32 structHash2 =
            keccak256(abi.encode(_PERMIT_TYPEHASH, msg.sender, address(ttsmarket), 63000 * 10 ** 6, 0, bltim));
        bytes32 digest2 = toTypedDataHash(BTCToken.DOMAIN_SEPARATOR(), structHash2);
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6, digest2);

        S_Permit2 memory ef2 = S_Permit2(63000 * 10 ** 6, bltim, v2, r2, s2);
        SimplePermit memory sp2 = SimplePermit(2, abi.encode(ef2));

        uint256 normalgoodconfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        ttsmarket.initGood(
            address(UsdtToken),
            toTTSwapUINT256(1 * 10 ** 8, 63000 * 10 ** 6),
            address(BTCToken),
            normalgoodconfig,
            abi.encode(sp1),
            abi.encode(sp2)
        );
        vm.stopBroadcast();
    }

    bytes internal constant defaultdata = abi.encode(L_CurrencyLibrary.S_transferData(1, ""));

    struct S_Permit2 {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct SimplePermit {
        uint8 transfertype;
        bytes detail;
    }

    bytes32 private _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }
}
