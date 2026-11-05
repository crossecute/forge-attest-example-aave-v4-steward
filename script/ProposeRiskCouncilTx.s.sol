// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Safe} from "safe-utils/Safe.sol";
import {AaveV4Ethereum} from "aave-address-book/AaveV4Ethereum.sol";
import {RiskCouncilPayload} from "../src/RiskCouncilPayload.sol";

/// @title ProposeRiskCouncilTx
/// @notice Proposes the nonce 447 payload to the Risk Council Safe through safe-utils,
///         the way aave-v4-risk-stewards does with `broadcast=true`: one MultiSend
///         batch, signed locally and posted to the Safe Transaction Service.
///
///         Run on its own, it posts for real. With `capture = "safe-utils"` forge-attest
///         runs it unchanged against a fork and intercepts the request instead, so
///         nothing is sent. PRIVATE_KEY is a public test key; the Safe takes its nonce
///         from the fork, so the fork block must be one where the Safe is at nonce 447.
contract ProposeRiskCouncilTx is Script {
    using Safe for *;

    Safe.Client internal safe;

    function run() external {
        bytes[] memory data = RiskCouncilPayload.calls();
        address[] memory targets = new address[](data.length);
        for (uint256 i; i < data.length; i++) {
            targets[i] = AaveV4Ethereum.RISK_STEWARD;
        }

        safe.initialize(AaveV4Ethereum.RISK_COUNCIL);
        address signer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        bytes32 safeTxHash = safe.proposeTransactions(targets, data, signer, "");
        console.log("proposed safe tx hash:");
        console.logBytes32(safeTxHash);
    }
}
