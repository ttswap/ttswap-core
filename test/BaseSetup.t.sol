// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {L_CurrencyLibrary} from "../src/libraries/L_Currency.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";
    import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {TestConfigConstants} from "./TestConfigConstants.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {S_GoodTmpState} from "../src/interfaces/I_TTSwap_Market.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

contract BaseSetup is Test, GasSnapshot {
    using L_GoodConfigLibrary for uint256;
    using L_TTSwapUINT256Library for uint256;
    address payable[8] internal users;
    MyToken btc;
    MyToken usdt;
    MyToken eth;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Market_Proxy market_proxy;
    TTSwap_Token tts_token;
    TTSwap_Token_Proxy tts_token_proxy;
    bytes internal constant defaultdata = bytes("");

    uint256 internal opTimestamp = 10;
    /// @dev Monotonic block cursor so consecutive `_warpToFreshRunSlot` calls always advance.
    uint256 internal runSlotBlock;

    uint256 internal constant SAFE_LINE_MASK =
        (uint256(0xFF) << TestConfigConstants.SAFE_LINE_UPPER_SHIFT) |
        (uint256(0xFF) << TestConfigConstants.SAFE_LINE_LOWER_SHIFT);

    /// @dev v2.0 removed on-chain good verification; no-op for legacy test setup hooks.
    function _verifyGood(uint256 /* goodId */) internal {}

    /// @dev Mark good as value-good without clearing other admin bits (safeLine / reserved).
    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig | (1 << 255);
        market.modifyGoodByAdmin(goodId, cfg, marketcreator, defaultdata);
        _snapMarket("modifyGoodByAdmin_markValue");
        vm.stopPrank();
    }

    function _expectedInitGoodConfig() internal pure returns (uint256) {
        return TestConfigConstants.INITIAL_GOOD_CONFIG;
    }

    /// @dev Advance block number so `_checkGoodActive` / `updateRunBlockConfig` anti-replay slots stay fresh.
    function _warpToFreshRunSlot() internal {
        if (runSlotBlock < block.number) {
            runSlotBlock = block.number;
        }
        runSlotBlock += 1;
        vm.roll(runSlotBlock);
        vm.warp(opTimestamp);
        opTimestamp += 10;
    }

    /// @dev Relax pool-depth guards for routine swaps: upper=255 (~2.55x reserve input), lower=1 (1% floor).
    /// @dev safeLineUpper/Lower are admin-only (bits 254-239).
    function _relaxSafeLine(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg =
            (cfg & ~SAFE_LINE_MASK) |
            (uint256(255) << TestConfigConstants.SAFE_LINE_UPPER_SHIFT) |
            (uint256(1) << TestConfigConstants.SAFE_LINE_LOWER_SHIFT);
        market.modifyGoodByAdmin(goodId, cfg, marketcreator, defaultdata);
        _snapMarket("modifyGoodByAdmin_relaxSafeLine");
        vm.stopPrank();
    }

    /// @dev Record gas of the immediately preceding external call (Market or Token).
    function _snapMarket(string memory name) internal {
        vm.snapshotGasLastCall(name);
    }

    function _snapToken(string memory name) internal {
        vm.snapshotGasLastCall(name);
    }

    /// @dev Credited V `investGood` will book for `qty` (fee, leverage, investThreshold).
    function _quotedInvestValue(
        uint256 goodId,
        uint128 qty
    ) internal view returns (uint128) {
        S_GoodTmpState memory s = market.getGoodState(goodId);
        uint256 cfg = s.goodConfig;
        uint128 enpower = cfg.getPower();
        uint128 fee = cfg.getInvestFee(qty);
        uint128 net = qty - fee;
        uint128 virtQty = uint128((uint256(net) * uint256(enpower)) / 100);
        uint128 val = toTTSwapUINT256(
            s.investState.amount1(),
            s.currentState.amount1()
        ).getamount0fromamount1(virtQty);
        return cfg.getInvestThreshold(val);
    }

    /// @dev Pack `_invest` so the ±1% quote check passes at current spot.
    function _packInvest(
        uint256 goodId,
        uint128 qty
    ) internal view returns (uint256) {
        return toTTSwapUINT256(_quotedInvestValue(goodId, qty), qty);
    }

    /// @dev Withdraw at most 20% of proof shares (matches default getDisinvestChips divisor=20, factor=4).
    function _partialDisinvestShares(uint256 proofId) internal view returns (uint128) {
        uint128 total = market.getProofState(proofId).shares.amount0();
        uint128 portion = total / 5;
        if (portion == 0) portion = 1;
        return portion;
    }

    function setUp() public virtual {
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        marketcreator = payable(address(6));
        btc = new MyToken("BTC", "BTC", 8);
        usdt = new MyToken("USDT", "USDT", 6);
        eth = new MyToken("ETH", "ETH", 18);
        vm.startPrank(marketcreator);
        TTSwap_Token tts_token_logic = new TTSwap_Token(address(usdt));
        tts_token_proxy=new TTSwap_Token_Proxy( marketcreator, 2 ** 255 + 10000,"TTSwap Token","TTS",address(tts_token_logic));
        tts_token=TTSwap_Token(payable(address(tts_token_proxy)));
        snapStart("depoly Market Manager");
        market = new TTSwap_Market(tts_token);
        market_proxy = new TTSwap_Market_Proxy(tts_token,address(market));
        market = TTSwap_Market(payable(address(market_proxy)));
        snapEnd();
        tts_token.setTokenAdmin(marketcreator,true);
        tts_token.setTokenManager(marketcreator,true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator,true);
        tts_token.setMarketManager(marketcreator,true);
        tts_token.setStakeAdmin(marketcreator,true);
        tts_token.setStakeManager(marketcreator,true);
        vm.stopPrank();
    }

    function test_market_proxy() public {
        assertEq(address(market), address(market_proxy));
    }
    
}
