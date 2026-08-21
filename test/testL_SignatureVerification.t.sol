// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {L_SignatureVerification} from "../src/libraries/L_SignatureVerification.sol";

contract SigHarness {
    using L_SignatureVerification for bytes;

    function verify(bytes calldata signature, bytes32 hash, address signer) external pure {
        signature.verify(hash, signer);
    }
}

contract testL_SignatureVerification is Test {
    uint256 internal constant KEY = 0xA11CE;
    SigHarness internal h;
    address internal signer;
    bytes32 internal hash;

    function setUp() public {
        h = new SigHarness();
        signer = vm.addr(KEY);
        hash = keccak256("tts");
    }

    function testSig_65ByteOk() public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, hash);
        h.verify(abi.encodePacked(r, s, v), hash, signer);
    }

    function testSig_eip2098Ok() public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, hash);
        uint8 yParity = v - 27;
        bytes32 vs = bytes32(uint256(s) | (uint256(yParity) << 255));
        h.verify(abi.encodePacked(r, vs), hash, signer);
    }

    function testSig_revert_badLength() public {
        vm.expectRevert(L_SignatureVerification.InvalidSignatureLength.selector);
        h.verify(hex"aa", hash, signer);
    }

    function testSig_revert_wrongSigner() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, hash);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        h.verify(abi.encodePacked(r, s, v), hash, address(0xBEEF));
    }

    function testSig_revert_highS() public {
        (uint8 v, bytes32 r, ) = vm.sign(KEY, hash);
        bytes32 highS = bytes32(
            uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) + 1
        );
        vm.expectRevert(L_SignatureVerification.InvalidSignature.selector);
        h.verify(abi.encodePacked(r, highS, v), hash, signer);
    }
}
