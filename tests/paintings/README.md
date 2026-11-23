# Paintings tests

- `test_paintings.py`: offline source contracts (DME includes, sprite states, art windows in the canvas, frame and locket sprites, recipes, mortar hook, upload checks and logs, generated icons kept out of saves).
- `probe.dm`: native probe of packing, shrinking, shared icons, allowed colours and mixes, upload refusals, saving and finishing, pigment use, the region cap, the admin list, hanging on walls, easels and lockets. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/paintings/probe.dm 300
```

The probe also writes `editor.html` (the editor for a table picture) into its evidence folder for a browser check.

The probe also covers original plan and drawing sheets in wall frames: the full
read-only rendering, rebuilding the thumbnail on load, and returning the same
sheet when the frame is removed. In game, use a finished wall canvas, a sheet with
drawings, or a filled supported plan sheet on the next solid wall tile. Examine
from the adjacent floor to see the image, or use a hammer to take it back down.
