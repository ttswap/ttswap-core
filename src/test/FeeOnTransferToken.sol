// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

/// @notice Minimal fee-on-transfer ERC20 for testing: `feeBps` of every
/// transfer/transferFrom is diverted to `feeRecipient`, so the recipient
/// receives less than the nominal amount.
contract FeeOnTransferToken {
    string public constant name = "FeeOnTransfer";
    string public constant symbol = "FOT";
    uint8 public constant decimals = 18;

    address public immutable feeRecipient;
    uint256 public immutable feeBps;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(uint256 _feeBps) {
        feeBps = _feeBps;
        feeRecipient = address(0xFEE);
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 net = amount - fee;
        balanceOf[from] -= amount;
        balanceOf[to] += net;
        balanceOf[feeRecipient] += fee;
    }
}
