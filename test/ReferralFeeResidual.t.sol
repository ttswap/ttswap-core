// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {toTTSwapUINT256, L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Regression for https://github.com/ttswap/ttswap-core/issues/311 —
///         referral-branch `allocateFee` stranded the ~2% fee residual: it was
///         deducted from the pool's investQty but credited to no commission ledger.
contract ReferralFeeResidualTest is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    address internal constant REFERRAL = address(0x5EED);

    function _setupPool() internal returns (T_GoodKey memory usdtKey, uint256 usdtId) {
        usdtKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        usdtId = usdtKey.toId();

        usdt.transfer(users[0], 200_000_000);
        usdt.transfer(users[1], 10_000_000);

        _warpToFreshRunSlot();
        vm.startPrank(users[0]);
        usdt.approve(address(market), type(uint256).max);
        market.initGood(
            usdtKey,
            toTTSwapUINT256(uint128(100_000_000_000_000_000), uint128(1_000_000)),
            defaultdata,
            users[0],
            defaultdata
        );
        market.goodWelfare(usdtId, 10_000_000, defaultdata, users[0], defaultdata);
        vm.stopPrank();

        _warpToFreshRunSlot();
        vm.startPrank(users[1]);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            usdtKey,
            toTTSwapUINT256(0, uint128(500_000)),
            defaultdata,
            defaultdata,
            users[1]
        );
        vm.stopPrank();
    }

    function _strandedAfterDisinvest(bool withReferral) internal returns (uint256) {
        (, uint256 usdtId) = _setupPool();

        if (withReferral) {
            vm.startPrank(marketcreator);
            tts_token.setCallMintTTS(marketcreator, true);
            tts_token.setReferral(users[1], REFERRAL);
            vm.stopPrank();
            assertEq(tts_token.getreferral(users[1]), REFERRAL);
        }

        uint256 proofId = S_ProofKey(users[1], usdtId).toId();
        uint128 shares = _partialDisinvestShares(proofId);
        assertGt(shares, 0);

        uint256[] memory ids = new uint256[](1);
        ids[0] = usdtId;
        address[4] memory parties = [address(0), users[1], REFERRAL, users[0]];

        uint256 qtyBefore = market.getGoodState(usdtId).currentState.amount0();
        uint256 balBefore = usdt.balanceOf(users[1]);
        uint256[4] memory commBefore;
        for (uint256 i = 0; i < parties.length; ++i) {
            commBefore[i] = market.queryCommission(ids, parties[i])[0];
        }

        _warpToFreshRunSlot();
        vm.prank(users[1]);
        market.disinvestProof(proofId, shares, address(0), users[1], defaultdata);

        uint256 qtyAfter = market.getGoodState(usdtId).currentState.amount0();
        uint256 balAfter = usdt.balanceOf(users[1]);

        uint256 accounted = balAfter - balBefore;
        for (uint256 i = 0; i < parties.length; ++i) {
            uint256 commAfter = market.queryCommission(ids, parties[i])[0];
            accounted += commAfter - commBefore[i];
        }
        return (qtyBefore - qtyAfter) - accounted;
    }

    function test_referral_branch_accounts_all_withdrawn_value() public {
        uint256 stranded = _strandedAfterDisinvest(true);
        assertEq(stranded, 0, "referral path must not strand fee residual");
    }

    function test_no_referral_branch_accounts_all_withdrawn_value() public {
        uint256 stranded = _strandedAfterDisinvest(false);
        assertEq(stranded, 0, "no-referral path already accounts fully");
    }
}
