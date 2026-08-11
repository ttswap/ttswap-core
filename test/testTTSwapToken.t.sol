// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {I_TTSwap_Market} from "../src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token, s_share, s_proof} from "../src/interfaces/I_TTSwap_Token.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice TTSwap_Token stake / unstake + governance (TASK-P1-012, P2-006~009).
contract testTTSwapToken is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;

    address internal stakeCaller;
    address internal beneficiary;

    uint128 internal constant STAKE_VALUE = 100_000;
    uint128 internal constant UNSTAKE_VALUE = 10_000;

    function setUp() public override {
        BaseSetup.setUp();
        stakeCaller = users[1];
        beneficiary = users[2];
        vm.warp(1_000_000);
        vm.prank(marketcreator);
        tts_token.setCallMintTTS(stakeCaller, true);
    }

    function testTTSwapToken_stake_unstake_cycle() public {
        vm.prank(stakeCaller);
        uint128 netconstruct = tts_token.stake(beneficiary, STAKE_VALUE);
        assertEq(netconstruct, 0, "first stake has no construct fee");

        uint256 stakeAfter = tts_token.stakestate();
        assertEq(stakeAfter.amount1(), STAKE_VALUE, "stakestate tracks proof value");
        assertEq(tts_token.balanceOf(beneficiary), 0, "no mint on stake");

        vm.warp(block.timestamp + 86_400);

        vm.prank(stakeCaller);
        tts_token.unstake(beneficiary, UNSTAKE_VALUE);

        uint256 stakeFinal = tts_token.stakestate();
        assertEq(
            stakeFinal.amount1(),
            STAKE_VALUE - UNSTAKE_VALUE,
            "partial unstake reduces stake"
        );
        assertGt(tts_token.balanceOf(beneficiary), 0, "profit minted to beneficiary");
    }

    function testTTSwapToken_stake_revert_notAuthorized() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 71));
        tts_token.stake(beneficiary, STAKE_VALUE);
    }

    function testTTSwapToken_unstake_full_exit() public {
        vm.startPrank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);
        vm.warp(block.timestamp + 86_400);
        tts_token.unstake(beneficiary, STAKE_VALUE);
        vm.stopPrank();

        assertEq(tts_token.stakestate().amount1(), 0, "full unstake clears stake");
    }

    // ── TASK-P2-006 governance ─────────────────────────────────────────────

    function testTTSwapToken_setDAOAdmin_ok() public {
        vm.prank(marketcreator);
        tts_token.setDAOAdmin(users[3], true);
        vm.prank(marketcreator);
        tts_token.setDAOAdmin(users[3], false);
    }

    function testTTSwapToken_setDAOAdmin_revert_notAdmin() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.setDAOAdmin(users[4], true);
    }

    function testTTSwapToken_setRatio_ok_and_revert() public {
        vm.prank(marketcreator);
        tts_token.setRatio(5000);
        assertEq(tts_token.ttstokenconfig() & 0xFFFF, 5000, "ratio stored");

        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.setRatio(100);

        vm.prank(marketcreator);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 66));
        tts_token.setRatio(10001);
    }

    // ── TASK-P2-007 addShare / burnShare / shareMint ───────────────────────

    function testTTSwapToken_addShare_burnShare_shareMint() public {
        address shareOwner = users[4];
        s_share memory share = s_share({
            leftamount: 1_000_000,
            metric: 10,
            chips: 4
        });

        vm.startPrank(marketcreator);
        tts_token.setEnv(address(market));
        tts_token.addShare(share, shareOwner);
        vm.stopPrank();

        s_share memory stored = tts_token.usershares(shareOwner);
        assertEq(stored.leftamount, share.leftamount, "share recorded");
        assertEq(stored.chips, share.chips, "chips recorded");

        uint256 ttsGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(tts_token),
            id: 0
        }).toId();
        uint256 usdtGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        }).toId();
        uint256 threshold = (uint256(1) << stored.metric) * (uint256(1) << 128) +
            20_000_000;

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                I_TTSwap_Market.ishigher.selector,
                ttsGoodId,
                usdtGoodId,
                threshold
            ),
            abi.encode(true)
        );

        uint256 balBefore = tts_token.balanceOf(shareOwner);
        vm.prank(shareOwner);
        tts_token.shareMint();
        assertGt(tts_token.balanceOf(shareOwner), balBefore, "shareMint minted");

        vm.prank(marketcreator);
        tts_token.burnShare(shareOwner);
        assertEq(tts_token.usershares(shareOwner).leftamount, 0, "share burned");
    }

    // ── TASK-P2-008 publicSell tiers + cap ─────────────────────────────────

    function testTTSwapToken_publicSell_tier1() public {
        uint256 usdtAmount = 1_000_000;
        vm.startPrank(users[5]);
        deal(address(usdt), users[5], usdtAmount, false);
        usdt.approve(address(tts_token), usdtAmount);
        tts_token.publicSell(usdtAmount, defaultdata);
        vm.stopPrank();

        assertEq(
            tts_token.balanceOf(users[5]),
            usdtAmount * 25_000_000,
            "tier-1 rate"
        );
        assertEq(tts_token.publicsell(), usdtAmount, "publicsell tracked");
    }

    function testTTSwapToken_publicSell_tier2() public {
        uint256 tier1Cap = 87_500_000_000;
        uint256 usdtAmount = 1_000_000;

        vm.startPrank(users[5]);
        deal(address(usdt), users[5], tier1Cap + usdtAmount, false);
        usdt.approve(address(tts_token), tier1Cap + usdtAmount);
        tts_token.publicSell(tier1Cap, defaultdata);
        tts_token.publicSell(usdtAmount, defaultdata);
        vm.stopPrank();

        assertEq(
            tts_token.balanceOf(users[5]),
            tier1Cap * 25_000_000 + usdtAmount * 20_000_000,
            "tier-2 rate after tier-1 cap"
        );
    }

    function testTTSwapToken_publicSell_revert_cap() public {
        vm.startPrank(users[5]);
        deal(address(usdt), users[5], 250_000_000_001, false);
        usdt.approve(address(tts_token), 250_000_000_001);
        tts_token.publicSell(250_000_000_000, defaultdata);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 70));
        tts_token.publicSell(1, defaultdata);
        vm.stopPrank();
    }

    // ── TASK-P2-009 views ──────────────────────────────────────────────────

    function testTTSwapToken_usershares_and_stakeproofinfo_views() public {
        s_share memory share = s_share({
            leftamount: 500_000,
            metric: 5,
            chips: 2
        });
        vm.prank(marketcreator);
        tts_token.addShare(share, users[6]);

        s_share memory viewShare = tts_token.usershares(users[6]);
        assertEq(viewShare.leftamount, 500_000, "usershares view");

        vm.prank(stakeCaller);
        tts_token.stake(beneficiary, STAKE_VALUE);

        uint256 proofId = uint256(keccak256(abi.encode(beneficiary, stakeCaller)));
        s_proof memory proof = tts_token.stakeproofinfo(proofId);
        assertEq(proof.fromcontract, stakeCaller, "stakeproof fromcontract");
        assertEq(proof.proofstate.amount0(), STAKE_VALUE, "stakeproof value");
    }
}
