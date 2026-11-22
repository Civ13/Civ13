# Stone Age storage

Headless probe for `code/modules/1713/stone_age_storage.dm`: the woven basket,
clay storage jar, hewn log chest and storage pit.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/stone_age_storage/probe.dm
```

It loads the real global crafting catalogue and checks that rope, grass, bamboo,
logs, clay and leather offer the four containers at era 0 (and that the wood
chest still waits for Cooperage), that each is gated by an era 0 research node,
the slot and item-size limits of each container, that Dump Out and destruction
put the contents on the floor, the food keeping rate each container gives,
that firing an unfired jar sets a jar down beside the kiln, that two real oven
passes fire one jar and one zeer pot (none inside the oven, no runtime, an
ordinary fired item still comes out) and an oven with nowhere to set a jar
keeps the unfired one, that fired jars give no wood when hammered apart while a
recipe-less structure still does, that a replayed
load binds the saved holder, and that every sprite state exists. It prints
PASS/FAIL lines and writes `result.json`; exit status 0 means no failures and
no runtime errors.

Sprites are drawn by `tests/sprites/create_stone_age_storage.py`
(`--preview <png>` writes a review sheet).

Not established: the storage window and Dump Out in a real client, digging a
pit in play, and a full save/load roundtrip.
