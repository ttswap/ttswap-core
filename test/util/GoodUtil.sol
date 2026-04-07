// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {console2} from "forge-std/src/Test.sol";
import {L_Good} from "../../src/libraries/L_Good.sol";
import {S_GoodTmpState, S_GoodState, S_ProofState} from "../../src/interfaces/I_TTSwap_Market.sol";
import {L_CurrencyLibrary} from "../../src/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../../src/libraries/L_GoodConfig.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../../src/libraries/L_TTSwapUINT256.sol";

library GoodUtil {
    using L_GoodConfigLibrary for uint256;
    using L_CurrencyLibrary for address;
    using L_TTSwapUINT256Library for uint256;

    function showGood(S_GoodTmpState memory p_) public pure {
        console2.log("good owner:", p_.owner);
        //showconfig(p_.goodConfig);
        console2.log("good currentState:", uint256(p_.currentState.amount0()));
        console2.log("good currentState:", uint256(p_.currentState.amount1()));
        console2.log("good investState:", uint256(p_.investState.amount0()));
        console2.log("good investState:", uint256(p_.investState.amount1()));
    }
}
