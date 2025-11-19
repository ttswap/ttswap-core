// SPDX-License-Identifier: UNLICENSED
// version 1.14.0
pragma solidity 0.8.29;

import {ERC20} from "./base/ERC20.sol";
import {I_TTSwap_Market} from "./interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token, s_share, s_proof} from "./interfaces/I_TTSwap_Token.sol";
import {L_TTSTokenConfigLibrary} from "./libraries/L_TTSTokenConfig.sol";
import {L_UserConfigLibrary} from "./libraries/L_UserConfig.sol";
import {L_CurrencyLibrary} from "./libraries/L_Currency.sol";
import {TTSwapError} from "./libraries/L_Error.sol";
import {toTTSwapUINT256, L_TTSwapUINT256Library, add, sub, mulDiv} from "./libraries/L_TTSwapUINT256.sol";
import {IEIP712} from "./interfaces/IEIP712.sol";
import {L_SignatureVerification} from "./libraries/L_SignatureVerification.sol";

/**
 * @title TTS Token Contract
 * @dev Implements ERC20 token with additional staking and cross-chain functionality
 */
contract TTSwap_Token is I_TTSwap_Token, ERC20, IEIP712 {
    using L_TTSwapUINT256Library for uint256;
    using L_TTSTokenConfigLibrary for uint256;
    using L_UserConfigLibrary for uint256;
    using L_CurrencyLibrary for address;
    using L_SignatureVerification for bytes;
    address internal implementation;
    address internal immutable usdt;
    uint256 public override ttstokenconfig;
    bool internal upgradeable;
    uint256 public override stakestate; // first 128 bit record lasttime,last 128 bit record poolvalue
    uint128 public override left_share = 45_000_000_000_000_000_000;
    /// @inheritdoc I_TTSwap_Token
    uint128 public override publicsell;
    // uint256 1:add referral priv 2: market priv
    /// @inheritdoc I_TTSwap_Token
    mapping(address => uint256) public override userConfig;

    address internal marketcontract;
    uint256 public override poolstate; // first 128 bit record all asset(contain actual asset and constuct fee),last  128 bit record construct  fee

    mapping(address => s_share) internal shares; // all share's mapping
    mapping(uint256 => s_proof) internal stakeproof;

    bytes32 internal constant _PERMITSHARE_TYPEHASH =
        keccak256(
            "permitShare(uint128 amount,uint120 chips,uint8 metric,address owner,uint128 existamount,uint128 deadline,uint256 nonce)"
        );

    constructor(address _usdt) ERC20("TTSwap Token", "TTS", 12) {
        usdt=_usdt;
    }

    /**
     * @dev Modifier to ensure function is only called on the main chain
     */
    modifier onlymain() {
        if (!ttstokenconfig.ismain()) revert TTSwapError(61);
        _;
    }
    //**************************privillages partition**********************************/

    /**
     * @dev Grants or revokes DAO admin privileges to a recipient address.
     * @param _recipient The address to grant or revoke DAO admin rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by an existing DAO admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setDAOAdmin(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        userConfig[_recipient] = userConfig[_recipient].setDAOAdmin(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Token admin privileges to a recipient address.
     * @param _recipient The address to grant or revoke Token admin rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a DAO admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setTokenAdmin(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(63);
        userConfig[_recipient] = userConfig[_recipient].setTokenAdmin(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Token manager privileges to a recipient address.
     * @param _recipient The address to grant or revoke Token manager rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a Token admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setTokenManager(
        address _recipient,
        bool result
    ) external override {
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        userConfig[_recipient] = userConfig[_recipient].setTokenManager(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes permission to call mintTTS to a recipient address.
     * @param _recipient The address to grant or revoke permission.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a Token admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setCallMintTTS(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        userConfig[_recipient] = userConfig[_recipient].setCallMintTTS(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Market admin privileges to a recipient address.
     * @param _recipient The address to grant or revoke Market admin rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a DAO admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setMarketAdmin(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        userConfig[_recipient] = userConfig[_recipient].setMarketAdmin(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Market manager privileges to a recipient address.
     * @param _recipient The address to grant or revoke Market manager rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a Market admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setMarketManager(
        address _recipient,
        bool result
    ) external override {
        if (!userConfig[msg.sender].isMarketAdmin()) revert TTSwapError(1);
        userConfig[_recipient] = userConfig[_recipient].setMarketManager(
            result
        );
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Stake admin privileges to a recipient address.
     * @param _recipient The address to grant or revoke Stake admin rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a DAO admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setStakeAdmin(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        userConfig[_recipient] = userConfig[_recipient].setStakeAdmin(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Grants or revokes Stake manager privileges to a recipient address.
     * @param _recipient The address to grant or revoke Stake manager rights.
     * @param result Boolean indicating whether to grant (true) or revoke (false) the privilege.
     * @notice Only callable by a Stake admin.
     */
    /// @inheritdoc I_TTSwap_Token
    function setStakeManager(
        address _recipient,
        bool result
    ) external override {
        if (!userConfig[msg.sender].isStakeAdmin()) revert TTSwapError(64);
        userConfig[_recipient] = userConfig[_recipient].setStakeManager(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Sets or unsets a ban on a recipient address, restricting their access.
     * @param _recipient The address to ban or unban.
     * @param result Boolean indicating whether to ban (true) or unban (false) the address.
     * @notice Only callable by a Token manager.
     */
    /// @inheritdoc I_TTSwap_Token
    function setBan(address _recipient, bool result) external override {
        if (!userConfig[msg.sender].isTokenManager()) revert TTSwapError(65);
        userConfig[_recipient] = userConfig[_recipient].setBan(result);
        emit e_updateUserConfig(_recipient, userConfig[_recipient]);
    }

    /**
     * @dev Returns the share information for a given user address.
     * @param user The address to query for share information.
     * @return The s_share struct containing the user's share details.
     */
    /// @inheritdoc I_TTSwap_Token
    function usershares(
        address user
    ) external view override returns (s_share memory) {
        return shares[user];
    }

    /**
     * @dev Returns the stake proof information for a given index.
     * @param index The index to query for stake proof information.
     * @return The s_proof struct containing the stake proof details.
     */
    /// @inheritdoc I_TTSwap_Token
    function stakeproofinfo(
        uint256 index
    ) external view override returns (s_proof memory) {
        return stakeproof[index];
    }

    /**
     * @dev Adds a referral relationship between a user and a referrer
     * @param user The address of the user being referred
     * @param referral The address of the referrer
     * @notice Only callable by authorized addresses (auths[msg.sender] == 1)
     * @notice Will only set the referral if the user doesn't already have one
     */
    /// @inheritdoc I_TTSwap_Token
    function setReferral(address user, address referral) external override {
        if (
            userConfig[msg.sender].isCallMintTTS() &&
            userConfig[user].referral() == address(0) &&
            user != referral
        ) {
            userConfig[user] = userConfig[user].setReferral(referral);
        }
        emit e_addreferral(user, referral);
    }

    /**
     * @dev Retrieves both the DAO admin address and the referrer address for a given customer
     * @param _customer The address of the customer
     * @return A tuple containing the DAO admin address and the customer's referrer address
     */
    /// @inheritdoc I_TTSwap_Token
    function getreferral(
        address _customer
    ) external view override returns (address) {
        return userConfig[_customer].referral();
    }

    /**
     * @dev  this chain trade vol ratio in protocol
     */
    /// @inheritdoc I_TTSwap_Token
    function setRatio(uint256 _ratio) external override {
        if (_ratio > 10000) revert TTSwapError(66);
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        ttstokenconfig = ttstokenconfig.setratio(_ratio);
        emit e_updatettsconfig(ttstokenconfig);
    }

    /**
     * @dev Set environment variables for the contract
     * @param _marketcontract Address of the market contract
     */
    /// @inheritdoc I_TTSwap_Token
    function setEnv(address _marketcontract) external override {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        marketcontract = _marketcontract;
        emit e_setenv(marketcontract);
    }
    /**
     * @dev Adds a new mint share to the contract
     * @param _share The share structure containing recipient, amount, metric, and chips
     * @notice Only callable on the main chain by the DAO admin
     * @notice Reduces the left_share by the amount in _share
     * @notice Increments the shares_index and adds the new share to the shares mapping
     * @notice Emits an e_addShare event with the share details
     */
    /// @inheritdoc I_TTSwap_Token
    function addShare(
        s_share memory _share,
        address owner
    ) external override onlymain {
        if (left_share < _share.leftamount) revert TTSwapError(67);
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        _addShare(_share, owner);
    }

    function _addShare(s_share memory _share, address owner) internal {
        left_share -= uint64(_share.leftamount);
        if (shares[owner].leftamount == 0) {
            shares[owner] = _share;
        } else {
            s_share memory newpart = shares[owner];
            newpart.leftamount += _share.leftamount;
            newpart.chips = newpart.chips >= _share.chips
                ? newpart.chips
                : _share.chips;
            newpart.metric = newpart.metric >= _share.metric
                ? newpart.metric
                : _share.metric;
            shares[owner] = newpart;
        }
        emit e_addShare(owner, _share.leftamount, _share.metric, _share.chips);
    }

    /**
     * @dev Burns (removes) a mint share from the contract
     * @param index The index of the share to burn
     * @notice Only callable on the main chain by the DAO admin
     * @notice Adds the leftamount of the burned share back to left_share
     * @notice Emits an e_burnShare event and deletes the share from the shares mapping
     */
    /// @inheritdoc I_TTSwap_Token
    function burnShare(address owner) external override onlymain {
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        left_share += uint64(shares[owner].leftamount);
        emit e_burnShare(owner);
        delete shares[owner];
    }

    /**
     * @dev Allows the DAO to mint tokens based on a specific share
     * @param index The index of the share to mint from
     * @notice Only callable on the main chain
     * @notice Requires the market price to be below a certain threshold
     * @notice Mints tokens to the share recipient, reduces leftamount, and increments metric
     * @notice Emits an e_daomint event with the minted amount and index
     */
    /// @inheritdoc I_TTSwap_Token
    function shareMint() external override onlymain {
        if (
            !I_TTSwap_Market(marketcontract).ishigher(
                address(this),
                usdt,
                2 ** shares[msg.sender].metric * 2 ** 128 + 20_000_000
            )
        ) revert TTSwapError(68);
        if (shares[msg.sender].leftamount == 0) revert TTSwapError(69);
        uint128 mintamount = shares[msg.sender].leftamount /
            shares[msg.sender].chips;
        shares[msg.sender].leftamount -= mintamount;
        shares[msg.sender].metric += 1;
        _mint(msg.sender, mintamount);
        emit e_shareMint(mintamount, msg.sender);
    }

    /**
     * @dev Perform public token sale
     * @param usdtamount Amount of USDT to spend on token purchase
     */
    /// @inheritdoc I_TTSwap_Token
    function publicSell(
        uint256 usdtamount,
        bytes calldata data
    ) external override onlymain {
        publicsell += uint128(usdtamount);
        if (publicsell > 500_000_000_000) revert TTSwapError(70);
        usdt.transferFrom(msg.sender, address(this), usdtamount, data);
        uint256 ttsamount;
        if (publicsell <= 87_500_000_000) {
            ttsamount = (usdtamount * 24_000_000);
            _mint(msg.sender, ttsamount);
        } else if (publicsell <= 162_500_000_000) {
            ttsamount = usdtamount * 20_000_000;
            _mint(msg.sender, ttsamount);
        } else if (publicsell <= 250_000_000_000) {
            ttsamount = (usdtamount * 16_000_000);
            _mint(msg.sender, ttsamount);
        }
        emit e_publicsell(usdtamount, ttsamount);
    }

    /**
     * @dev Withdraws funds from public token sale
     * @param amount The amount of USDT to withdraw
     * @param recipient The address to receive the withdrawn funds
     * @notice Only callable on the main chain by the DAO admin
     * @notice Transfers the specified amount of USDT to the recipient
     */
    /// @inheritdoc I_TTSwap_Token
    function withdrawPublicSell(
        uint256 amount,
        address recipient
    ) external override onlymain {
        if (!userConfig[msg.sender].isTokenAdmin()) revert TTSwapError(63);
        usdt.safeTransfer(recipient, amount);
    }

    /**
     * @dev Stakes a user's proof of investment to earn platform rewards.
     * @param _staker The address of the user staking their proof (usually msg.sender, but can be delegated).
     * @param proofvalue The value of the proof being staked (represents investment amount).
     * @return netconstruct The net construction fee or initial stake value recorded.
     * @notice Staking allows users to earn a share of the platform's transaction fees or inflationary rewards.
     * - Calculates pending rewards and updates the global pool state (`_stakeFee`).
     * - Records the stake in a mapping, associating it with the `_staker` and `msg.sender` (market contract).
     * - Updates the global `stakestate` and `poolstate`.
     * @custom:security Requires `msg.sender` to have `isCallMintTTS` permission (only Market contract).
     * @custom:security Uses `_stakeFee` to checkpoint global rewards before modifying user stake.
     */
    /// @inheritdoc I_TTSwap_Token
    function stake(
        address _staker,
        uint128 proofvalue
    ) external override returns (uint128 netconstruct) {
        if (!userConfig[msg.sender].isCallMintTTS()) revert TTSwapError(71);
        _stakeFee();
        uint256 restakeid = uint256(keccak256(abi.encode(_staker, msg.sender)));
        netconstruct = poolstate.amount1() == 0
            ? 0
            : mulDiv(poolstate.amount0(), proofvalue, stakestate.amount1());
        poolstate = add(poolstate, toTTSwapUINT256(netconstruct, netconstruct));
        stakestate = add(stakestate, toTTSwapUINT256(0, proofvalue));
        stakeproof[restakeid].fromcontract = msg.sender;
        stakeproof[restakeid].proofstate = add(
            stakeproof[restakeid].proofstate,
            toTTSwapUINT256(proofvalue, netconstruct)
        );
        emit e_stakeinfo(
            _staker,
            stakeproof[restakeid].proofstate,
            toTTSwapUINT256(0, netconstruct),
            stakestate,
            poolstate
        );
    }

    /**
     * @dev Unstakes a user's proof of investment and claims accumulated rewards.
     * @param _staker The address of the user unstaking.
     * @param proofvalue The amount of proof value to unstake.
     * @notice This function calculates the user's share of the pool's growth since staking.
     * - Updates global pool state (`_stakeFee`).
     * - Calculates profit based on the change in `poolstate` relative to `stakestate`.
     * - Mints new TTS tokens as profit to the `_staker`.
     * - Burns the staked proof value from the state.
     * @custom:security Requires `msg.sender` to have `isCallMintTTS` permission.
     * @custom:security Handles partial unstaking correctly.
     */
    /// @inheritdoc I_TTSwap_Token
    function unstake(address _staker, uint128 proofvalue) external override {
        if (!userConfig[msg.sender].isCallMintTTS()) revert TTSwapError(71);
        _stakeFee();
        uint128 profit;
        uint128 construct;
        uint256 restakeid = uint256(keccak256(abi.encode(_staker, msg.sender)));
        if (proofvalue >= stakeproof[restakeid].proofstate.amount0()) {
            proofvalue = stakeproof[restakeid].proofstate.amount0();
            construct = stakeproof[restakeid].proofstate.amount1();
            delete stakeproof[restakeid];
        } else {
            construct = stakeproof[restakeid].proofstate.getamount1fromamount0(
                proofvalue
            );
            stakeproof[restakeid].proofstate = sub(
                stakeproof[restakeid].proofstate,
                toTTSwapUINT256(proofvalue, construct)
            );
        }
        profit = toTTSwapUINT256(poolstate.amount0(), stakestate.amount1())
            .getamount0fromamount1(proofvalue);
        stakestate = sub(stakestate, toTTSwapUINT256(0, proofvalue));
        poolstate = sub(poolstate, toTTSwapUINT256(profit, construct));
        profit = profit - construct;
        if (profit > 0) _mint(_staker, profit);
        emit e_stakeinfo(
            _staker,
            stakeproof[restakeid].proofstate,
            toTTSwapUINT256(construct, profit),
            stakestate,
            poolstate
        );
    }

    /**
     * @dev Internal function to handle staking fees
     */
    function _stakeFee() internal {
        if (stakestate.amount0() + 86400 < block.timestamp) {
            stakestate = add(stakestate, toTTSwapUINT256(86400, 0));
            uint128 leftamount = uint128(200_000_000_000_000_000_000 - totalSupply);
            uint128 mintamount = leftamount < 1000000
                ? 1000000
                : leftamount / 18250; //leftamount /50 /365
            poolstate = add(
                poolstate,
                toTTSwapUINT256(ttstokenconfig.getratio(mintamount), 0)
            );
            emit e_updatepool(
                toTTSwapUINT256(stakestate.amount0(), poolstate.amount0())
            );
        }
    }
    // burn
    /**
     * @dev Burn tokens from an account
     * @param account Address of the account to burn tokens from
     * @param value Amount of tokens to burn
     */
    /// @inheritdoc I_TTSwap_Token
    function burn(uint256 value) external override {
        _burn(msg.sender, value);
    }

    function _mint(address to, uint256 amount) internal override {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal override {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
    /**
     * @dev Permits a share to be transferred
     * @param _share The share structure containing recipient, amount, metric, and chips
     * @param dealline The deadline for the share transfer
     * @param signature The signature of the share transfer
     * @param signer The address of the signer
     */
    /// @inheritdoc I_TTSwap_Token
    function permitShare(
        s_share memory _share,
        uint128 dealline,
        bytes calldata signature,
        address signer
    ) external override {
        if (block.timestamp > dealline) revert TTSwapError(72);
        // Verify the signer address from the signature.
        signature.verify(
            _hashTypedData(
                shareHash(
                    _share,
                    msg.sender,
                    shares[msg.sender].leftamount,
                    dealline,
                    nonces[msg.sender]++
                )
            ),
            userConfig[signer].isTokenAdmin() ? signer : address(0)
        );
        _addShare(_share, msg.sender);
    }

    /**
     * @dev Calculates the hash of a share transfer
     * @param _share The share structure containing recipient, amount, metric, and chips
     * @param owner The address of the owner
     * @param leftamount The amount of left share
     * @param deadline The deadline for the share transfer
     */
    function shareHash(
        s_share memory _share,
        address owner,
        uint128 leftamount,
        uint128 deadline,
        uint256 nonce
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _PERMITSHARE_TYPEHASH,
                    _share.leftamount,
                    _share.chips,
                    _share.metric,
                    owner,
                    leftamount,
                    deadline,
                    nonce
                )
            );
    }

    /// @notice Builds a domain separator using the current chainId and contract address.
    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(typeHash, nameHash, block.chainid, address(this))
            );
    }

    /// @notice Creates an EIP-712 typed data hash
    function _hashTypedData(bytes32 dataHash) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), dataHash)
            );
    }

    function DOMAIN_SEPARATOR()
        public
        view
        override(ERC20, IEIP712)
        returns (bytes32)
    {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view override returns (bytes32) {
        return
            _buildDomainSeparator(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name))
            );
    }

    function disableUpgrade() external {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        upgradeable = false;
    }

    function mint(address to, uint256 amount) external {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (!userConfig[msg.sender].isDAOAdmin()) revert TTSwapError(62);
        _burn(from, amount);
    }
}
