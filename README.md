# forge-attest-example-aave-v4-steward

A demo of [`forge-attest`](https://github.com/crossecute/forge-attest/tree/c5760b798e68901c60192e22c500b63a5a996bd3) on a real
Aave v4 transaction. [`script/BuildRiskCouncilTx.s.sol`](script/BuildRiskCouncilTx.s.sol)
rebuilds the Risk Council transaction executed at Safe nonce 447
([`0x47c7…0fA8`](https://app.safe.global/home?safe=eth:0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8),
Ethereum). `forge-attest` derives the same `safeTxHash` the Safe executed.

The Safe, the steward, the hub configurator, both hubs, both spokes and the four
assets all come from [`aave-address-book`](https://github.com/aave-dao/aave-address-book),
a git submodule pinned at `b71495a`. Only the update values (rates and caps) are
written in the script.

This is not Aave's payload. Aave's risk stewards repo
([`aave-v4-risk-stewards`](https://github.com/aave-dao/aave-v4-risk-stewards)) generates payloads
locally and none of them are published, so I could not find the code that produced
nonce 447. The values here were decoded from the executed calldata, and the test
checks the rebuilt calls against it byte for byte.

## What nonce 447 does

A MultiSendCallOnly delegatecall (Safe 1.3.0) with two calls to `AaveV4Ethereum.RISK_STEWARD`:

| Call | Change |
|---|---|
| `updateHubAssetIRs` | USDC `rateGrowthBeforeOptimal` set to 550 on the Core Hub and 450 on the Prime Hub. Every other field keeps its current value. |
| `updateHubSpokeCaps` | On the Core Hub, draw caps of 45,000 for WETH on the EtherFi spoke, 40,000,000 for USDC and 20,000,000 for USDT on the Main spoke, and an add cap of 25,000 for weETH on the Main spoke. Values are as encoded. |

## Run it

```bash
git clone https://github.com/crossecute/forge-attest-example-aave-v4-steward
cd forge-attest-example-aave-v4-steward
git submodule update --init
git -C lib/aave-address-book submodule update --init lib/aave-v4   # skips the address book's other dependency
forge test
forge script script/BuildRiskCouncilTx.s.sol:BuildRiskCouncilTx && cat out/risk-council-tx.json
```

The script writes a Safe{Wallet} Transaction Builder file with the Safe in
`meta.createdFromSafeAddress`. It has no timestamp, so the file is byte-stable.

## Verify with forge-attest

```bash
git clone https://github.com/crossecute/forge-attest.git ../forge-attest
git -C ../forge-attest checkout --detach c5760b798e68901c60192e22c500b63a5a996bd3 # main after v1.3.0; use the next release tag when cut
../forge-attest/attest.sh --config attest.toml --require-live
./scripts/check-executed.sh
```

`attest.sh` re-runs the pinned producer commit and checks the raw file hash, the
canonical hash, and the `safeTxHash` with `cast` and with Solidity. The pinned
`safeTxHash` is `0x0ea9a8fe…8e4`, the hash of the executed transaction. The claims set
`safe_network = "ethereum"`, so the live check also compares the hash with the
transaction the Safe Transaction Service holds at nonce 447. That transaction has
already executed; for a pending one the same setting compares it with the queued
transaction. Add `--require-live` to fail instead of skipping when the service cannot
be reached. [`scripts/check-executed.sh`](scripts/check-executed.sh) additionally
confirms that the transaction executed successfully and prints its block.

## Capture Aave's own proposal flow

`aave-v4-risk-stewards` proposes through [`safe-utils`](https://github.com/Recon-Fuzz/safe-utils)
(`_safe.proposeTransactions`, pinned at v0.0.22). [`script/ProposeRiskCouncilTx.s.sol`](script/ProposeRiskCouncilTx.s.sol)
does the same for this payload: one MultiSend batch, signed locally and posted to the Safe
Transaction Service. [`attest.capture.toml`](attest.capture.toml) uses forge-attest's
`capture = "safe-utils"` mode to run it unchanged on a fork one block before nonce 447
executed, intercept the request it would have posted, and attest that:

```bash
MAINNET_RPC_URL=https://eth.drpc.org ../forge-attest/attest.sh --config attest.capture.toml --require-live
```

The captured request folds to the same canonical transaction as the Transaction Builder
file above (`ef44057e…5d10`) and to the executed `safeTxHash`. Notes:

- It needs an archive RPC for the fork block. The public `eth.drpc.org` endpoint served it
  when I tried; use your own for anything that matters.
- `PRIVATE_KEY = "1"` is a public test key for the script's local signing step. Never use an
  owner key. The signature in the request is not an approval.
- The request is stored outside the clone, so the script writes no file and the capture
  needs no change to the producer.
- Aave's own script reads `SIGNER_ADDRESS` and signs with a hardware wallet. This demo script
  signs with the test key because capture forbids a device.

## The Safe is nested

Both owners of the Risk Council are Safes. Each approves with a transaction of its own,
`approveHash(parentHash)` on the Risk Council, and its owners sign that. `forge-attest`
builds each approval from the parent transaction, so the child's signers can see which
hash they are approving. One claim names one child, and two claims cannot share an output
path, so each child has its own config. Each config also sets `child_network`, so the
approval is compared with the child's own transaction in the Safe service:

| Config | Child Safe | Child nonce | `child_approval` | Child safeTxHash |
|---|---|---|---|---|
| [`attest.toml`](attest.toml) | `0x2B99…B1cA` (2 of 5) | 18 | `plain` | `0xf7ebe808…52e5` |
| [`attest.child-a.toml`](attest.child-a.toml) | `0xb291…Afef` (1 of 3) | 205 | `preimage-suffix` | `0xcce0f737…07cb` |

Both hashes are the executed child transactions. The first child sent the plain call. The
second sent `approveHash(parentHash)` followed by the parent transaction, as `0xfb4e87b0`
and an ABI-encoded copy of the Risk Council transaction (2,788 extra bytes here), so its
owners could read what they approved. `child_approval = "preimage-suffix"` rebuilds that
form from the parent, so a suffix that described a different transaction would not match.
I do not know which tool writes the suffix.

An approval is only valid while the Risk Council nonce equals the one in the claim.

## What this proves, and what it does not

It proves the transaction is exactly the output of this script at a pinned commit. It
does not prove Aave's own tooling produced it, that the values were reviewed, or that
the steward accepts them. The steward enforces its own bounds on chain.
