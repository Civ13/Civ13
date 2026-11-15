# Design codes tests

Player designs (pictures, flag maker flags, pole flags, faction symbols and tailoring designs) export as text codes and import back; see `code/modules/paintings/design_codes.dm`.

- `test_design_codes.py`: offline source contracts (DME order, an exporter and reader per kind, Copy and Paste in both faction symbol editors, import logging and rate limit, imports keeping pigment, research and name rules, painter-only codes for finished pictures, flags redrawn after loading).
- `probe.dm`: native probe of every code kind: round trips, refusals (size, colours, version, kind, layers, symbols, pieces, names, symbol pixel counts), faction symbols exported approximated past 16 colours, import marking and logging, flags redrawn after loading. It also writes `editor.html` (a table picture editor) into its evidence folder for a browser check of Export and Import. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/design_codes/probe.dm 300
```
