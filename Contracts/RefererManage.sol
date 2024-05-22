// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./interfaces/I_Referer.sol";

abstract contract RefererManage is I_Referer {
    uint256 public customernum;
    mapping(address => uint256) public customerno;
    mapping(address => address) public relations;

    constructor() {}

    /// @inheritdoc I_Referer
    function addreferer(address _referer) external override returns (bool is_success_) {
        require(customerno[msg.sender] == 0, "U1");
        customernum += 1;
        customerno[msg.sender] = customernum;
        relations[msg.sender] = _referer;
        emit e_addreferer(msg.sender, _referer);
        return true;
    }
}
