// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {L_Proof} from "./L_Proof.sol";
import {L_MarketConfigLibrary} from "./L_MarketConfig.sol";
import {L_GoodConfigLibrary} from "./L_GoodConfig.sol";
import {S_Ralate, S_GoodKey} from "./L_Struct.sol";

import {
    T_BalanceUINT256,
    L_BalanceUINT256Library,
    toBalanceUINT256,
    addsub,
    subadd,
    lowerprice
} from "./L_BalanceUINT256.sol";

library L_Good {
    using L_GoodConfigLibrary for uint256;
    using L_MarketConfigLibrary for uint256;
    using L_BalanceUINT256Library for uint256;
    using L_Proof for L_Proof.S_ProofState;

    struct S_GoodState {
        uint256 goodConfig; //商品配置refer to goodConfig
        address owner; //商品创建者 good's creator
        address erc20address; //商品的erc20合约地址good's erc20address
        T_BalanceUINT256 currentState; //前128位表示商品的价值,后128位表示商品数量 amount0:the good's total value ,amount1:the good's quantity
        T_BalanceUINT256 investState; //前128位表示商品的投资总价值,后128位表示商品投资总数量 amount0:the good's total invest value,amount1:the good's total invest quantity
        T_BalanceUINT256 feeQunitityState; //前128位表示商品的手续费总额(包含构建手续费),后128位表示商品的构建手续费总额 amount0:the good's total fee quantity which contain contruct fee,amount1:the good's total contruct fee.
        mapping(address => uint256) fees;
    }

    struct S_GoodTmpState {
        uint256 goodConfig; //商品配置refer to goodConfig
        address owner; //商品创建者 good's creator
        address erc20address; //商品的erc20合约地址good's erc20address
        T_BalanceUINT256 currentState; //前128位表示商品的价值,后128位表示商品数量 amount0:the good's total value ,amount1:the good's quantity
        T_BalanceUINT256 investState; //前128位表示商品的投资总价值,后128位表示商品投资总数量 amount0:the good's total invest value,amount1:the good's total invest quantity
        T_BalanceUINT256 feeQunitityState; //前128位表示商品的手续费总额(包含构建手续费),后128位表示商品的构建手续费总额 amount0:the good's total fee quantity which contain contruct fee,amount1:the good's total contruct fee.
    }

    struct S_GoodInvestReturn {
        uint128 actualFeeQuantity; //实际手续费
        uint128 contructFeeQuantity; //构建手续费
        uint128 actualInvestValue; //实际投资价值
        uint128 actualInvestQuantity; //实际投资数量
    }

    struct S_GoodDisinvestReturn {
        uint128 profit; //实际手续费
        uint128 actual_fee; //构建手续费
        uint128 actualDisinvestValue; //实际投资价值
        uint128 actualDisinvestQuantity; //实际投资数量
    }

    function getMaxTradeValue(S_GoodState storage self) internal view returns (uint128) {
        return self.goodConfig.getSwapChips(self.currentState.amount0());
    }

    function getMaxTradeQunitity(S_GoodState storage self) internal view returns (uint128) {
        return self.goodConfig.getSwapChips(self.currentState.amount1());
    }

    function updateToValueGood(S_GoodState storage self) internal {
        require(!self.goodConfig.isvaluegood(), "G007");
        uint256 b = self.goodConfig;
        assembly {
            b := shr(1, shl(1, b))
        }
        self.goodConfig = b + 1 * 2 ** 255;
    }

    function updateToNormalGood(S_GoodState storage self) internal {
        require(self.goodConfig.isvaluegood(), "G008");
        uint256 b = self.goodConfig;
        assembly {
            b := shr(1, shl(1, b))
        }
        self.goodConfig = b;
    }

    function updateGoodConfig(S_GoodState storage _self, uint256 _goodConfig) internal {
        assembly {
            _goodConfig := shr(4, shl(4, _goodConfig))
        }
        _self.goodConfig = (_self.goodConfig & (15 * 2 ** 252)) + _goodConfig;
    }

    function init(S_GoodState storage self, T_BalanceUINT256 _init, address _erc20address, uint256 _goodConfig)
        internal
    {
        self.currentState = _init;
        self.investState = _init;
        assembly {
            _goodConfig := shr(1, shl(1, _goodConfig))
        }
        self.goodConfig = _goodConfig;
        self.erc20address = _erc20address;
        self.owner = msg.sender;
    }

    struct swapCache {
        uint128 remainQuantity;
        uint128 outputQuantity;
        uint128 feeQuantity;
        uint128 swapvalue;
        T_BalanceUINT256 good1currentState;
        uint256 good1config;
        T_BalanceUINT256 good2currentState;
        uint256 good2config;
    }

    function swapCompute1(swapCache memory _stepCache, T_BalanceUINT256 _limitPrice)
        internal
        pure
        returns (swapCache memory)
    {
        uint128 minValue;
        uint128 minQuantity;
        _stepCache.feeQuantity = _stepCache.good1config.getSellFee(_stepCache.remainQuantity);
        _stepCache.remainQuantity -= _stepCache.feeQuantity;
        while (
            _stepCache.remainQuantity > 0
                && lowerprice(_stepCache.good1currentState, _stepCache.good2currentState, _limitPrice)
        ) {
            minValue = _stepCache.good1config.getSwapChips(_stepCache.good1currentState.amount0())
                >= _stepCache.good2config.getSwapChips(_stepCache.good2currentState.amount0())
                ? _stepCache.good2config.getSwapChips(_stepCache.good2currentState.amount0())
                : _stepCache.good1config.getSwapChips(_stepCache.good1currentState.amount0());
            minQuantity = _stepCache.good1currentState.getamount1fromamount0(minValue);

            if (_stepCache.remainQuantity > minQuantity) {
                _stepCache.remainQuantity -= minQuantity;

                _stepCache.outputQuantity += _stepCache.good2currentState.getamount1fromamount0(minValue);

                _stepCache.good1currentState =
                    subadd(_stepCache.good1currentState, toBalanceUINT256(minValue, minQuantity));
                _stepCache.good2currentState = addsub(
                    _stepCache.good2currentState,
                    toBalanceUINT256(minValue, _stepCache.good2currentState.getamount1fromamount0(minValue))
                );
            } else {
                minValue = _stepCache.good1currentState.getamount0fromamount1(_stepCache.remainQuantity);

                _stepCache.outputQuantity += _stepCache.good2currentState.getamount1fromamount0(minValue);

                _stepCache.good1currentState =
                    subadd(_stepCache.good1currentState, toBalanceUINT256(minValue, _stepCache.remainQuantity));

                _stepCache.good2currentState = addsub(
                    _stepCache.good2currentState,
                    toBalanceUINT256(minValue, _stepCache.good2currentState.getamount1fromamount0(minValue))
                );
                _stepCache.remainQuantity = 0;
            }
            _stepCache.swapvalue += minValue;
        }

        if (_stepCache.remainQuantity > 0) {
            _stepCache.feeQuantity -= _stepCache.good1config.getSellerFee(_stepCache.remainQuantity);
            _stepCache.remainQuantity += _stepCache.good1config.getSellerFee(_stepCache.remainQuantity);
        }

        return _stepCache;
    }

    function swapCompute2(swapCache memory _stepCache, T_BalanceUINT256 _limitPrice)
        internal
        pure
        returns (swapCache memory)
    {
        uint128 minValue;
        uint128 minQuantity;
        _stepCache.feeQuantity = _stepCache.good2config.getBuyFee(_stepCache.remainQuantity);
        while (
            _stepCache.remainQuantity > 0
                && lowerprice(_stepCache.good1currentState, _stepCache.good2currentState, _limitPrice)
        ) {
            minValue = _stepCache.good1config.getSwapChips(_stepCache.good1currentState.amount0())
                >= _stepCache.good2config.getSwapChips(_stepCache.good2currentState.amount0())
                ? _stepCache.good2config.getSwapChips(_stepCache.good2currentState.amount0())
                : _stepCache.good1config.getSwapChips(_stepCache.good1currentState.amount0());
            minQuantity = _stepCache.good2currentState.getamount1fromamount0(minValue);

            if (_stepCache.remainQuantity > minQuantity) {
                _stepCache.remainQuantity -= minQuantity;

                _stepCache.outputQuantity += _stepCache.good1currentState.getamount1fromamount0(minValue);
                _stepCache.good2currentState =
                    addsub(_stepCache.good2currentState, toBalanceUINT256(minValue, minQuantity));
                _stepCache.good1currentState = subadd(
                    _stepCache.good1currentState,
                    toBalanceUINT256(minValue, _stepCache.good1currentState.getamount1fromamount0(minValue))
                );
            } else {
                minValue = _stepCache.good2currentState.getamount0fromamount1(_stepCache.remainQuantity);
                _stepCache.outputQuantity += _stepCache.good1currentState.getamount1fromamount0(minValue);
                _stepCache.good2currentState =
                    addsub(_stepCache.good2currentState, toBalanceUINT256(minValue, _stepCache.remainQuantity));

                _stepCache.good1currentState = subadd(
                    _stepCache.good1currentState,
                    toBalanceUINT256(minValue, _stepCache.good1currentState.getamount1fromamount0(minValue))
                );
                _stepCache.remainQuantity = 0;
            }
            if (_stepCache.remainQuantity > 0) {
                _stepCache.feeQuantity -= _stepCache.good1config.getSellerFee(_stepCache.remainQuantity);
            }
            _stepCache.swapvalue += minValue;
        }
        return _stepCache;
    }

    function swapCommit(
        S_GoodState storage _self,
        T_BalanceUINT256 _swapstate,
        uint128 _fee,
        uint256 _marketconfig,
        S_Ralate memory _ralate
    ) internal {
        _self.currentState = _swapstate;
        _self.feeQunitityState = _self.feeQunitityState + toBalanceUINT256(_marketconfig.getLiquidFee(_fee), 0);
        if (_fee > 0) allocateFee(_self, _fee, _marketconfig, _ralate);
    }

    function investGood(S_GoodState storage _self, uint128 _invest, uint256 _marketConfig, S_Ralate memory _ralate)
        internal
        returns (S_GoodInvestReturn memory investResult_)
    {
        investResult_.actualInvestQuantity = _invest - _self.goodConfig.getInvestFee(_invest);

        investResult_.actualInvestValue = _self.currentState.getamount0fromamount1(investResult_.actualInvestQuantity);

        investResult_.contructFeeQuantity = toBalanceUINT256(
            _self.feeQunitityState.amount0(), _self.investState.amount1()
        ).getamount0fromamount1(investResult_.actualInvestQuantity);

        investResult_.actualFeeQuantity = _marketConfig.getLiquidFee(_invest - investResult_.actualInvestQuantity);

        _self.feeQunitityState = _self.feeQunitityState
            + toBalanceUINT256(
                investResult_.actualFeeQuantity + investResult_.contructFeeQuantity, investResult_.contructFeeQuantity
            );
        _self.currentState =
            _self.currentState + toBalanceUINT256(investResult_.actualInvestValue, investResult_.actualInvestQuantity);
        _self.investState =
            _self.investState + toBalanceUINT256(investResult_.actualInvestValue, investResult_.actualInvestQuantity);
        uint128 actutal_fee = _invest - investResult_.actualInvestQuantity;
        if (actutal_fee > 0) {
            allocateFee(_self, actutal_fee, _marketConfig, _ralate);
        }
    }

    function disinvestGood(
        S_GoodState storage _self,
        S_GoodState storage _valueGoodState,
        L_Proof.S_ProofState storage _investProof,
        uint128 _goodQuantity,
        uint256 _marketconfig,
        S_Ralate memory _ralate
    )
        internal
        returns (S_GoodDisinvestReturn memory normalGoodResult1_, S_GoodDisinvestReturn memory valueGoodResult2_)
    {
        require(_self.goodConfig.isvaluegood() || _valueGoodState.goodConfig.isvaluegood(), "G10");
        uint128 var1 = toBalanceUINT256(_investProof.state.amount0(), _investProof.invest.amount1())
            .getamount0fromamount1(_goodQuantity);
        normalGoodResult1_ = S_GoodDisinvestReturn(
            toBalanceUINT256(_self.feeQunitityState.amount0(), _self.investState.amount1()).getamount0fromamount1(
                _goodQuantity
            ),
            toBalanceUINT256(_investProof.invest.amount0(), _investProof.invest.amount1()).getamount0fromamount1(
                _goodQuantity
            ),
            var1,
            _goodQuantity
        );

        require(
            normalGoodResult1_.actualDisinvestValue < _self.goodConfig.getDisinvestChips(_self.currentState.amount0())
                && _goodQuantity < _self.goodConfig.getDisinvestChips(_self.currentState.amount1()),
            "G011"
        );

        _self.currentState = _self.currentState
            - toBalanceUINT256(normalGoodResult1_.actualDisinvestValue, normalGoodResult1_.actualDisinvestQuantity);

        _self.investState = _self.investState
            - toBalanceUINT256(normalGoodResult1_.actualDisinvestValue, normalGoodResult1_.actualDisinvestQuantity);

        _self.feeQunitityState =
            _self.feeQunitityState - toBalanceUINT256(normalGoodResult1_.profit, normalGoodResult1_.actual_fee);

        _investProof.burnProof(var1);

        normalGoodResult1_.profit = normalGoodResult1_.profit - normalGoodResult1_.actual_fee;

        normalGoodResult1_.actual_fee = _self.goodConfig.getDisinvestFee(normalGoodResult1_.actualDisinvestQuantity);

        if (normalGoodResult1_.actual_fee > 0) {
            _self.feeQunitityState =
                _self.feeQunitityState + toBalanceUINT256(_marketconfig.getLiquidFee(normalGoodResult1_.actual_fee), 0);
            allocateFee(_self, normalGoodResult1_.actual_fee, _marketconfig, _ralate);
        }

        if (_investProof.valuegood != 0) {
            var1 = toBalanceUINT256(_investProof.valueinvest.amount1(), _investProof.invest.amount1())
                .getamount0fromamount1(_goodQuantity);
            valueGoodResult2_ = S_GoodDisinvestReturn(
                toBalanceUINT256(_valueGoodState.feeQunitityState.amount0(), _valueGoodState.investState.amount1())
                    .getamount0fromamount1(var1),
                toBalanceUINT256(_investProof.valueinvest.amount0(), _investProof.valueinvest.amount1())
                    .getamount0fromamount1(var1),
                toBalanceUINT256(_investProof.state.amount0(), _investProof.valueinvest.amount1()).getamount0fromamount1(
                    var1
                ),
                var1
            );

            require(
                var1 < _valueGoodState.goodConfig.getDisinvestChips(_valueGoodState.currentState.amount1())
                    && valueGoodResult2_.actualDisinvestValue
                        < _valueGoodState.goodConfig.getDisinvestChips(_valueGoodState.currentState.amount0()),
                "G012"
            );

            _valueGoodState.currentState = _valueGoodState.currentState
                - toBalanceUINT256(valueGoodResult2_.actualDisinvestValue, valueGoodResult2_.actualDisinvestQuantity);

            _valueGoodState.investState = _valueGoodState.investState
                - toBalanceUINT256(valueGoodResult2_.actualDisinvestValue, valueGoodResult2_.actualDisinvestQuantity);

            _valueGoodState.feeQunitityState = _valueGoodState.feeQunitityState
                - toBalanceUINT256(valueGoodResult2_.profit, valueGoodResult2_.actual_fee);

            valueGoodResult2_.profit = valueGoodResult2_.profit - valueGoodResult2_.actual_fee;

            valueGoodResult2_.actual_fee =
                _valueGoodState.goodConfig.getDisinvestFee(valueGoodResult2_.actualDisinvestQuantity);

            if (valueGoodResult2_.actual_fee > 0) {
                _valueGoodState.feeQunitityState = _valueGoodState.feeQunitityState
                    + toBalanceUINT256(_marketconfig.getLiquidFee(valueGoodResult2_.actual_fee), 0);
                allocateFee(_valueGoodState, valueGoodResult2_.actual_fee, _marketconfig, _ralate);
            }
        }
    }

    function collectGoodFee(
        S_GoodState storage _self,
        S_GoodState storage _valuegood,
        L_Proof.S_ProofState storage _investProof
    ) internal returns (T_BalanceUINT256 profit) {
        profit = toBalanceUINT256(
            toBalanceUINT256(_self.feeQunitityState.amount0(), _self.investState.amount1()).getamount0fromamount1(
                _investProof.invest.amount1()
            ) - _investProof.invest.amount0(),
            _investProof.valuegood != 0
                ? (
                    toBalanceUINT256(_valuegood.feeQunitityState.amount0(), _valuegood.investState.amount1())
                        .getamount0fromamount1(_investProof.valueinvest.amount1()) - _investProof.valueinvest.amount0()
                )
                : 0
        );
        _self.feeQunitityState = _self.feeQunitityState + toBalanceUINT256(0, profit.amount0());
        if (_investProof.valuegood != 0) {
            _valuegood.feeQunitityState = _valuegood.feeQunitityState + toBalanceUINT256(0, profit.amount1());
        }

        _investProof.collectProofFee(profit);
    }

    function allocateFee(
        S_GoodState storage _self,
        uint128 _actualFeeQuantity,
        uint256 _marketconfig,
        S_Ralate memory _ralate
    ) private {
        if (_ralate.refer == address(0)) {
            uint128 temfee;
            temfee = _marketconfig.getSellerFee(_actualFeeQuantity) + _marketconfig.getCustomerFee(_actualFeeQuantity);
            _self.fees[_self.owner] += temfee;

            _self.fees[_ralate.gater] += (_actualFeeQuantity - _marketconfig.getLiquidFee(_actualFeeQuantity) - temfee);
        } else {
            _self.fees[_self.owner] += _marketconfig.getSellerFee(_actualFeeQuantity);
            _self.fees[_ralate.refer] += _marketconfig.getReferFee(_actualFeeQuantity);
            _self.fees[msg.sender] += _marketconfig.getCustomerFee(_actualFeeQuantity);
            _self.fees[_ralate.gater] += _marketconfig.getGaterFee(_actualFeeQuantity);
        }
    }
}

library L_GoodIdLibrary {
    function toId(S_GoodKey memory goodKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(goodKey));
    }
}
