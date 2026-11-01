# Toolchain ci: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-24: target BYOND version and historical fixture boundary -->
tools/byond/version.json pins target 516.1688 and observed official HTTPS archive
bytes; it is embedded directly into source launcher 1.0.8 and consumed by the
default compiler bootstrap/receipts and WSL setup. This does not establish native
compatibility or publish the launcher. Compiler admission is the exact canonical
pin; savefile major remains 516. Older-engine compatibility is not required after
a pin advances. Retire obsolete modes and port valuable behavior regressions to
the current pin; retain old receipts and hashes as labelled historical evidence.
The canonical bootstrap rejects retired legacy flags. Component/train Linux
manual profiles use that bootstrap and shared archive/member identity before
each compiler/daemon launch; workflow_dispatch admission remains unchanged.
Their source port is not native acceptance. Other strict old-version harnesses
remain migration/retirement debt; do not relabel old results or silently skip
failed current-pin validation.
Windows fixture callers must inject a reviewed current-pin facade; the shared
runner refuses the old implicit floor-decal binding. See docs/byond-5161688.md.
Active hosted compilation explicitly selects the user-approved Civ13/Civ13
repository-release asset pinned in the Linux manifest. Only its exact public URL
may redirect once to its reviewed release-assets.githubusercontent.com path;
no credentials, signed-query receipts, source fallback or broad redirect rule.
Official/community choices retain NoRedirect. Only the versioned archive and
acquisition metadata are cached by OS/version/hash; each hit verifies every byte
before fresh extraction and actual compilation. Preserve original cache-origin
provenance, fail closed on corrupt caches, and require exact-source receipts.
BYOND cache prereleases are excluded from launcher publication by both the
workflow and release planner; this archive route does not change the stable feed.

## Language & toolchain
Never use an em dash; use "-" instead.
- **DM** (DreamMaker) - BYOND's proprietary language. Sources have `.dm` extension.
- **Entry point**: `civ13.dme` - the DM Environment file.
- **Build**: `dm civ13.dme` (Windows) or `DreamMaker civ13.dme` (Linux). Outputs `civ13.dmb` + `civ13.rsc`.
- **Lint**: `./dreamchecker.exe` (SpacemanDMM static analyzer). Config in `SpacemanDMM.toml` (sets `dreamchecker = true` for the langserver).
- **Target BYOND version**: exactly 516.1688 from `tools/byond/version.json`; compiler admission must match that pin. No `.vscode/tasks.json` is tracked at this base.
- **CI** (`.github/workflows/test.yml`): the default Ubuntu compiler bootstrap targets the manifest version, runs `DreamMaker -max_errors 0 civ13.dme`, and requires the exact version banner plus zero errors/warnings. Exact-head hosted 516.1688 acceptance is pending. The separate evidence-checker and MCP protocol workflows do not establish gameplay or rendering.

## Code structure

| Path | Purpose |
|---|---|
| `code/` | Core game code: atoms, mobs, objects, turfs, helpers, defines |
| `code/__defines/` | Global constants, macros, flags |
| `code/modules/1713/` | Bulk of Civ13-specific content (apparel, jobs, weapons, vehicles, sieges, etc.) |
| `code/modules/admin/` | Admin tools and verbs |
| `maps/` | Map (`.dmm`) files organized by era (e.g. `maps/5000bc/`, `maps/1913/`, `maps/nomads/`) |
| `config/` | Server configuration (`config.txt`, `admin_ranks.txt`, `host.txt`) |
| `scripts/` | Linux deployment scripts (`launch.py`, `updateserver.py`) |
| `UI/` | HTML/CSS interface files |
| `icons/` | Game sprites (`.dmi` files) |
| `sound/` | Audio assets |
| `SQL/` | Database integration (Discord bot OOC bridge via file polling) |

## VSCode integration (`.vscode/tasks.json`)

Available tasks:
- **`dm civ13.dme`** - build the project (default build task)
- **`DreamChecker`** - run static analysis
- **`OpenDream Build`** - historical local task; any future equivalent must target the canonical manifest version.
- **`Build and Check`** - sequential: build then lint

## OpenDream

An experimental open-source BYOND reimplementation. `.vscode/launch.json` has an "OpenDream: Build & Run" configuration using `DMCompiler.exe` and `Robust.Server.exe`. The JSON output is `civ13.json`.

## Conventions

- `#define DEBUG` is set in `civ13.dme` (enables custom error handler).
- `_compile_options.dm` controls TESTING, UNIT_TESTS, REFERENCE_TRACKING, etc. - uncomment as needed.
- `.gitignore` excludes compiled outputs (`*.dmb`, `*.rsc`), log files, `data/`, `SQL/`, `dreamchecker.exe`, `civ13.json`, `TODO.md`.

## Agent self-maintenance

