// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./GoodManage.sol";
import "./ProofManage.sol";

import "./interfaces/I_MarketManage.sol";
import {L_Good, L_GoodIdLibrary} from "./libraries/L_Good.sol";
import {L_Proof, L_ProofIdLibrary} from "./libraries/L_Proof.sol";
import {Multicall} from "./Multicall.sol";
import {L_GoodConfigLibrary} from "./libraries/L_GoodConfig.sol";
import {S_ProofKey, S_GoodKey, S_Ralate} from "./libraries/L_Struct.sol";
import {L_MarketConfigLibrary} from "./libraries/L_MarketConfig.sol";
import {L_CurrencyLibrary} from "./libraries/L_Currency.sol";
import {L_ArrayStorage} from "./libraries/L_ArrayStorage.sol";

contract MarketManager is Multicall, GoodManage, ProofManage, I_MarketManage {
    using L_GoodConfigLibrary for uint256;
    using L_GoodIdLibrary for S_GoodKey;
    using L_ProofIdLibrary for S_ProofKey;
    using L_Good for L_Good.S_GoodState;
    using L_Proof for L_Proof.S_ProofState;
    using L_CurrencyLibrary for address;
    using L_MarketConfigLibrary for uint256;
    using L_ArrayStorage for L_ArrayStorage.S_ArrayStorage;

    constructor(address _marketcreator, uint256 _marketconfig) GoodManage(_marketcreator, _marketconfig) {}

    /// @inheritdoc I_MarketManage
    function initMetaGood(address _erc20address, T_BalanceUINT256 _initial, uint256 _goodConfig)
        external
        override
        onlyMarketCreator
        returns (uint256, uint256)
    {
        require(_goodConfig.isvaluegood(), "M02");

        _erc20address.safeTransferFrom(msg.sender, address(this), _initial.amount1());

        goodNum += 1;
        goodseq[S_GoodKey(_erc20address, msg.sender).toId()] = goodNum;

        goods[goodNum].init(_initial, _erc20address, _goodConfig);
        goods[goodNum].updateToValueGood();
        ownergoods[msg.sender].addvalue(goodNum);

        bytes32 normalproof = S_ProofKey(msg.sender, goodNum, 0).toId();
        totalSupply += 1;
        proofseq[normalproof] = totalSupply;
        proofs[totalSupply].updateInvest(
            goodNum,
            0,
            toBalanceUINT256(_initial.amount0(), 0),
            toBalanceUINT256(0, _initial.amount1()),
            toBalanceUINT256(0, 0)
        );
        ownerproofs[msg.sender].addvalue(totalSupply);
        emit e_initMetaGood(goodNum, totalSupply, _erc20address, _goodConfig, _initial);
        return (goodNum, totalSupply);
    }

    /// @inheritdoc I_MarketManage
    function initGood(
        uint256 _valuegood,
        T_BalanceUINT256 _initial,
        address _erc20address,
        uint256 _goodConfig,
        address _gater
    ) external payable override noReentrant returns (uint256, uint256) {
        require(goods[_valuegood].goodConfig.isvaluegood(), "M02");
        bytes32 togood = S_GoodKey(_erc20address, msg.sender).toId();
        require(goodseq[togood] == 0, "M01");

        _erc20address.transferFrom(msg.sender, _initial.amount0());
        goods[_valuegood].erc20address.transferFrom(msg.sender, _initial.amount1());

        L_Good.S_GoodInvestReturn memory investResult =
            goods[_valuegood].investGood(_initial.amount1(), marketconfig, S_Ralate(_gater, relations[msg.sender]));

        goodNum += 1;
        goodseq[togood] = goodNum;
        ownergoods[msg.sender].addvalue(goodNum);
        goods[goodNum].init(
            toBalanceUINT256(investResult.actualInvestValue, _initial.amount0()), _erc20address, _goodConfig
        );
        totalSupply += 1;
        proofseq[S_ProofKey(msg.sender, goodNum, _valuegood).toId()] = totalSupply;
        proofs[totalSupply] = L_Proof.S_ProofState(
            msg.sender,
            goodNum,
            _valuegood,
            toBalanceUINT256(investResult.actualInvestValue, 0),
            toBalanceUINT256(0, _initial.amount0()),
            toBalanceUINT256(0, investResult.actualInvestQuantity),
            address(0),
            address(0)
        );
        ownerproofs[msg.sender].addvalue(totalSupply);
        emit e_initGood(
            totalSupply,
            goodNum,
            _valuegood,
            _erc20address,
            _goodConfig,
            toBalanceUINT256(_initial.amount0(), investResult.actualInvestValue),
            toBalanceUINT256(investResult.actualFeeQuantity, investResult.actualInvestQuantity)
        );
        return (goodNum, totalSupply);
    }

    /// @inheritdoc I_MarketManage
    function buyGood(
        uint256 _goodid1,
        uint256 _goodid2,
        uint128 _swapQuantity,
        uint256 _limitPrice,
        bool _istotal,
        address _gater
    ) external payable override noReentrant returns (uint128 goodid2Quantity_, uint128 goodid2FeeQuantity_) {
        L_Good.swapCache memory swapcache = L_Good.swapCache({
            remainQuantity: _swapQuantity,
            outputQuantity: 0,
            feeQuantity: 0,
            swapvalue: 0,
            good1currentState: goods[_goodid1].currentState,
            good1config: goods[_goodid1].goodConfig,
            good2currentState: goods[_goodid2].currentState,
            good2config: goods[_goodid2].goodConfig
        });
        swapcache = L_Good.swapCompute1(swapcache, T_BalanceUINT256.wrap(_limitPrice));
        if (_istotal == true && swapcache.remainQuantity > 0) {
            revert err_total();
        }
        goodid2FeeQuantity_ = goods[_goodid2].goodConfig.getBuyFee(swapcache.outputQuantity);
        goodid2Quantity_ = swapcache.outputQuantity - goodid2FeeQuantity_;
        goods[_goodid1].swapCommit(
            swapcache.good1currentState, swapcache.feeQuantity, marketconfig, S_Ralate(_gater, relations[msg.sender])
        );
        goods[_goodid2].swapCommit(
            swapcache.good2currentState, goodid2FeeQuantity_, marketconfig, S_Ralate(_gater, relations[msg.sender])
        );
        goods[_goodid1].erc20address.transferFrom(msg.sender, _swapQuantity - swapcache.remainQuantity);

        goods[_goodid2].erc20address.safeTransfer(msg.sender, goodid2Quantity_);
        emit e_buyGood(
            _goodid1,
            _goodid2,
            msg.sender,
            swapcache.swapvalue,
            toBalanceUINT256(_swapQuantity - swapcache.remainQuantity, swapcache.feeQuantity),
            toBalanceUINT256(goodid2Quantity_, goodid2FeeQuantity_)
        );
    }

    /// @inheritdoc I_MarketManage
    function buyGoodForPay(
        uint256 _goodid1,
        uint256 _goodid2,
        uint128 _swapQuantity,
        uint256 _limitPrice,
        address _recipent,
        address _gater
    ) external payable override noReentrant returns (uint128 goodid1Quantity_, uint128 goodid1FeeQuantity_) {
        L_Good.swapCache memory swapcache = L_Good.swapCache({
            remainQuantity: _swapQuantity,
            outputQuantity: 0,
            feeQuantity: 0,
            swapvalue: 0,
            good1currentState: goods[_goodid1].currentState,
            good1config: goods[_goodid1].goodConfig,
            good2currentState: goods[_goodid2].currentState,
            good2config: goods[_goodid2].goodConfig
        });

        swapcache = L_Good.swapCompute2(swapcache, T_BalanceUINT256.wrap(_limitPrice));

        if (swapcache.remainQuantity > 0) revert err_total();
        goodid1FeeQuantity_ = goods[_goodid1].goodConfig.getBuyFee(swapcache.outputQuantity);
        goodid1Quantity_ = swapcache.outputQuantity - goodid1FeeQuantity_;

        goods[_goodid2].swapCommit(
            swapcache.good2currentState, swapcache.feeQuantity, marketconfig, S_Ralate(_gater, relations[msg.sender])
        );
        goods[_goodid1].swapCommit(
            swapcache.good1currentState, goodid1FeeQuantity_, marketconfig, S_Ralate(_gater, relations[msg.sender])
        );
        goods[_goodid2].erc20address.safeTransfer(
            _recipent, _swapQuantity - swapcache.remainQuantity - swapcache.feeQuantity
        );
        goods[_goodid1].erc20address.transferFrom(msg.sender, goodid1Quantity_);
        emit e_buyGoodForPay(
            _goodid1,
            _goodid2,
            msg.sender,
            _recipent,
            swapcache.swapvalue,
            toBalanceUINT256(_swapQuantity - swapcache.remainQuantity, swapcache.feeQuantity),
            toBalanceUINT256(goodid1Quantity_, goodid1FeeQuantity_)
        );
    }

    /// @inheritdoc I_MarketManage
    function investGood(uint256 _togood, uint256 _valuegood, uint128 _quantity, address _gater)
        external
        payable
        override
        noReentrant
        returns (
            L_Good.S_GoodInvestReturn memory normalInvest_,
            L_Good.S_GoodInvestReturn memory valueInvest_,
            uint256 proofno_
        )
    {
        require(goods[_togood].currentState.amount1() <= 2 ** 108, "M02");

        require((_valuegood == 0 && goods[_togood].goodConfig.isvaluegood()) || _valuegood != 0, "M02");
        require(_valuegood == 0 || goods[_valuegood].goodConfig.isvaluegood(), "M02");
        normalInvest_ = goods[_togood].investGood(_quantity, marketconfig, S_Ralate(_gater, relations[msg.sender]));
        goods[_togood].erc20address.transferFrom(msg.sender, _quantity);
        if (_valuegood != 0) {
            valueInvest_.actualInvestQuantity =
                goods[_valuegood].currentState.getamount1fromamount0(normalInvest_.actualInvestValue);

            valueInvest_.actualInvestQuantity =
                goods[_valuegood].goodConfig.getInvestFulFee(valueInvest_.actualInvestQuantity);
            goods[_valuegood].erc20address.transferFrom(msg.sender, valueInvest_.actualInvestQuantity);

            valueInvest_ = goods[_valuegood].investGood(
                valueInvest_.actualInvestQuantity, marketconfig, S_Ralate(_gater, relations[msg.sender])
            );
        }

        proofno_ = proofseq[S_ProofKey(msg.sender, _togood, _valuegood).toId()];
        if (proofno_ == 0) {
            totalSupply += 1;
            proofseq[S_ProofKey(msg.sender, _togood, _valuegood).toId()] = totalSupply;
            proofno_ = totalSupply;
        }

        proofs[proofno_].updateInvest(
            _togood,
            _valuegood,
            toBalanceUINT256(normalInvest_.actualInvestValue, 0),
            toBalanceUINT256(normalInvest_.contructFeeQuantity, normalInvest_.actualInvestQuantity),
            toBalanceUINT256(valueInvest_.contructFeeQuantity, valueInvest_.actualInvestQuantity)
        );
        emit e_investGood(
            proofno_,
            _togood,
            _valuegood,
            toBalanceUINT256(normalInvest_.actualFeeQuantity, normalInvest_.actualInvestQuantity),
            toBalanceUINT256(valueInvest_.actualFeeQuantity, valueInvest_.actualInvestQuantity)
        );
    }

    /// @inheritdoc I_MarketManage
    function disinvestGood(uint256 _togood, uint256 _valuegood, uint128 _goodQuantity, address _gater)
        external
        override
        returns (
            L_Good.S_GoodDisinvestReturn memory disinvestNormalResult1_,
            L_Good.S_GoodDisinvestReturn memory disinvestValueResult2_,
            uint256 proofno_
        )
    {
        proofno_ = proofseq[S_ProofKey(msg.sender, _togood, _valuegood).toId()];
        (disinvestNormalResult1_, disinvestValueResult2_) = disinvestProof(proofno_, _goodQuantity, _gater);
    }
    /// @inheritdoc I_MarketManage

    function disinvestProof(uint256 _proofid, uint128 _goodQuantity, address _gater)
        public
        override
        noReentrant
        returns (
            L_Good.S_GoodDisinvestReturn memory disinvestNormalResult1_,
            L_Good.S_GoodDisinvestReturn memory disinvestValueResult2_
        )
    {
        require(proofs[_proofid].owner == msg.sender, "M05");
        uint256 normalgood = proofs[_proofid].currentgood;
        uint256 valuegood = proofs[_proofid].valuegood;
        (disinvestNormalResult1_, disinvestValueResult2_) = goods[normalgood].disinvestGood(
            goods[valuegood], proofs[_proofid], _goodQuantity, marketconfig, S_Ralate(_gater, relations[msg.sender])
        );

        T_BalanceUINT256 protocalfee = toBalanceUINT256(
            marketconfig.getPlatFee128(disinvestNormalResult1_.profit),
            marketconfig.getPlatFee128(disinvestValueResult2_.profit)
        );
        disinvestNormalResult1_.actual_fee += protocalfee.amount0();
        goods[normalgood].fees[marketcreator] += protocalfee.amount0();
        goods[normalgood].erc20address.safeTransfer(
            msg.sender, _goodQuantity + disinvestNormalResult1_.profit - disinvestNormalResult1_.actual_fee
        );
        if (proofs[_proofid].valuegood != 0) {
            disinvestValueResult2_.actual_fee += protocalfee.amount1();
            goods[valuegood].fees[marketcreator] += protocalfee.amount1();
            goods[valuegood].erc20address.safeTransfer(
                msg.sender,
                disinvestValueResult2_.actualDisinvestQuantity + disinvestValueResult2_.profit
                    - disinvestValueResult2_.actual_fee
            );
        }
        emit e_disinvestProof(
            _proofid,
            normalgood,
            valuegood,
            toBalanceUINT256(disinvestNormalResult1_.actual_fee, disinvestNormalResult1_.actualDisinvestQuantity),
            toBalanceUINT256(disinvestValueResult2_.actual_fee, disinvestValueResult2_.actualDisinvestQuantity),
            toBalanceUINT256(disinvestNormalResult1_.profit, disinvestValueResult2_.profit)
        );
    }

    /// @inheritdoc I_MarketManage
    function collectProofFee(uint256 _proofid) external override returns (T_BalanceUINT256 profit_) {
        require(proofs[_proofid].owner == msg.sender || proofs[_proofid].beneficiary == msg.sender, "M09");
        uint256 valuegood = proofs[_proofid].valuegood;
        uint256 currentgood = proofs[_proofid].currentgood;
        profit_ = goods[currentgood].collectGoodFee(goods[valuegood], proofs[_proofid]);
        T_BalanceUINT256 protocalfee = toBalanceUINT256(
            marketconfig.getPlatFee128(profit_.amount0()), marketconfig.getPlatFee128(profit_.amount1())
        );
        profit_ = profit_ - protocalfee;
        goods[currentgood].fees[marketcreator] += protocalfee.amount0();
        goods[currentgood].erc20address.safeTransfer(msg.sender, profit_.amount0());
        if (valuegood != 0) {
            goods[valuegood].fees[marketcreator] += protocalfee.amount1();
            goods[valuegood].erc20address.safeTransfer(msg.sender, profit_.amount1());
        }
        emit e_collectProofFee(_proofid, currentgood, valuegood, profit_, protocalfee);
    }
}
