// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {toTTSwapUINT256, L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

contract DisinvestTruncationUnderflowTest is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    function test_disinvestGood_share_mint_truncation_does_not_freeze() public {
        T_GoodKey memory usdtKey = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        });
        uint256 usdtId = usdtKey.toId();

        uint128 initQty = 1_000_000;
        uint128 initVal = 100_000_000_000_000_000;
        usdt.transfer(users[0], 200_000_000);
        usdt.transfer(users[1], 10_000);

        _warpToFreshRunSlot();
        vm.startPrank(users[0]);
        usdt.approve(address(market), type(uint256).max);
        market.initGood(
            usdtKey,
            toTTSwapUINT256(initVal, initQty),
            defaultdata,
            users[0],
            defaultdata
        );

        market.goodWelfare(usdtId, 99_000_000, defaultdata, users[0], defaultdata);
        vm.stopPrank();

        _warpToFreshRunSlot();
        vm.startPrank(users[1]);
        usdt.approve(address(market), type(uint256).max);
        market.investGood(
            usdtKey,
            toTTSwapUINT256(1_249_000_000_000, 1249),
            defaultdata,
            defaultdata,
            users[1]
        );

        uint256 proofId = S_ProofKey(users[1], usdtId).toId();
        uint128 lp2Shares = market.getProofState(proofId).shares.amount0();
        assertEq(lp2Shares, 12);


        // Regression: disinvesting the truncated position must not underflow
        // (previously every share amount 1..proofShares0 reverted Panic 0x11).
        // A 1-share request hits the dust-closeout path and exits the position.
        _warpToFreshRunSlot();
        market.disinvestProof(proofId, 1, address(0), users[1], defaultdata);
        assertEq(market.getProofState(proofId).shares.amount0(), 0);
        vm.stopPrank();
    }
}
