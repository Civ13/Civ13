# Verification: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-18: isolated fixture ports -->
`world.OpenPort(0)` opens an available port; `OpenPort("none")` closes it.
The Help fixture disables compile-time visibility, rejects clients and overrides
OpenPort to prevent reopening. These controls do not replace external socket monitoring.

<!-- 2026-10-11: repeatable game verification -->
## Game verification evidence

<!-- 2026-10-22: representative observer failure retention -->
Representative sampler and observer waits must recheck their existing monotonic
targets after early wakes. `tests/save_latency/representative` covers this offline.
Phase log/diagnostic retention runs after owned cleanup on failures too; secondary
retention errors preserve the original exception and never establish acceptance.

<!-- 2026-10-17: maintainer rules -->
- Art: reuse and transform existing art assets where possible. Never use image
  generation tools (Stable Diffusion and similar). New art made from scratch must
  use appropriate graphic tools such as vector-based graphics.
- DreamDaemon must always run as trusted (`-trusted`), with maintainer approval.
  All repository runners launch `-trusted`; never add `-safe`. Fixtures must still
  disable outbound hooks/shell effects through their startup adapters.

<!-- 2026-10-13: native catch variable scope -->
BYOND 516.1681 treats catch variable declarations as proc-scoped. Use distinct
names for separate catch blocks in one proc or compilation fails with duplicate definition.

<!-- 2026-10-19: opt-in physical human movement -->
The experimental human adapter keeps the living Move third gameplay flag and
uses one-use context at movable's native offset seam. Runtime ownership fields
need explicit custom-save exclusion. Owned capsule presence is detected before
loader assignments; no-capsule legacy humans retain their old offset policy.
The minimal world-save stub rejects owned capsules instead of faking restoration.
Use tests/human_subtile/run.py --prepare-only for offline exact-Git staging;
native integration and connected-client timing are separate acceptance gates.
DM reserves proc name run, and an if-local variable cannot be read afterward;
offline text contracts do not replace the pinned native compiler.

- Follow `docs/game-verification.md` for exact-commit build, isolated-fixture,
  graphical, season-memory, and save-round-trip evidence. Reuse probes present in
  the selected checkout; investigation-branch probes may not be on master yet.
- Game PRs need actual screenshots and reproduction steps, plus video when
  movement/timing requires it. Keep unavailable acceptance explicit. Current
  captures are internal testing material; no AI-generated art or mock evidence.
- Use `scripts/check-game-evidence.py` to validate existing bundles. Its success
  proves metadata/file consistency, not gameplay acceptance or OOM remediation.
  Tests live in `tests/test_game_evidence.py` and do not launch BYOND.
- Use temporary saves and external-effect adapters. Testing does not authorize
  production restarts, live season transitions/imports, or publishing captures.

<!-- 2026-10-11: observer reference bookkeeping -->
- Observer cleanup count lists retain their datum keys. Counts must reflect actual callbacks: duplicate global registrations do not increment them, and unregistering all callbacks subtracts their full count.
- `scripts/test-observer-memory.ps1 -ByondBin <BYOND-bin-directory>` runs complete production observer registration/cleanup code in an isolated fixture with temporary outputs and no game startup.
<!-- 2026-10-11: evidence harness review -->
Native BYOND world.Export returns the remote Topic value, and its caller address includes a port (127.0.0.1:port). Reject empty/non-JSON replies and authenticate the tested commit before reporting evidence success. PowerShell native Git failures need explicit LASTEXITCODE checks; ErrorActionPreference alone is insufficient. The isolated evidence launcher must verify daemon readiness and clean its unique temporary DME/DMB/RSC outputs.
<!-- 2026-10-14: local CID source comparison -->
`tools/cid/get-cid.ps1` calls the reviewed Windows BYOND 516.1681 library's
fingerprint/CRC routines in 32-bit PowerShell. Private offsets require its exact
documented library hash. `run-local.ps1` compares with a real local client's
`computer_id`; its negative control tests equality only, with no spoof detection.
<!-- 2026-10-12: native GC outcome triage -->
BYOND 516.1681 can clear a native `del(A)` argument when `Del()` aborts while
the target remains alive. Verify disappearance with the saved ref and retirement
identity, not a null local. `tests/gc_triage/run.py` checks production outcomes
and bounded opt-in owner-field inspection; outcome rows share deletion profiling's
128 named types plus overflow. `gc_forced_types` telemetry counts these bounded
forced-call buckets, not exact distinct types after saturation.

<!-- 2026-10-12: finite native probe completion -->
<!-- 2026-10-17: native fixture gotchas found unblocking #3197/#3199/#3082 -->
Native BYOND 516.1681 `OpenPort("none")` returns 0 even when it closes the port;
assert the resulting `port == 0` and a refused reopen, not the return value.
`new /atom` without a loc raises `bad loc`; use `/atom/movable` for atom-hook
coverage. `underlays`/`overlays` hold appearances, not `/image` datums, so
`for (var/image/I in D.underlays)` never matches; iterate untyped and read
`U:icon_state`. Headless HUD fixtures need `makeDatumRefLists()` (fills
`HUDdatums`) and an explicit `defaultHUD` (only `check_HUD()` sets it, for a
client). A runner's "failed outside its intended assertion" can mean an earlier,
equally valid assertion caught the mutation; `*_assert` procs report their own
throw line, not the caller's. GitHub job logs are readable via the GitHub MCP
`get_job_logs` when direct log downloads return 403.

Native del(world) does not immediately stop the current procedure. Accumulate
probe failures before emitting one final result, and return explicitly after
world disposal so failure paths cannot continue into a passing receipt.

<!-- 2026-10-15: native seed port contract -->
`world.OpenPort(0)` opens any available port; `world.OpenPort("none")` closes it.
Do not infer offline isolation from `-close`: verify the critical phase has port0
and an actual zero-listener OS census. The Gaia seed observer rejects reopening
and denies all seed clients; `tests/world_save/playable_reconnect/test_port.py`
checks its native516.1681 port contract separately from full recovery acceptance.
<!-- 2026-10-19: native bind versus host address -->
Linux BYOND world.address can report the host interface even with -ip 127.0.0.1.
Isolated exclusion CI verifies the engine's startup bind diagnostic plus closed
port/refused reopen state; do not use world.address as the socket-bind oracle.
