# Lazy floor decal tracking

Source candidate starts at master `cc03b199128f8afed58713912c551ad7556e6bc4`.
The production change makes `floor_decal_cache_keys` nullable and allocates an
individual list immediately before the existing floor writer's union insertion.
The global `floor_decals` image cache is unchanged.

## Caller and compatibility audit

There are exactly three production references: the turf field declaration,
floor decal `initialize` writer, and seasonal reader in `roundstart_etc.dm`.
Cover decals return before the floor writer; non-floors never enter it. Native
iteration over null/empty is exercised by the prepared fixture, not assumed to
be a Python behavior. Duplicate keys and insertion order use the existing `|=`.
Every decorated turf owns its list; no shared mutable list is introduced.

Reset clears `decals` and updates the icon but historically retains tracking
keys. `make_plating` clears appearance and also retains keys; `make_grass` replaces
the turf. This patch preserves those semantics. Turf replacement creates a fresh
field value. No tracking registry or external reference to these per-turf lists
is added, and no destruction hook or explicit list purge is needed by this change.
The fixture checks fresh replacement state, not GC completion or native heap use.

Ordinary turf persistence uses `map_storage_saved_vars`, which does **not** include
this field. No new field is added to that allowlist, and no saver/loader edit is
made. Absent fields now keep the null default. If an explicit turf allowlist or a
historical entry includes the field, the existing real serializer must preserve
typed null/empty/populated lists and legacy absent, `**null`, `**emptylist` and raw
list values. Legacy empty lists remain valid, independently mutable lists; there
is no normalization hook, lossy migration or image reconstruction claim here.

## Offline checks and frozen packet

Use a verified Python interpreter:

```text
<python> -B -m unittest discover -s tests/floor_decal_tracking -p test_*.py -v
<python> -B tests/floor_decal_tracking/prepare.py --output <new-packet-directory>
```

Preparation copies the actual decal prefix, exact seasonal read block, actual
plating/grass cleanup procedures, standard world-save fixture adapters, complete
production persistence dependencies, fixture and DMI resources into four hashed
cases. Extracted bodies retain their production statements; only the seasonal
block's enclosing function/indentation changes. It never launches a process.
It refuses changed extraction anchors or overwriting an existing packet.

The 16x8x1 native fixture has 128 initially bare turfs. It counts actual initialized
tracking fields and distinct native list identities at fixed checkpoints. Those
are retained initialized-list counts, not cumulative allocation telemetry, bytes,
RAM, peak memory or OOM evidence. Comparable before/after process profiling is
still required for any memory-size or world-load performance claim.

`test_oracles.py` uses synthetic logs to reject incomplete assertions, incorrect
allocation/list-identity counts and false control passes. Its success is parser
evidence only. The fixture contains 33 actual DM assertions. Both fixed and
eager-parity cases passed all 33 in `contained-v7`.

## Native packet history and remaining controls

The first native attempt (`contained-v2`, head `3ad4e0fb5`) stopped at compilation:
`decal.dm:13:error: anchored: undefined var`. No runtime assertions ran; owned
cleanup and the pinned daemon census passed. The corrected fixture declares
`/atom/movable/var/anchored = FALSE`, matching `code/game/atoms_movable.dm`.
This supplies an omitted isolated dependency; the production patch is unchanged.
The failed packet, logs and spent single-use marker remain preserved.

The corrected `contained-v3` compiler reported zero errors and warnings, then
stopped at the terminal Job gate: retained compiler exit 0, Job active count 1.
Cleanup and the pinned daemon census passed; no runtime assertions ran.
The cause is unproven. The next packet records a bounded 32-entry
[`JOBOBJECT_BASIC_PROCESS_ID_LIST`](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_process_id_list)
snapshot for every sample and terminal observation. During execution only the
retained child PID may appear. After its exit the list must be empty; accounting
may drain for at most two seconds within the original phase/aggregate wall and
CPU limits. All Job, watcher, output and termination checks remain enforced.
Acceptance requires both empty membership and active count zero. Immediate exit
and settled observations are retained separately. Unexpected PIDs, truncated
queries, persistent accounting or resource failures abort without a retry.
Mocked drain tests exercise these guards; they do not establish the native cause.

