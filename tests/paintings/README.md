# Paintings tests

- `test_paintings.py`: offline source contracts (DME includes, sprite states, art windows in the canvas, frame and locket sprites, recipes, mortar hook, upload checks and logs, generated icons kept out of saves).
- `probe.dm`: native probe of packing, shrinking, shared icons, allowed colours and mixes, upload refusals, saving and finishing, pigment use, the region cap, the admin list, hanging on walls, easels and lockets. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/paintings/probe.dm 300
```

The probe also writes `editor.html` (the editor for a table picture) into its evidence folder for a browser check.
