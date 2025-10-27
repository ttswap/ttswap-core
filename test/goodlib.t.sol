// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import { S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract testBuy11 is Test {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;
    using L_CurrencyLibrary for address;
    using L_TTSwapUINT256Library for uint256;
    using L_Good for S_GoodState;

    S_GoodState good1;

    function setUp() public {}

    function testUpdateGood() public {
        uint256 _goodConfig = 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
        good1.updateGoodConfig(_goodConfig);
        assertEq(_goodConfig, good1.goodConfig, "update goodconfig error");
        uint256 _goodConfig1 =  92709122<<229;
        good1.modifyGoodConfig(_goodConfig1);
        console2.log(good1.goodConfig);
        console2.log(_goodConfig);
        console2.log(good1.goodConfig.isvaluegood());
        assertEq(
            _goodConfig1  + _goodConfig,
            good1.goodConfig+2**255,
            "modified godoconfig error"
        );
    }
}
