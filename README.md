# forge-attest-example-aave-v4-steward

A demo of Forge Attest v1.4.0 using the Aave v4 Risk Council Safe on Ethereum
at nonce 447. The demo reconstructs the transaction from its historical calldata
and takes its addresses from `aave-address-book` at `b71495a`.

## Run it

Install Foundry, then run the calldata tests and attest the Builder file and the
plain child approval with [`attest.toml`](attest.toml).

```bash
git clone https://github.com/crossecute/forge-attest-example-aave-v4-steward
cd forge-attest-example-aave-v4-steward
git submodule update --init
git -C lib/aave-address-book submodule update --init lib/aave-v4
forge test
git clone https://github.com/crossecute/forge-attest.git ../forge-attest
git -C ../forge-attest checkout --detach 9e76385ac2f96f171ceb9391cf9e8298e2d408cf # v1.4.0
../forge-attest/attest.sh --config attest.toml --require-live
```

`forge test` compares both calls byte for byte with the historical calldata.
Forge Attest reruns [`BuildRiskCouncilTx`](script/BuildRiskCouncilTx.s.sol)
at the pinned producer commit and checks the raw Builder file and canonical
transaction digests. It derives `safeTxHash` with both `cast` and Solidity.
With `--require-live`, the parent and child hashes must also match the records
at their respective nonces in the Safe Transaction Service.

## Check the second child approval

Both Risk Council owners are Safes. Forge Attest builds each owner's
`approveHash(parentHash)` transaction from the same parent. Each child has its
own config because a claim names one child and the claims use the same Builder
file.

| Config | Child Safe | Child nonce | `child_approval` | Child safeTxHash |
|---|---|---|---|---|
| [`attest.toml`](attest.toml) | `0x2B99…B1cA` (2 of 5) | 18 | `plain` | `0xf7ebe808…52e5` |
| [`attest.child-a.toml`](attest.child-a.toml) | `0xb291…Afef` (1 of 3) | 205 | `preimage-suffix` | `0xcce0f737…07cb` |

```bash
../forge-attest/attest.sh --config attest.child-a.toml --require-live
```

The second approval appends `0xfb4e87b0` and an ABI-encoded copy of the parent
transaction to the plain call. `child_approval = "preimage-suffix"` rebuilds
those bytes from the parent.

## Capture a safe-utils proposal

[`ProposeRiskCouncilTx`](script/ProposeRiskCouncilTx.s.sol) sends the same
payload through `safe-utils` v0.0.22, the library used by Aave's risk steward
script. [`attest.capture.toml`](attest.capture.toml) runs the demo producer on
a fork at block 26,337,525 and intercepts its request locally. Use Foundry
v1.8.1 and an Ethereum archive RPC.

```bash
MAINNET_RPC_URL=https://eth.drpc.org ../forge-attest/attest.sh --config attest.capture.toml --require-live
```

The claim provides public test key `1` for local signing. Use the capture
command above, since the producer sends a real Safe service request when run
directly. The captured request has the same canonical digest
(`ef44057e…5d10`) and Safe hash (`0x0ea9a8fe…8e4`) as the Builder file.

## What nonce 447 does

The Safe uses a MultiSendCallOnly delegatecall for two calls to
`AaveV4Ethereum.RISK_STEWARD`.

| Call | Change |
|---|---|
| `updateHubAssetIRs` | Sets USDC `rateGrowthBeforeOptimal` to 550 on the Core Hub and 450 on the Prime Hub. |
| `updateHubSpokeCaps` | On the Core Hub, sets draw caps of 45,000 for WETH on the EtherFi spoke, 40,000,000 for USDC and 20,000,000 for USDT on the Main spoke, and an add cap of 25,000 for weETH on the Main spoke. Values are as encoded. |
