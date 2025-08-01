// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
import {TTSwapError} from "./libraries/L_Error.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
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
contract TTSwap_StakeETH_Proxy {
    using L_UserConfigLibrary for uint256;
    address internal  implementation;
    bool internal upgradeable;
    I_TTSwap_Token internal immutable tts_token;

    constructor(
        address _implementation,
        I_TTSwap_Token _tts_token
    ) {
        implementation=_implementation;
        tts_token=_tts_token;
        upgradeable=true;
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
    modifier onlyStakeAdminProxy() {
        if (!tts_token.userConfig(msg.sender).isStakeAdmin()||!upgradeable) revert TTSwapError(1);
        _;
    }

                /// onlydao admin can execute
    modifier onlyStakeOperatorProxy() {
        if (!tts_token.userConfig(msg.sender).isStakeManager()||!upgradeable) revert TTSwapError(1);
        _;
    }

    function upgrade(address _implementation) external onlyStakeAdminProxy{
        implementation=_implementation;
    }

    function freezeStake() external onlyStakeOperatorProxy{
        implementation=address(0);
    }
    
    event e_Received(uint256 amount);
    /**
     * @notice Receive function to accept ETH transfers.
     * @dev Emits an event with the received ETH amount.
     */
    receive() external payable {
        emit e_Received(msg.value);
    }
}