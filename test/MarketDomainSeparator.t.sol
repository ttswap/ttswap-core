// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {BaseSetup} from "./BaseSetup.t.sol";
import {TTSwap_Market} from "../src/TTSwap_Market.sol";

contract MarketDomainSeparatorTest is BaseSetup {
    function test_domainSeparatorUsesProxyAddress() public view {
        bytes32 proxyDomain = market.DOMAIN_SEPARATOR();
        bytes32 expectedProxyDomain = _domainSeparator(address(market));
        bytes32 implementationDomain = _domainSeparator(market_proxy.implementation());

        assertEq(proxyDomain, expectedProxyDomain, "proxy domain separator mismatch");
        assertTrue(
            proxyDomain != implementationDomain,
            "proxy domain should not match implementation domain"
        );
    }

    function test_domainSeparatorRemainsProxyScopedAfterUpgrade() public {
        bytes32 beforeUpgrade = market.DOMAIN_SEPARATOR();

        vm.startPrank(marketcreator);
        TTSwap_Market newImplementation = new TTSwap_Market(tts_token);
        market_proxy.upgrade(address(newImplementation));
        vm.stopPrank();
        bytes32 afterUpgrade = market.DOMAIN_SEPARATOR();
        bytes32 expectedProxyDomain = _domainSeparator(address(market));

        assertEq(afterUpgrade, expectedProxyDomain, "proxy domain changed after upgrade");
        assertEq(afterUpgrade, beforeUpgrade, "proxy domain should stay stable across upgrades");
        assertTrue(
            afterUpgrade != _domainSeparator(address(newImplementation)),
            "proxy domain should not switch to implementation address"
        );
    }

    function _domainSeparator(address verifyingContract) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("TTSwap_Market")),
                keccak256(bytes("1.16.0")),
                block.chainid,
                verifyingContract
            )
        );
    }
}
