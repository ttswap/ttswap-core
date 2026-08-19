// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {I_TTSwap_Market} from "../src/interfaces/I_TTSwap_Market.sol";
import {I_TTSwap_Token, s_share} from "../src/interfaces/I_TTSwap_Token.sol";
import {T_GoodKey, T_GoodKeyLibrary} from "../src/type/T_GoodKey.sol";
import {TTSwapError} from "../src/libraries/L_Error.sol";

/// @notice P1-05 / P1-06: DAO mint/burn and shareMint failure branches.
contract testTTSwapTokenMintBurn is BaseSetup {
    using T_GoodKeyLibrary for T_GoodKey;

    function testUserBurn_reducesBalanceAndSupply() public {
        uint256 amount = 1_000_000 ether;
        vm.prank(marketcreator);
        tts_token.mint(users[5], amount);
        _snapToken("tts_token_mint_testTTSwapTokenMintBurn.t_17");

        uint256 supplyBefore = tts_token.totalSupply();
        vm.prank(users[5]);
        tts_token.burn(amount / 2);
        _snapToken("tts_token_burn_testTTSwapTokenMintBurn.t_21");

        assertEq(tts_token.balanceOf(users[5]), amount / 2, "balance halved");
        assertEq(tts_token.totalSupply(), supplyBefore - amount / 2, "supply reduced");
    }

    function testDAOAdminMint_onlyMain_success() public {
        uint256 amount = 500 ether;
        vm.prank(marketcreator);
        tts_token.mint(users[3], amount);
        _snapToken("tts_token_mint_testTTSwapTokenMintBurn.t_30");
        assertEq(tts_token.balanceOf(users[3]), amount, "minted");
    }

    function testDAOAdminMint_revert_notDAO() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.mint(users[4], 1 ether);
        _snapToken("tts_token_mint_testTTSwapTokenMintBurn.t_37");
    }

    function testDAOAdminBurnFrom_success() public {
        uint256 amount = 100 ether;
        vm.prank(marketcreator);
        tts_token.mint(users[4], amount);
        _snapToken("tts_token_mint_testTTSwapTokenMintBurn.t_43");

        vm.prank(marketcreator);
        tts_token.burn(users[4], amount / 4);
        _snapToken("tts_token_burn_testTTSwapTokenMintBurn.t_46");
        assertEq(tts_token.balanceOf(users[4]), amount * 3 / 4, "burned from");
    }

    function testDAOAdminBurnFrom_revert_notDAO() public {
        vm.prank(users[3]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 62));
        tts_token.burn(users[4], 1);
        _snapToken("tts_token_burn_testTTSwapTokenMintBurn.t_53");
    }

    function testShareMint_revert_marketPriceNotHigher() public {
        address shareOwner = users[4];
        s_share memory share = s_share({leftamount: 1_000_000, metric: 10, chips: 4});

        vm.startPrank(marketcreator);
        tts_token.setEnv(address(market));
        _snapToken("tts_token_setEnv_testTTSwapTokenMintBurn.t_61");
        tts_token.addShare(share, shareOwner);
        _snapToken("tts_token_addShare_testTTSwapTokenMintBurn.t_62");
        vm.stopPrank();

        uint256 ttsGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(tts_token),
            id: 0
        }).toId();
        uint256 usdtGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        }).toId();
        uint256 threshold = (uint256(1) << share.metric) * (uint256(1) << 128) +
            20_000_000;

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                I_TTSwap_Market.ishigher.selector,
                ttsGoodId,
                usdtGoodId,
                threshold
            ),
            abi.encode(false)
        );

        vm.prank(shareOwner);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 68));
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_testTTSwapTokenMintBurn.t_91");
    }

    function testShareMint_revert_noSharesLeft() public {
        vm.prank(marketcreator);
        tts_token.setEnv(address(market));
        _snapToken("tts_token_setEnv_testTTSwapTokenMintBurn.t_96");

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(I_TTSwap_Market.ishigher.selector),
            abi.encode(true)
        );

        vm.prank(users[5]);
        vm.expectRevert(abi.encodeWithSelector(TTSwapError.selector, 69));
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_testTTSwapTokenMintBurn.t_106");
    }

    function testShareMint_metricIncrementsAndLeftAmountDecreases() public {
        address shareOwner = users[4];
        s_share memory share = s_share({leftamount: 1_000_000, metric: 5, chips: 4});

        vm.startPrank(marketcreator);
        tts_token.setEnv(address(market));
        _snapToken("tts_token_setEnv_testTTSwapTokenMintBurn.t_114");
        tts_token.addShare(share, shareOwner);
        _snapToken("tts_token_addShare_testTTSwapTokenMintBurn.t_115");
        vm.stopPrank();

        uint256 ttsGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(tts_token),
            id: 0
        }).toId();
        uint256 usdtGoodId = T_GoodKey({
            ercType: 1,
            contractAddress: address(usdt),
            id: 0
        }).toId();
        uint256 threshold = (uint256(1) << share.metric) * (uint256(1) << 128) +
            20_000_000;

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                I_TTSwap_Market.ishigher.selector,
                ttsGoodId,
                usdtGoodId,
                threshold
            ),
            abi.encode(true)
        );

        uint128 expectedMint = share.leftamount / share.chips;
        vm.prank(shareOwner);
        tts_token.shareMint();
        _snapToken("tts_token_shareMint_testTTSwapTokenMintBurn.t_144");

        s_share memory afterMint = tts_token.usershares(shareOwner);
        assertEq(afterMint.leftamount, share.leftamount - expectedMint, "left reduced");
        assertEq(afterMint.metric, share.metric + 1, "metric incremented");
        assertEq(tts_token.balanceOf(shareOwner), expectedMint, "mint amount");
    }
}
