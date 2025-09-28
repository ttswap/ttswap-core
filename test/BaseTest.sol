// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import "../src/TTSwap_Market.sol";
import "../src/TTSwap_Token.sol";
import "../src/TTSwap_Token_Proxy.sol";
import "../src/interfaces/I_TTSwap_Market.sol";
import "../src/interfaces/I_TTSwap_Token.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != from) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract BaseTest is Test {
    TTSwap_Market market;
    I_TTSwap_Token ttsToken;
    TTSwap_Token_Proxy tokenProxy;
    TTSwap_Token implementation;
    MockERC20 usdt;
    MockERC20 tokenA;
    MockERC20 tokenB;
    
    address constant ADMIN = address(0x1);
    address constant USER1 = address(0x2);
    address constant USER2 = address(0x3);
    address constant ATTACKER = address(0x666);
    
    uint256 constant INITIAL_BALANCE = 1000000 * 10**6;
    uint256 constant MAX_UINT128 = type(uint128).max;
    
    function setUp() public virtual {
        // Deploy mock tokens
        usdt = new MockERC20();
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        
        // Deploy TTS Token implementation
        implementation = new TTSwap_Token();
        
        // Deploy proxy with initial DAO admin
        tokenProxy = new TTSwap_Token_Proxy(
            address(usdt),
            ADMIN,  // Initial DAO admin
            2**255 + 5000, // Initial config - set bit 255 to enable main chain mode + 50% ratio
            "TTSwap Token",
            "TTS",
            address(implementation)
        );
        
        // Cast proxy to I_TTSwap_Token interface
        ttsToken = I_TTSwap_Token(address(tokenProxy));
        
        // Deploy market
        market = new TTSwap_Market(ttsToken, address(0));
        
        // Setup initial configuration as ADMIN
        vm.startPrank(ADMIN);
        
        // Now ADMIN is already DAO admin from proxy constructor
        // Set other admin privileges
        ttsToken.setTokenAdmin(ADMIN, true);
        ttsToken.setMarketAdmin(ADMIN, true);
        ttsToken.setMarketManager(ADMIN, true);  // Add market manager privilege
        ttsToken.setCallMintTTS(address(market), true);
        ttsToken.setEnv(address(market));
        
        // Mint initial tokens
        usdt.mint(ADMIN, INITIAL_BALANCE);
        usdt.mint(USER1, INITIAL_BALANCE);
        usdt.mint(USER2, INITIAL_BALANCE);
        tokenA.mint(ADMIN, INITIAL_BALANCE);
        tokenA.mint(USER1, INITIAL_BALANCE);
        tokenB.mint(ADMIN, INITIAL_BALANCE);
        tokenB.mint(USER1, INITIAL_BALANCE);
        
        vm.stopPrank();
    }
    
    function _createGoodConfig(
        bool isValueGood,
        uint8 investFee,
        uint8 disinvestFee,
        uint8 buyFee,
        uint8 sellFee
    ) internal pure returns (uint256) {
        uint256 config = 0;
        if (isValueGood) config |= (1 << 255);
        config |= (uint256(investFee) << 233);     // invest fee position
        config |= (uint256(disinvestFee) << 239);  // disinvest fee position
        config |= (uint256(buyFee) << 245);        // buy fee position
        config |= (uint256(sellFee) << 252);       // sell fee position
        config |= (uint256(1) << 63);              // power = 1 (valid range)
        return config;
    }
    
    function _boundFee(uint256 fee) internal pure returns (uint256) {
        return bound(fee, 0, 1000); // 0-10%
    }
}