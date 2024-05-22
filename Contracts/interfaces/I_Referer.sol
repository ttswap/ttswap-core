// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface I_Referer {
    /// @notice user add referer~用户添加推荐人
    /// @param _referer   address or referer~推荐人地址
    function addreferer(address _referer) external returns (bool is_success_);
    /// @notice user addrefer~ 用户添加推荐人
    /// @param _user User address,用户地址
    /// @param _referer referer address,推荐人地址

    event e_addreferer(address _user, address _referer);
}
