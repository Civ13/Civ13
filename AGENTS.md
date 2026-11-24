# Civ13 - Agent guide

These rules apply to every task. Step-by-step procedures live in the skills
listed below; subsystem notes live in the scoped guides at the end. Read a
skill or guide when its trigger matches, not for every task.

## Every task

- Start with one sentence naming the task's scope, deliverable and stopping
  point, and respect any narrower or broader authority the user gave.
- A source task is done when the change is committed and pushed, local checks
  ran and are reported, a dated PR comment is posted and CI on the new head is
  checked. Analysis alone is not done; fix a valid in-scope issue in the same
  turn. Follow `civ13-pr-completion`.
- One owner per branch/PR for edits, pushes and CI follow-up. Inspect the
  checkout, branch and existing ownership before editing, preserve unrelated
  work, and use a separate checkout when another worker owns the branch.
- Ask the user only for decisions that are theirs: merging, deploying,
  restarting servers, changing scope. Pushing to your assigned PR branch needs
  no approval. Finish independent authorized work before raising a blocker,
  and ask one question with a recommended answer.
- Verification order: compile, focused tests for the touched area,
  `python3 scripts/agent_preflight.py all --write`, then push. Report exact
  commands and results. Unverified native, in-game, graphical or save/load
  behavior is a report note, never a reason to block a source fix.

## Build, test and conventions

- DM sources enter through `civ13.dme`. The BYOND pin is
  `tools/byond/version.json`; code, dependencies and active tests target it.
  Once the pin advances, older-engine compatibility is not required: retire
  obsolete version-specific modes/tests, port valuable regressions to the
  current pin, keep old evidence labelled historical, never use floating
  latest downloads or silently skip a failed current-pin validation.
- Compile: Windows console `dm.exe civ13.dme`; Linux
  `DreamMaker -max_errors 0 civ13.dme`. Before the first source or config push
  follow `civ13-pr-preflight`.
- Documentation-only changes need focused documentation checks; compilation
  and gameplay checks are not applicable ([CI selection](docs/ci-selection.md)).
- Include order must not matter (the Dream Maker IDE re-sorts `civ13.dme`). A
  define used by another file or tested with `#if`/`#ifdef` goes in
  `code/__defines/`; file-local defines are `#undef`'d at the end of their
  file. Extend a proc through a hook the base proc calls, never a same-type
  override in another file.
- The world's global initialiser is at BYOND's proc size limit: never add an
  eagerly initialised global list. Follow `civ13-global-init-limit`.
- Lint with `dreamchecker` when relevant (`SpacemanDMM.toml`). Keep existing
  formatting, use "-" instead of em dashes, and preserve unrelated work.
- `_compile_options.dm` controls test/debug flags. Compiled outputs, logs and
  runtime `data/` stay out of commits.
- Art, sprites, animations and UI layout follow `civ13-art-and-ui`: reuse
  existing art, never image generation.
- On Windows use a verified full Python executable or working `py -3`, never
  the Store alias. In Git Bash, use relative or drive-letter paths.

## Live-server and security boundary

Source PR work does not authorize merging, deployment, live-server restarts,
save/import operations, feature activation, credential changes or
security-setting changes; honor authorization already given and keep existing
action-time confirmations. Servers and bots the launcher manages start and
stop only through it, never ad-hoc scripts. DreamDaemon runs use `-trusted`
with maintainer authorization and the existing isolated runner's controls.
Keep operational restrictions distinct from missing evidence. Follow
`civ13-server-ops` before any server work.

## Skills

| Skill | Use when |
| --- | --- |
| `civ13-pr-preflight` | Before the first push of any source or config change, and whenever CI goes red |
| `civ13-pr-completion` | Opening, updating or finishing a PR: findings triage, PR comments, CI follow-up, handoffs and blockers |
| `civ13-merge-and-changelog` | Writing a PR's `Changelog:` line, merging, and the post-merge wiki, atlas, roadmap and master-CI follow-ups |
| `civ13-wiki-and-help-pins` | Editing civ13-wiki guides or the in-game Help pins |
| `civ13-tests-and-probes` | Writing or running offline tests, native probes or fixtures |
| `civ13-compile-skill` | Diagnosing compile errors in isolated BYOND fixtures |
| `civ13-global-init-limit` | Adding global or static variables, or "Procedure is too large" |
| `civ13-art-and-ui` | Any sprite, icon, animation, visual or UI layout change |
| `civ13-map-renders` | Any `.dmm` change or map rotation change |
| `civ13-server-ops` | Launcher, server, bot or deployment work |
| `github-workflow-troubleshooting` | Ambiguous PR, branch, permission or Actions state |

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
