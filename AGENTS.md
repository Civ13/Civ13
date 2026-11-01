# Civ13 - Agent guide

<!-- 2026-10-28: short always-on guidance and scoped references -->
State a one-sentence stopping rule for each task. Follow [Completing a PR task](CODEX.md)
for findings, verification, committing/pushing, the dated PR update and CI checks.
Keep subsystem notes in the scoped READMEs below; read the relevant entries only
when that area is touched, rather than loading every guide for every task.

## Build, test and conventions

- DM sources enter through `civ13.dme`. The canonical BYOND pin is in
  `tools/byond/version.json`; code, dependencies and active tests target that pin.
- Once the pin advances, older-engine compatibility is not required. Retire
  obsolete version-specific modes/tests and port valuable behavior regressions
  to the current pin. Keep old evidence labelled historical; do not use floating
  latest downloads or silently skip failed current-pin validation.
- Compile before focused tests: Windows console `dm.exe civ13.dme`; Linux
  `DreamMaker -max_errors 0 civ13.dme`. Use the matching existing test runner
  and its README for the touched area. Report exact commands and results.
- Documentation-only changes need focused documentation checks; compilation
  and gameplay checks are not applicable. CI selection in
  [docs/ci-selection.md](docs/ci-selection.md) also skips docs-only compilation.
- Lint with `dreamchecker.exe` when relevant; config is `SpacemanDMM.toml`.
  Keep existing formatting, use "-" instead of em dashes, and preserve unrelated work.
- `_compile_options.dm` controls test/debug flags. Compiled outputs, logs and
  runtime `data/` stay out of source commits. Reuse existing art; use graphic
  tools for new art rather than image generation.
- On Windows use a verified full Python executable or working `py -3`, never
  the Store alias. In Git Bash, use relative or drive-letter paths.

## Live-server and security boundary

Source PR work does not authorize merging, deployment, live-server restarts,
save/import operations, feature activation, credential changes or security-setting
changes. Honor any authorization already given. DreamDaemon runs use `-trusted`
with maintainer authorization and the existing isolated runner's controls.
Keep operational restrictions distinct from missing evidence: unverified native,
in-game, graphical and save/load items go in the report and never block a source fix.

## Scoped reading index

Paths and test families select the relevant guide; a task spanning areas reads
the matching entries in each. These files are references, not automatic includes.

| Touched area / paths | Read when relevant |
| --- | --- |
| Toolchain, `tools/byond/`, `.github/`, CI scripts, repository conventions | [Toolchain and CI](docs/agent-guides/toolchain-ci/README.md) |
| `maps/`, map metadata/level admission, lobby/spawning, Backrooms/extraction instances | [Maps and instances](docs/agent-guides/maps-instances/README.md) |
| `code/modules/persistence/`, serialization, zones, recovery, runtime exclusions | [Persistence](docs/agent-guides/persistence/README.md) |
| Lighting, area changes, building appearance, footwear masks, floor decals | [Lighting](docs/agent-guides/lighting/README.md) |
| Human movement/pulling, combat, HUD hover, vehicles/trains/conveyors, wait contexts | [Movement and combat](docs/agent-guides/movement-combat/README.md) |
| Crafting/atlas, resources/mining, chemistry, farming production, food, medicine, power | [Crafting and resources](docs/agent-guides/crafting-resources/README.md) |
| Seasons/weather/snow, ecology, plant growth, decay, population readiness | [Environment](docs/agent-guides/environment/README.md) |
| GC/pooling, scheduler/process lists, ownership and memory benchmarks | [Runtime and memory](docs/agent-guides/runtime-memory/README.md) |
| Player Help, retrieval, conversation/spool format | [Player Help](docs/agent-guides/player-help/README.md) |
| `tools/opendream-client/`, discovery, launcher/updater/native shutdown | [Launcher](docs/agent-guides/launcher/README.md) |
| `icons/`, DMI metadata and sprite audits | [Sprites](docs/agent-guides/sprites/README.md) |
| Isolated native fixtures, ports, game-evidence bundles, graphical acceptance | [Verification](docs/agent-guides/verification/README.md) |
| MCP/debug/variable readers, bots, watchdog, YouTube, changelogs/API publication | [Operations and integrations](docs/agent-guides/operations-integrations/README.md) |
