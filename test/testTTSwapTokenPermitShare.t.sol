// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {I_TTSwap_Token, s_share} from "../src/interfaces/I_TTSwap_Token.sol";
import {L_SignatureVerification} from "../src/libraries/L_SignatureVerification.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P0-02: permitShare EIP-712 path.
contract testTTSwapTokenPermitShare is BaseSetup {
    using L_SignatureVerification for bytes;

    uint256 internal constant ADMIN_KEY = 0xA11CE;
    address internal tokenAdmin;

    bytes32 internal constant PERMIT_SHARE_TYPEHASH = keccak256(
        "permitShare(uint128 amount,uint120 chips,uint8 metric,address owner,uint128 existamount,uint128 deadline,uint256 nonce)"
    );

    function setUp() public override {
        BaseSetup.setUp();
        tokenAdmin = vm.addr(ADMIN_KEY);
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(tokenAdmin, true);
        vm.stopPrank();
    }

    function _signPermitShare(
        s_share memory share,
        address owner,
        uint128 existAmount,
        uint128 deadline,
        uint256 nonce
    ) internal view returns (bytes memory sig) {
        bytes32 structHash = tts_token.shareHash(
            share,
            owner,
            existAmount,
            deadline,
            nonce
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", tts_token.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ADMIN_KEY, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function testPermitShare_tokenAdminSignature_addsShare() public {
        address recipient = users[4];
        s_share memory share = s_share({
            leftamount: 500_000,
            metric: 5,
            chips: 2
        });
        uint128 deadline = uint128(block.timestamp + 3600);
        uint256 nonce = tts_token.nonces(recipient);

        bytes memory sig = _signPermitShare(
            share,
            recipient,
            0,
            deadline,
            nonce
        );

        vm.prank(recipient);
        tts_token.permitShare(share, deadline, sig, tokenAdmin);

        s_share memory stored = tts_token.usershares(recipient);
        assertEq(stored.leftamount, 500_000, "share added");
        assertEq(tts_token.nonces(recipient), nonce + 1, "nonce bumped");
    }

    function testPermitShare_revert_expiredDeadline() public {
        s_share memory share = s_share({leftamount: 100, metric: 1, chips: 1});
        uint128 deadline = uint128(block.timestamp - 1);
        bytes memory sig = _signPermitShare(share, users[4], 0, deadline, 0);

        vm.prank(users[4]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 72));
        tts_token.permitShare(share, deadline, sig, tokenAdmin);
    }

    function testPermitShare_revert_nonTokenAdminSigner() public {
        uint256 outsiderKey = 0xBEEF;
        address outsider = vm.addr(outsiderKey);
        s_share memory share = s_share({leftamount: 100, metric: 1, chips: 1});
        uint128 deadline = uint128(block.timestamp + 3600);

        bytes32 structHash = tts_token.shareHash(share, users[4], 0, deadline, 0);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", tts_token.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(outsiderKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(users[4]);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        tts_token.permitShare(share, deadline, sig, outsider);
    }

    function testPermitShare_revert_replay() public {
        address recipient = users[4];
        s_share memory share = s_share({leftamount: 100, metric: 1, chips: 1});
        uint128 deadline = uint128(block.timestamp + 3600);
        uint256 nonce = tts_token.nonces(recipient);
        bytes memory sig = _signPermitShare(share, recipient, 0, deadline, nonce);

        vm.startPrank(recipient);
        tts_token.permitShare(share, deadline, sig, tokenAdmin);
        vm.expectRevert(L_SignatureVerification.InvalidSigner.selector);
        tts_token.permitShare(share, deadline, sig, tokenAdmin);
        vm.stopPrank();
    }

    function testShareHash_matchesTypedData() public view {
        s_share memory share = s_share({leftamount: 42, metric: 3, chips: 7});
        address owner = users[1];
        uint128 exist = 0;
        uint128 deadline = 12345;
        uint256 nonce = 99;

        bytes32 fromContract = tts_token.shareHash(
            share,
            owner,
            exist,
            deadline,
            nonce
        );
        bytes32 manual = keccak256(
            abi.encode(
                PERMIT_SHARE_TYPEHASH,
                share.leftamount,
                share.chips,
                share.metric,
                owner,
                exist,
                deadline,
                nonce
            )
        );
        assertEq(fromContract, manual, "shareHash matches typed data");
    }
}
