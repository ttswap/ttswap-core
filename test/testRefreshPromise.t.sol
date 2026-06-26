// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice `refreshPromise` focused tests (TASK-P1-010 ~ P1-011).
contract testRefreshPromise is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    bytes32 internal constant PROMISE_TOPIC =
        keccak256("e_getPromiseProof(uint256,uint256)");

    uint128 internal constant BTC_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_VALUE = uint128(63_000 * 10 ** 12);

    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        btcGoodId = _initBtcGood(users[1]);
        _verifyAndPromiseGood(btcGoodId);
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }

    function _initBtcGood(address owner) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 10 * BTC_QTY, false);
        btc.approve(address(market), BTC_QTY);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(BTC_VALUE, BTC_QTY),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _verifyAndPromiseGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market
            .getGoodState(goodId)
            .goodConfig
            
            .setPromised(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function testRefreshPromise_happyPath() public {
        uint256 proofId = _proofId(users[1], btcGoodId);

        vm.startPrank(users[1]);
        vm.recordLogs();
        market.refreshPromise(proofId);
        snapLastCall("refresh_promise_owner");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == PROMISE_TOPIC) {
                found = true;
                assertEq(uint256(logs[i - 1].topics[1]), btcGoodId, "good id");
                assertEq(abi.decode(logs[i - 1].data, (uint256)), proofId, "proof id");
                break;
            }
        }
        assertTrue(found, "e_getPromiseProof emitted");
        vm.stopPrank();
    }

    function testRefreshPromise_revert_notOwner() public {
        uint256 proofId = _proofId(users[1], btcGoodId);

        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 19));
        market.refreshPromise(proofId);
    }
}
