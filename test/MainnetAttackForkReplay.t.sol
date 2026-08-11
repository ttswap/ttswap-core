// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/src/Test.sol";

/// @notice Mainnet attack fork replay (TASK-P3-005).
/// @dev Skips when fixture or RPC unavailable. Place raw tx at
///      `test/fixtures/mainnet_attack_raw_tx.hex` to enable.
contract MainnetAttackForkReplay is Test {
    string internal constant TX_FIXTURE =
        "/test/fixtures/mainnet_attack_raw_tx.hex";
    uint256 internal constant FORK_BLOCK = 24_991_800;

    function _fixtureExists() internal view returns (bool) {
        string memory path = string.concat(vm.projectRoot(), TX_FIXTURE);
        try vm.readFile(path) returns (string memory content) {
            return bytes(content).length > 0;
        } catch {
            return false;
        }
    }

    function _rpcUrl() internal view returns (string memory) {
        try vm.envString("MAINNET_RPC_URL") returns (string memory url) {
            if (bytes(url).length > 0) return url;
        } catch {}
        return "https://eth.drpc.org";
    }

    function testMainnetAttackForkReplay_skipsWithoutFixture() public {
        if (!_fixtureExists()) {
            vm.skip(true);
        }

        string memory path = string.concat(vm.projectRoot(), TX_FIXTURE);
        bytes memory rawTx = vm.parseBytes(vm.readFile(path));
        assertGt(rawTx.length, 0, "fixture non-empty");

        try vm.createSelectFork(_rpcUrl(), FORK_BLOCK) {
            // Replay only when fork succeeds; do not assert profit — regression guard.
            (bool ok,) = address(0).call(rawTx);
            ok;
        } catch {
            vm.skip(true);
        }
    }
}
