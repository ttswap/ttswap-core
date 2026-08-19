// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {BaseSetup} from "../BaseSetup.t.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../../src/type/T_GoodKey.sol";
import {toTTSwapUINT256} from "../../src/libraries/L_TTSwapUINT256.sol";

error BalanceDeltaInsufficient();

/// @dev Returns gas used inside the external call (excludes call overhead variance).
contract DeltaProbe {
    function pullPlain(address token, address from, uint256 amount) external returns (uint256 gasUsed) {
        uint256 g0 = gasleft();
        _tf(token, from, amount);
        gasUsed = g0 - gasleft();
    }

    function pullWithDeltaSol(address token, address from, uint256 amount) external returns (uint256 gasUsed) {
        uint256 g0 = gasleft();
        uint256 before_ = _bal(token, address(this));
        _tf(token, from, amount);
        uint256 after_ = _bal(token, address(this));
        if (after_ - before_ < amount) revert BalanceDeltaInsufficient();
        gasUsed = g0 - gasleft();
    }

    function pullWithDeltaAsm(address token, address from, uint256 amount) external returns (uint256 gasUsed) {
        uint256 g0 = gasleft();
        uint256 before_ = _balAsm(token);
        _tf(token, from, amount);
        uint256 after_ = _balAsm(token);
        if (after_ - before_ < amount) revert BalanceDeltaInsufficient();
        gasUsed = g0 - gasleft();
    }

    function _tf(address token, address from, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "tf");
    }

    function _bal(address token, address who) internal view returns (uint256 b) {
        (bool ok, bytes memory ret) = token.staticcall(
            abi.encodeWithSelector(0x70a08231, who)
        );
        require(ok && ret.length >= 32, "bal");
        b = abi.decode(ret, (uint256));
    }

    function _balAsm(address token) internal view returns (uint256 b) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            if iszero(staticcall(gas(), token, ptr, 36, ptr, 32)) { revert(0, 0) }
            b := mload(ptr)
        }
    }
}

contract TransferFromBalanceDeltaGas is Test {
    MyToken internal token;
    DeltaProbe internal probe;
    address internal alice = address(0xA11CE);

    uint256 internal gasPlain;
    uint256 internal gasSol;
    uint256 internal gasAsm;

    function setUp() public {
        token = new MyToken("T", "T", 18);
        probe = new DeltaProbe();
        token.mint(alice, 1_000_000); // -> 1e6 * 1e18
        vm.prank(alice);
        token.approve(address(probe), type(uint256).max);

        // Warm all touched slots / accounts.
        vm.startPrank(alice);
        probe.pullPlain(address(token), alice, 1e18);
        probe.pullWithDeltaSol(address(token), alice, 1e18);
        probe.pullWithDeltaAsm(address(token), alice, 1e18);
        vm.stopPrank();
    }

    function test_gas_plain_vs_balance_delta() public {
        uint256 amount = 100e18;

        // Independent probes + balances so SSTORE refunds from one path cannot
        // bleed into the next measurement (which previously inverted sol < plain).
        DeltaProbe pPlain = new DeltaProbe();
        DeltaProbe pSol = new DeltaProbe();
        DeltaProbe pAsm = new DeltaProbe();

        deal(address(token), alice, amount * 10, true);
        vm.startPrank(alice);
        token.approve(address(pPlain), type(uint256).max);
        token.approve(address(pSol), type(uint256).max);
        token.approve(address(pAsm), type(uint256).max);
        // Warm each probe independently.
        pPlain.pullPlain(address(token), alice, 1e18);
        pSol.pullWithDeltaSol(address(token), alice, 1e18);
        pAsm.pullWithDeltaAsm(address(token), alice, 1e18);

        gasPlain = pPlain.pullPlain(address(token), alice, amount);
        gasSol = pSol.pullWithDeltaSol(address(token), alice, amount);
        gasAsm = pAsm.pullWithDeltaAsm(address(token), alice, amount);
        vm.stopPrank();

        emit log_named_uint("gas plain transferFrom           ", gasPlain);
        emit log_named_uint("gas +delta Solidity balanceOf x2 ", gasSol);
        emit log_named_uint("gas +delta asm staticcall x2     ", gasAsm);

        int256 ohSol = int256(gasSol) - int256(gasPlain);
        int256 ohAsm = int256(gasAsm) - int256(gasPlain);
        emit log_named_int("overhead Solidity (signed)       ", ohSol);
        emit log_named_int("overhead asm (signed)            ", ohAsm);

        assertGt(gasSol, gasPlain, "sol > plain");
        assertGt(gasAsm, gasPlain, "asm > plain");
    }

    function test_delta_blocks_phantom() public {
        Phantom p = new Phantom();
        DeltaProbe pr = new DeltaProbe();
        vm.expectRevert(BalanceDeltaInsufficient.selector);
        pr.pullWithDeltaSol(address(p), alice, 1000);
    }
}

