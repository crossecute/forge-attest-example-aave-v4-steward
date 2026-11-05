# Fixtures

`nonce-447-call-0.hex` and `nonce-447-call-1.hex` are the two inner calls of the
executed Risk Council transaction at Safe nonce 447, copied from the Safe
Transaction Service on 2026-11-05:

```
https://api.safe.global/tx-service/eth/api/v1/safes/0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8/multisig-transactions/?nonce=447
```

safeTxHash `0x0ea9a8fed74bc267e88a5de190ca88a3c63b5963784f50176bfd0f4fb523f8e4`,
executed in block 26337526. Each file holds one call's calldata without a trailing
newline.
