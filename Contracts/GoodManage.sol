// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./RefererManage.sol";
import "./interfaces/I_Good.sol";

import {L_GoodConfigLibrary} from "./libraries/L_GoodConfig.sol";
import {L_Good} from "./libraries/L_Good.sol";

import {L_MarketConfigLibrary} from "./libraries/L_MarketConfig.sol";
import {L_CurrencyLibrary} from "./libraries/L_Currency.sol";
import {S_GoodKey} from "./libraries/L_Struct.sol";
import {L_ArrayStorage} from "./libraries/L_ArrayStorage.sol";
import {
    T_BalanceUINT256,
    L_BalanceUINT256Library,
    toBalanceUINT256,
    addsub,
    subadd
} from "./libraries/L_BalanceUINT256.sol";

abstract contract GoodManage is I_Good, RefererManage {
    using L_CurrencyLibrary for address;
    using L_GoodConfigLibrary for uint256;
    using L_MarketConfigLibrary for uint256;
    using L_ArrayStorage for L_ArrayStorage.S_ArrayStorage;
    using L_Good for L_Good.S_GoodState;

    /// @inheritdoc I_Good
    uint256 public override marketconfig;
    /// @inheritdoc I_Good
    uint256 public override goodNum;
    /// @inheritdoc I_Good
    address public override marketcreator;

    mapping(uint256 => L_Good.S_GoodState) internal goods;
    mapping(address => L_ArrayStorage.S_ArrayStorage) internal ownergoods;
    mapping(bytes32 => uint256) internal goodseq;
    uint256 internal locked;
    mapping(address => uint256) private banlist;

    constructor(address _marketcreator, uint256 _marketconfig) {
        marketcreator = _marketcreator;
        marketconfig = _marketconfig;
    }

    modifier onlyMarketCreator() {
        require(msg.sender == marketcreator, "G02");
        _;
    }

    modifier noReentrant() {
        require(locked == 0, "G01");
        locked = 1;
        _;
        locked = 0;
    }

    modifier noblacklist() {
        require(banlist[msg.sender] == 0);
        _;
    }

    /// @inheritdoc I_Good
    function addbanlist(address _user) external override onlyMarketCreator returns (bool) {
        banlist[_user] = 1;
        emit e_addbanlist(_user);
        return true;
    }

    /// @inheritdoc I_Good
    function removebanlist(address _user) external override onlyMarketCreator returns (bool) {
        banlist[_user] = 0;
        emit e_removebanlist(_user);
        return true;
    }

    /// @inheritdoc I_Good
    function setMarketConfig(uint256 _marketconfig) external override onlyMarketCreator returns (bool) {
        require(_marketconfig.checkAllocate(), "G03");
        marketconfig = _marketconfig;
        emit e_setMarketConfig(_marketconfig);
        return true;
    }

    /// @inheritdoc I_Good
    function getGoodIdByAddress(address _owner, uint256 _key) external view override returns (uint256) {
        return _key <= ownergoods[_owner].key ? ownergoods[_owner].key_value[_key] : 0;
    }

    /// @inheritdoc I_Good
    function getGoodState(uint256 _goodid) external view override returns (L_Good.S_GoodTmpState memory good_) {
        good_.currentState = goods[_goodid].currentState;
        good_.investState = goods[_goodid].investState;
        good_.feeQunitityState = goods[_goodid].feeQunitityState;
        good_.goodConfig = goods[_goodid].goodConfig;
        good_.owner = goods[_goodid].owner;
        good_.erc20address = goods[_goodid].erc20address;
    }

    /// @inheritdoc I_Good
    function getGoodsFee(uint256 _goodid, address user) external view override returns (uint256) {
        return goods[_goodid].fees[user];
    }

    function updateGoodConfig(uint256 _goodid, uint256 _goodConfig) external override returns (bool) {
        require(msg.sender == goods[_goodid].owner, "G04");
        goods[_goodid].updateGoodConfig(_goodConfig);
        emit e_updateGoodConfig(_goodid, _goodConfig);
        return true;
    }

    /// @inheritdoc I_Good
    function updatetoValueGood(uint256 _goodid) external override onlyMarketCreator returns (bool) {
        goods[_goodid].updateToValueGood();
        emit e_updatetoValueGood(_goodid);
        return true;
    }

    /// @inheritdoc I_Good
    function updatetoNormalGood(uint256 _goodid) external override onlyMarketCreator returns (bool) {
        goods[_goodid].updateToNormalGood();
        emit e_updatetoNormalGood(_goodid);
        return true;
    }

    /// @inheritdoc I_Good
    function payGood(uint256 _goodid, uint256 _payquanity, address _recipent) external returns (bool) {
        goods[_goodid].erc20address.safeTransfer(_recipent, _payquanity);
        return true;
    }

    /// @inheritdoc I_Good
    function changeGoodOwner(uint256 _goodid, address _to) external override returns (bool) {
        require(msg.sender == goods[_goodid].owner || msg.sender == marketcreator, "G05");
        goods[_goodid].owner = _to;
        ownergoods[_to].addvalue(_goodid);
        return true;
    }

    /// @inheritdoc I_Good
    function collectProtocolFee(uint256 _goodid) external override noblacklist returns (uint256) {
        uint256 fee = goods[_goodid].fees[msg.sender];
        require(fee > 0, "G06");
        goods[_goodid].fees[msg.sender] = 0;
        uint256 protocol = marketconfig.getPlatFee256(fee);
        goods[_goodid].fees[marketcreator] += protocol;
        goods[_goodid].erc20address.safeTransfer(msg.sender, fee - protocol);
        return fee;
    }

    /// @inheritdoc I_Good
    function check_banlist(address _user) external view override returns (bool _isban) {
        return banlist[_user] == 1 ? true : false;
    }
}
