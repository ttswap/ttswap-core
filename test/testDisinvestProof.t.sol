// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice v2.0 `disinvestProof` integration tests — ERC20/Native, normal/value goods,
///         owner vs third-party, partial/consecutive withdraw, gate, and revert guards.
contract testDisinvestProof is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    bytes32 internal constant DISINVEST_TOPIC =
        keccak256(
            "e_disinvestProof(uint256,uint256,address,uint256,uint256,uint256,address)"
        );

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant NATIVE_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(63000 * 10 ** 12);

    uint128 internal constant BTC_INVEST = uint128(1 * 10 ** 6);
    uint128 internal constant USDT_INVEST = uint128(1000 * 10 ** 6);
    uint128 internal constant NATIVE_INVEST = uint128(1 * 10 ** 6);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;
    uint256 internal nativeNormalGoodId;


    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        usdtGoodId = _initUsdtGood(marketcreator, USDT_INIT_QTY, USDT_INIT_VALUE);
        btcGoodId = _initBtcGood(users[1], BTC_INIT_VALUE, BTC_INIT_QTY);
        nativeNormalGoodId = _initNativeGood(
            users[1],
            NATIVE_INIT_VALUE,
            NATIVE_INIT_QTY
        );

        _markAsValueGood(usdtGoodId);
        _verifyGood(usdtGoodId);
        _verifyGood(btcGoodId);
        _verifyGood(nativeNormalGoodId);
    }

    // ── helpers ────────────────────────────────────────────────────────────

    function _usdtKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
    }

    function _btcKey() internal view returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }


    function _initUsdtGood(
        address owner,
        uint128 qty,
        uint128 value
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        usdt.mint(owner, 1000000);
        usdt.approve(address(market), qty);
        T_GoodKey memory key = _usdtKey();
        market.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initBtcGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        deal(address(btc), owner, 20 * qty, false);
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory key = _btcKey();
        market.initGood(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }

    function _initNativeGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 20 * qty);
        T_GoodKey memory key = _nativeKey();
        market.initGood{value: qty}(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function _verifyAndPromiseGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market
            .getGoodState(goodId)
            .goodConfig
            
            .setPromised(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _freezeGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setFreeze(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _investBtc(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        btc.approve(address(market), qty);
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _investUsdt(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        usdt.approve(address(market), qty);
        market.investGood(
            _usdtKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _investNative(address trader, uint128 qty) internal {
        _warpToFreshRunSlot();
        market.investGood{value: qty}(
            _nativeKey(),
            toTTSwapUINT256(0, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _partialShares(uint256 proofId) internal view returns (uint128) {
        return _partialDisinvestShares(proofId);
    }

    function _disinvest(
        address trader,
        uint256 proofId,
        uint128 shares,
        address gate
    ) internal returns (uint128 profit) {
        _warpToFreshRunSlot();
        return market.disinvestProof(
            proofId,
            shares,
            gate,
            trader,
            defaultdata
        );
    }

    // ── ERC20 normal good (BTC) ────────────────────────────────────────────

    function testDisinvestERC20NormalGood_owner_partial() public {
        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);

        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);
        uint256 btcBefore = btc.balanceOf(users[1]);
        uint256 marketBtcBefore = btc.balanceOf(address(market));
        S_GoodTmpState memory poolBefore = market.getGoodState(btcGoodId);
        S_ProofState memory proofBefore = market.getProofState(proofId);

        uint128 profit = _disinvest(users[1], proofId, shares, address(0));
        snapLastCall("disinvest_erc20_normal_owner_first");

        assertGt(profit, 0, "profit returned");
        assertGt(btc.balanceOf(users[1]), btcBefore, "user received btc");
        assertLt(btc.balanceOf(address(market)), marketBtcBefore, "market btc down");
        assertLt(
            market.getGoodState(btcGoodId).currentState.amount1(),
            poolBefore.currentState.amount1(),
            "pool virtual qty down"
        );
        assertLt(
            market.getProofState(proofId).shares.amount0(),
            proofBefore.shares.amount0(),
            "proof shares burned"
        );
        vm.stopPrank();
    }

    function testDisinvestERC20NormalGood_owner_consecutive() public {
        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);

        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 s1 = _partialShares(proofId);
        _disinvest(users[1], proofId, s1, address(0));
        snapLastCall("disinvest_erc20_normal_owner_second");

        uint128 s2 = _partialShares(proofId);
        _disinvest(users[1], proofId, s2, address(0));
        snapLastCall("disinvest_erc20_normal_owner_third");

        assertGt(market.getProofState(proofId).shares.amount0(), 0, "shares remain");
        vm.stopPrank();
    }

    function testDisinvestERC20NormalGood_otherUser() public {
        vm.startPrank(users[2]);
        deal(address(btc), users[2], 10 * BTC_INVEST, false);
        btc.approve(address(market), type(uint256).max);
        _investBtc(users[2], BTC_INVEST);

        uint256 proofId = _proofId(users[2], btcGoodId);
        uint128 shares = _partialShares(proofId);
        uint256 btcBefore = btc.balanceOf(users[2]);

        _disinvest(users[2], proofId, shares, address(0));
        snapLastCall("disinvest_erc20_normal_other_first");

        assertGt(btc.balanceOf(users[2]), btcBefore, "other user received btc");
        vm.stopPrank();
    }

    function testDisinvestERC20NormalGood_withGate() public {
        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);

        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);

        vm.recordLogs();
        _disinvest(users[1], proofId, shares, users[3]);
        snapLastCall("disinvest_erc20_normal_with_gate");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == DISINVEST_TOPIC) {
                found = true;
                assertEq(logs[i - 1].topics[1], bytes32(proofId), "proof in event");
                break;
            }
        }
        assertTrue(found, "e_disinvestProof emitted");
        vm.stopPrank();
    }

    // ── ERC20 value good (USDT) ────────────────────────────────────────────

    function testDisinvestERC20ValueGood_owner() public {
        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        _investUsdt(marketcreator, USDT_INVEST);

        uint256 proofId = _proofId(marketcreator, usdtGoodId);
        uint128 shares = _partialShares(proofId);
        uint256 balBefore = usdt.balanceOf(marketcreator);

        _disinvest(marketcreator, proofId, shares, address(0));
        snapLastCall("disinvest_erc20_value_owner_first");

        assertGt(usdt.balanceOf(marketcreator), balBefore, "owner received usdt");
        vm.stopPrank();
    }

    function testDisinvestERC20ValueGood_owner_consecutive() public {
        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        _investUsdt(marketcreator, USDT_INVEST);

        uint256 proofId = _proofId(marketcreator, usdtGoodId);
        _disinvest(marketcreator, proofId, _partialShares(proofId), address(0));
        _disinvest(marketcreator, proofId, _partialShares(proofId), address(0));
        snapLastCall("disinvest_erc20_value_owner_third");
        vm.stopPrank();
    }

    function testDisinvestERC20ValueGood_otherUser() public {
        vm.startPrank(users[2]);
        deal(address(usdt), users[2], 10 * USDT_INVEST, false);
        usdt.approve(address(market), type(uint256).max);
        _investUsdt(users[2], USDT_INVEST);

        uint256 proofId = _proofId(users[2], usdtGoodId);
        uint256 balBefore = usdt.balanceOf(users[2]);

        _disinvest(users[2], proofId, _partialShares(proofId), address(0));
        snapLastCall("disinvest_erc20_value_other_first");

        assertGt(usdt.balanceOf(users[2]), balBefore, "other user received usdt");
        vm.stopPrank();
    }

    function testDisinvestERC20ValueGood_initProofOnly() public {
        vm.startPrank(marketcreator);
        uint256 proofId = _proofId(marketcreator, usdtGoodId);
        uint128 shares = _partialShares(proofId);
        uint256 balBefore = usdt.balanceOf(marketcreator);

        _disinvest(marketcreator, proofId, shares, address(0));
        snapLastCall("disinvest_erc20_value_init_only");

        assertGt(usdt.balanceOf(marketcreator), balBefore, "init proof disinvest ok");
        vm.stopPrank();
    }

    // ── Native ETH normal good ─────────────────────────────────────────────

    function testDisinvestNativeETHNormalGood_owner() public {
        vm.startPrank(users[1]);
        _investNative(users[1], NATIVE_INVEST);

        uint256 proofId = _proofId(users[1], nativeNormalGoodId);
        uint128 shares = _partialShares(proofId);
        uint256 ethBefore = users[1].balance;

        _disinvest(users[1], proofId, shares, address(0));
        snapLastCall("disinvest_native_normal_owner_first");

        assertGt(users[1].balance, ethBefore, "owner received eth");
        vm.stopPrank();
    }

    function testDisinvestNativeETHNormalGood_owner_consecutive() public {
        vm.startPrank(users[1]);
        _investNative(users[1], NATIVE_INVEST);

        uint256 proofId = _proofId(users[1], nativeNormalGoodId);
        _disinvest(users[1], proofId, _partialShares(proofId), address(0));
        _disinvest(users[1], proofId, _partialShares(proofId), address(0));
        snapLastCall("disinvest_native_normal_owner_third");
        vm.stopPrank();
    }

    function testDisinvestNativeETHNormalGood_otherUser() public {
        vm.startPrank(users[4]);
        vm.deal(users[4], 10 * NATIVE_INVEST);
        _investNative(users[4], NATIVE_INVEST);

        uint256 proofId = _proofId(users[4], nativeNormalGoodId);
        uint256 ethBefore = users[4].balance;

        _disinvest(users[4], proofId, _partialShares(proofId), address(0));
        snapLastCall("disinvest_native_normal_other_first");

        assertGt(users[4].balance, ethBefore, "other user received eth");
        vm.stopPrank();
    }

    // ── revert guards ──────────────────────────────────────────────────────

    function testDisinvestProof_revert_notProofOwner() public {
        uint256 proofId = _proofId(users[1], btcGoodId);
        vm.startPrank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 19));
        _disinvest(users[2], proofId, BTC_INIT_QTY / 4, address(0));
        vm.stopPrank();
    }

    function testDisinvestProof_revert_traderMismatch() public {
        uint256 proofId = _proofId(users[1], btcGoodId);
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.disinvestProof(
            proofId,
            BTC_INIT_QTY / 4,
            address(0),
            users[2],
            defaultdata
        );
        vm.stopPrank();
    }

    function testDisinvestProof_revert_sharesExceedProof() public {
        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 tooMany = market.getProofState(proofId).shares.amount0() + 1;
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 41));
        _disinvest(users[1], proofId, tooMany, address(0));
        vm.stopPrank();
    }

    function testDisinvestProof_revert_frozenGood() public {
        _freezeGood(btcGoodId);
        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);
        vm.startPrank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        _disinvest(users[1], proofId, shares, address(0));
        vm.stopPrank();
    }

    function testDisinvestProof_revert_promisedOwner() public {
        _verifyAndPromiseGood(btcGoodId);
        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);
        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);

        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 40));
        _disinvest(users[1], proofId, shares, address(0));
        vm.stopPrank();
    }

    function testDisinvestProof_refreshPromise_emitsForOwner() public {
        _verifyAndPromiseGood(btcGoodId);
        uint256 proofId = _proofId(users[1], btcGoodId);

        vm.startPrank(users[1]);
        vm.recordLogs();
        market.refreshPromise(proofId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        bytes32 promiseTopic = keccak256("e_getPromiseProof(uint256,uint256)");
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == promiseTopic) {
                found = true;
                assertEq(uint256(logs[i - 1].topics[1]), btcGoodId, "good id");
                assertEq(abi.decode(logs[i - 1].data, (uint256)), proofId, "proof id");
                break;
            }
        }
        assertTrue(found, "e_getPromiseProof emitted");
        vm.stopPrank();
    }

    function testDisinvestProof_bannedGate_fallsBackToPlatform() public {
        address gate = users[3];

        vm.startPrank(marketcreator);
        tts_token.setBan(gate, true);
        vm.stopPrank();

        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);
        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);
        _disinvest(users[1], proofId, shares, gate);
        snapLastCall("disinvest_banned_gate");
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;
        assertEq(market.queryCommission(ids, gate)[0], 0, "banned gate accrues nothing");
        assertGt(market.queryCommission(ids, address(0))[0], 1, "platform keeps gate share");
    }

    function testDisinvestProof_bannedGate_vsActiveGate() public {
        address gate = users[3];

        vm.startPrank(users[1]);
        _investBtc(users[1], BTC_INVEST);
        uint256 proofId = _proofId(users[1], btcGoodId);
        uint128 shares = _partialShares(proofId);
        _disinvest(users[1], proofId, shares, gate);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = btcGoodId;
        uint256 activeGateFee = market.queryCommission(ids, gate)[0];
        assertGt(activeGateFee, 1, "active gate accrues commission");
    }
}

