# Tanning validation: source proposal, not executed

The parent clarified that the no-BYOND instruction is a **preparation gate pending
review**, not an indefinite external resource hold. No current external hold,
owner or lease denial has been established. Historical compiler/CPU records do
not create one. This proposal adds no approval-file protocol or new approval
layer. Source work continues; native execution awaits the requested parent review.

## Four local native launches

The new Windows driver `tests/animal_harvest/validate_tanning.py` runs both existing
fixtures in the same Python process, under one bounded Session:

| Order | Exact native payload | Why it is needed | Phase wall/CPU ceiling |
| --- | --- | --- | --- |
| 1 | `dm.exe -max_errors 0 probe.dme` in the retained Atlas directory | Compile the actual renderer and generated 10,214-record catalog adapter | 120 s |
| 2 | `dd.exe probe.dmb -invisible -close -ip 127.0.0.1 -nowebclient -trusted -log runtime.log` | Execute full-catalog rendering, tanning/rack research links, turkey search, tannin acquisition and no-direct-leather assertions | 30 s |
| 3 | `dm.exe -max_errors 0 <isolated-worktree>/.animal_harvest_ci.dme` | Compile full production types/resources with map includes and normal startup removed | 120 s |
| 4 | `dd.exe <retained-harvest-directory>/.animal_harvest_ci.dmb -invisible -close -ip 127.0.0.1 -nowebclient -trusted -params tested_commit=<reviewed-head> -log runtime.log` | Execute the 8×8×1 production harvesting/tanning, cancellation, stack/reagent accounting, rack lifecycle, synthetic save/load and turkey anatomy fixture | 60 s |

There is one native child at a time, four native launches total, no DreamSeeker,
no player clients, and no live Gaia paths or saves. Git identity/cleanliness checks
are short read-only subprocesses before/around staging; they are not additional
BYOND launches. Compile-only or negative-control variants are outside this initial
four-launch proposal. A failed phase stops the sequence with no retry/fallback.

After review, from the isolated feature worktree, the single driver command is:

```powershell
& 'C:\Users\valza\AppData\Local\Programs\Python\Python312\python.exe' -B tests/animal_harvest/validate_tanning.py --expected-commit '<exact-reviewed-40-character-head>' --byond-bin 'C:\Users\valza\.codex\cache\byond\516.1681\byond\bin' --output '<new-isolated-evidence-directory>'
```

`--expected-commit` checks source identity, not permission. The output directory
must be new. The final task handoff supplies the immutable source head and SHA-256
manifest. The fixed existing adapter executable hashes pin Windows BYOND 516.1681.
No version probe, native interop test, compiler or daemon was executed in preparing
this proposal.

## Containment implementation

`scripts/native_fixture.py` reuses the **unchanged** launch code and Win32 types in
`tests/floor_decal_tracking/windows.py`, whose README records successful native
fixture history. It does not reuse that runner's earlier terminal accounting
acceptance. It imports no native libraries until the runner explicitly constructs
the native backend. Offline tests inject inert adapters and fake API functions.

Each phase gets a fresh unnamed Job. The existing launch creates the root
detached, hidden and suspended, with only explicit stdio handles inherited. It
assigns/verifies Job membership and records image/creation identity before resume.
Assignment failure terminates only the newly created suspended root. No process
is attached or killed by executable name. No breakaway or visible-console fallback
is permitted.

The new limits combine kill-on-close, one active process, hard process/Job commit
caps of **1,920 MiB**, and a kernel Job user-CPU ceiling matching the phase timeout.
The watcher gets a **128 MiB** reserve, keeping the sampled combined budget within
**2 GiB**, with **6 GiB** host free physical memory required before launch and at
each sample. Limits are queried back while running. These bounds follow the
[Windows Job limit contract](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_limit_information).
Memory is not yet measured for these fixtures at this head; resource failure is
inconclusive validation, not permission to grow the budget automatically.

The Session stops work at **330 seconds**, reserves cleanup within **360 seconds**,
and enforces phase wall deadlines with a monotonic clock. It samples retained root
CPU/memory, watcher memory, host free memory, Job accounting, membership and sockets
at approximately 100 ms. Kernel Job CPU accounting is user-mode time; the sampled
root CPU includes kernel time too. Synchronous OS/filesystem calls can delay a
Python deadline observation; this is not a hard real-time wall-clock guarantee.

**Cumulative total processes must equal exactly one retained root throughout and
at terminal acceptance.** An empty Job is insufficient. A short-lived unretained
child whose lifetime falls between samples still raises the cumulative count and
fails acceptance. An observed unexpected member is captured through an exact-Job
query/synchronize handle for cleanup evidence and still fails the run. Missing
exit evidence remains incomplete; it is never represented as successful cleanup.

