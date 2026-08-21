// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {L_Good} from "../libraries/L_Good.sol";
import {L_Proof} from "../libraries/L_Proof.sol";
import {L_GoodConfigLibrary} from "../libraries/L_GoodConfig.sol";
import {T_GoodKey} from "../type/T_GoodKey.sol";
import {S_GoodState, S_ProofState} from "../interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../libraries/L_TTSwapUINT256.sol";

/// @dev Public wrapper for `L_Good` unit tests (no Market contract).
contract GoodHarness {
    using L_Good for S_GoodState;
    using L_Proof for S_ProofState;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    mapping(uint256 => S_GoodState) internal goods;
    mapping(uint256 => S_ProofState) internal proofs;

    function init(uint256 id, uint256 initial, T_GoodKey memory key) external {
        goods[id].init(initial, key);
        (uint128 initVal, uint128 initQty) = initial.amount01();
        proofs[id].updateInvest(
            id,
            toTTSwapUINT256(initQty, 0),
            toTTSwapUINT256(initVal, initVal),
            toTTSwapUINT256(initQty, initQty)
        );
    }

    function relaxSafeLine(uint256 id) external {
        uint256 cfg = goods[id].goodConfig;
        uint256 mask = (uint256(0xFF) << 247) | (uint256(0xFF) << 239);
        goods[id].updateConfigbyAdmin(
            (cfg & ~mask) | (uint256(255) << 247) | (uint256(1) << 239)
        );
    }

    function updateOwner(uint256 id, uint256 cfg) external {
        goods[id].updateConfigbyGoodOwner(cfg);
    }

    function updateManager(uint256 id, uint256 cfg) external {
        goods[id].updateConfigbyManager(cfg);
    }

    function updateAdmin(uint256 id, uint256 cfg) external {
        goods[id].updateConfigbyAdmin(cfg);
    }

    function lockGood(uint256 id) external {
        goods[id].lockGood();
    }

    function buyInput(uint256 id, uint128 qty) external returns (uint256) {
        return goods[id].buyGoodInput(qty);
    }

    function buyOutput(uint256 id, uint128 valueIn) external returns (uint256) {
        return goods[id].buyGoodOutput(valueIn);
    }

    function payOutput(uint256 id, uint128 qtyOut) external returns (uint256) {
        return goods[id].payGoodOutput(qtyOut);
    }

    function payInput(uint256 id, uint128 valueIn) external returns (uint256) {
        return goods[id].payGoodInput(valueIn);
    }

    function invest(uint256 id, uint128 qty, uint128 enpower) external returns (L_Good.S_GoodInvestReturn memory r) {
        (r.goodShares, r.goodValues) = goods[id].investState.amount01();
        (r.goodInvestQuantity, r.goodCurrentQuantity) = goods[id].currentState.amount01();
        goods[id].investGood(qty, r, enpower);
        proofs[id].updateInvest(
            id,
            toTTSwapUINT256(r.investShare, 0),
            toTTSwapUINT256(r.investValue, r.investValue),
            toTTSwapUINT256(r.investQuantity, qty - r.investFeeQuantity)
        );
    }

    function disinvest(
        uint256 id,
        uint128 shares,
        address gater,
        address referral,
        address sender
    ) external returns (L_Good.S_GoodDisinvestReturn memory r, uint256 value) {
        (r, value) = goods[id].disinvestGood(
            proofs[id],
            L_Good.S_GoodDisinvestParam(shares, gater, referral, sender)
        );
    }

    function getGoodState(uint256 id) external view returns (uint256) {
        return goods[id].getGoodState();
    }

    function getBalanceLimit(uint256 id) external view returns (uint256) {
        return goods[id].getBalanceLimit();
    }

    function toGoodKey(uint256 id) external view returns (T_GoodKey memory) {
        return goods[id].toGoodKey();
    }

    function goodConfig(uint256 id) external view returns (uint256) {
        return goods[id].goodConfig;
    }

    function currentState(uint256 id) external view returns (uint256) {
        return goods[id].currentState;
    }

    function investState(uint256 id) external view returns (uint256) {
        return goods[id].investState;
    }

    function ownerOf(uint256 id) external view returns (address) {
        return goods[id].owner;
    }

    function setOwner(uint256 id, address owner) external {
        goods[id].owner = owner;
    }

    function setCurrentState(uint256 id, uint256 v) external {
        goods[id].currentState = v;
    }

    function setProof(uint256 id, uint256 sharePacked, uint256 statePacked, uint256 investPacked) external {
        proofs[id].shares = sharePacked;
        proofs[id].state = statePacked;
        proofs[id].invest = investPacked;
    }

    function proofShares(uint256 id) external view returns (uint256) {
        return proofs[id].shares;
    }

    function commissionOf(uint256 id, address who) external view returns (uint256) {
        return goods[id].commission[who];
    }
}
