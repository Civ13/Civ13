# Fishing grounds

Code: `code/modules/1713/fishing_grounds.dm`. Design: `docs/fishing-grounds.md`.

```sh
python3 -m unittest discover -s tests/fishing_grounds -p 'test_*.py' -v
python3 tests/ecology_spawning/run_linux.py . tests/fishing_grounds/probe.dm
```

`test_source.py` is offline: the include, the absence of any fishing spot object
in code, maps and the land generator, and the order of checks in the cast.

`probe.dm` runs the production file natively in a 64x64 fixture: water kinds and
capacities, one ground per 16x16 stretch and kind, takes, the reading a player
gets, regrowth at half stock, near full and from empty (with and without fish
in neighbouring grounds), the catch tables and the tool profiles, and breaking ice: tool times, the
water a broken tile opens to, refreezing, thickening and thawing through a
marker whose air the probe sets, and small boats at thick and rotten ice. It moves a
ground's clock back instead of waiting. It does not run a cast: `do_after`, the
messages and the catch landing in a hand are not covered natively.

This replaces `tests/fishing_stock`, which pinned the removed fishing spot
object and the 8x8 open-sea stock.
