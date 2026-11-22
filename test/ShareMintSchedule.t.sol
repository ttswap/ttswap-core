// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {s_share} from "../src/interfaces/I_TTSwap_Token.sol";

/// @notice Gate that always passes, so shareMint reaches the release math.
contract AlwaysHigherMarket {
    function ishigher(uint256, uint256, uint256) external pure returns (bool) {
        return true;
    }
}

/// @notice #325: shareMint must release the full allocation over `chips`
/// unlocks (equal chunks, final chip sweeps remainder) instead of geometric
/// decay that strands ~25-37% and can never mint again.
contract ShareMintSchedule is BaseSetup {
    address internal owner_;
    AlwaysHigherMarket internal gate;

    function setUp() public override {
        BaseSetup.setUp();
        owner_ = users[4];
        gate = new AlwaysHigherMarket();
        vm.prank(marketcreator);
        tts_token.setEnv(address(gate));
    }

    function _grant(uint128 amount, uint8 chips) internal {
        s_share memory share = s_share({leftamount: amount, metric: 0, chips: chips});
        vm.prank(marketcreator);
        tts_token.addShare(share, owner_);
    }

    function _mint() internal returns (uint256 minted) {
        uint256 before_ = tts_token.balanceOf(owner_);
        vm.prank(owner_);
        tts_token.shareMint();
        return tts_token.balanceOf(owner_) - before_;
    }

    function testShareMint_fullSchedule_releasesAll() public {
        _grant(1_000_000, 4);
        uint256 total;
        for (uint256 i; i < 4; ++i) total += _mint();
        assertEq(total, 1_000_000, "full allocation minted");
        assertEq(tts_token.usershares(owner_).leftamount, 0, "nothing stranded");
        // A further unlock reverts: no share left.
        vm.prank(owner_);
        vm.expectRevert();
        tts_token.shareMint();
    }

    function testShareMint_twoChips_equalHalves() public {
        _grant(1_000_000, 2);
        assertEq(_mint(), 500_000, "first half");
        assertEq(_mint(), 500_000, "second half sweeps remainder");
        assertEq(tts_token.usershares(owner_).leftamount, 0);
    }

    function testShareMint_dustShare_fullyUnlocks() public {
        // Small-share case: geometric decay used to strand the remainder
        // and terminal unlocks minted 0 while burning metric; the schedule
        // now completes and releases the full allocation. (chips=100 keeps
        // metric < 128 — the separate 2**metric overflow at high unlock
        // counts is out of scope here.)
        _grant(200, 100);
        uint256 total;
        for (uint256 i; i < 100; ++i) total += _mint();
        assertEq(total, 200, "dust share fully released");
        assertEq(tts_token.usershares(owner_).leftamount, 0);
    }

    function testShareMint_mergeMidSchedule_completes() public {
        _grant(600_000, 4);
        assertEq(_mint(), 150_000, "first chip of grant1");
        // Second grant merges into the remaining schedule.
        _grant(400_000, 4);
        uint256 total = 150_000;
        for (uint256 i; i < 3; ++i) total += _mint();
        assertEq(tts_token.usershares(owner_).leftamount, 0, "merged share drained");
        assertEq(total, 1_000_000, "both grants fully released");
    }
}
