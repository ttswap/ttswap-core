// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-gas-snapshot/src/GasSnapshot.sol";
import {Test, console2, Vm} from "forge-std/src/Test.sol";
import {MyToken} from "../src/test/MyToken.sol";
import "../src/TTSwap_Market.sol";
import "../src/TTSwap_Token.sol";
import "../src/TTSwap_Token_Proxy.sol";    
    import {TTSwap_Market_Proxy} from "../src/TTSwap_Market_Proxy.sol";
import {BaseSetup} from "./BaseSetup.t.sol";
import {S_ProofKey} from "../src/interfaces/I_TTSwap_Market.sol";
import {L_ProofIdLibrary, L_Proof} from "../src/libraries/L_Proof.sol";
import {L_Good} from "../src/libraries/L_Good.sol";
import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";

import {L_GoodConfigLibrary} from "../src/libraries/L_GoodConfig.sol";

import {L_TTSwapUINT256Library, toTTSwapUINT256, addsub, subadd, lowerprice, toUint128} from "../src/libraries/L_TTSwapUINT256.sol";

contract modified_swap_without_fee is Test, GasSnapshot {
    using L_TTSwapUINT256Library for uint256;
    using L_GoodConfigLibrary for uint256;

    using L_ProofIdLibrary for S_ProofKey;
    using L_TTSwapUINT256Library for uint256;

    address metagood;
    address normalgoodusdt;
    address normalgoodusdc;
    address normalgoodbtc;
    address payable[8] internal users;
    MyToken usdc;
    MyToken usdt;
    MyToken btc;
    address marketcreator;
    TTSwap_Market market;
    TTSwap_Token tts_token;
    TTSwap_Token_Proxy tts_token_proxy;
    TTSwap_Market_Proxy market_proxy;
    bytes internal constant defaultdata = bytes("");

    function setUp() public {
        users[0] = payable(address(1));
        users[1] = payable(address(2));
        users[2] = payable(address(3));
        users[3] = payable(address(4));
        users[4] = payable(address(5));
        users[5] = payable(address(15));
        users[6] = payable(address(16));
        users[7] = payable(address(17));
        marketcreator = payable(address(6));
        usdt = new MyToken("USDT", "USDT", 6);
        usdc = new MyToken("USDC", "USDC", 6);
        btc = new MyToken("BTC", "BTC", 8);
        vm.startPrank(marketcreator);
        TTSwap_Token tts_token_logic = new TTSwap_Token(address(usdt));
        tts_token_proxy = new TTSwap_Token_Proxy(
            
            marketcreator,
            2 ** 255 + 10000,
            "TTSwap Token",
            "TTS",
            address(tts_token_logic)
        );
        tts_token = TTSwap_Token(payable(address(tts_token_proxy)));
        market = new TTSwap_Market(tts_token);
        market_proxy = new TTSwap_Market_Proxy(tts_token,address(market));
        market = TTSwap_Market(payable(address(market_proxy)));
       
        tts_token.setTokenAdmin(marketcreator, true);
        tts_token.setTokenManager(marketcreator, true);
        tts_token.setCallMintTTS(address(market), true);
        tts_token.setMarketAdmin(marketcreator, true);
        tts_token.setStakeAdmin(marketcreator, true);
        tts_token.setStakeManager(marketcreator, true);
        vm.stopPrank();
        initmetagood();
        initusdcgood();
        initbtcgood();
    }

    function initmetagood() public {
        vm.startPrank(marketcreator);
        deal(address(usdt), marketcreator, 1000000 * 10 ** 6, false);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(usdt),
            toTTSwapUINT256(50000 * 10 ** 12, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        metagood = address(usdt);
        vm.stopPrank();
    }

    function initusdcgood() public {
        vm.startPrank(marketcreator);
        deal(address(usdc), marketcreator, 1000000 * 10 ** 6, false);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(usdc),
            toTTSwapUINT256(50000 * 10 ** 12, 50000 * 10 ** 6),
            _goodconfig,
            defaultdata
        );
        normalgoodusdc = address(usdc);
        vm.stopPrank();
    }

    function initbtcgood() public {
        vm.startPrank(marketcreator);
        deal(address(btc), marketcreator, 1000000 * 10 ** 8, false);
        btc.approve(address(market), 100 * 10 ** 8 + 1);
        uint256 _goodconfig = (2 ** 255);
        market.initMetaGood(
            address(btc),
            toTTSwapUINT256(118000 * 10 ** 12, 1 * 10 ** 8),
            _goodconfig,
            defaultdata
        );
        normalgoodbtc = address(btc);
        vm.stopPrank();
    }

    /**
     * @notice 纯数学测试：当K为固定值时，good1Swap+good2Swap 组合是否可逆
     * @dev 复现白皮书附录I的公式，验证 Δa -> ΔV -> Δb -> ΔV' -> Δa' 时 Δa' == Δa
     *      白皮书证明：当 K=2 时严格可逆；代码中 K 缩放100倍，故 K=200
     * 公式 (无手续费):
     * - good1Swap输入侧: ΔV = K*V*Δa / (K*Q + Δa*100)
     * - good2Swap输出侧: Δb = K*Q*ΔV / (K*V + ΔV*100)
     */
    function testFixedKSwapReversibility() public pure {
        // 固定K值，对应白皮书K=2 (代码中K缩放100倍，故K=200)
        uint128 K = 200;

        // 初始池状态 (与initMetaGood一致: Q=V, I=Q, virtual=0)
        uint128 Q_A = 50_000 * 10**6;
        uint128 V_A = 50_000 * 10**12; // amount1 of investState
        uint128 Q_B = 50_000 * 10**6;
        uint128 V_B = 50_000 * 10**12;

        // 正向: 输入 Δa 个 Token A
        uint128 deltaA = 10_000 * 10**6;

        // Step 1: good1Swap(A, side=true): quantity -> value
        uint256 deltaV = (uint256(K) * uint256(V_A) * uint256(deltaA))
            / (uint256(K) * uint256(Q_A) + uint256(deltaA) * 100);

        // Step 2: good2Swap(B, side=true): value -> quantity
        uint256 deltaB = (uint256(K) * uint256(Q_B) * deltaV)
            / (uint256(K) * uint256(V_B) + deltaV * 100);

        // 正向后池状态
        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        // 反向: 输入 Δb 个 Token B 换回 Token A
        uint128 deltaB_u128 = uint128(deltaB);

        // Step 3: good1Swap(B, side=true): quantity -> value
        uint256 deltaV_rev = (uint256(K) * uint256(V_B) * uint256(deltaB_u128))
            / (uint256(K) * uint256(Q_B_after) + uint256(deltaB_u128) * 100);

        // Step 4: good2Swap(A, side=true): value -> quantity
        uint256 deltaA_rev = (uint256(K) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K) * uint256(V_A) + deltaV_rev * 100);

        // 可逆性断言: Δa' 应等于 Δa (允许1单位整数截断误差)
        assertApproxEqAbs(
            deltaA_rev,
            uint256(deltaA),
            1,
            "Fixed K: A->B->A should be reversible (within rounding)"
        );
    }

    /// @notice 验证 K=300 时是否可逆 (白皮书附录I: 仅 K=2 时可逆)
    function testFixedK300SwapReversibility() public pure {
        uint128 K = 300;
        uint128 Q_A = 50_000 * 10**6;
        uint128 V_A = 50_000 * 10**12;
        uint128 Q_B = 50_000 * 10**6;
        uint128 V_B = 50_000 * 10**12;
        uint128 deltaA = 10_000 * 10**6;

        uint256 deltaV = (uint256(K) * uint256(V_A) * uint256(deltaA))
            / (uint256(K) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K) * uint256(Q_B) * deltaV)
            / (uint256(K) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        uint256 deltaV_rev = (uint256(K) * uint256(V_B) * deltaB)
            / (uint256(K) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K) * uint256(V_A) + deltaV_rev * 100);

        // K=300 不可逆: 反向换回量 deltaA_rev > deltaA，存在套利空间
        assertGt(deltaA_rev, uint256(deltaA), "K=300: not reversible, reverse yields more");
    }

    /**
     * @notice 验证非对称K的可逆性: A池 数量→价值K=300, 价值→数量K=150; B池K=200
     * @dev 带*100因子的可逆条件: k2=100*k1/(k1-100). 故 k1=300 时 k2=150 恰好可逆
     */
    function testAsymmetricKReversibility() public pure {
        uint128 K_A_in = 300;  // A 数量→价值
        uint128 K_A_out = 150; // A 价值→数量
        uint128 K_B = 200;     // B 双向

        uint128 Q_A = 50_000 * 10**6;
        uint128 V_A = 50_000 * 10**12;
        uint128 Q_B = 50_000 * 10**6;
        uint128 V_B = 50_000 * 10**12;
        uint128 deltaA = 10_000 * 10**6;

        // 正向 A->B: A用K_A_in算Δv, B用K_B算Δb
        uint256 deltaV = (uint256(K_A_in) * uint256(V_A) * uint256(deltaA))
            / (uint256(K_A_in) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K_B) * uint256(Q_B) * deltaV)
            / (uint256(K_B) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        // 反向 B->A: B用K_B算Δv', A用K_A_out算Δa'
        uint256 deltaV_rev = (uint256(K_B) * uint256(V_B) * deltaB)
            / (uint256(K_B) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K_A_out) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K_A_out) * uint256(V_A) + deltaV_rev * 100);

        // 可逆性: 允许整数截断误差
        assertApproxEqAbs(
            deltaA_rev,
            uint256(deltaA),
            1,
            "Asymmetric K: A(K_in=300,K_out=150) B(200) reversibility check"
        );
    }

    /**
     * @notice 验证双池同参数可逆性: A和B均为 数量→价值K=300, 价值→数量K=150
     */
    function testBothPoolsAsymmetricKReversibility() public pure {
        uint128 K_in = 300;
        uint128 K_out = 150;

        uint128 Q_A = 50_000 * 10**6;
        uint128 V_A = 50_000 * 10**12;
        uint128 Q_B = 50_000 * 10**6;
        uint128 V_B = 50_000 * 10**12;
        uint128 deltaA = 10_000 * 10**6;

        // 正向 A->B: A用K_in, B用K_out
        uint256 deltaV = (uint256(K_in) * uint256(V_A) * uint256(deltaA))
            / (uint256(K_in) * uint256(Q_A) + uint256(deltaA) * 100);
        uint256 deltaB = (uint256(K_out) * uint256(Q_B) * deltaV)
            / (uint256(K_out) * uint256(V_B) + deltaV * 100);

        uint128 Q_A_after = Q_A + deltaA;
        uint128 Q_B_after = uint128(uint256(Q_B) - deltaB);

        // 反向 B->A: B用K_in, A用K_out
        uint256 deltaV_rev = (uint256(K_in) * uint256(V_B) * deltaB)
            / (uint256(K_in) * uint256(Q_B_after) + deltaB * 100);
        uint256 deltaA_rev = (uint256(K_out) * uint256(Q_A_after) * deltaV_rev)
            / (uint256(K_out) * uint256(V_A) + deltaV_rev * 100);

        assertApproxEqAbs(
            deltaA_rev,
            uint256(deltaA),
            1,
            "Both pools K_in=300,K_out=150 reversibility check"
        );
    }

    function testswapA2B2Awithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore1:", usdcbefore);
        console2.log("usdcafter1:", usdcafter);
        console2.log("usdtbefore1:", usdtbefore);
        console2.log("usdtafter1:", usdtafter);
        market.buyGood(
            address(usdt),
            address(usdc),
            toTTSwapUINT256(8823529411, 6000000000),
            
            msg.sender,
            "",
            marketcreator,""
        );

        snapLastCall("testswapwithoutfee1");
        usdcafter = usdc.balanceOf(address(marketcreator));
        usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        S_GoodTmpState memory afterusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory afterusdt = market.getGoodState(address(usdt));
        console2.log(
            "beforeusdc_currentStateamount0:",
            beforeusdc.currentState.amount0()
        );
        console2.log(
            "afterusdc_currentStateamount0:",
            afterusdc.currentState.amount0()
        );
        console2.log(
            "beforeusdc_currentStateamount1:",
            beforeusdc.currentState.amount1()
        );
        console2.log(
            "afterusdc_currentStateamount1:",
            afterusdc.currentState.amount1()
        );
        console2.log(
            "beforeusdc_investStateamount0:",
            beforeusdc.investState.amount0()
        );
        console2.log(
            "afterusdc_investStateamount0:",
            afterusdc.investState.amount0()
        );
        console2.log(
            "beforeusdc_investStateamount1:",
            beforeusdc.investState.amount1()
        );
        console2.log(
            "afterusdc_investStateamount1:",
            afterusdc.investState.amount1()
        );
       
        console2.log(
            "beforeusdt_currentStateamount0:",
            beforeusdt.currentState.amount0()
        );
        console2.log(
            "afterusdt_currentStateamount0:",
            afterusdt.currentState.amount0()
        );
        console2.log(
            "beforeusdt_currentStateamount1:",
            beforeusdt.currentState.amount1()
        );
        console2.log(
            "afterusdt_currentStateamount1:",
            afterusdt.currentState.amount1()
        );
        console2.log(
            "beforeusdt_investStateamount0:",
            beforeusdt.investState.amount0()
        );
        console2.log(
            "afterusdt_investStateamount0:",
            afterusdt.investState.amount0()
        );
        console2.log(
            "beforeusdt_investStateamount1:",
            beforeusdt.investState.amount1()
        );
        console2.log(
            "afterusdt_investStateamount1:",
            afterusdt.investState.amount1()
        );
        
        vm.stopPrank();
    }

    function testswapA2B2C2Awithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(address(market));
        uint256 usdtbefore = usdt.balanceOf(address(market));
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(address(market)));
        uint256 usdtafter = usdt.balanceOf(address(address(market)));
        uint256 btcbefore = btc.balanceOf(address(address(market)));
        console2.log("btcbefore:", btcbefore);
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        market.buyGood(
            address(usdt),
            address(btc),
            toTTSwapUINT256(8333333332, 0),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        usdcafter = usdc.balanceOf(address(address(market)));
        usdtafter = usdt.balanceOf(address(address(market)));
        uint256 btcafter = btc.balanceOf(address(address(market)));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        console2.log("btcafter:", btcafter);
        market.buyGood(
            address(btc),
            address(usdc),
            toTTSwapUINT256(7418397, 0),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee3");
        usdcafter = usdc.balanceOf(address(market));
        usdtafter = usdt.balanceOf(address(market));
        btcafter = btc.balanceOf(address(market));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        console2.log("btcafter:", btcafter);
        vm.stopPrank();
    }

    function testswapA2B_part1() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        vm.stopPrank();
    }

  //usdcbefore: 950000000000
  //usdtbefore: 950000000000
  //usdcafter: 940000000000
  //usdtafter: 958333333332
    function testswapA2B_part2() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(marketcreator);
        uint256 usdtbefore = usdt.balanceOf(marketcreator);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(5000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );

        market.buyGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(5000 * 10 ** 6, 1000 * 10 ** 6),
            
            address(0),
            "",
            marketcreator,""
        );
        snapLastCall("testswapwithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        vm.stopPrank();
    }

    function testpaywithoutfee() public {
        vm.startPrank(marketcreator);
        uint256 usdcbefore = usdc.balanceOf(address(marketcreator));
        uint256 usdtbefore = usdt.balanceOf(address(marketcreator));
        console2.log("usdcbefore:", usdcbefore);
        console2.log("usdtbefore:", usdtbefore);
        usdt.approve(address(market), 50000 * 10 ** 6 + 1);
        S_GoodTmpState memory beforeusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory beforeusdt = market.getGoodState(address(usdt));
        market.payGood(
            address(usdt),
            address(usdc),
            toTTSwapUINT256(3000 * 10 ** 6, 1000 * 10 ** 6),
            
            marketcreator,
            "",
            marketcreator,"",0
        );
        snapLastCall("testpaywithoutfee1");
        uint256 usdcafter = usdc.balanceOf(address(marketcreator));
        uint256 usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        usdc.approve(address(market), 50000 * 10 ** 6 + 1);
        market.payGood(
            address(usdc),
            address(usdt),
            toTTSwapUINT256(10000 * 10 ** 6, 1020408163),
            marketcreator,
            "",
            marketcreator,"",0
        );
        snapLastCall("testpaywithoutfee2");
        usdcafter = usdc.balanceOf(address(marketcreator));
        usdtafter = usdt.balanceOf(address(marketcreator));
        console2.log("usdcafter:", usdcafter);
        console2.log("usdtafter:", usdtafter);
        S_GoodTmpState memory afterusdc = market.getGoodState(address(usdc));
        S_GoodTmpState memory afterusdt = market.getGoodState(address(usdt));
        console2.log(
            "beforeusdc_currentStateamount0:",
            beforeusdc.currentState.amount0()
        );
        console2.log(
            "afterusdc_currentStateamount0:",
            afterusdc.currentState.amount0()
        );
        console2.log(
            "beforeusdc_currentStateamount1:",
            beforeusdc.currentState.amount1()
        );
        console2.log(
            "afterusdc_currentStateamount1:",
            afterusdc.currentState.amount1()
        );
        console2.log(
            "beforeusdc_investStateamount0:",
            beforeusdc.investState.amount0()
        );
        console2.log(
            "afterusdc_investStateamount0:",
            afterusdc.investState.amount0()
        );
        console2.log(
            "beforeusdc_investStateamount1:",
            beforeusdc.investState.amount1()
        );
        console2.log(
            "afterusdc_investStateamount1:",
            afterusdc.investState.amount1()
        );
       
        console2.log(
            "beforeusdt_currentStateamount0:",
            beforeusdt.currentState.amount0()
        );
        console2.log(
            "afterusdt_currentStateamount0:",
            afterusdt.currentState.amount0()
        );
        console2.log(
            "beforeusdt_currentStateamount1:",
            beforeusdt.currentState.amount1()
        );
        console2.log(
            "afterusdt_currentStateamount1:",
            afterusdt.currentState.amount1()
        );
        console2.log(
            "beforeusdt_investStateamount0:",
            beforeusdt.investState.amount0()
        );
        console2.log(
            "afterusdt_investStateamount0:",
            afterusdt.investState.amount0()
        );
        console2.log(
            "beforeusdt_investStateamount1:",
            beforeusdt.investState.amount1()
        );
        console2.log(
            "afterusdt_investStateamount1:",
            afterusdt.investState.amount1()
        );
        
        vm.stopPrank();
    }

    // function testaaswap()public{
    //     vm.startPrank(marketcreator);
    //     uint256 usdcbefore=usdc.balanceOf(marketcreator);
    //     uint256 usdtbefore=usdt.balanceOf(marketcreator);
    //     usdc.approve(address(market), 50000 * 10 ** 6 + 1);
    //     usdt.approve(address(market), 50000 * 10 ** 6 + 1);
    //     market.buyGood(address(usdc),address(usdt),1000*10**6,5,address(0),"");
    //     uint256 usdcafter=usdc.balanceOf(marketcreator);
    //     uint256 usdtafter=usdt.balanceOf(marketcreator);
    //     console2.log("usdcbefore:",usdcbefore);
    //     console2.log("usdtbefore:",usdtbefore);
    //     console2.log("usdcafter:",usdcafter);
    //     console2.log("usdtafter:",usdtafter);
    //     market.buyGood(address(usdt),address(usdc),99601593,5,address(0),"");
    //     usdcafter=usdc.balanceOf(marketcreator);
    //     usdtafter=usdt.balanceOf(marketcreator);

    //     console2.log("usdcafter:",usdcafter);
    //     console2.log("usdtafter:",usdtafter);
    //     vm.stopPrank();
    // }
}
