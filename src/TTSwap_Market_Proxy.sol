// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {TTSwapError} from "./libraries/L_Error.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
import {toTTSwapUINT256} from "./libraries/L_TTSwapUINT256.sol";
import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
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
contract TTSwap_Market_Proxy {
    using L_UserConfigLibrary for uint256;
    address public implementation;
    I_TTSwap_Token public TTS_CONTRACT;
    bool public upgradeable;
    constructor(
        I_TTSwap_Token _TTS_Contract,
        address _implementation
    ) {
        TTS_CONTRACT = _TTS_Contract;
        implementation = _implementation;
        upgradeable = true;
    }

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

    /// onlydao admin can execute
    modifier onlyMarketAdminProxy() {
        if (!TTS_CONTRACT.userConfig(msg.sender).isMarketAdmin() || !upgradeable)
            revert TTSwapError(1);
        _;
    }

    /// onlydao admin can execute
    modifier onlyMarketManagerProxy() {
        if (!TTS_CONTRACT.userConfig(msg.sender).isMarketManager() || !upgradeable)
            revert TTSwapError(1);
        _;
    }

    function upgrade(address _implementation) external onlyMarketAdminProxy {
        implementation = _implementation;
    }

    function disableUpgrade() external {
        if (!TTS_CONTRACT.userConfig(msg.sender).isDAOAdmin()) revert TTSwapError(62);
        upgradeable = false;
    }

    function freezeMarket() external onlyMarketManagerProxy {
        implementation = address(0);
    }

    receive() external payable {}
}
