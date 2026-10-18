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
evidence only. The fixture contains 33 actual DM assertions, all unexecuted.

## Corrected proposed native packet (not run)

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

| Case | Intended result, pending native observation |
| --- | --- |
| `fixed` | All authored DM assertions pass; initialized counts 0, 1, 2 |
| `eager`, `-params eager=1` | Same semantics pass; initialized counts 128, 128, 128 |
| `eager`, no params | Reject `bare turf allocation count`, proving the zero-allocation assertion detects eager initialization |
| `missing-lazy` | Reject `first decal records key` if native null-union behavior loses the list; actual causal outcome must be inspected |
| `shared` | Reject `two turf lists have independent identity` |

`eager` restores the exact old `= list()` declaration while retaining the new
writer guard for explicit-null migration tests. It is an eager-default comparison,
not a claim of executing every byte of the historical program. All other controls
alter only their named allocation line(s). Assertions stop at first failure to
avoid invented downstream oracles. No control is accepted until actual native
output proves its target failure without an engine diagnostic. In particular,
if native `|=` creates a usable list from null, the omission is not causal and
must be reported or revised; it must never be counted as caught automatically.

The prepared fixture uses the real `BuildVarDirectory`/`Load_Entry` and closes and
reopens actual temporary `.sav` files. It is an entry roundtrip with isolated
constructor/lighting/reboot adapters, not a full world save, ordinary game
construction, seasonal transition, screenshot or deployment acceptance.

`run-contained.py` is the proposed Windows executor. It requires an exact hashed
packet and separate time-bounded single-use grant, then owns every compiler and
daemon through retained native handles and a suspended-before-assignment Windows
Job. The byte-identical `windows.py`/`guard_config.py` adapters are reused from
accepted Help packet `contained-7e35bcec-v9` (adapter SHA-256
`f4ed282efd63a1bcad135878ad0a861c69793d9c0c58ba8300f1778d16e68b0d`,
config `ee5db97cabe3bcb2d8acb6660d67bbb56ee1f82052f96da00d54b13756615d35`).
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

## CI selection proposal (not installed or dispatched)

Keep this separate from reserved-cell lighting. Register an offline step guarded
by extensive opt-in or introduced suite `tests/floor_decal_tracking`. It should
run `test_*.py`. Add a similarly guarded isolated native step only after the
bounded runner and actual control outcomes have been reviewed. Normal PR CI also
selects game compilation because production DM changes. Existing regressions
must remain opt-in; no broad suite, manual workflow, publication or deployment
is authorized by preparation. The current candidate intentionally does not edit
shared workflows or `AGENTS.md`; coordinate those paths before a later CI commit.
