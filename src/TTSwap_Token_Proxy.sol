// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
import {I_TTSwap_StakeETH} from "./interfaces/I_TTSwap_StakeETH.sol";
import {TTSwapError} from "./libraries/L_Error.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
import {
    toTTSwapUINT256
} from "./libraries/L_TTSwapUINT256.sol";
/**
 * @title TTSwap_Market
 * @dev Core market contract for TTSwap protocol that manages goods trading, investing, and staking operations
 * @notice This contract implements a decentralized market system with the following key features:
 * - Meta good, value goods, and normal goods management
 * - Automated market making (AMM) with configurable fees
 * - Investment and disinvestment mechanisms
 * - Flash loan functionality
 * - Commission distribution system
 * - ETH or WETH staking integration
 */
contract TTSwap_Token_Proxy {
    using L_UserConfigLibrary for uint256;
    string internal name     ;
    string internal symbol ;
    string internal totalSupply;
    mapping(address => uint256) internal balanceOf;
    mapping(address => mapping(address => uint256))  internal allowance;
    mapping(address => uint256) internal nonces;
    address internal implementation;
    bool internal upgradeable;
    address internal usdt;
    uint256 internal ttstokenconfig;
    uint256 internal stakestate;
    uint128 internal left_share = 45_000_000_000_000;
    uint128 internal  publicsell ;
    mapping(address => uint256) internal userConfig;

    event e_updateUserConfig(address user, uint256 config);
    constructor(
       address _usdt, address _dao_admin, uint256 _ttsconfig,string memory _name,string memory _symbol,address _implementation
    ) {
        usdt = _usdt;
        stakestate = toTTSwapUINT256(uint128(block.timestamp), 0);
        ttstokenconfig = _ttsconfig;
        userConfig[_dao_admin]=userConfig[_dao_admin].setDAOAdmin(true);
        name =_name;
        symbol=_symbol;
        implementation=_implementation;
        upgradeable=true;
        emit e_updateUserConfig(_dao_admin,userConfig[_dao_admin]);
    }

    fallback() external payable{
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if iszero(result) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }

        /// onlydao admin can execute
    modifier onlyDAOadmin() {
        if (!userConfig[msg.sender].isDAOAdmin()||!upgradeable) revert TTSwapError(1);
        _;
    }

    function upgrade(address _implementation) external onlyDAOadmin{
        implementation=_implementation;
    }

    receive() external payable {}
}