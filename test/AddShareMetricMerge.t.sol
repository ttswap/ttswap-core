// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {I_TTSwap_Market} from "../src/interfaces/I_TTSwap_Market.sol";
import {s_share} from "../src/interfaces/I_TTSwap_Token.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";

/// @notice Regression for #322: merging a second share grant must not raise
/// the stored metric (unlock bar) for the existing unminted remainder.
contract AddShareMetricMerge is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;

    address internal owner_;

    function setUp() public override {
        BaseSetup.setUp();
        owner_ = users[4];
        vm.prank(marketcreator);
        tts_token.setEnv(address(market));
    }

    function _mockGate(uint8 metric, bool result) internal {
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
        uint256 threshold = (uint256(1) << metric) * (uint256(1) << 128) +
            20_000_000;
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                I_TTSwap_Market.ishigher.selector,
                ttsGoodId,
                usdtGoodId,
                threshold
            ),
            abi.encode(result)
        );
    }

    function testAddShare_mergeKeepsExistingMetric() public {
        s_share memory g1 = s_share({leftamount: 1_000, metric: 0, chips: 2});
        s_share memory g2 = s_share({leftamount: 500, metric: 120, chips: 2});

        vm.startPrank(marketcreator);
        tts_token.addShare(g1, owner_);
        tts_token.addShare(g2, owner_);
        vm.stopPrank();

        s_share memory stored = tts_token.usershares(owner_);
        assertEq(stored.leftamount, 1_500, "leftamount summed");
        assertEq(stored.chips, 2, "chips merged");
        // Buggy code took max(metric) -> 120, re-gating the old remainder.
        assertEq(stored.metric, 0, "existing metric kept");

        // The merged balance mints under the ORIGINAL (low) bar.
        _mockGate(0, true);
        uint256 balBefore = tts_token.balanceOf(owner_);
        vm.prank(owner_);
        tts_token.shareMint();
        assertEq(tts_token.balanceOf(owner_), balBefore + 750, "minted 1500/2");
    }

    function testAddShare_mergeKeepsHigherExistingMetric() public {
        s_share memory g1 = s_share({leftamount: 1_000, metric: 120, chips: 2});
        s_share memory g2 = s_share({leftamount: 500, metric: 0, chips: 2});

        vm.startPrank(marketcreator);
        tts_token.addShare(g1, owner_);
        tts_token.addShare(g2, owner_);
        vm.stopPrank();

        // Keep-existing semantics: a later lower-metric grant does not lower
        // the bar either (matches upstream v2.1.0 RT-14b).
        assertEq(tts_token.usershares(owner_).metric, 120, "metric kept");
    }
}