Cleanup terminates/closes only the owned Job, waits through every retained handle,
records exit identity/code, and checks every handle close. A timeout, rejected
observation, failed assignment, missing exit or close failure prevents another
phase. The receipt retains rejected observations and distinguishes retained exits
from complete owned-process accounting.

## Explicit port policy and its limits

Both fixtures call `OpenPort("none")` first in startup, override OpenPort to
delegate only `"none"`, and assert both `world.port == 0` and refusal of a numeric
open request. They write a bounded `port-closed.txt` marker. The launch explicitly
sets loopback IP and disables web clients. The supervisor rejects **any observed
TCP/UDP socket**, including during startup; it does not allow a temporary listener
until the marker appears. Inventory comes from the retained child's PID, invalidated
if its retained process handle exits, avoiding attribution after PID reuse.

[BYOND documents](https://www.byond.com/docs/ref/info.html#/world/proc/OpenPort)
that `OpenPort("none")` closes the port and that an override without `..()` refuses
opening. Its `-close` option exits DreamDaemon after world shutdown; it is not a
network-isolation flag. No undocumented `-port none` or `-ports 0` behavior is used.
The loopback CLI setting constrains an attempted initial bind, rather than proving
that no bind occurred.

**Neither the startup marker nor sampled socket inventory proves there was no
transient listener between samples.** That remains an explicit native acceptance
limit; there is no continuous socket audit or OS network sandbox claim. These
checks also do not prove absence of every possible outbound operation.

## Evidence, output and saves

The shared Session retains argv, working directory, pinned source head, process
image/creation identities, accounting/memory/socket samples, phase exits and cleanup
in `containment.json`. The driver retains input/toolchain SHA-256s in `inputs.json`.
Both runner logs and compiled files remain in the new evidence directory; Atlas
no longer destroys its only diagnostic directory on exit.

Before reads, logs and marker files have explicit size limits. Each phase's
generated text/state is sampled against **16 MiB**; compiled artifacts are sampled
against **1 GiB per file**. These are monitored size ceilings, not filesystem hard
quotas or a claim that no disk-write overshoot can occur between samples. Reparse
paths in evidence fail inspection. The Session receipt itself is capped at 4 MiB.

The harvest runner removes only its four newly generated source/build files from
the isolated worktree. It refuses pre-existing probe files. Runtime evidence,
copied binaries and synthetic `*.sav` files remain retained; **no saves are deleted**.
Do not use production saves, canonical configuration, live processes or restart
Gaia. Successful fixture execution would still leave actual-client interaction,
browser appearance, public mode reachability and production-save acceptance for
separate assessment where material uncertainty remains.

## Existing CI alternative — no workflow changes or dispatch performed

The existing `.github/workflows/test.yml` runs on **GitHub-hosted ubuntu-latest**,
not the desktop or Gaia. Its build job calls `scripts/travis_pre_byond.sh`, which
regenerates the source-only catalog and compiles normal `civ13.dme`, including its
maps, with BYOND 516.1681 and zero-warning enforcement. That supplies full-build
evidence beyond the map-free harvest fixture.

For an ordinary PR synchronization against master, `scripts/select-ci.py` selects
introduced executable test suites. The tanning PR introduces Python tests under
both `tests/animal_harvest` and `tests/crafting_atlas`, so the existing conditional
steps can execute production harvesting/tanning plus the Atlas export/rendering
suite. The latter already generates real sprite PNGs, runs its DOM checker, and
executes basic, full-catalog, pagination and four navigation-control fixtures.
This hosted route is broader than the four local native launches; it must not be
reported as that bounded local packet. Linux runners keep their existing subprocess
timeouts; this proposal does not claim Windows Job limits apply on Linux.

The current head deliberately retains `[skip ci]`. A later reviewed normal PR
synchronization with a non-skipped head can use the existing pipeline without
workflow edits. A `build:` title on an edited event requests compilation only and
does not select introduced native suites. `workflow_dispatch` with default inputs
also does not select those suites; `extensive_regressions=true` selects all suites
and is unnecessarily broad for this acceptance. No CI dispatch, skip removal,
workflow edit, merge or deployment has been performed here.

## Verification performed

The new injected supervisor suite covers hard-limit API configuration, retained
waits/checked closes, phase/aggregate deadlines, memory and socket rejection,
assignment/cleanup failure, launch-count bounds and cumulative short-lived-child
controls. It executes the four-phase driver with injected inert runners. Its
success is control-flow/API-argument evidence, **not native interop acceptance**.
