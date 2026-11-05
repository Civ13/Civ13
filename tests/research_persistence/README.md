# Research unlocks on persistent worlds

Persistent worlds run Auto-Research: every faction's legacy research rises on
one clock and the world starts in WW2. These checks cover three gaps found on
Gaia's save of 2026-11-05 (world era 7, half the factions at baseline 6):

- `sync_autoresearch_baselines` raises each faction's main-tree baseline to the
  age the legacy clock reached (age flags). An era reached through one faction's
  capstone is not granted to others. Baselines are saved, so a raised baseline
  survives a restart although `age9_done` is not saved.
- `legacy_age_advance` never lowers `ordinal_age` below an era a capstone reached.
- On persistent worlds a faction's specialist-tree nodes up to WW2
  (`PERSISTENT_SPECIALIST_BASELINE_ERA`) count as done; factionless players
  still never get specialist trees.

Offline: `python3 -m unittest discover -s tests/research_persistence -v`.

Native: `python3 tests/research_persistence/run.py --byond-bin <pinned bin>`
(source `byondsetup` first on Linux). It compiles the production
`research_faction.dm`, the tree defines, the real `/datum/research_node` and the
legacy age helpers from `_map_metadata.dm` with small stubs, runs DreamDaemon
with `-safe` on port 0 and prints `PASS`. `--negative-control baseline`,
`regression` or `specialist` each removes one fix and must report its failure.
It does not load a real save or run the full game.
