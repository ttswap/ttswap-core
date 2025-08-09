// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title L_GoodConfigLibrary
/// @notice A library for managing and retrieving configuration data for goods
/// @dev This library uses bitwise operations and assembly for efficient storage and retrieval of configuration data
library L_GoodConfigLibrary {
    /// @notice Check if the good is a value good
    /// @param config The configuration value
    /// @return a True if it's a value good, false otherwise
    function isvaluegood(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 255)) != 0;
    }

    /// @notice Check if the good is a normal good
    /// @param config The configuration value
    /// @return a True if it's a normal good, false otherwise
    function isnormalgood(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 255)) == 0;
    }

    function isFreeze(uint256 config) internal pure returns (bool a) {
        return (config & (1 << 254)) != 0;
    }

    function getLiquidFee(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(253, shl(2, config))
                config := mul(config, amount)
                a := div(config, 10)
            }
        }
    }

    function getOperatorFee(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(252, shl(5, config))
                config := mul(config, amount)
                a := div(config, 50)
            }
        }
    }

    function getGateFee(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(253, shl(9, config))
                config := mul(config, amount)
                a := div(config, 25)
            }
        }
    }

    function getReferFee(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(251, shl(12, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function getCustomerFee(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(251, shl(17, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function getPlatformFee128(uint256 config, uint256 amount)internal pure returns(uint128 a){
        unchecked {
            assembly {
                config := shr(251, shl(22, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function getPlatformFee256(uint256 config, uint256 amount)internal pure returns(uint256 a){
        unchecked {
            assembly {
                config := shr(251, shl(22, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function getLimitPower(uint256 config) internal pure returns(uint128 a){
        unchecked {
            assembly {
                a := shr(250, shl(27, config))
            }
            if(a==0) a=1;
        }
    }

    /// @notice Calculate the investment fee for a given amount
    /// @param config The configuration value
    /// @param amount The investment amount
    /// @return a The calculated investment fee
    function getInvestFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(33, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    function getInvestFullFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(33, config))
                amount := div(amount, sub(10000, config))
                a := mul(amount, 10000)
            }
        }
    }

    /// @notice Calculate the disinvestment fee for a given amount
    /// @param config The configuration value
    /// @param amount The disinvestment amount
    /// @return a The calculated disinvestment fee
    function getDisinvestFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(39, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Calculate the buying fee for a given amount
    /// @param config The configuration value
    /// @param amount The buying amount
    /// @return a The calculated buying fee
    function getBuyFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(45, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Calculate the selling fee for a given amount
    /// @param config The configuration value
    /// @param amount The selling amount
    /// @return a The calculated selling fee
    function getSellFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(52, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    /// @notice Get the swap chips for a given amount
    /// @param config The configuration value
    /// @param amount The amount
    /// @return The swap chips for the given amount
    function getPower(uint256 config, uint128 amount) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(246, shl(58, config))
        }
        if (a == 0) return 1;
        return (amount / a);
    }


    /// @notice Get the swap chips for a given amount
    /// @param config The configuration value
    /// @return The swap chips for the given amount
    function getPower(uint256 config) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(250, shl(63, config))
        }
        if (a == 0) return 1;
        return (a);
    }

    /// @notice Get the disinvestment chips for a given amount
    /// @param config The configuration value
    /// @param amount The amount
    /// @return The disinvestment chips for the given amount
    function getDisinvestChips(uint256 config, uint128 amount) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(246, shl(69, config))
        }
        if (a == 0) return amount;
        return (amount / a);
    }

    function checkGoodConfig(uint256 config) internal pure returns(bool result){
        result=false;
        uint256 liquid=((config/(2**251))%(2**3))*10;
        uint256 operator=((config/(2**247))%(2**3))*2;
        uint256 gate=((config/(2**244))%(2**3))*4;
        uint256 referal=((config/(2**239))%(2**5));
        uint256 cust=((config/(2**234))%(2**5));
        uint256 platform=((config/(2**229))%(2**5));
        if(liquid==0||operator==0||gate==0||referal==0||cust==0||platform==0) result=false;
        if(liquid+operator+gate+referal+cust+platform==100) result=true;
    }
}