/// @notice Native ETH value-good disinvest (isolated — single native pool per market).
contract testDisinvestNativeETHValueGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint128 internal constant NATIVE_VAL_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant NATIVE_VAL_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant NATIVE_INVEST = uint128(50000 * 10 ** 6);

    uint256 internal nativeValueGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(0);
        nativeValueGoodId = _initNativeValueGood(
            marketcreator,
            NATIVE_VAL_VALUE,
            NATIVE_VAL_QTY
        );
        _markAsValueGood(nativeValueGoodId);
        _verifyGood(nativeValueGoodId);
    }

    function _nativeKey() internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: address(1), id: 0});
    }

    function _proofId(address owner, uint256 goodId) internal pure returns (uint256) {
        return S_ProofKey({owner: owner, currentgood: goodId}).toId();
    }


    function _initNativeValueGood(
        address owner,
        uint128 value,
        uint128 qty
    ) internal returns (uint256 goodId) {
        vm.startPrank(owner);
        vm.deal(owner, 20 * qty);
        T_GoodKey memory key = _nativeKey();
        market.initGood{value: qty}(
            key,
            toTTSwapUINT256(value, qty),
            defaultdata,
            owner,
            defaultdata
        );
        goodId = key.toId();
        vm.stopPrank();
    }


    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _partialShares(uint256 proofId) internal view returns (uint128) {
        return _partialDisinvestShares(proofId);
    }

    function testDisinvestNativeETHValueGood_owner() public {
        vm.startPrank(marketcreator);
        vm.deal(marketcreator, 20 * NATIVE_INVEST);
        _warpToFreshRunSlot();
        market.investGood{value: NATIVE_INVEST}(
            _nativeKey(),
            toTTSwapUINT256(0, NATIVE_INVEST),
            defaultdata,
            defaultdata,
            marketcreator
        );

        uint256 proofId = _proofId(marketcreator, nativeValueGoodId);
        uint256 ethBefore = marketcreator.balance;

        market.disinvestProof(
            proofId,
            _partialShares(proofId),
            address(0),
            marketcreator,
            defaultdata
        );
        snapLastCall("disinvest_native_value_owner_first");

        assertGt(marketcreator.balance, ethBefore, "owner received eth");
        vm.stopPrank();
    }

    function testDisinvestNativeETHValueGood_otherUser() public {
        vm.startPrank(users[2]);
        vm.deal(users[2], 20 * NATIVE_INVEST);
        _warpToFreshRunSlot();
        market.investGood{value: NATIVE_INVEST}(
            _nativeKey(),
            toTTSwapUINT256(0, NATIVE_INVEST),
            defaultdata,
            defaultdata,
            users[2]
        );

        uint256 proofId = _proofId(users[2], nativeValueGoodId);
        uint256 ethBefore = users[2].balance;

        market.disinvestProof(
            proofId,
            _partialShares(proofId),
            address(0),
            users[2],
            defaultdata
        );
        snapLastCall("disinvest_native_value_other_first");

        assertGt(users[2].balance, ethBefore, "other user received eth");
        vm.stopPrank();
    }

    function testDisinvestNativeETHValueGood_initProofOnly() public {
        vm.startPrank(marketcreator);
        uint256 proofId = _proofId(marketcreator, nativeValueGoodId);
        uint256 ethBefore = marketcreator.balance;

        market.disinvestProof(
            proofId,
            _partialShares(proofId),
            address(0),
            marketcreator,
            defaultdata
        );
        snapLastCall("disinvest_native_value_init_only");

        assertGt(marketcreator.balance, ethBefore, "init proof disinvest ok");
        vm.stopPrank();
    }
}
