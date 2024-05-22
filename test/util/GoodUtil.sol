// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2} from "forge-std/Test.sol";
import {L_Good} from "../../Contracts/libraries/L_Good.sol";
import {L_CurrencyLibrary} from "../../Contracts/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../../Contracts/libraries/L_GoodConfig.sol";

library GoodUtil {
    using L_GoodConfigLibrary for uint256;
    using L_CurrencyLibrary for address;

    function showGood(L_Good.S_GoodTmpState memory p_) public pure {
        console2.log("good owner:", p_.owner);
        //showconfig(p_.goodConfig);
        console2.log("good erc20address:", p_.erc20address);
        console2.log("good currentState:", uint256(p_.currentState.amount0()));
        console2.log("good currentState:", uint256(p_.currentState.amount1()));
        console2.log("good investState:", uint256(p_.investState.amount0()));
        console2.log("good investState:", uint256(p_.investState.amount1()));
        console2.log("good feeQunitityState:", uint256(p_.feeQunitityState.amount0()));
        console2.log("good feeQunitityState:", uint256(p_.feeQunitityState.amount1()));
    }

    function showconfig(uint256 _goodConfig) public pure {
        console2.log("good goodConfig:isvaluegood:", _goodConfig.isvaluegood());
        console2.log("good goodConfig:getInvestFee:", uint256(_goodConfig.getInvestFee()));
        console2.log("good goodConfig:getDisinvestFee:", uint256(_goodConfig.getDisinvestFee()));
        console2.log("good goodConfig:getBuyFee:", uint256(_goodConfig.getBuyFee()));
        console2.log("good goodConfig:getSellFee:", uint256(_goodConfig.getSellFee()));
        console2.log("good goodConfig:getSwapChips:", uint256(_goodConfig.getSwapChips()));
    }
}
