// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {console2} from "forge-std/src/Test.sol";
import {L_Proof} from "../../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../../src/libraries/L_TTSwapUINT256.sol";
import {S_GoodTmpState, S_GoodState, S_ProofState} from "../../src/interfaces/I_TTSwap_Market.sol";

library ProofUtil {
    using L_TTSwapUINT256Library for uint256;

    function showproof(S_ProofState memory p_) public pure {
        // console2.log('proof currentgood',T_GoodId.unwrap(p_.currentgood));
        // console2.log('proof valuegood',p_.valuegood);
        console2.log("proof extends:", uint256(p_.state.amount0()));
        console2.log("proof extends:", uint256(p_.state.amount1()));
        console2.log("proof invest:", uint256(p_.invest.amount0()));
        console2.log("proof invest:", uint256(p_.invest.amount1()));
        console2.log("proof valueinvest:", uint256(p_.valueinvest.amount0()));
        console2.log("proof valueinvest:", uint256(p_.valueinvest.amount1()));
    }
}
