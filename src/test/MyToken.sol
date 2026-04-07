// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from "../base/ERC20.sol";

contract MyToken is ERC20 {
    address public owner;

    constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol, _decimals) {
        owner = msg.sender;
        _mint(msg.sender, 100000000 * 10 ** decimals);
    }

    function mint(address recipent, uint256 amount) external {
        require(amount <= 100000000);
        _mint(recipent, amount * 10 ** decimals);
    }

    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    function deposit() public payable virtual {
        emit Deposit(msg.sender, msg.value);
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public virtual {
        _burn(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);

        payable(msg.sender).transfer(amount);
    }

    receive() external payable virtual {
        deposit();
    }
}