`contained-v4` stopped at its first compiler sample with actual Job PIDs
173080 (retained compiler) and 239248 (unidentified). Accounting reported two
active processes. No compilation or runtime phase was accepted. The owned Job
was terminated/closed and the retained compiler exited; the second process had
no retained handle, so its identity and separate exit were not independently
attested. The existing daemon's pre/post identity census was unchanged.

The next `--compiler-diagnostic` packet executes only the fixed compiler, with
60-second wall/30-second CPU/1-GiB private limits and at most 90 seconds aggregate
(80 work plus 10 cleanup). On an unexpected Job PID it attempts a read-only
query/synchronize handle to that exact PID, verifies exact owned-Job membership
before and after identity/exit observations, retains confirmed owned handles
for cleanup waits, then aborts. Missing/raced identity remains unavailable.
No command lines, global process lookup, arbitrary termination or launch-flag
changes are used. Daemon and behavioral cases are excluded from this packet.

The `contained-v5` compiler diagnostic verified a live owned
`C:/WINDOWS/System32/conhost.exe` member through a retained handle, then stopped
on the strict unexpected-member gate. Both compiler and console-host handles
confirmed exit during owned cleanup. This identifies only that run's member;
the v4 PID remains unidentified. No behavioral assertions ran in v5.

The next five-case packet replaces `CREATE_NO_WINDOW` with `DETACHED_PROCESS`,
keeping suspended creation, Unicode environment, extended startup information,
hidden startup settings and the explicit standard-handle allowlist. See the
[Windows process creation flags](https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags).
This aims to avoid creating a console host; it does not permit extra Job members.
There is no visible-console alternative or automatic flag fallback. Compiler
logs and all process/resource guards remain mandatory.
Job PID-list counts use explicit 32-bit integers, preserving the Win32 DWORD
layout when pure offline checks run on Linux. The pointer-sized PID array keeps
the host pointer width; tests assert the exact eight-byte counts header.

After a separate native allocation, use pinned BYOND 516.1681, temporary packet
storage, no normal game startup and serial runs. Proposed limits: each compiler
60 seconds, each daemon 15 seconds, complete packet 240 seconds including cleanup.
Capture compiler/daemon logs, exact process identities, exit statuses and source
manifest; terminate only owned processes on timeout. Reject compiler warnings,
runtime/engine diagnostics, incomplete assertion counts or unexpected failures.
The fixture rejects clients, closes its startup port and refuses reopening.
Use relative `runtime.log` inside each isolated case; Linux safe-mode log paths
must be relative. Do not use any live host, Topic, UI, SQL or existing save.

Planned serial cases:

| Case | Result or remaining target |
| --- | --- |
| `fixed` | v7 passed 33 assertions; initialized counts 0, 1, 2 |
| `eager`, `-params eager=1` | v7 passed 33 assertions; initialized counts 128, 128, 128 |
| `eager`, no params | v7 rejected `bare turf allocation count` as intended |
| `missing-lazy` | v8 accepted the exact first-union exception below with sole initial 0/0 metric |
| `shared` | v8 rejected `two turf lists have independent identity` with matching caught assertion |

`eager` restores the exact old `= list()` declaration while retaining the new
writer guard for explicit-null migration tests. It is an eager-default comparison,
not a claim of executing every byte of the historical program. All other controls
alter only their named allocation line(s). Assertions stop at first failure to
avoid invented downstream oracles. No control is accepted until actual native
output proves its target failure without an engine diagnostic. Removing the
guard in v7 produced exactly `FAIL exception: type mismatch: 0 |= "255--2-corner_white-2.2"`
after the sole initial metric `TRACKING initialized_turfs=0 distinct_native_lists=0`.
The old oracle rejected that result; v7 remains recorded as stopped, not passed.
Only the missing-lazy profile may accept that exact exception, with that exact
failure list and initial metric, no PASS claim and no diagnostic. Offline tests
reject wrong exception/key, extra failures, extra metrics and false PASS output.

