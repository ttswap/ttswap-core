// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import { S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {ProofUtil} from "./util/ProofUtil.sol";
import {GoodUtil} from "./util/GoodUtil.sol";

contract testBuy123 is Test {
   
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;
    using L_CurrencyLibrary for address;
    using L_TTSwapUINT256Library for uint256;

    address usdtgood;
    address nativenormalgood;
    address btcgood;
    address ethgood;
    address normalgoodusdt;
    uint256 metaproofid;
    address marketcreator;

    TTSwap_Market market;
    TTSwap_Token tts_token;
    MyToken usdt;
    MyToken eth;
    MyToken wbtc;
    bytes internal constant defaultdata = bytes("");

    function setUp() public {
        marketcreator = address(1);
        vm.startPrank(marketcreator);
        usdt = new MyToken("USDT", "USDT", 6);
        wbtc = new MyToken("BTC", "BTC", 8);
        eth = new MyToken("ETH", "ETH", 18);
        TTSwap_Token tts_token_logic = new TTSwap_Token(address(usdt), marketcreator, 2 ** 255 + 10000);
        TTSwap_Token_Proxy tts_token_proxy=new TTSwap_Token_Proxy(address(usdt), marketcreator,  2 ** 255 + 10000,"TTSwap Token","TTS",address(tts_token_logic));
        tts_token=TTSwap_Token(payable(address(tts_token_proxy)));
       
        TTSwap_Market market2 = new TTSwap_Market();
        TTSwap_Market_Proxy  market_proxy=new TTSwap_Market_Proxy(tts_token,address(market2));
        market= TTSwap_Market( payable(address(market_proxy)));

        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        //81562183917421901855786361352751956561780156203962646020495653018153967943680
        //            (45*2**250+5*2**244+10*2**238+15*2**232+25*2**226+20*2**221)

        deal(address(usdt), marketcreator, 10 ** 10 * 10 ** 6, false);
        usdt.approve(address(market), 10 ** 10 * 10 ** 6);
        console2.log(1, 1);
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(4316279969830, 4316279969830),
            58014493144340224047723362035128774673999617126840714024924520715586495315968 + 2 * 2 ** 216 + 10 * 2 ** 206,
            defaultdata
        );
        console2.log(1, 1);
        usdtgood = address(usdt);
        //58014493144340224047723362035128774673999617126840714024924520715586495315968 ((2 ** 255) + 1 * 2 ** 246 + 3 * 2 ** 240 + 5 * 2 ** 233 + 7 * 2 ** 226)
        //34028236692093846346337460743176821145700000000000(100000000000*2**128+100000000000)

        deal(address(eth), marketcreator, 10 ** 5 * 10 ** 18, false);

        eth.approve(address(market), 100 * 10 ** 18);
        market.initGood(
            usdtgood,
            toTTSwapUINT256(10 * 10 ** 18, 33000 * 10 ** 6),
            address(eth),
            574294852927029179450682055812555939397509459020590716783642472657759240192,
            defaultdata,
            defaultdata
        );
        ethgood = address(eth);

        deal(address(wbtc), marketcreator, 10 ** 5 * 10 ** 18, false);
        wbtc.approve(address(market), 100 * 10 ** 8);
        market.initGood(
            usdtgood,
            toTTSwapUINT256(2 * 10 ** 8, 128000 * 10 ** 6),
            address(wbtc),
            574294852927029179450682055812555939397509459020590716783642472657759240192,
            defaultdata,
            defaultdata
        );

        btcgood = address(wbtc);
        vm.stopPrank();
    }

    function testBuyfromethtobtc() public {
        vm.startPrank(marketcreator);
        console2.log("before balance of eth", eth.balanceOf(marketcreator));
        console2.log("before balance of wbtc", wbtc.balanceOf(marketcreator));
        market.buyGood(ethgood, btcgood, 1 * 10 ** 18, 99, address(0), defaultdata);
        console2.log("after balance of eth", eth.balanceOf(marketcreator));
        console2.log("after balance of wbtc", wbtc.balanceOf(marketcreator));
        console2.log(33000 * 10 ** 6 * 2 * 10 ** 5 * 995, 10 * 10 ** 18 * 128000 * 10 ** 6);
        vm.stopPrank();
    }
}
