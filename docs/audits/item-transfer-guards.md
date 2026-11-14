# Item-transfer guards (2026-11-14)

Imported report patches 10–12, reviewed against master 7cb35e806751e1c5b1c6d0c732d7c62a9647e16d.

- Vending: retire each selected stored object before delivery, so repeat purchases do not pull the same object back from the buyer. Stop selection if the list is exhausted. Generated-product and stack routes remain unchanged.
- Evidence bags: reject nested bags, oversized items and occupied bags before removing anything from storage or the user's hands. The observed bug strands a stored item; actual deletion was not demonstrated.
- Fence exchange: require successful creation of both change and destination notes before committing payment. Clean up prepared change if output creation fails. This prevents a converted value above the note factory's 50,000 limit from debiting payment with no output.

## Evidence and limitations

`python3 tests/item_transfer_guards/test_guards.py` passes seven source-order contracts, including mutations that remove/misorder guards. These inspect the actual production source; they do not execute DM or demonstrate gameplay behavior.

Pinned 516.1688 setup was attempted with `bash scripts/cloud_byond_setup.sh`; it stops at `sudo: command not found`. No compiler or DreamDaemon was launched. Hosted compilation and real inventory/FX acceptance remain outstanding. No live world, account login, save, deployment or server operation was performed.

Required native checks: stock two uniquely identified non-stack objects and buy twice, confirming distinct identity and depleted stock; refuse each evidence-bag case from storage/hands without displacement, then accept and recover a small item; exchange within the note limit and beyond it (cash and game-credit inputs), verifying exact balances, change cleanup and no payment on rejection. Exercise failed trade commit as a rollback control.
