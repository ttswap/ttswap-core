// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {I_TTSwap_Token} from "./interfaces/I_TTSwap_Token.sol";
import {I_TTSwap_StakeETH} from "./interfaces/I_TTSwap_StakeETH.sol";
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
contract TTSwap_Market_Proxy {
    using L_UserConfigLibrary for uint256;
    address internal  implementation;
    bool internal upgradeable;
    I_TTSwap_StakeETH private  restakeContract;
    I_TTSwap_Token private  officialTokenContract;

    constructor(
        I_TTSwap_Token _officialTokenContract,
        address _implementation
    ) {
        officialTokenContract = _officialTokenContract;
        implementation=_implementation;
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
    modifier onlyDAOadmin() {
        if (!officialTokenContract.userConfig(msg.sender).isDAOAdmin()||!upgradeable) revert TTSwapError(1);
        _;
    }

    function upgrade(address _implementation) external onlyDAOadmin{
        implementation=_implementation;
    }

    receive() external payable {}
}