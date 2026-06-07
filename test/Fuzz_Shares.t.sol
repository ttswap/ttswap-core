// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {s_share} from "../src/interfaces/I_TTSwap_Token.sol";

/// @notice Fuzz addShare / burnShare (TASK-P3-004).
contract Fuzz_Shares is FuzzBase {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_AddShare_valid(
        uint128 amount,
        uint120 metric,
        uint8 chips
    ) public {
        amount = uint128(bound(amount, 1, tts_token.left_share() / 1000));
        metric = uint120(bound(metric, 0, 120));
        chips = uint8(bound(chips, 1, 20));

        uint128 leftBefore = tts_token.left_share();
        s_share memory share = s_share({
            leftamount: amount,
            metric: metric,
            chips: chips
        });

        vm.prank(marketcreator);
        tts_token.addShare(share, users[4]);

        assertEq(tts_token.left_share(), leftBefore - amount, "left_share");
        s_share memory stored = tts_token.usershares(users[4]);
        assertEq(stored.leftamount, amount, "user share");
        assertEq(stored.chips, chips, "chips");
    }

    function testFuzz_BurnShare_restoresLeft(address owner, uint128 amount) public {
        amount = uint128(bound(amount, 1, tts_token.left_share() / 1000));
        vm.assume(owner != address(0));

        s_share memory share = s_share({leftamount: amount, metric: 5, chips: 2});
        vm.startPrank(marketcreator);
        tts_token.addShare(share, owner);
        uint128 leftMid = tts_token.left_share();
        tts_token.burnShare(owner);
        vm.stopPrank();

        assertEq(tts_token.left_share(), leftMid + amount, "restored");
        assertEq(tts_token.usershares(owner).leftamount, 0, "burned");
    }
}
