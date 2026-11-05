#!/usr/bin/env bash
# Check that the safeTxHash pinned in attest.toml is the one the Safe executed at
# that nonce. This is the check the live queue step does for a pending transaction.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
field() { sed -n "s/^$1 = \"\(.*\)\"$/\1/p" attest.toml | head -1; }

safe=$(field safe_address)
nonce=$(field safe_nonce)
want=$(field expected_safe_tx_hash)

row=$(curl -fsS "https://api.safe.global/tx-service/eth/api/v1/safes/$safe/multisig-transactions/?nonce=$nonce&executed=true" |
  jq -c '.results[0] // empty')
[[ -n "$row" ]] || { echo "no executed transaction at nonce $nonce" >&2; exit 1; }

got=$(jq -r .safeTxHash <<<"$row")
[[ "${got,,}" == "${want,,}" ]] || { echo "executed $got, pinned $want" >&2; exit 1; }
[[ "$(jq -r .isSuccessful <<<"$row")" == true ]] || { echo "executed but failed" >&2; exit 1; }

echo "nonce $nonce executed in block $(jq -r .blockNumber <<<"$row") as $got"
