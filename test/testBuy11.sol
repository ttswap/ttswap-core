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

    bytes internal constant defaultdata = abi.encode(L_CurrencyLibrary.S_transferData(1, "0X"));
    address usdtgood;
    address nativenormalgood;
    address btcgood;
    address ethgood;
    address normalgoodusdt;
    uint256 metaproofid;
    address marketcreator;

    MyToken usdt;
    MyToken eth;
    MyToken wbtc;
    S_GoodState ethstate;

    S_GoodState btcstate;

    function setUp() public {
        marketcreator = address(1);
        vm.startPrank(marketcreator);
        usdt = new MyToken("USDT", "USDT", 6);
        wbtc = new MyToken("BTC", "BTC", 8);
        eth = new MyToken("ETH", "ETH", 18);
        ethstate.init(
            toTTSwapUINT256(3991740104749, 830576621067531951132),
            574294852927029179450682055812555939397509459020590716783642472657759240192
        );

        btcstate.init(
            toTTSwapUINT256(2549265184202, 6171481752),
            574294852927029179450682055812555939397509459020590716783642472657759240192
        );
        vm.stopPrank();
    }

    function testBuyfromethtobtc() public view {
        uint128 swap = 10 * 10 ** 18;

        L_Good.swapCache memory swapcache = L_Good.swapCache({
            remainQuantity: swap,
            outputQuantity: 0,
            feeQuantity: 0,
            swapvalue: 0,
            good1currentState: ethstate.currentState,
            good1config: ethstate.goodConfig,
            good2currentState: btcstate.currentState,
            good2config: btcstate.goodConfig
        });

        L_Good.swapCompute1(swapcache);
        console2.log("1", swapcache.remainQuantity);
        console2.log("2", swapcache.outputQuantity);
    }
}