contract Phantom {
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}

/// @dev buyGood baseline gas (1 inbound transferFrom). Delta adds ~once per inbound pull.
contract TransferFromDelta_E2E_BuyGood is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;

    uint256 internal usdtGoodId;
    uint256 internal btcGoodId;

    function setUp() public override {
        BaseSetup.setUp();
        vm.warp(100);

        vm.startPrank(marketcreator);
        usdt.mint(marketcreator, 100_000_000);
        usdt.approve(address(market), type(uint256).max);
        T_GoodKey memory uk = T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0});
        market.initGood(
            uk,
            toTTSwapUINT256(uint128(50_000 * 10 ** 12), uint128(50_000 * 10 ** 6)),
            defaultdata,
            marketcreator,
            defaultdata
        );
        _snapMarket("market_initGood_TransferFromBalanceDeltaGas.t_164");
        usdtGoodId = uk.toId();
        vm.stopPrank();

        vm.startPrank(users[1]);
        btc.mint(users[1], 10); // MyToken: 10 * 10**8
        btc.approve(address(market), type(uint256).max);
        T_GoodKey memory bk = T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0});
        market.initGood(
            bk,
            toTTSwapUINT256(uint128(63_000 * 10 ** 12), uint128(1 * 10 ** 8)),
            defaultdata,
            users[1],
            defaultdata
        );
        _snapMarket("market_initGood_TransferFromBalanceDeltaGas.t_178");
        btcGoodId = bk.toId();
        vm.stopPrank();

        _relaxSafeLine(usdtGoodId);
        _relaxSafeLine(btcGoodId);
    }

    function test_gas_buyGood_and_projected_delta() public {
        address trader = users[4];
        deal(address(usdt), trader, 1_000_000 * 10 ** 6, false);
        uint128 swapIn = 50 * 10 ** 6;

        vm.startPrank(trader);
        usdt.approve(address(market), type(uint256).max);
        _warpToFreshRunSlot();
        market.buyGood(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0}),
            toTTSwapUINT256(swapIn, 0),
            address(0),
            defaultdata,
            trader,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_TransferFromBalanceDeltaGas.t_203");
        _warpToFreshRunSlot();
        market.buyGood(
            T_GoodKey({ercType: 1, contractAddress: address(usdt), id: 0}),
            T_GoodKey({ercType: 1, contractAddress: address(btc), id: 0}),
            toTTSwapUINT256(swapIn, 0),
            address(0),
            defaultdata,
            trader,
            defaultdata,
            0
        );
        _snapMarket("market_buyGood_TransferFromBalanceDeltaGas.t_214");
        uint256 gasBuy = vm.lastCallGas().gasTotalUsed;
        vm.stopPrank();

        // From microbench: asm overhead ~2600 per inbound transferFrom.
        uint256 overhead = 2600;
        emit log_named_uint("buyGood gas now (no delta)       ", gasBuy);
        emit log_named_uint("projected +asm delta (1 pull)    ", gasBuy + overhead);
        emit log_named_uint("projected overhead bps           ", (overhead * 10000) / gasBuy);
        // payGood can pull 1x; initGood 1x; investGood 1x — same per-pull add.
        // Round-trip buy+pay = 2 pulls -> ~2 * overhead.
        emit log_named_uint("projected +delta on buy+pay pair ", 2 * overhead);
    }
}
