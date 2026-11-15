# Firearm coverage manifest

`docs/firearm-coverage.json` lists every `/obj/item/weapon/gun` type with its
compiler-resolved name, caliber, load method, capacity, magazine and ammo
types, a category and a scope (`modern` or `separate`). It is the migration
checklist for issue #4443: phase 5 sets each modern type's `migration` from
`pending` to `modular` once its family is converted, or to `fixed` when the
type sets `firearm_fixed_reason` (a modern design kept whole on purpose, such
as the sawn-off Obrez); the reason is stored as `fixed_reason`.

- `python3 tests/firearm_coverage/run.py --byond-bin <BYOND bin> --write`
  compiles the game with the pinned compiler, dumps `initial()` values for
  every gun type (`probe.dm`) and rewrites the manifest through
  `firearm_coverage.py`. Without `--write` it fails when the manifest is stale.
- `python3 -B scripts/ci_baseline.py unit --suite firearm_coverage --output <file>`
  runs the offline checks: no unclassified types, modern scope holds cartridge
  calibers only, the stored rows still classify the same way, and every gun type
  declared in `code/` is in the manifest. Adding a gun means rerunning `run.py
  --write` (cloud sessions: `bash scripts/cloud_byond_setup.sh` first).

Categories come from ancestry rules in `firearm_coverage.py`, earliest match
first, with caliber overrides (laser/laserb/taser to energy, rocket to
launcher). Modern = revolvers, pistols, bolt/lever/semi-auto rifles, shotguns,
SMGs and machine guns. Blackpowder, energy, launchers, bows, darts and the
custom gunsmith gun are separate categories, not counted as complete. Entries
whose name looks like an abstract parent ("gun", "pistol") carry a `review`
note: whether players can obtain them is not established here.

Acquisition routes (jobs, maps, vendors, factories) are not resolved by this
manifest; `scripts/firearm_inventory.py` collects that lexical evidence.
