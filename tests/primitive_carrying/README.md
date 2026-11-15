# Early carrying gear

Headless probe for `code/modules/1713/primitive_carrying.dm`: the grass carry net,
hide sling bag, pack basket, pack frame and travois.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/primitive_carrying/probe.dm
```

It loads the real global crafting catalogue and checks that the Stone Age menus
(rope, wolf pelt, leather, wood) offer the net, sling bag, basket and travois,
that the pack frame waits for the Bronze Age node the leather backpack uses, that
each tier holds more than the last (with the item-size limits), that only the
pack frame slows its wearer, that every item and worn sprite state exists, and
that a travois closes over 15 things. It prints PASS/FAIL lines and writes
`result.json`; exit status 0 means no failures and no runtime errors.

Sprites are drawn by `tests/sprites/create_primitive_carrying.py`
(`--preview <png>` writes a review sheet).
