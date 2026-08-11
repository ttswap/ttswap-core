// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P0-01 / P1-04: publicSell fund flow and tier pricing.
contract testTTSwapTokenPublicSell is BaseSetup {
    uint256 internal constant TIER1_CAP = 87_500_000_000;
    uint256 internal constant TIER2_CAP = 162_500_000_000;
    uint256 internal constant HARD_CAP = 250_000_000_000;

    function testPublicSell_transfersUsdtToTokenContract() public {
        uint256 amount = 1_000_000;
        address buyer = users[5];

        vm.startPrank(buyer);
        deal(address(usdt), buyer, amount, false);
        usdt.approve(address(tts_token), amount);

        uint256 buyerUsdtBefore = usdt.balanceOf(buyer);
        uint256 tokenUsdtBefore = usdt.balanceOf(address(tts_token));

        tts_token.publicSell(amount, defaultdata);

        assertEq(usdt.balanceOf(address(tts_token)), tokenUsdtBefore + amount, "usdt in token");
        assertEq(usdt.balanceOf(buyer), buyerUsdtBefore - amount, "buyer spent usdt");
        assertEq(
            tts_token.balanceOf(buyer),
            amount * 25_000_000,
            "tier-1 mint"
        );
        vm.stopPrank();
    }

    function testWithdrawPublicSell_byTokenAdmin() public {
        uint256 amount = 2_000_000;
        address buyer = users[5];
        address recipient = users[6];

        vm.startPrank(buyer);
        deal(address(usdt), buyer, amount, false);
        usdt.approve(address(tts_token), amount);
        tts_token.publicSell(amount, defaultdata);
        vm.stopPrank();

        vm.prank(marketcreator);
        tts_token.withdrawPublicSell(amount, recipient);

        assertEq(usdt.balanceOf(recipient), amount, "recipient received");
        assertEq(usdt.balanceOf(address(tts_token)), 0, "token drained");
    }

    function testWithdrawPublicSell_revert_notTokenAdmin() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        tts_token.withdrawPublicSell(1, users[4]);
    }

    function testPublicSell_tier3() public {
        uint256 tier3Amount = 1_000_000;
        // Jump cumulative publicsell into tier-3 with one purchase.
        uint256 tier3Prefill = 162_500_000_001;
        address buyer = users[5];

        vm.startPrank(buyer);
        deal(address(usdt), buyer, tier3Prefill + tier3Amount, false);
        usdt.approve(address(tts_token), tier3Prefill + tier3Amount);
        tts_token.publicSell(tier3Prefill, defaultdata);
        tts_token.publicSell(tier3Amount, defaultdata);
        vm.stopPrank();

        assertEq(
            tts_token.balanceOf(buyer),
            tier3Prefill * 16_000_000 + tier3Amount * 16_000_000,
            "tier-3 rate"
        );
        assertEq(tts_token.publicsell(), tier3Prefill + tier3Amount, "cumulative");
    }

    function testPublicSell_crossTierSingleTx_usesPostCumulativeTier() public {
        uint256 prefill = TIER1_CAP;
        uint256 amount = 1_000_000;
        address buyer = users[5];

        vm.startPrank(buyer);
        deal(address(usdt), buyer, prefill + amount, false);
        usdt.approve(address(tts_token), prefill + amount);
        tts_token.publicSell(prefill, defaultdata);
        // Single tx crosses into tier-2; entire amount priced at tier-2 rate.
        tts_token.publicSell(amount, defaultdata);
        vm.stopPrank();

        assertEq(
            tts_token.balanceOf(buyer),
            prefill * 25_000_000 + amount * 20_000_000,
            "post-cumulative tier pricing"
        );
    }

    function testPublicSell_zeroAmount_noMint() public {
        address buyer = users[5];
        vm.startPrank(buyer);
        deal(address(usdt), buyer, 1_000_000, false);
        usdt.approve(address(tts_token), 1_000_000);
        tts_token.publicSell(0, defaultdata);
        assertEq(tts_token.balanceOf(buyer), 0, "no mint on zero");
        assertEq(tts_token.publicsell(), 0, "publicsell unchanged");
        vm.stopPrank();
    }
}
