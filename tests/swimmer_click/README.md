# Swimmer click area

Headless probe for the water mask click area in
`code/game/mob/living/carbon/human/update_icons.dm`. The alpha mask that hides a
swimmer's submerged body also hid it from the mouse, so the right-click menu on
their tile listed only the water.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/swimmer_click/probe.dm
```

It checks that a human in water gets `mouse_opacity` 2 while masked and 1 again
on dry ground, that a full redraw keeps it, that a mob set unclickable by other
code stays unclickable, and that bathtub water drawn over a bather takes no
clicks. Exit status 0 means no failures and no runtime errors.

Not established: the right-click menu in a real client (BYOND popup menus need
a connected client).
