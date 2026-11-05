// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAaveV4ConfigEngine as IEngine} from "aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol";
import {EngineFlags} from "aave-v4/config-engine/libraries/EngineFlags.sol";
import {IAssetInterestRateStrategy} from "aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol";
import {
    AaveV4Ethereum,
    AaveV4EthereumAssets,
    AaveV4EthereumHubs,
    AaveV4EthereumSpokes
} from "aave-address-book/AaveV4Ethereum.sol";

/// @dev The two RiskSteward entrypoints this update calls. The struct types come
///      from the Aave v4 config engine, as in aave-dao/aave-v4-risk-stewards.
interface IRiskStewardUpdates {
    function updateHubAssetIRs(IEngine.AssetConfigUpdate[] calldata updates) external;
    function updateHubSpokeCaps(IEngine.SpokeConfigUpdate[] calldata updates) external;
}

/// @title RiskCouncilPayload
/// @notice The Aave v4 Risk Council update executed at Safe nonce 447 (0x47c7…0fA8,
///         Ethereum): two steward calls. Every address is read from aave-address-book;
///         the update values are decoded from the executed calldata. Shared by the
///         script that writes a Safe file and the one that proposes through safe-utils.
library RiskCouncilPayload {
    function hubAssetIrUpdates() internal pure returns (IEngine.AssetConfigUpdate[] memory updates) {
        updates = new IEngine.AssetConfigUpdate[](2);
        updates[0] = _irUpdate(address(AaveV4EthereumHubs.CORE_HUB), 5_50);
        updates[1] = _irUpdate(address(AaveV4EthereumHubs.PRIME_HUB), 4_50);
    }

    function hubSpokeCapsUpdates() internal pure returns (IEngine.SpokeConfigUpdate[] memory updates) {
        updates = new IEngine.SpokeConfigUpdate[](4);
        updates[0] = _capsUpdate(
            AaveV4EthereumAssets.WETH_UNDERLYING,
            address(AaveV4EthereumSpokes.ETHERFI_ESPOKE),
            EngineFlags.KEEP_CURRENT,
            45_000
        );
        updates[1] = _capsUpdate(
            AaveV4EthereumAssets.weETH_UNDERLYING,
            address(AaveV4EthereumSpokes.MAIN_SPOKE),
            25_000,
            EngineFlags.KEEP_CURRENT
        );
        updates[2] = _capsUpdate(
            AaveV4EthereumAssets.USDC_UNDERLYING,
            address(AaveV4EthereumSpokes.MAIN_SPOKE),
            EngineFlags.KEEP_CURRENT,
            40_000_000
        );
        updates[3] = _capsUpdate(
            AaveV4EthereumAssets.USDT_UNDERLYING,
            address(AaveV4EthereumSpokes.MAIN_SPOKE),
            EngineFlags.KEEP_CURRENT,
            20_000_000
        );
    }

    /// @dev The calls in the order the Safe batch carries them.
    function calls() internal pure returns (bytes[] memory data) {
        data = new bytes[](2);
        data[0] = abi.encodeCall(IRiskStewardUpdates.updateHubAssetIRs, (hubAssetIrUpdates()));
        data[1] = abi.encodeCall(IRiskStewardUpdates.updateHubSpokeCaps, (hubSpokeCapsUpdates()));
    }

    function _irUpdate(address hub, uint32 rateGrowthBeforeOptimal) private pure returns (IEngine.AssetConfigUpdate memory) {
        return IEngine.AssetConfigUpdate({
            hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
            hub: hub,
            underlying: AaveV4EthereumAssets.USDC_UNDERLYING,
            liquidityFee: EngineFlags.KEEP_CURRENT,
            feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
            irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
            irData: IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: EngineFlags.KEEP_CURRENT_UINT16,
                baseDrawnRate: EngineFlags.KEEP_CURRENT_UINT32,
                rateGrowthBeforeOptimal: rateGrowthBeforeOptimal,
                rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
            }),
            reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
        });
    }

    function _capsUpdate(address underlying, address spoke, uint256 addCap, uint256 drawCap)
        private
        pure
        returns (IEngine.SpokeConfigUpdate memory)
    {
        return IEngine.SpokeConfigUpdate({
            hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
            hub: address(AaveV4EthereumHubs.CORE_HUB),
            underlying: underlying,
            spoke: spoke,
            addCap: addCap,
            drawCap: drawCap,
            riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
            active: EngineFlags.KEEP_CURRENT,
            halted: EngineFlags.KEEP_CURRENT
        });
    }
}
