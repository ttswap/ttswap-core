// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import {TTSwap_Token} from "../src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "../src/TTSwap_Token_Proxy.sol";
import {MyToken} from "../src/test/MyToken.sol";
import {I_TTSwap_Token, s_share} from "../src/interfaces/I_TTSwap_Token.sol";
import {I_TTSwap_Market} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_UserConfigLibrary} from "../src/libraries/L_UserConfig.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";
import {L_TTSwapUINT256Library} from "../src/libraries/L_TTSwapUINT256.sol";

contract MarketPriceMock {
    bool public higher = true;

    function setHigher(bool v) external {
        higher = v;
    }

    function ishigher(uint256, uint256, uint256) external view returns (bool) {
        return higher;
    }
}

/// @notice Token + Token Proxy coverage without compiling `TTSwap_Market`.
contract testTTSwapTokenCoverage is Test {
    using L_UserConfigLibrary for uint256;
    using L_TTSwapUINT256Library for uint256;

    uint256 internal constant MAIN_CFG = uint256(1 << 255) + 10_000;
    uint256 internal constant ADMIN_KEY = 0xA11CE;

    MyToken internal usdt;
    TTSwap_Token internal token;
    TTSwap_Token internal impl;
    TTSwap_Token_Proxy internal proxy;
    MarketPriceMock internal marketMock;

    address internal dao;
    address internal stakeCaller;
    address internal user;
    address internal tokenAdmin;

    function setUp() public {
        dao = makeAddr("dao");
        stakeCaller = makeAddr("stakeCaller");
        user = makeAddr("user");
        tokenAdmin = vm.addr(ADMIN_KEY);
        usdt = new MyToken("USDT", "USDT", 6);
        impl = new TTSwap_Token(address(usdt));
        proxy = new TTSwap_Token_Proxy(dao, MAIN_CFG, "TTSwap Token", "TTS", address(impl));
        token = TTSwap_Token(payable(address(proxy)));
        marketMock = new MarketPriceMock();

        vm.startPrank(dao);
        token.setTokenAdmin(dao, true);
        token.setTokenAdmin(tokenAdmin, true);
        token.setTokenManager(dao, true);
        token.setCallMintTTS(stakeCaller, true);
        token.setMarketAdmin(dao, true);
        token.setMarketManager(dao, true);
        token.setStakeAdmin(dao, true);
        token.setStakeManager(dao, true);
        token.setEnv(address(marketMock));
        vm.stopPrank();
        vm.warp(1_000_000);
    }

    function testToken_rolesAndBanAndRatio() public {
        vm.prank(dao);
        token.setBan(user, true);
        assertTrue(token.userConfig(user).isBan());

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        token.setTokenAdmin(user, true);

        vm.prank(dao);
        token.setRatio(5_000);
        assertEq(token.ttstokenconfig() & 0xffff, 5_000);

        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 66));
        token.setRatio(10_001);
    }

    function testToken_setReferral_onlyFirstBind() public {
        address ref = makeAddr("ref");
        vm.prank(stakeCaller);
        token.setReferral(user, ref);
        assertEq(token.getreferral(user), ref);

        vm.prank(stakeCaller);
        token.setReferral(user, makeAddr("other"));
        assertEq(token.getreferral(user), ref, "already bound");

        vm.prank(stakeCaller);
        token.setReferral(user, user);
        assertEq(token.getreferral(user), ref, "self-ref ignored");
    }

    function testToken_stakeUnstakeAndEmptyPoolTick() public {
        vm.prank(stakeCaller);
        uint128 net = token.stake(user, 100_000);
        assertEq(net, 0);
        assertEq(token.stakestate().amount1(), 100_000);

        vm.warp(block.timestamp + 86_401);
        vm.prank(stakeCaller);
        token.unstake(user, 40_000);
        assertEq(token.stakestate().amount1(), 60_000);
        assertGt(token.balanceOf(user), 0);

        vm.prank(stakeCaller);
        token.unstake(user, 60_000);
        assertEq(token.stakestate().amount1(), 0);

        vm.warp(block.timestamp + 86_401);
        vm.prank(stakeCaller);
        token.stake(makeAddr("late"), 1);
    }

    function testToken_mintBurnShareAndShareMint() public {
        s_share memory share = s_share({leftamount: 1_000_000, metric: 1, chips: 4});
        vm.prank(dao);
        token.addShare(share, user);
        assertEq(token.usershares(user).leftamount, 1_000_000);

        vm.prank(dao);
        token.addShare(s_share({leftamount: 100, metric: 1, chips: 2}), user);
        assertEq(token.usershares(user).leftamount, 1_000_100);

        marketMock.setHigher(true);
        vm.prank(user);
        token.shareMint();
        assertGt(token.balanceOf(user), 0);

        marketMock.setHigher(false);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        token.shareMint();

        vm.prank(dao);
        token.burnShare(user);
        assertEq(token.usershares(user).leftamount, 0);

        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 73));
        token.addShare(s_share({leftamount: 10, metric: 1, chips: 0}), user);

        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 75));
        token.addShare(s_share({leftamount: 10, metric: 61, chips: 1}), user);
    }

    function testToken_publicSellAndWithdraw() public {
        uint256 amount = 1_000_000;
        vm.startPrank(user);
        deal(address(usdt), user, amount, false);
        usdt.approve(address(token), amount);
        token.publicSell(amount, "");
        vm.stopPrank();
        assertEq(token.balanceOf(user), amount * 25_000_000);

        address recv = makeAddr("recv");
        vm.prank(dao);
        token.withdrawPublicSell(amount, recv);
        assertEq(usdt.balanceOf(recv), amount);
    }

    function testToken_permitShare_andDaoMintBurn() public {
        s_share memory share = s_share({leftamount: 500_000, metric: 5, chips: 2});
        uint128 deadline = uint128(block.timestamp + 3600);
        bytes32 structHash = token.shareHash(share, user, 0, deadline, token.nonces(user));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ADMIN_KEY, digest);

        vm.prank(user);
        token.permitShare(share, deadline, abi.encodePacked(r, s, v), tokenAdmin);
        assertEq(token.usershares(user).leftamount, 500_000);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 72));
        token.permitShare(share, uint128(block.timestamp - 1), "", tokenAdmin);

        vm.prank(dao);
        token.mint(user, 1_000);
        vm.prank(user);
        token.burn(400);
        assertEq(token.balanceOf(user), 600);

        vm.prank(dao);
        token.burn(user, 100);
        assertEq(token.balanceOf(user), 500);
    }

    function testToken_proxyUpgradeFreezeAndDisable() public {
        TTSwap_Token impl2 = new TTSwap_Token(address(usdt));
        vm.prank(dao);
        proxy.upgrade(address(impl2));
        assertEq(proxy.implementation(), address(impl2));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        proxy.upgrade(address(impl));

        vm.prank(dao);
        proxy.freezeToken();
        assertEq(proxy.implementation(), address(0));

        vm.prank(dao);
        proxy.upgrade(address(impl));

        vm.prank(dao);
        token.disableUpgrade();
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        proxy.upgrade(address(impl2));
    }

    function testToken_disableUpgrade_revert_notDao() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        token.disableUpgrade();
    }

    function testToken_setDAOAdmin_andSidechainOnlyMain() public {
        address other = makeAddr("dao2");
        vm.prank(dao);
        token.setDAOAdmin(other, true);
        assertTrue(token.userConfig(other).isDAOAdmin());

        TTSwap_Token_Proxy side = new TTSwap_Token_Proxy(
            dao,
            10_000,
            "TTS",
            "TTS",
            address(impl)
        );
        TTSwap_Token sideTok = TTSwap_Token(payable(address(side)));
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 61));
        sideTok.mint(user, 1);
    }

    function testToken_publicSellCap_shareMintEmpty_andFreezeFallback() public {
        vm.prank(dao);
        token.addShare(s_share({leftamount: 100, metric: 1, chips: 1}), user);
        marketMock.setHigher(true);
        vm.prank(user);
        token.shareMint();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 69));
        token.shareMint();

        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 74));
        token.addShare(s_share({leftamount: 0, metric: 1, chips: 1}), user);

        uint256 over = 250_000_000_001;
        vm.startPrank(user);
        deal(address(usdt), user, over, false);
        usdt.approve(address(token), over);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 70));
        token.publicSell(over, "");
        vm.stopPrank();

        uint256 id = uint256(keccak256(abi.encode(user, stakeCaller)));
        vm.prank(stakeCaller);
        token.stake(user, 10);
        assertEq(token.stakeproofinfo(id).fromcontract, stakeCaller);

        vm.deal(address(this), 1 ether);
        (bool ok, ) = address(proxy).call{value: 1 ether}("");
        assertTrue(ok);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        proxy.freezeToken();

        vm.prank(dao);
        proxy.freezeToken();
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        token.balanceOf(user);
    }

    function testToken_publicSellTiers_andMergeChipsCap() public {
        vm.startPrank(user);
        uint256 tier2 = 87_500_000_001;
        deal(address(usdt), user, 250_000_000_000, false);
        usdt.approve(address(token), 250_000_000_000);
        token.publicSell(tier2, "");
        assertEq(token.balanceOf(user), tier2 * 20_000_000);

        uint256 tier3 = 162_500_000_001 - tier2;
        token.publicSell(tier3, "");
        vm.stopPrank();
        assertGt(token.balanceOf(user), tier2 * 20_000_000);

        vm.prank(dao);
        token.addShare(s_share({leftamount: 10, metric: 60, chips: 1}), user);
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 75));
        token.addShare(s_share({leftamount: 10, metric: 1, chips: 2}), user);
    }
}
