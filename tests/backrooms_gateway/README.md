# Disabled expedition gateway foundation

`test_contract.py` runs offline source-derived power/debit predicates, boundary
projections, disabled/save-field contracts and fixture preparation checks. It
does not execute DM or prove gameplay. Run with a verified interpreter:

```powershell
& 'C:/Path/To/Python/python.exe' -B -m unittest discover -s tests/backrooms_gateway -v
```

`prepare.py --output <new-directory>` copies the exact production datums and
native assertions, records hashes and writes probe.dme. It never compiles or
launches a process. Optional `--control outage|debit|restore` mutates only the
prepared copy; each control must fail its named fixture assertion.

The fixture tests real production state transitions and native savefile disk
round trips of the explicit snapshot ABI. It does not use the world serializer,
create a gateway object or move a human. Native execution remains **not_run**
until a maintainer reviews docs/backrooms-expedition/ACCEPTANCE.md's bounded
plan and an appropriately isolated harness. Compilation alone is not execution.

No file in this suite launches DreamDaemon, changes a live server or reads a
production save. Keep source/fixture compilation logs, original failures and
missing acceptance explicit. Do not weaken socket restrictions to obtain a pass.
