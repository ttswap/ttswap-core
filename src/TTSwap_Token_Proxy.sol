// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {TTSwapError} from "./libraries/L_Error.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
import {toTTSwapUINT256} from "./libraries/L_TTSwapUINT256.sol";
/**
 * @title TTSwap Token Proxy
 * @dev Proxy contract for TTSwap Token using delegatecall.
 * @notice This contract stores the token state (balances, allowances, etc.) and delegates
 * logic execution to the implementation contract. It supports upgradability.
 */
contract TTSwap_Token_Proxy {
    using L_UserConfigLibrary for uint256;
    string internal name;
    string internal symbol;
    string internal totalSupply;
    mapping(address => uint256) internal balanceOf;
    mapping(address => mapping(address => uint256)) internal allowance;
    mapping(address => uint256) internal nonces;
    address public implementation;
    uint256 internal ttstokenconfig;
    bool public upgradeable;
    uint256 internal stakestate;
    uint128 internal left_share = 45_000_000_000_000;
    uint128 internal publicsell;
    mapping(address => uint256) internal userConfig;

    event e_updateUserConfig(address user, uint256 config);
    /// @notice Initializes the token proxy with admin, config, metadata, and implementation.
    /// @param _dao_admin The address of the initial DAO admin.
    /// @param _ttsconfig The initial token configuration value.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _implementation The address of the initial Token implementation logic.
    constructor(

        address _dao_admin,
        uint256 _ttsconfig,
        string memory _name,
        string memory _symbol,
        address _implementation
    ) {
       
        stakestate = toTTSwapUINT256(uint128(block.timestamp), 0);
        ttstokenconfig = _ttsconfig;
        userConfig[_dao_admin] = userConfig[_dao_admin].setDAOAdmin(true);
        name = _name;
        symbol = _symbol;
        implementation = _implementation;
        upgradeable = true;
        emit e_updateUserConfig(_dao_admin, userConfig[_dao_admin]);
    }

    /// @notice Fallback function that delegates calls to the implementation contract.
    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if iszero(result) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }

    /// @dev Restricts access to Token Admins.
    modifier onlyTokenAdminProxy() {
        if (!userConfig[msg.sender].isTokenAdmin() || !upgradeable)
            revert TTSwapError(1);
        _;
    }

    /// @dev Restricts access to Token Managers (Operators).
    modifier onlyTokenOperatorProxy() {
        if (!userConfig[msg.sender].isTokenManager() || !upgradeable)
            revert TTSwapError(1);
        _;
    }

    /// @notice Upgrades the token implementation contract.
    /// @param _implementation The new implementation address.
    function upgrade(address _implementation) external onlyTokenAdminProxy {
        implementation = _implementation;
    }

    /// @notice Freezes the token logic by setting implementation to address(0).
    /// @dev Can be called by Token Manager for emergency stops.
    function freezeToken() external onlyTokenOperatorProxy {
        implementation = address(0);
    }

    receive() external payable {}
}
