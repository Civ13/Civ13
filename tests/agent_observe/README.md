# Agent observe fixture

```bash
source <BYOND>/bin/byondsetup
python3 tests/agent_observe/run.py --byond-bin <BYOND>/bin
```

The runner compiles the production sources with maps and ordinary start-up
removed, then runs `probe.dm` on a 30 x 30 grass level using the pinned BYOND
build. It needs every assertion to pass and no runtime errors.

Covered: `character_observe` change lists (`rev`, `since_rev`, an empty list
when nothing changed, walking not marking rows changed, new and removed
objects, a stale baseline giving the full list); prompts an agent character
could not answer (choices, what it took, a number prompt's kind, a prompt the
step answered left out); sounds in hearing range with their offset and volume,
footsteps only when asked, `sound_since` and deafness; queued `repeat` and
`until` steps and their bounds; `expect_name` on a target.

Not covered: the client-side `wait_s` polling (offline suite) and sounds from
other z-levels.
