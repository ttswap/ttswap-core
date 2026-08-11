// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {FuzzBase} from "./FuzzBase.t.sol";
import {toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice Fuzz query/collect commission (TASK-P3-004).
contract Fuzz_CollectCommission is FuzzBase {
    address internal gate;

    function setUp() public override {
        super.setUp();
        gate = users[3];
        _fuzzPoolSetUp();

        vm.startPrank(FUZZ_USER);
        deal(address(btc), FUZZ_USER, 1 * 10 ** 8, false);
        btc.approve(address(market), type(uint256).max);
        _warp();
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, uint128(1 * 10 ** 8)),
            defaultdata,
            defaultdata,
            FUZZ_USER
        );
        market.disinvestProof(
            _proofId(FUZZ_USER, btcGoodId),
            uint128(1 * 10 ** 7),
            gate,
            FUZZ_USER,
            defaultdata
        );
        vm.stopPrank();
    }

    function testFuzz_QueryCommission_nonZero(uint8 goodCount) public {
        goodCount = uint8(bound(goodCount, 1, 3));
        uint256[] memory ids = new uint256[](goodCount);
        for (uint256 i = 0; i < goodCount; i++) {
            ids[i] = btcGoodId;
        }
        uint256[] memory gateAmt = market.queryCommission(ids, gate);
        assertGt(gateAmt[0], 1, "gate commission accrued");
    }

    function testFuzz_CollectCommission_idempotent() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;

        uint256[] memory before = market.queryCommission(ids, gate);
        if (before[0] <= 1) return;

        vm.startPrank(gate);
        market.collectCommission(ids, gate, defaultdata);
        uint256[] memory afterCollect = market.queryCommission(ids, gate);
        assertLe(afterCollect[0], 1, "collected to sentinel/zero");
        vm.stopPrank();
    }

    function testGas_CollectCommission() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;

        vm.startPrank(gate);
        market.collectCommission(ids, gate, defaultdata);
        _snapMarket("gas_baseline_collect_commission");
        vm.stopPrank();
    }
}
