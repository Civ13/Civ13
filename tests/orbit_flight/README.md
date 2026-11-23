# Local two-world flight test

`native_flight.py` is developer evidence, not a CI suite. It flies a crew to
orbit and back between two full worlds on this machine, the way the live
region group does, without touching any server:

```
python3 tests/orbit_flight/native_flight.py --byond-bin ~/byond-516.1688/byond/bin \
    --rust-g librust_g.so --output /fresh/dir
```

- It builds two worlds from temporary copies of `civ13.dme` with `flight.dm`
  appended: `gaia`, the mainland on `maps/nomads/nomads_gaia.dmm`, and `orbit`,
  an `ORBIT` region on `maps/space/orbit.dmm`.
- Each world runs in its own folder under `--output` with its own
  `config/shard_region.json` and `config/transfer_agent.json` (with `peers`,
  as `shard_group.py` writes them), and its own transfer agent from
  `tools/transfer_storage`, served in the runner with a coordinator relaying
  between them. Saving is off; character trips are journaled and need no save.
- On the mainland, the test sets a pad for orbit, builds a launch complex
  office beside it, and has the faction research what the plan needs. The
  office takes the "hub station" sheet and every delivery as stacks, and two
  crew members set off one by one through `depart()`, as `travel()` sends a
  player. `travel_refusal()` is skipped because it wants a player's client.
- On the orbit world, both arrive at the return hatch of a station founded
  from the plan: five sealed modules, a console, and a layout surveyed at the
  console that matches the plan. Both ride the hatch home.
- Back on the mainland, both wait at the office for their players. Then a
  third pilot sets off from the pad on a flight to orbit bound for a free
  berth the orbit world advertises (`port` payload), and the orbit world
  checks the capsule docked at the station's docking airlock, its deck
  against the hatch and the airlock still sealed.

Each side writes `result-<role>.json`. The runner fails on a failed or missing
check and on any runtime error in space, orbit, travel, transfer or party
code. Linux needs the i686 `librust_g.so` of rust-g 3.0.0 (its SHA-256 is
checked). Compiling takes about 25 s, and the flight takes about 65 s from start
to finish.
