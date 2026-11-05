# Crossroads Mall offline suite

`build.py` generates `maps/EFT/crossroads_mall.dmm`, the original mall raid map
and loot test range described in [docs/crossroads-mall.md](../../docs/crossroads-mall.md).
`test_crossroads_mall.py` parses the checked-in map, compares it with the
generator, projects the loot tables from `code/game/objects/random.dm` and
`code/game/objects/effects/spawners/loot.dm`, and flood-fills walking routes.

```text
python3 -I -B tests/crossroads_mall/build.py
python3 -I -B tests/crossroads_mall/test_crossroads_mall.py
```

The suite never launches BYOND. Passing it is not native movement, lighting or
loot acceptance; compile the map in a temporary environment and run it under
DreamDaemon for that.
