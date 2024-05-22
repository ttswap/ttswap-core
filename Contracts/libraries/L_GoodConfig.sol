// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice
library L_GoodConfigLibrary {
    //商品配置
    function isvaluegood(uint256 config) internal pure returns (bool a) {
        uint256 b;
        assembly {
            b := shr(255, config)
        }
        return b == 1 ? true : false;
    }

    //商品投资费率 单位万分之一
    //起始位 5 长度 7
    function getInvestFee(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(249, shl(4, config))
        }
    }

    function getInvestFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(4, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    function getInvestFulFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(4, config))
                amount := div(amount, sub(10000, config))
                a := mul(amount, 10000)
            }
        }
    }

    //商品撤资费率 单位万分之一
    //起始位 13 长度 7
    function getDisinvestFee(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(249, shl(11, config))
        }
    }

    function getDisinvestFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(11, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    //商品购买费率 单位万分之一
    //起始位 20 长度 7
    function getBuyFee(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(249, shl(18, config))
        }
    }

    function getBuyFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(18, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    //商品出售费率 单位万分之一
    //起始位 27 长度 7
    function getSellFee(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(249, shl(25, config))
        }
    }

    function getSellFee(uint256 config, uint256 amount) internal pure returns (uint128 a) {
        unchecked {
            assembly {
                config := shr(249, shl(25, config))
                config := mul(config, amount)
                a := div(config, 10000)
            }
        }
    }

    // get swap chips
    function getSwapChips(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(246, shl(32, config))
        }
        return a * 64;
    }

    function getSwapChips(uint256 config, uint128 amount) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(246, shl(32, config))
        }
        if (a == 0) return amount;
        return (amount / (a * 64));
    }

    // get disinvest Chips
    function getDisinvestChips(uint256 config) internal pure returns (uint16 a) {
        assembly {
            a := shr(246, shl(42, config))
        }
        return a;
    }

    function getDisinvestChips(uint256 config, uint128 amount) internal pure returns (uint128) {
        uint128 a;
        assembly {
            a := shr(246, shl(42, config))
        }
        if (a == 0) return amount;
        return (amount / a);
    }

    //物品类型
    function getGoodType(uint256 config) internal pure returns (uint128 a) {
        assembly {
            a := shr(223, shl(52, config))
        }

        return a;
    }

    //电话号码
    function getTell(uint256 config) internal pure returns (uint128 a) {
        assembly {
            a := shr(208, shl(85, config))
        }

        return a;
    }

    //经度
    function getLongitude(uint256 config) internal pure returns (uint128 a) {
        assembly {
            a := shr(208, shl(133, config))
        }

        return a;
    }

    //纬度
    function getLatitude(uint256 config) internal pure returns (uint128 a) {
        assembly {
            a := shr(208, shl(181, config))
        }
        return a;
    }
}
