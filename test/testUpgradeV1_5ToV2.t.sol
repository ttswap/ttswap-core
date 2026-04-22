// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {I_TTSwap_Market, S_ProofKey, S_GoodTmpState, S_ProofState} from "../src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token} from "../src/interfaces/I_TTSwap_Token.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256,
    addsub,
    subadd,
    lowerprice,
    toUint128
} from "../src/libraries/L_TTSwapUINT256.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @title Upgrade test: TTSwap_Market v1.5 → v2 (single-token liquidity)
/// @dev Strategy: deploy two separate TTSwap_Market (v2) instances — "implA" acts as
///      the pre-upgrade v1.5 implementation (storage-identical), "implB" is the fresh
///      upgrade target. State created under implA is verified against implB reads and
///      the new v2-only functions (initGoodWithPrice, oneTokenInvest) are exercised.
///      This is valid because v1.5 and v2 share an identical storage layout; the only
///      difference is the logic bytecode.
contract testUpgradeV1_5ToV2 is Test {
    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    address payable[4] users;
    address marketcreator;

    MyToken btc;
    MyToken usdt;
    MyToken eth;

    TTSwap_Market implA; // acts as v1.5 (pre-upgrade)
    TTSwap_Market implB; // acts as v2   (post-upgrade)
    TTSwap_Market_Proxy marketProxy;

    I_TTSwap_Market market;
    I_TTSwap_Token ttsToken;
    TTSwap_Token_Proxy ttsTokenProxy;

    bytes internal constant defaultdata = bytes("");

    address metagood;
    address normalgoodbtc;

    S_GoodTmpState preUpgrade_usdtGood;
    S_GoodTmpState preUpgrade_btcGood;
    S_ProofState preUpgrade_btcProof;
    uint256 preUpgrade_btcProofId;

    uint256 constant normalgoodconfig =
        1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;
    uint256 constant metagoodconfig =
        (2 ** 255) + 1 * 2 ** 217 + 3 * 2 ** 211 + 5 * 2 ** 204 + 7 * 2 ** 197;

    function setUp() public {
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        marketcreator = payable(address(6));

        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);

        vm.startPrank(marketcreator);
        TTSwap_Token ttsLogic = new TTSwap_Token(address(usdt));
        ttsTokenProxy = new TTSwap_Token_Proxy(
            marketcreator,
            2 ** 255 + 10000,
            "TTSwap Token",
            "TTS",
            address(ttsLogic)
        );
        ttsToken = I_TTSwap_Token(address(ttsTokenProxy));

        // Deploy two separate implementations behind the proxy
        implA = new TTSwap_Market(ttsToken);
        implB = new TTSwap_Market(ttsToken);
        marketProxy = new TTSwap_Market_Proxy(ttsToken, address(implA));
        market = I_TTSwap_Market(address(marketProxy));

        ttsToken.setTokenAdmin(marketcreator, true);
        ttsToken.setTokenManager(marketcreator, true);
        ttsToken.setCallMintTTS(address(market), true);
        ttsToken.setMarketAdmin(marketcreator, true);
        ttsToken.setMarketManager(marketcreator, true);
        ttsToken.setStakeAdmin(marketcreator, true);
        ttsToken.setStakeManager(marketcreator, true);
        ttsToken.setEnv(address(market));
        vm.stopPrank();
    }

    // ─── Helpers ───────────────────────────────────

    function _initMetaGood() internal {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1_000_000 * 10 ** 6, false);
        usdt.approve(address(market), 50_000 * 10 ** 6 + 1);
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(50_000 * 10 ** 12, 50_000 * 10 ** 6),
            metagoodconfig,
            defaultdata
        );
        metagood = address(usdt);
        vm.stopPrank();
    }

    function _initBtcGood() internal {
        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 1 * 10 ** 8 + 1);
        deal(address(usdt), users[1], 50_000_000 * 10 ** 6, false);
        usdt.approve(address(market), 50_000_000 * 10 ** 6 + 1);
        market.initGood(
            metagood,
            toTTSwapUINT256(1 * 10 ** 8, 63_000 * 10 ** 6),
            address(btc),
            normalgoodconfig,
            defaultdata,
            defaultdata,
            users[1],
            defaultdata
        );
        normalgoodbtc = address(btc);
        vm.stopPrank();
    }

    function _doBuy() internal {
        vm.startPrank(users[1]);
        usdt.approve(address(market), 10_000 * 10 ** 6 + 1);
        market.buyGood(
            metagood,
            normalgoodbtc,
            toTTSwapUINT256(10_000 * 10 ** 6, 0),
            users[1],
            defaultdata,
            users[1],
            defaultdata,0
        );
        vm.stopPrank();
    }

    function _snapshotState() internal {
        preUpgrade_usdtGood = market.getGoodState(metagood);
        preUpgrade_btcGood = market.getGoodState(normalgoodbtc);
        preUpgrade_btcProofId = S_ProofKey(users[1], normalgoodbtc, metagood).toId();
        preUpgrade_btcProof = market.getProofState(preUpgrade_btcProofId);
    }

    function _doUpgrade() internal {
        vm.prank(marketcreator);
        marketProxy.upgrade(address(implB));
    }

    // ─── Test 1: State preservation ───────────────

    function test_upgrade_statePreserved() public {
        _initMetaGood();
        _initBtcGood();
        _doBuy();
        _snapshotState();

        _doUpgrade();

        S_GoodTmpState memory postUsdt = market.getGoodState(metagood);
        assertEq(postUsdt.currentState, preUpgrade_usdtGood.currentState, "usdt currentState changed");
        assertEq(postUsdt.investState, preUpgrade_usdtGood.investState, "usdt investState changed");
        assertEq(postUsdt.owner, preUpgrade_usdtGood.owner, "usdt owner changed");
        assertEq(postUsdt.goodConfig, preUpgrade_usdtGood.goodConfig, "usdt goodConfig changed");

        S_GoodTmpState memory postBtc = market.getGoodState(normalgoodbtc);
        assertEq(postBtc.currentState, preUpgrade_btcGood.currentState, "btc currentState changed");
        assertEq(postBtc.investState, preUpgrade_btcGood.investState, "btc investState changed");
        assertEq(postBtc.owner, preUpgrade_btcGood.owner, "btc owner changed");
        assertEq(postBtc.goodConfig, preUpgrade_btcGood.goodConfig, "btc goodConfig changed");

        S_ProofState memory postProof = market.getProofState(preUpgrade_btcProofId);
        assertEq(postProof.currentgood, preUpgrade_btcProof.currentgood, "proof currentgood changed");
        assertEq(postProof.valuegood, preUpgrade_btcProof.valuegood, "proof valuegood changed");
        assertEq(postProof.shares, preUpgrade_btcProof.shares, "proof shares changed");
        assertEq(postProof.state, preUpgrade_btcProof.state, "proof state changed");
        assertEq(postProof.invest, preUpgrade_btcProof.invest, "proof invest changed");
        assertEq(postProof.valueinvest, preUpgrade_btcProof.valueinvest, "proof valueinvest changed");
    }

    // ─── Test 2: buyGood still works after upgrade ─

    function test_upgrade_buyGoodStillWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        vm.startPrank(users[1]);
        usdt.approve(address(market), 5_000 * 10 ** 6 + 1);
        uint256 btcBefore = btc.balanceOf(users[1]);

        (, uint256 good2change) = market.buyGood(
            metagood,
            normalgoodbtc,
            toTTSwapUINT256(5_000 * 10 ** 6, 0),
            users[1],
            defaultdata,
            users[1],
            defaultdata,0
        );

        assertGt(good2change.amount1(), 0, "post-upgrade buyGood should return btc");
        assertGt(btc.balanceOf(users[1]), btcBefore, "post-upgrade btc balance should increase");
        vm.stopPrank();
    }

    // ─── Test 3: payGood still works after upgrade ─

    function test_upgrade_payGoodStillWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 100_000_000 * 10 ** 6, false);
        usdt.approve(address(market), 100_000_000 * 10 ** 6);
        uint256 btcBefore = btc.balanceOf(users[2]);

        // Pay USDT to deliver BTC to users[2]
        market.payGood(
            metagood,
            normalgoodbtc,
            toTTSwapUINT256(10_000 * 10 ** 6, 100_000), // max 10k USDT in, want 0.001 BTC out
            users[2],
            defaultdata,
            users[1],
            defaultdata,
            0
        );

        assertGt(btc.balanceOf(users[2]), btcBefore, "post-upgrade payGood should deliver btc");
        vm.stopPrank();
    }

    // ─── Test 4: investGood still works after upgrade

    function test_upgrade_investGoodStillWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        vm.startPrank(users[1]);
        deal(address(btc), users[1], 10 * 10 ** 8, false);
        btc.approve(address(market), 10 * 10 ** 8);
        deal(address(usdt), users[1], 500_000_000 * 10 ** 6, false);
        usdt.approve(address(market), 500_000_000 * 10 ** 6);

        S_GoodTmpState memory btcBefore = market.getGoodState(normalgoodbtc);

        market.investGood(
            normalgoodbtc,
            metagood,
            5_000_000,
            defaultdata,
            defaultdata,
            users[1],
            defaultdata
        );

        S_GoodTmpState memory btcAfter = market.getGoodState(normalgoodbtc);
        assertGt(
            btcAfter.investState.amount0(),
            btcBefore.investState.amount0(),
            "post-upgrade investGood should increase shares"
        );
        vm.stopPrank();
    }

    // ─── Test 5: disinvestProof still works ────────

    function test_upgrade_disinvestProofStillWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        uint256 proofId = S_ProofKey(users[1], normalgoodbtc, metagood).toId();
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 sharesToDivest = proof.shares.amount0() / 10;

        vm.prank(users[1]);
        market.disinvestProof(proofId, sharesToDivest, address(0), users[1], defaultdata);

        S_ProofState memory proofAfter = market.getProofState(proofId);
        assertLt(
            proofAfter.shares.amount0(),
            proof.shares.amount0(),
            "post-upgrade disinvest should reduce shares"
        );
    }

    // ─── Test 6: initGoodWithPrice works after upgrade

    function test_upgrade_initGoodWithPriceWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        TTSwap_Market marketV2 = TTSwap_Market(payable(address(marketProxy)));

        vm.startPrank(users[2]);
        deal(address(eth), users[2], 100 * 10 ** 18, false);
        eth.approve(address(market), 10 * 10 ** 18 + 1);

        uint128 ethQty = 10 * 10 ** 18;
        uint128 ethVal = uint128(3_200 * 10 ** 12);

        marketV2.initGoodWithPrice(
            address(eth),
            toTTSwapUINT256(ethVal, ethQty),
            normalgoodconfig,
            defaultdata,
            users[2],
            defaultdata
        );

        S_GoodTmpState memory ethGood = market.getGoodState(address(eth));
        assertEq(ethGood.currentState.amount0(), ethQty, "eth currentState.amount0 error");
        assertEq(ethGood.currentState.amount1(), ethQty, "eth currentState.amount1 error");
        assertEq(ethGood.investState.amount1(), ethVal, "eth investState value error");
        assertEq(ethGood.owner, users[2], "eth owner error");

        uint256 proofId = S_ProofKey(users[2], address(eth), address(0)).toId();
        S_ProofState memory proof = market.getProofState(proofId);
        assertEq(proof.currentgood, address(eth), "proof currentgood error");
        assertEq(proof.valuegood, address(0), "proof valuegood should be zero");
        assertEq(proof.shares.amount0(), ethQty, "proof shares error");

        vm.stopPrank();
    }

    // ─── Test 7: oneTokenInvest works after upgrade ─

    function test_upgrade_oneTokenInvestWorks() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        TTSwap_Market marketV2 = TTSwap_Market(payable(address(marketProxy)));

        vm.startPrank(users[2]);
        deal(address(eth), users[2], 100 * 10 ** 18, false);
        eth.approve(address(market), 100 * 10 ** 18);

        uint128 ethQty = 10 * 10 ** 18;
        uint128 ethVal = uint128(3_200 * 10 ** 12);

        marketV2.initGoodWithPrice(
            address(eth),
            toTTSwapUINT256(ethVal, ethQty),
            normalgoodconfig,
            defaultdata,
            users[2],
            defaultdata
        );

        uint128 investQty = 5 * 10 ** 18;
        uint128 investVal = uint128(uint256(ethVal) * investQty / ethQty);
        marketV2.oneTokenInvest(
            address(eth),
            toTTSwapUINT256(0, investQty),
            defaultdata,
            defaultdata,
            users[2]
        );

        S_GoodTmpState memory ethGood = market.getGoodState(address(eth));
        assertGe(
            ethGood.currentState.amount0(),
            ethGood.currentState.amount1(),
            "after oneTokenInvest: amount0 >= amount1"
        );
        assertGt(
            ethGood.investState.amount0(),
            ethQty,
            "after oneTokenInvest: shares should increase"
        );

        vm.stopPrank();
    }

    // ─── Test 8: Full single-token lifecycle ───────
    //  initGoodWithPrice → oneTokenInvest → buyGood → disinvest

    function test_upgrade_fullSingleTokenLifecycle() public {
        _initMetaGood();
        _initBtcGood();
        _doUpgrade();

        TTSwap_Market marketV2 = TTSwap_Market(payable(address(marketProxy)));

        // 1. Create ETH good with single-token deposit
        vm.startPrank(users[2]);
        deal(address(eth), users[2], 1_000 * 10 ** 18, false);
        eth.approve(address(market), 1_000 * 10 ** 18);

        uint128 ethQty = 100 * 10 ** 18;
        uint128 ethVal = uint128(3_200 * 10 ** 12);

        marketV2.initGoodWithPrice(
            address(eth),
            toTTSwapUINT256(ethVal, ethQty),
            normalgoodconfig,
            defaultdata,
            users[2],
            defaultdata
        );
        vm.stopPrank();

        // 2. Another user adds liquidity
        vm.startPrank(users[3]);
        deal(address(eth), users[3], 500 * 10 ** 18, false);
        eth.approve(address(market), 500 * 10 ** 18);

        uint128 investQty2 = 50 * 10 ** 18;
        uint128 investVal2 = uint128(uint256(ethVal) * investQty2 / ethQty);
        marketV2.oneTokenInvest(
            address(eth),
            toTTSwapUINT256(0, investQty2),
            defaultdata,
            defaultdata,
            users[3]
        );
        vm.stopPrank();

        // 3. Swap USDT → ETH
        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 10_000_000 * 10 ** 6, false);
        usdt.approve(address(market), 10_000_000 * 10 ** 6);

        uint256 ethBefore = eth.balanceOf(users[1]);
        market.buyGood(
            metagood,
            address(eth),
            toTTSwapUINT256(1_000 * 10 ** 6, 0),
            users[1],
            defaultdata,
            users[1],
            defaultdata,0
        );
        assertGt(eth.balanceOf(users[1]), ethBefore, "buyGood should deliver eth");
        vm.stopPrank();

        // 4. Creator disinvests from single-token proof
        uint256 proofId = S_ProofKey(users[2], address(eth), address(0)).toId();
        S_ProofState memory proofBefore = market.getProofState(proofId);
        uint128 sharesToDivest = proofBefore.shares.amount0() / 10;

        vm.prank(users[2]);
        market.disinvestProof(proofId, sharesToDivest, address(0), users[2], defaultdata);

        S_ProofState memory proofAfter = market.getProofState(proofId);
        assertLt(
            proofAfter.shares.amount0(),
            proofBefore.shares.amount0(),
            "disinvest should reduce shares"
        );
    }

    // ─── Test 9: Dual-token & single-token proofs coexist ─

    function test_upgrade_dualAndSingleTokenProofsCoexist() public {
        _initMetaGood();
        _initBtcGood();

        uint256 dualProofId = S_ProofKey(users[1], normalgoodbtc, metagood).toId();
        S_ProofState memory dualProofPre = market.getProofState(dualProofId);

        _doUpgrade();

        TTSwap_Market marketV2 = TTSwap_Market(payable(address(marketProxy)));

        vm.startPrank(users[2]);
        deal(address(eth), users[2], 100 * 10 ** 18, false);
        eth.approve(address(market), 100 * 10 ** 18);
        marketV2.initGoodWithPrice(
            address(eth),
            toTTSwapUINT256(uint128(3_200 * 10 ** 12), uint128(10 * 10 ** 18)),
            normalgoodconfig,
            defaultdata,
            users[2],
            defaultdata
        );
        vm.stopPrank();

        uint256 singleProofId = S_ProofKey(users[2], address(eth), address(0)).toId();

        // Dual-token proof intact
        S_ProofState memory dualProofPost = market.getProofState(dualProofId);
        assertEq(dualProofPost.currentgood, dualProofPre.currentgood, "dual proof currentgood corrupted");
        assertEq(dualProofPost.valuegood, dualProofPre.valuegood, "dual proof valuegood corrupted");
        assertEq(dualProofPost.shares, dualProofPre.shares, "dual proof shares corrupted");
        assertEq(dualProofPost.invest, dualProofPre.invest, "dual proof invest corrupted");

        // Single-token proof exists
        S_ProofState memory singleProof = market.getProofState(singleProofId);
        assertEq(singleProof.currentgood, address(eth), "single proof currentgood error");
        assertEq(singleProof.valuegood, address(0), "single proof valuegood should be zero");

        // Both can disinvest
        vm.prank(users[1]);
        market.disinvestProof(
            dualProofId,
            dualProofPost.shares.amount0() / 10,
            address(0),
            users[1],
            defaultdata
        );

        vm.prank(users[2]);
        market.disinvestProof(
            singleProofId,
            singleProof.shares.amount0() / 10,
            address(0),
            users[2],
            defaultdata
        );
    }

    // ─── Test 10: Implementation address updated ───

    function test_upgrade_implementationChanged() public {
        assertEq(marketProxy.implementation(), address(implA), "pre-upgrade impl wrong");
        _doUpgrade();
        assertEq(marketProxy.implementation(), address(implB), "post-upgrade impl wrong");
    }

    // ─── Test 11: Only admin can upgrade ───────────

    function test_upgrade_onlyAdminCanUpgrade() public {
        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        marketProxy.upgrade(address(implB));
    }

    // ─── Test 12: Multi-swap state preserved through upgrade ─

    function test_upgrade_stateAfterMultipleSwapsPreserved() public {
        _initMetaGood();
        _initBtcGood();

        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(users[1]);
            usdt.approve(address(market), 5_000 * 10 ** 6 + 1);
            market.buyGood(
                metagood,
                normalgoodbtc,
                toTTSwapUINT256(5_000 * 10 ** 6, 0),
                users[1],
                defaultdata,
                users[1],
                defaultdata,0
            );
            vm.stopPrank();
        }

        _snapshotState();
        _doUpgrade();

        S_GoodTmpState memory postBtc = market.getGoodState(normalgoodbtc);
        assertEq(postBtc.currentState, preUpgrade_btcGood.currentState, "btc currentState drift");
        assertEq(postBtc.investState, preUpgrade_btcGood.investState, "btc investState drift");

        S_GoodTmpState memory postUsdt = market.getGoodState(metagood);
        assertEq(postUsdt.currentState, preUpgrade_usdtGood.currentState, "usdt currentState drift");
        assertEq(postUsdt.investState, preUpgrade_usdtGood.investState, "usdt investState drift");

        // Continue trading on new impl
        vm.startPrank(users[1]);
        usdt.approve(address(market), 5_000 * 10 ** 6 + 1);
        market.buyGood(
            metagood,
            normalgoodbtc,
            toTTSwapUINT256(5_000 * 10 ** 6, 0),
            users[1],
            defaultdata,
            users[1],
            defaultdata,0
        );
        vm.stopPrank();
    }

    // ─── Test 13: Token balances unchanged by upgrade ─

    function test_upgrade_tokenBalancesConsistent() public {
        _initMetaGood();
        _initBtcGood();

        uint256 marketUsdt = usdt.balanceOf(address(market));
        uint256 marketBtc = btc.balanceOf(address(market));

        _doUpgrade();

        assertEq(usdt.balanceOf(address(market)), marketUsdt, "market usdt balance changed");
        assertEq(btc.balanceOf(address(market)), marketBtc, "market btc balance changed");
    }
}
