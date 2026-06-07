// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Vm} from "forge-std/src/Test.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {S_GoodTmpState, S_ProofState, S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";
import {L_ProofIdLibrary} from "../src/libraries/L_Proof.sol";
import {
    L_TTSwapUINT256Library,
    toTTSwapUINT256
} from "../src/libraries/L_TTSwapUINT256.sol";

/// @notice v2.0 `investGood` integration tests — ERC20/Native, normal/value goods,
///         owner vs third-party, leverage & fee paths, and revert guards.
contract testInvestGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    bytes32 internal constant INVEST_GOOD_TOPIC =
        keccak256(
            "e_investGood(uint256,uint256,uint256,uint256,uint256,address)"
        );

    uint256 internal constant POWER_SHIFT = 162;
    uint256 internal constant LIMIT_POWER_SHIFT = 214;
    uint256 internal constant INVEST_FEE_SHIFT = 148;

    uint128 internal constant USDT_INIT_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_INIT_VALUE = uint128(50000 * 10 ** 12);
    uint128 internal constant BTC_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant BTC_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant NATIVE_INIT_QTY = uint128(1 * 10 ** 8);
    uint128 internal constant NATIVE_INIT_VALUE = uint128(63000 * 10 ** 12);
    uint128 internal constant NATIVE_VAL_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant NATIVE_VAL_VALUE = uint128(50000 * 10 ** 12);

    uint128 internal constant BTC_INVEST = uint128(1 * 10 ** 8);
    uint128 internal constant USDT_INVEST = uint128(50000 * 10 ** 6);
    uint128 internal constant USDT_SMALL_INVEST = uint128(1 * 10 ** 6);
    uint128 internal constant NATIVE_INVEST = uint128(1 * 10 ** 8);

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;
    uint256 internal nativeNormalGoodId;

    uint256 internal investTs = 1;

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

    function _warpForInvest() internal {
        vm.warp(investTs);
        investTs++;
        if (investTs > 9) investTs = 1;
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

    function _verifyGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setVerified(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _verifyAndPromiseGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market
            .getGoodState(goodId)
            .goodConfig
            .setVerified(true)
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

    function _setLimitPower(uint256 goodId, uint256 limitField) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << LIMIT_POWER_SHIFT)) |
            (limitField << LIMIT_POWER_SHIFT);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerPower(uint256 goodId, address owner, uint256 powerField) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x1f) << POWER_SHIFT)) | (powerField << POWER_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _setOwnerInvestFee(
        uint256 goodId,
        address owner,
        uint256 feeField
    ) internal {
        vm.startPrank(owner);
        uint256 cfg = market.getGoodState(goodId).goodConfig;
        cfg = (cfg & ~(uint256(0x3f) << INVEST_FEE_SHIFT)) |
            (feeField << INVEST_FEE_SHIFT);
        market.modifyGoodByGoodOwner(goodId, cfg, owner, defaultdata);
        vm.stopPrank();
    }

    function _investBtc(
        address trader,
        uint128 value,
        uint128 qty
    ) internal returns (bool) {
        btc.approve(address(market), qty);
        return market.investGood(
            _btcKey(),
            toTTSwapUINT256(value, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _investUsdt(
        address trader,
        uint128 value,
        uint128 qty
    ) internal returns (bool) {
        usdt.approve(address(market), qty);
        return market.investGood(
            _usdtKey(),
            toTTSwapUINT256(value, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function _investNative(
        address trader,
        uint128 value,
        uint128 qty
    ) internal returns (bool) {
        return market.investGood{value: qty}(
            _nativeKey(),
            toTTSwapUINT256(value, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    // ── ERC20 normal good (BTC) ────────────────────────────────────────────

    function testInvestERC20NormalGood_owner_poolPrice() public {
        vm.startPrank(users[1]);
        S_GoodTmpState memory before_ = market.getGoodState(btcGoodId);
        uint256 btcBefore = btc.balanceOf(address(market));

        _warpForInvest();
        assertTrue(_investBtc(users[1], 0, BTC_INVEST), "invest ok");
        snapLastCall("invest_erc20_normal_owner_first");
        uint256 proofId = _proofId(users[1], btcGoodId);

        S_GoodTmpState memory after_ = market.getGoodState(btcGoodId);
        assertGt(after_.currentState.amount1(), before_.currentState.amount1(), "virtual qty up");
        assertGt(after_.currentState.amount0(), before_.currentState.amount1(), "actual > init virtual");
        assertEq(
            btc.balanceOf(address(market)),
            btcBefore + BTC_INVEST,
            "btc escrowed"
        );

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), BTC_INIT_QTY, "proof actual qty grew");
        assertGt(proof.shares.amount0(), BTC_INIT_QTY, "proof shares grew");
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_owner_consecutive() public {
        vm.startPrank(users[1]);
        _warpForInvest();
        _investBtc(users[1], 0, BTC_INVEST);
        snapLastCall("invest_erc20_normal_owner_second");

        S_GoodTmpState memory mid = market.getGoodState(btcGoodId);
        _warpForInvest();
        _investBtc(users[1], 0, BTC_INVEST);
        snapLastCall("invest_erc20_normal_owner_third");

        S_GoodTmpState memory after_ = market.getGoodState(btcGoodId);
        assertGt(after_.currentState.amount1(), mid.currentState.amount1(), "second invest grew pool");
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_otherUser_poolPrice() public {
        vm.startPrank(users[4]);
        deal(address(btc), users[4], 10 * BTC_INVEST, false);
        btc.approve(address(market), type(uint256).max);

        S_GoodTmpState memory before_ = market.getGoodState(btcGoodId);

        _warpForInvest();
        assertTrue(_investBtc(users[4], 0, BTC_INVEST), "other user invest");
        snapLastCall("invest_erc20_normal_other_first");
        uint256 proofId = _proofId(users[4], btcGoodId);

        S_GoodTmpState memory after_ = market.getGoodState(btcGoodId);
        assertGt(after_.currentState.amount1(), before_.currentState.amount1(), "pool grew");

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), 0, "new proof created");
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_owner_explicitPrice_whenPromised() public {
        _verifyAndPromiseGood(btcGoodId);
        vm.startPrank(users[1]);
        _warpForInvest();
        assertTrue(
            _investBtc(users[1], BTC_INIT_VALUE, BTC_INVEST),
            "owner same-price invest"
        );
        snapLastCall("invest_erc20_normal_owner_explicitPrice");
        S_GoodTmpState memory state = market.getGoodState(btcGoodId);
        assertGt(state.currentState.amount1(), BTC_INIT_QTY, "pool grew");
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_notVerified() public {
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(eth),
            id: 0
        });
        vm.startPrank(users[2]);
        deal(address(eth), users[2], 10 * BTC_INVEST, false);
        eth.approve(address(market), type(uint256).max);
        market.initGood(
            key,
            toTTSwapUINT256(BTC_INIT_VALUE, BTC_INVEST),
            defaultdata,
            users[2],
            defaultdata
        );
        _warpForInvest();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 37));
        market.investGood(
            key,
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_frozen() public {
        _freezeGood(btcGoodId);
        vm.startPrank(users[1]);
        _warpForInvest();
        btc.approve(address(market), BTC_INVEST);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 10));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[1]
        );
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_traderMismatch() public {
        vm.startPrank(users[1]);
        _warpForInvest();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 39));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_highExplicitPrice() public {
        _verifyAndPromiseGood(btcGoodId);
        vm.startPrank(users[1]);
        _warpForInvest();
        btc.approve(address(market), BTC_INVEST);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 47));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(uint128(64000 * 10 ** 12), BTC_INVEST),
            defaultdata,
            defaultdata,
            users[1]
        );
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_otherUser_explicitPrice() public {
        _verifyAndPromiseGood(btcGoodId);
        vm.startPrank(users[4]);
        deal(address(btc), users[4], BTC_INVEST, false);
        btc.approve(address(market), BTC_INVEST);
        _warpForInvest();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 47));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(BTC_INIT_VALUE, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[4]
        );
        vm.stopPrank();
    }

    function testInvestERC20NormalGood_revert_dustValue() public {
        vm.startPrank(users[1]);
        _warpForInvest();
        btc.approve(address(market), 1);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 38));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, 1),
            defaultdata,
            defaultdata,
            users[1]
        );
        vm.stopPrank();
    }

    // ── ERC20 value good (USDT) ────────────────────────────────────────────

    function testInvestERC20ValueGood_owner() public {
        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        S_GoodTmpState memory before_ = market.getGoodState(usdtGoodId);
        uint256 balBefore = usdt.balanceOf(marketcreator);

        _warpForInvest();
        assertTrue(_investUsdt(marketcreator, 0, USDT_INVEST), "value good invest");
        snapLastCall("invest_erc20_value_owner_first");
        uint256 proofId = _proofId(marketcreator, usdtGoodId);

        S_GoodTmpState memory after_ = market.getGoodState(usdtGoodId);
        assertGt(after_.currentState.amount1(), before_.currentState.amount1(), "virtual up");
        assertEq(
            usdt.balanceOf(marketcreator),
            balBefore - USDT_INVEST,
            "usdt spent"
        );

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), USDT_INIT_QTY, "proof qty grew");
        vm.stopPrank();
    }

    function testInvestERC20ValueGood_owner_consecutive() public {
        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        _warpForInvest();
        _investUsdt(marketcreator, 0, USDT_INVEST);
        snapLastCall("invest_erc20_value_owner_second");

        S_GoodTmpState memory mid = market.getGoodState(usdtGoodId);
        _warpForInvest();
        _investUsdt(marketcreator, 0, USDT_INVEST);
        snapLastCall("invest_erc20_value_owner_third");

        assertGt(
            market.getGoodState(usdtGoodId).currentState.amount1(),
            mid.currentState.amount1(),
            "third invest grew pool"
        );
        vm.stopPrank();
    }

    function testInvestERC20ValueGood_otherUser() public {
        vm.startPrank(users[2]);
        deal(address(usdt), users[2], 10 * USDT_INVEST, false);
        usdt.approve(address(market), type(uint256).max);

        _warpForInvest();
        assertTrue(_investUsdt(users[2], 0, USDT_INVEST), "other user value invest");
        snapLastCall("invest_erc20_value_other_first");
        uint256 proofId = _proofId(users[2], usdtGoodId);

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), 0, "proof for other user");
        assertGt(proof.state.amount0(), 0, "proof value credited");
        vm.stopPrank();
    }

    function testInvestERC20ValueGood_smallIncrement() public {
        vm.startPrank(users[1]);
        deal(address(usdt), users[1], 10 * USDT_SMALL_INVEST, false);
        usdt.approve(address(market), USDT_SMALL_INVEST);
        S_GoodTmpState memory before_ = market.getGoodState(usdtGoodId);

        _warpForInvest();
        assertTrue(
            _investUsdt(users[1], 0, USDT_SMALL_INVEST),
            "small metagood invest"
        );
        snapLastCall("invest_erc20_value_small");

        assertGt(
            market.getGoodState(usdtGoodId).currentState.amount1(),
            before_.currentState.amount1(),
            "metagood pool grew"
        );
        vm.stopPrank();
    }

    // ── Native ETH normal good ─────────────────────────────────────────────

    function testInvestNativeETHNormalGood_owner() public {
        vm.startPrank(users[1]);
        S_GoodTmpState memory before_ = market.getGoodState(nativeNormalGoodId);
        uint256 marketEthBefore = address(market).balance;

        _warpForInvest();
        assertTrue(
            _investNative(users[1], 0, NATIVE_INVEST),
            "native normal invest"
        );
        snapLastCall("invest_native_normal_owner_first");

        S_GoodTmpState memory after_ = market.getGoodState(nativeNormalGoodId);
        assertGt(after_.currentState.amount1(), before_.currentState.amount1(), "virtual up");
        assertEq(
            address(market).balance,
            marketEthBefore + NATIVE_INVEST,
            "eth escrowed"
        );
        vm.stopPrank();
    }

    function testInvestNativeETHNormalGood_owner_consecutive() public {
        vm.startPrank(users[1]);
        _warpForInvest();
        _investNative(users[1], 0, NATIVE_INVEST);
        _warpForInvest();
        _investNative(users[1], 0, NATIVE_INVEST);
        snapLastCall("invest_native_normal_owner_third");
        S_GoodTmpState memory state = market.getGoodState(nativeNormalGoodId);
        assertGt(state.currentState.amount1(), 2 * NATIVE_INIT_QTY, "two extra invests");
        vm.stopPrank();
    }

    function testInvestNativeETHNormalGood_otherUser() public {
        vm.startPrank(users[4]);
        vm.deal(users[4], 10 * NATIVE_INVEST);
        uint256 proofId = _proofId(users[4], nativeNormalGoodId);

        _warpForInvest();
        assertTrue(
            _investNative(users[4], 0, NATIVE_INVEST),
            "other native invest"
        );
        snapLastCall("invest_native_normal_other_first");

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), 0, "proof minted");
        vm.stopPrank();
    }

    // ── leverage (power) & invest fee (USDT value good) ───────────────────

    function testInvestValueGood_powerWithoutFee() public {
        _setLimitPower(usdtGoodId, 6);
        _setOwnerPower(usdtGoodId, marketcreator, 6);
        _setOwnerInvestFee(usdtGoodId, marketcreator, 0);

        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        S_GoodTmpState memory before_ = market.getGoodState(usdtGoodId);
        uint128 virtualBefore = before_.currentState.amount1();
        uint128 actualBefore = before_.currentState.amount0();

        _warpForInvest();
        _investUsdt(marketcreator, 0, USDT_INVEST);
        snapLastCall("invest_value_power_no_fee");

        S_GoodTmpState memory after_ = market.getGoodState(usdtGoodId);
        uint128 virtualDelta = after_.currentState.amount1() - virtualBefore;
        uint128 actualDelta = after_.currentState.amount0() - actualBefore;

        assertEq(actualDelta, USDT_INVEST, "actual deposit");
        assertGt(virtualDelta, actualDelta, "leverage mints extra virtual qty");
        assertGe(virtualDelta, (actualDelta * 500) / 100, "~6x virtual increment");
        assertGt(after_.goodConfig.amount1(), 0, "virtual excess tracked in config");
        vm.stopPrank();
    }

    function testInvestValueGood_powerWithFee() public {
        _setLimitPower(usdtGoodId, 6);
        _setOwnerPower(usdtGoodId, marketcreator, 6);

        vm.startPrank(marketcreator);
        usdt.approve(address(market), type(uint256).max);
        S_GoodTmpState memory before_ = market.getGoodState(usdtGoodId);

        _warpForInvest();
        _investUsdt(marketcreator, 0, USDT_INVEST);
        snapLastCall("invest_value_power_with_fee");

        S_GoodTmpState memory after_ = market.getGoodState(usdtGoodId);
        uint128 virtualDelta = after_.currentState.amount1() - before_.currentState.amount1();
        uint128 actualDelta = after_.currentState.amount0() - before_.currentState.amount0();

        assertGt(actualDelta, 0, "actual deposit");
        assertGt(virtualDelta, actualDelta, "leverage still applies");
        assertGt(
            market.getGoodState(usdtGoodId).goodConfig.getInvestFee(USDT_INVEST),
            0,
            "default invest fee applies"
        );
        vm.stopPrank();
    }

    // ── shared revert guards ───────────────────────────────────────────────

    function testInvestGood_revert_busySlot() public {
        vm.startPrank(users[1]);
        vm.warp(10);
        btc.approve(address(market), BTC_INVEST);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 46));
        market.investGood(
            _btcKey(),
            toTTSwapUINT256(0, BTC_INVEST),
            defaultdata,
            defaultdata,
            users[1]
        );
        vm.stopPrank();
    }

    function testInvestGood_event_emitted() public {
        vm.startPrank(users[1]);
        _warpForInvest();
        vm.recordLogs();
        _investBtc(users[1], 0, BTC_INVEST);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i - 1].topics[0] == INVEST_GOOD_TOPIC) {
                found = true;
                assertEq(
                    uint256(logs[i - 1].topics[1]),
                    _proofId(users[1], btcGoodId),
                    "event proofNo matches toId()"
                );
                assertEq(uint256(logs[i - 1].topics[2]), btcGoodId, "good id in event");
                break;
            }
        }
        assertTrue(found, "e_investGood emitted");
        vm.stopPrank();
    }

    function testInvestGood_revert_poolOverflow() public {
        MyToken maxToken = new MyToken("MAX", "MAX", 6);
        uint128 maxQty = uint128(2 ** 109);
        uint128 minValue = uint128(500_000_000_000_000);

        vm.startPrank(users[1]);
        deal(address(maxToken), users[1], maxQty, false);
        maxToken.approve(address(market), maxQty);
        T_GoodKey memory key = T_GoodKey({
            ercType: 1,
            contractAddress: address(maxToken),
            id: 0
        });
        market.initGood(
            key,
            toTTSwapUINT256(minValue, maxQty),
            defaultdata,
            users[1],
            defaultdata
        );
        uint256 maxGoodId = key.toId();
        vm.stopPrank();

        _verifyGood(maxGoodId);

        vm.startPrank(users[2]);
        deal(address(maxToken), users[2], 10, false);
        maxToken.approve(address(market), 10);
        _warpForInvest();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 18));
        market.investGood(
            key,
            toTTSwapUINT256(0, 1),
            defaultdata,
            defaultdata,
            users[2]
        );
        vm.stopPrank();
    }
}

