// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test} from "forge-std/src/Test.sol";
import {console2} from "forge-std/src/console2.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {L_TTSTokenConfigLibrary} from "../src/libraries/L_TTSTokenConfig.sol";
import {I_TTSwap_Token, s_share, s_proof} from "../src/interfaces/I_TTSwap_Token.sol";

contract testTTSwapToken is Test, GasSnapshot {
    address payable[8] internal users;
    MyToken btc;
    MyToken usdt;
    MyToken eth;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Token tts_token;
    uint256 internal marketcreatorkey;

    using L_TTSTokenConfigLibrary for uint256;

    function setUp() public virtual {
        marketcreatorkey = 0xA121;
        marketcreator = vm.addr(marketcreatorkey);
        vm.warp(1728111156);
        
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);
        vm.startPrank(marketcreator);
        tts_token = new TTSwap_Token(address(usdt), marketcreator, 2 ** 255 + 10000);
        snapStart("depoly Market Manager");
        market = new TTSwap_Market( tts_token, marketcreator);
        snapEnd();

        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        vm.stopPrank();
    }

    function teststake() public {
        vm.warp(1728211156);
        vm.startPrank(marketcreator);

        tts_token.setCallMintTTS(users[1], true);
        vm.stopPrank();
        vm.startPrank(users[1]);
        tts_token.stake(users[2], 100000);
        vm.stopPrank();
        assertEq(tts_token.stakestate() % 2 ** 128, 100000, "pool value error");
        assertEq(tts_token.poolstate() / 2 ** 128, 10958904109, "pool asset error1");
        assertEq(tts_token.poolstate() % 2 ** 128, 0, "pool construct error");
        assertEq(tts_token.balanceOf(users[2]), 0, "tts balance error");
        console2.log("pool value", tts_token.stakestate() % 2 ** 128);
        console2.log("pool asset", tts_token.poolstate() / 2 ** 128);
        console2.log("pool construct", tts_token.poolstate() % 2 ** 128);
        console2.log("tts balance", tts_token.poolstate() % 2 ** 128);

        vm.stopPrank();
        vm.startPrank(users[1]);
        tts_token.unstake(users[2], 1000);
        vm.stopPrank();
        console2.log("pool value", tts_token.stakestate() % 2 ** 128);
        console2.log("pool asset", tts_token.poolstate() / 2 ** 128);
        console2.log("pool construct", tts_token.poolstate() % 2 ** 128);
        assertEq(tts_token.stakestate() % 2 ** 128, 99000, "pool value error");
        assertEq(tts_token.poolstate() / 2 ** 128, 10849315068, "pool asset erro2r");
        assertEq(tts_token.poolstate() % 2 ** 128, 0, "pool construct error");
        assertEq(tts_token.balanceOf(users[2]), 109589041, "tts balance error");
    }

    function testSetRatio() public {
        vm.startPrank(marketcreator);
        tts_token.setTokenAdmin(marketcreator, true);
        tts_token.setRatio(10000);
        uint256 result = tts_token.ttstokenconfig().getratio(10000);
        assertEq(10000, result, "Ratio error");
        vm.stopPrank();
    }

    function testAddShare() public {
        vm.startPrank(marketcreator);
        s_share memory _share = s_share(10000, 5, 6);
        tts_token.addShare(_share, users[5]);

        s_share memory share = tts_token.usershares(users[5]);
        uint128 leftamount = share.leftamount;
        uint128 metric = share.metric;
        uint8 chips = share.chips;
        assertEq(10000, leftamount, "left amount error");
        assertEq(5, metric, "left metric error");
        assertEq(6, chips, "left chips error");

        _share = s_share(20000, 7, 5);
        tts_token.addShare(_share, users[5]);

        share = tts_token.usershares(users[5]);
        leftamount = share.leftamount;
        metric = share.metric;
        chips = share.chips;
        assertEq(30000, leftamount, "left amount error");
        assertEq(7, metric, "left metric error");
        assertEq(6, chips, "left chips error");
        vm.stopPrank();
    }

    function testPermitAddShare() public {
        vm.startPrank(marketcreator);
        s_share memory _share = s_share(10000, 5, 6);
        tts_token.addShare(_share, users[5]);
        vm.stopPrank();

        bytes32 _PERMIT_TYPEHASH = keccak256(
            "permitShare(uint128 amount,uint120 chips,uint8 metric,address owner,uint128 existamount,uint128 deadline,uint256 nonce)"
        );
        vm.startPrank(marketcreator);
        _share = s_share(10000, 5, 6);
        uint128 dealline = uint128(block.timestamp + 10000);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                tts_token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH, _share.leftamount, _share.chips, _share.metric, users[5], 10000, dealline, 0
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(marketcreatorkey, digest);

        vm.stopPrank();

        vm.startPrank(users[5]);
        tts_token.permitShare(_share, dealline, bytes.concat(r, s, bytes1(v)),marketcreator);
        s_share memory share = tts_token.usershares(users[5]);
        uint128 leftamount = share.leftamount;
        uint128 metric = share.metric;
        uint8 chips = share.chips;
        assertEq(20000, leftamount, "left amount error");
        assertEq(5, metric, "left metric error");
        assertEq(6, chips, "left chips error");
        vm.stopPrank();
    }
}
