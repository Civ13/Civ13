---
name: civ13-tests-and-probes
description: Write and run Civ13 tests - offline source suites, native DreamDaemon probes on the pinned compiler, fixtures and game evidence - and register them with CI. Use when adding or changing a test, running a probe, or choosing what to run for a touched area.
---

# Tests and probes

## Choosing what to run

- Use the existing runner and README for the touched area (`tests/<area>/README.md`).
  `python3 scripts/agent_preflight.py pins` lists the tests and fixtures that
  name each changed file; `suites --affected` runs what CI maps to the diff.
- `agent_preflight.py all` does not run every workflow. After touching region
  travel, region homes or transfer tooling, also run
  `python3 -I -B tests/transfer_storage/run.py`.
- If a suite fails, rerun it on master before blaming your change.

## Writing offline tests

- Prefer focused behavior checks over whole-file equality or hashes.
- Tests must not depend on Git history (`git show <sha>`). Freeze any
  historical source a test needs as a checked-in fixture.
- Register a new suite in `scripts/ci_baseline.py` `SUITES` with its `files`,
  `paths` and the `shared_paths` it guards; append to master's order on conflicts.
- A valid review finding gets a test that fails without the fix.
- Retire tests for engine versions older than the pin; port valuable
  regressions to the current pin and keep old evidence labelled historical.

## Native probes

A probe is a `.dm` file compiled into the game without maps and run headless
on the pinned DreamDaemon (`-trusted`, as every repository runner does):

```bash
bash scripts/cloud_byond_setup.sh                     # once per container
python3 tests/ecology_spawning/run_linux.py . tests/<area>/probe.dm 300
```

- Keep the probe next to its offline tests and document the command in the
  area README (see `tests/accolades/README.md`).
- Probes add their own globals; `civ13-global-init-limit` keeps headroom for them.
- Fixtures disable outbound hooks and shell effects through their startup
  adapters, use temporary saves, and never touch live data.
- Isolated native fixtures, ports and graphical acceptance:
  [Verification guide](../../../docs/agent-guides/verification/README.md) and
  `docs/game-verification.md`. Compile errors inside fixtures: `civ13-compile-skill`.
- The weekly native sweep (`tests/native_sweep/manifest.json`) runs every
  `tests/**/run*.py`; a new runner that cannot run there goes in its skip list
  with a reason.

## Evidence

Unverified native, in-game, graphical or save/load behavior goes in the
report and never blocks a source fix. Screenshots when cheap; real captures
only, never mock or generated evidence.