The root AGENTS.md is read at session start; these notes load only for the
area being changed. If you discover useful subsystem guidance, **update the
matching scoped README**, keeping the root guide short.
Good candidates for additions:

- Gotchas that caused you to waste time (type mismatches, missing procs, naming
  conventions that differ from what you'd expect).
- Workarounds you had to apply and why (e.g. "lerp is reserved, use mix_value").
- Runtime truths: things that compile fine but break at runtime (empty lists
  passed to pick(), world-scan performance, list modification during iteration).
- File locations for subsystems you explored (process schedulers, global singletons,
  landmark systems, etc.).
- Anything you learned from CI failures or compiler warnings that isn't obvious.

When adding, keep it concise and put it under the most relevant existing section.
If nothing fits, create a new section. Prefix your additions with the date and
a brief tag so others can tell when and why it was added (e.g. `<!-- 2026-06-10: subcom audit -->`).

<!-- 2026-10-13: unsupported OpenDream shell work -->
OpenDream TTS returns before scheduling shell-backed audio jobs; native TTS
remains available. Python control uses mutually exclusive engine branches.
tests/opendream_shell runs both production branches with counted external-effect
adapters and omission controls, without launching OpenDream or real scripts.

<!-- 2026-10-12: opt-in regression CI -->
<!-- 2026-10-24: bounded offline CI baseline and exact-source receipts -->
CI always runs selector-policy, stubbed bootstrap and serializer-source tests.
scripts/ci_baseline.py registers exact reviewed offline files and bounded impact
paths for research/ping scheduling, persistence-year projections and synthetic
evidence validation. Affected production, existing-test and helper edits select
those files; unknown impact or missing comparisons explicitly selects the whole
small offline registry. Do not add broad Python discovery or native launchers to
this registry without inspecting imports, subprocesses, dependencies and cost.
Other existing regressions retain manual opt-in and introduced-test admission;
ordinary edits do not expand native/costly admission. Register those suite guards
through ci-selection.yml. Preserve all separate execution/resource holds.

CI required aggregate requires successful selected jobs and exact head/base,
run/attempt and selection-bound offline/compile receipts. Missing, failed,
unexpectedly skipped or empty required execution fails. Documentation-only
compilation is an explicit skip, never compiler acceptance. Inspect ci-* artifacts
and docs/ci-selection.md; a job-level green alone does not describe what ran.
<!-- 2026-10-24: event coverage and check identity -->
PR text edits requesting `build:` evaluate compilation but keep native admission
off. Recognized unforced title/description edits skip duplicate builds while
the separate changelog workflow validates PR descriptions. Edited/other-base PRs,
feature pushes and manual runs use the
informational build/aggregate names even when a real compile passes. Only ordinary
opened/synchronize/reopened PR scopes and master pushes retain gating names.
Base retargets fail the required context until an ordinary PR run can validate
the new base; unrecognized edit metadata also fails closed.
Selector failures or missing outputs retain failed gating names. Inspect receipt
action and compile/native/gating reasons; an informational success cannot certify
omitted native coverage. Preserve existing native opt-ins and toolchain ownership.
Hosted DreamMaker results must identify the actually executed manifest version;
Python projections, compiled core_boot variants and native runtime/gameplay
acceptance are separate evidence. Historical 516.1681 runs do not verify 1688.
<!-- 2026-10-28: re-run of failed jobs -->
CI receipt consumers download ci-selection/baseline/compile by the producing
job's `attempt` output: a re-run of failed jobs reuses earlier jobs whose
artifacts keep their original attempt. Receipts record `job_attempt`; keep the
attempt ordering checks in scripts/ci_baseline.py when changing these jobs.
Cloud-only workers must keep unavailable local native checks as not_run. After
committing and pushing to the assigned PR branch, obtain hosted validation for the current head
and inspect its outcomes/artifacts; never substitute local tool absence or an
older green run. This policy does not authorize installing native tools, running
held probes, deployment, release publication, branch-protection changes or merging.

<!-- 2026-10-12: official DM reference -->
`dm_reference_search` and `dm_reference_read` fetch only the official BYOND manual
over HTTPS, with bounded downloads, cancellation and a temporary in-memory cache.
Returned source hashes identify reference content, not compiler compatibility;
the live manual can describe features newer than the canonical manifest pin.

<!-- 2026-10-11: documentation-only CI selection -->
Admitted ci-selection.yml runs select compilation conservatively and skip it for documentation-only changes unless requested. Extensive runtime suites require CI workflow_dispatch with extensive_regressions enabled; train tests are workflow_dispatch-only. Skips do not prove gameplay; see docs/ci-selection.md.

<!-- 2026-10-19: injected Windows adapter CI -->
The bounded-build test suite runs without Windows DLLs. Inject ctypes error
state too: get_last_error does not exist on Linux. CI explicitly recognizes the
two added bounded-build tests; passing them is not native containment evidence.
