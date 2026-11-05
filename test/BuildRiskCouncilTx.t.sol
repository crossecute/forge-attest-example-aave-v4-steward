// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV4Ethereum} from "aave-address-book/AaveV4Ethereum.sol";
import {BuildRiskCouncilTx, IRiskStewardUpdates} from "../script/BuildRiskCouncilTx.s.sol";

contract BuildRiskCouncilTxTest is Test {
    BuildRiskCouncilTx internal producer = new BuildRiskCouncilTx();

    function _fixture(string memory name) internal view returns (bytes memory) {
        return vm.parseBytes(vm.readFile(string.concat("test/fixtures/", name)));
    }

    function test_CallsEqualTheExecutedNonce447Calldata() external view {
        bytes[] memory data = producer.calls();
        assertEq(data.length, 2);
        assertEq(data[0], _fixture("nonce-447-call-0.hex"), "updateHubAssetIRs");
        assertEq(data[1], _fixture("nonce-447-call-1.hex"), "updateHubSpokeCaps");
    }

    function test_SelectorsAreTheStewardEntrypoints() external view {
        bytes[] memory data = producer.calls();
        assertEq(bytes4(data[0]), IRiskStewardUpdates.updateHubAssetIRs.selector);
        assertEq(bytes4(data[1]), IRiskStewardUpdates.updateHubSpokeCaps.selector);
        assertEq(bytes4(data[0]), bytes4(0x2cd0fd70));
        assertEq(bytes4(data[1]), bytes4(0xd3e6db1b));
    }

    function test_RunWritesTheSafeFromTheAddressBook() external {
        producer.run();
        string memory json = vm.readFile("out/risk-council-tx.json");
        assertEq(vm.parseJsonAddress(json, ".meta.createdFromSafeAddress"), AaveV4Ethereum.RISK_COUNCIL);
        assertEq(vm.parseJsonAddress(json, ".transactions[0].to"), AaveV4Ethereum.RISK_STEWARD);
        assertEq(vm.parseJsonAddress(json, ".transactions[1].to"), AaveV4Ethereum.RISK_STEWARD);
        assertEq(vm.parseJsonBytes(json, ".transactions[0].data"), producer.calls()[0]);
        assertEq(vm.parseJsonBytes(json, ".transactions[1].data"), producer.calls()[1]);
    }
}
