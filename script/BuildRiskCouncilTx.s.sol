// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {AaveV4Ethereum} from "aave-address-book/AaveV4Ethereum.sol";
import {RiskCouncilPayload} from "../src/RiskCouncilPayload.sol";

/// @title BuildRiskCouncilTx
/// @notice Rebuilds the Aave v4 Risk Council transaction executed at Safe nonce 447
///         (see RiskCouncilPayload) and writes it as a Safe{Wallet} Transaction Builder
///         file that names the Safe in `meta.createdFromSafeAddress`. The nonce is not
///         in the file, so forge-attest takes it from the claim.
contract BuildRiskCouncilTx is Script {
    function run() external {
        bytes[] memory data = RiskCouncilPayload.calls();
        string memory json = string.concat(
            "{\n",
            '  "version": "1.0",\n',
            '  "chainId": "1",\n',
            '  "meta": {\n',
            '    "name": "Risk Council steward update",\n',
            '    "createdFromSafeAddress": "',
            vm.toString(AaveV4Ethereum.RISK_COUNCIL),
            '"\n',
            "  },\n",
            '  "transactions": [\n',
            _entry(data[0]),
            ",\n",
            _entry(data[1]),
            "\n  ]\n}\n"
        );
        vm.createDir("out", true);
        vm.writeFile("out/risk-council-tx.json", json);
    }

    function _entry(bytes memory data) private pure returns (string memory) {
        return string.concat(
            '    { "to": "',
            vm.toString(AaveV4Ethereum.RISK_STEWARD),
            '", "value": "0", "data": "',
            vm.toString(data),
            '", "operation": "0" }'
        );
    }
}
