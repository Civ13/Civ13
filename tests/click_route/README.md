# Click-to-move routing

Headless probe for `code/modules/1713/click_route.dm`, the Ctrl+click route
players walk and agent characters follow with the `walk_to` queue action. The
planner must go round walls without cutting corners, prefer dry ground over
wading when the way round is short, never plan through deep water, stop next
to a goal it cannot stand on, and refuse far or sealed goals with a reason. A
route must arrive tile by tile, stop when the walker is hurt or a hostile
animal comes close, and let go of the held movement keys when cancelled.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/click_route/probe.dm
```
