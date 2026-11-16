# Mouse nests

Mice live in nests (`code/modules/ecology/mouse_nests.dm`), settled by the
`mouse nests` process (`code/processes/mouse_nests.dm`). See
`docs/mouse-nests.md` for the design.

- `python3 -m unittest tests/mouse_nests/test_source.py`: offline source
  contracts (rot spawns nothing, mice are timid, burrows come from the ecology
  cycle, emitted mice are not saved, sprites exist).
- `python3 tests/ecology_spawning/run_linux.py . tests/mouse_nests/probe.dm`:
  headless DM probe of settle growth and starving, the 12-step clamp, the
  load clock reset, emitted mice, the wild burrow target, store access
  (jar, basket, log chest), feeding and fouling, seeds and crops, and
  spreading (floor, crowding, range). Needs the pinned
  BYOND from `scripts/cloud_byond_setup.sh`.
- Sprites: `python3 tests/sprites/create_mouse_nests.py` (`--check`, `--preview`).