/// @notice Native ETH value-good invest tests (isolated — native good id is unique per market).
contract testInvestNativeETHValueGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;
    using L_ProofIdLibrary for S_ProofKey;

    uint128 internal constant NATIVE_VAL_QTY = uint128(50000 * 10 ** 6);
    uint128 internal constant NATIVE_VAL_VALUE = uint128(50000 * 10 ** 12);

    uint256 internal nativeValueGoodId;
    uint256 internal investTs = 1;

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

    function _warpForInvest() internal {
        vm.warp(investTs);
        investTs++;
        if (investTs > 9) investTs = 1;
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

    function _verifyGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        uint256 cfg = market.getGoodState(goodId).goodConfig.setVerified(true);
        market.modifyGoodByManager(goodId, cfg, marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _markAsValueGood(uint256 goodId) internal {
        vm.startPrank(marketcreator);
        market.modifyGoodByAdmin(goodId, (1 << 255), marketcreator, defaultdata);
        vm.stopPrank();
    }

    function _investNative(
        address trader,
        uint128 value,
        uint128 qty
    ) internal returns (bool) {
        return market.investGood{value: qty}(
            _nativeKey(),
            toTTSwapUINT256(value, qty),
            defaultdata,
            defaultdata,
            trader
        );
    }

    function testInvestNativeETHValueGood_owner() public {
        vm.startPrank(marketcreator);
        vm.deal(marketcreator, 20 * NATIVE_VAL_QTY);
        S_GoodTmpState memory before_ = market.getGoodState(nativeValueGoodId);

        _warpForInvest();
        assertTrue(
            _investNative(marketcreator, 0, NATIVE_VAL_QTY),
            "native value invest"
        );
        snapLastCall("invest_native_value_owner_first");

        S_GoodTmpState memory after_ = market.getGoodState(nativeValueGoodId);
        assertGt(after_.currentState.amount1(), before_.currentState.amount1(), "virtual up");
        vm.stopPrank();
    }

    function testInvestNativeETHValueGood_otherUser() public {
        vm.startPrank(users[2]);
        vm.deal(users[2], 10 * NATIVE_VAL_QTY);
        uint256 proofId = _proofId(users[2], nativeValueGoodId);

        _warpForInvest();
        assertTrue(
            _investNative(users[2], 0, NATIVE_VAL_QTY),
            "other native value invest"
        );
        snapLastCall("invest_native_value_other_first");

        S_ProofState memory proof = market.getProofState(proofId);
        assertGt(proof.invest.amount1(), 0, "proof for user2");
        vm.stopPrank();
    }

    function testInvestNativeETHValueGood_owner_consecutive() public {
        vm.startPrank(marketcreator);
        vm.deal(marketcreator, 20 * NATIVE_VAL_QTY);
        _warpForInvest();
        _investNative(marketcreator, 0, NATIVE_VAL_QTY);
        _warpForInvest();
        _investNative(marketcreator, 0, NATIVE_VAL_QTY);
        snapLastCall("invest_native_value_owner_third");

        S_GoodTmpState memory state = market.getGoodState(nativeValueGoodId);
        assertGt(state.currentState.amount0(), 2 * NATIVE_VAL_QTY, "two deposits");
        vm.stopPrank();
    }
}
