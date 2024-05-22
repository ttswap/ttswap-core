// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Library for computing the ID of a pool

library L_MarketConfigLibrary {
    //流动性提供者占比 单位百分之一
    //起始位 1 长度
    function getLiquidFee(uint256 config) internal pure returns (uint8 a) {
        assembly {
            a := shr(250, config)
        }
    }

    function getLiquidFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, config)
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    //投资者分佣占比 单位百分之一
    //起始位 7 长度 6
    function getSellerFee(uint256 config) internal pure returns (uint8 a) {
        assembly {
            a := shr(250, shl(6, config))
        }
    }

    function getSellerFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(6, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    //门户分佣占比 单位百分之一
    //起始位 53 长度 6
    function getGaterFee(uint256 config) internal pure returns (uint8 a) {
        unchecked {
            assembly {
                a := shr(250, shl(12, config))
            }
        }
    }

    function getGaterFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(12, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    //推荐人分佣占比 单位百分之一
    //起始位 59 长度 6
    function getReferFee(uint256 config) internal pure returns (uint8 a) {
        unchecked {
            assembly {
                a := shr(250, shl(18, config))
            }
        }
    }

    function getReferFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(18, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    //用户分佣占比 单位百分之一
    //起始位 65 长度 6
    function getCustomerFee(uint256 config) internal pure returns (uint8 a) {
        unchecked {
            assembly {
                a := shr(250, shl(24, config))
            }
        }
    }

    function getCustomerFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(250, shl(24, config))
                config := mul(amount, config)
                a := div(config, 100)
            }
        }
    }

    //平台分佣占比 单位百分之一
    //起始位 47 长度 5
    function getPlatFee(uint256 config) internal pure returns (uint8 a) {
        unchecked {
            assembly {
                a := shr(251, shl(30, config))
            }
        }
    }

    function getPlatFee128(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(251, shl(30, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function getPlatFee256(uint256 config, uint256 amount) internal pure returns (uint256 a) {
        unchecked {
            assembly {
                config := shr(251, shl(30, config))
                config := mul(config, amount)
                a := div(config, 100)
            }
        }
    }

    function checkAllocate(uint256 config) internal pure returns (bool) {
        uint8 a = getLiquidFee(config) + getSellerFee(config) + getGaterFee(config) + getReferFee(config)
            + getCustomerFee(config);
        return a == 100 ? true : false;
    }
}
