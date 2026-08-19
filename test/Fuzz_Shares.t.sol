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
        // Keep in sync with TTSwap_Token.MAX_SHARE_MINT_METRIC
        uint120 maxMintMetric = 60;
        amount = uint128(bound(amount, 1, tts_token.left_share() / 1000));
        chips = uint8(bound(chips, 1, 20));
        // last unlock metric = metric + chips - 1 <= maxMintMetric
        uint120 maxMetric = uint120(maxMintMetric - (uint256(chips) - 1));
        metric = uint120(bound(metric, 0, maxMetric));
        // Fresh recipient each run so merge-path schedule checks cannot fire.
        address owner = address(uint160(uint256(keccak256(abi.encode(amount, metric, chips)))));

        uint128 leftBefore = tts_token.left_share();
        s_share memory share = s_share({
            leftamount: amount,
            metric: metric,
            chips: chips
        });

        vm.prank(marketcreator);
        tts_token.addShare(share, owner);
        _snapToken("tts_token_addShare_Fuzz_Shares.t_36");

        assertEq(tts_token.left_share(), leftBefore - amount, "left_share");
        s_share memory stored = tts_token.usershares(owner);
        assertEq(stored.leftamount, amount, "user share");
        assertEq(stored.chips, chips, "chips");
        assertEq(stored.metric, metric, "metric");
    }

    function testFuzz_BurnShare_restoresLeft(address owner, uint128 amount) public {
        amount = uint128(bound(amount, 1, tts_token.left_share() / 1000));
        vm.assume(owner != address(0));

        s_share memory share = s_share({leftamount: amount, metric: 5, chips: 2});
        vm.startPrank(marketcreator);
        tts_token.addShare(share, owner);
        _snapToken("tts_token_addShare_Fuzz_Shares.t_51");
        uint128 leftMid = tts_token.left_share();
        tts_token.burnShare(owner);
        _snapToken("tts_token_burnShare_Fuzz_Shares.t_53");
        vm.stopPrank();

        assertEq(tts_token.left_share(), leftMid + amount, "restored");
        assertEq(tts_token.usershares(owner).leftamount, 0, "burned");
    }
}
