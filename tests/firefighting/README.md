# Firefighting tests

- `test_firefighting.py`: offline source contracts (DME order, sprite states, recipes and research mapping, saved state). CI suite `firefighting`.
- `probe.dm`: native probe of beating fires out (odds, cooldown, wear), soaking in open water, containers and wells, beating flames off a burning person, smothering with pelts and the research mapping. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/firefighting/probe.dm 300
```

Sprites: `python3 tests/sprites/create_firefighting.py [--preview sheet.png]` rewrites `icons/obj/firefighting.dmi`.