The v7 invocation completed eight phases in 7.016 seconds, then stopped at the
missing-lazy oracle. Retained owned handles confirmed exit, terminal Job membership
was empty and the existing-daemon identity census was unchanged. The shared case
did not run. The `--remaining-controls` successor runs missing-lazy and shared only,
within 180 seconds aggregate (170 work plus 10 cleanup), retaining the same phase
limits. Fixed/eager evidence is reused because those production and probe sources
are unchanged. The single v8 invocation at head `e5ee60c15` accepted both causal
controls in 2.469 seconds including cleanup. All four phases exited zero, terminal
Job membership was empty and active counts were zero. Both owned cleanups confirmed
all retained handles exited without errors; six census observations preserved the
existing daemon's identity. Original v7 failure evidence remains unchanged.
Native evidence is Windows-only and uses isolated startup adapters. Engine startup
logs contain account-login text; sampled socket checks establish only their bounded
observations, not absence of every possible outbound connection.

The prepared fixture uses the real `BuildVarDirectory`/`Load_Entry` and closes and
reopens actual temporary `.sav` files. It is an entry roundtrip with isolated
constructor/lighting/reboot adapters, not a full world save, ordinary game
construction, seasonal transition, screenshot or deployment acceptance.

`run-contained.py` is the proposed Windows executor. It requires an exact hashed
packet and separate time-bounded single-use grant, then owns every compiler and
daemon through retained native handles and a suspended-before-assignment Windows
Job. The `windows.py`/`guard_config.py` adapters originate from
accepted Help packet `contained-7e35bcec-v9` (adapter SHA-256
`f4ed282efd63a1bcad135878ad0a861c69793d9c0c58ba8300f1778d16e68b0d`,
config `ee5db97cabe3bcb2d8acb6660d67bbb56ee1f82052f96da00d54b13756615d35`).
The local Windows adapter skips closing null thread handles for query-only
retained handles and uses `DETACHED_PROCESS` in place of `CREATE_NO_WINDOW`.
The original adapter hash above describes its origin; each packet binds the
actual corrected adapter hash separately. `guard_config.py` is unchanged.
There is no host free-memory admission. Each Job permits one process, kill-on-close,
1 GiB compiler or 512 MiB daemon private memory, with a 128 MiB watcher bound.
Compiler evidence uses byte-identical accepted `z_budget_evidence.py`, SHA-256
`133c130845ab28cfb6f0bfb8b2c63b595d3694afc44a3af398cb1fdf3de584db`.
It requires one exact pinned banner, one clean result for `probe.dmb`, correct
ordering and no diagnostics. Runtime logs are capped at 1 MiB before reading.
Owned sockets permit TCP only: the loopback listener on 59474 before the fixture
closure marker, and states 5 through 12 with both endpoints exactly 127.0.0.1
and integer ports 1 through 65535. After closure, no listener is allowed.
A read-only process census before each phase and after owned cleanup requires
the sole existing daemon PID 161088, creation FILETIME 134368205457714990 and the
pinned daemon image path. This checks process identity only; no Topic, status,
RSC inspection or host control occurs. An altered baseline requires review.
The aggregate 240-second allowance may stop before all worst-case phases finish;
there is no automatic extension, retry or fallback.
Output is retained; the executor deletes no fixture or unrelated files.

## CI selection

The evidence-checker has one offline `test_*.py` step guarded by extensive opt-in
or introduced suite `tests/floor_decal_tracking`. Normal PR CI also selects game
compilation because production DM changes. No Linux native step was added; local
Windows native results do not establish Linux execution. CI selection and policy
tests pass locally. Automatic exact-head PR CI remains pending publication.
Reserved-cell lighting and other shared workflow behavior are unchanged.
