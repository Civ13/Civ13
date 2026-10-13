# Private snapshot mechanism and offline probe preparation

SOURCE ONLY, UNRUN. Parent source `93cc986780e3016bbdc6b5890b470fc6f9da2e94`.
Shared implementation and all local execution remain held. This plan selects the
**private immutable snapshot mechanism with demonstrated exclusive host ownership**
for further review. It does not claim that the necessary host primitive exists.
Retained foreign readers are not selected because no verified interface binds
them to native DM savefile consumers. No md5/sha1, file2text or Boolean/Lock
substitution closes that gap.

## Proposed dependency boundary

The host adapter must return a typed acquisition containing an opaque ownership
identity, acquisition epoch, exact selected generation, immutable manifest bytes,
and an ordered inventory of metadata and all closed version-2 level snapshots.
Each member has exact byte count, SHA-256, private snapshot path and member
identity. The native savefile loader receives only those private paths while
ownership remains valid. It must never reopen original source paths. Every
validation, metadata read, recursive decode and callback belongs to that same
acquisition. A level handle without member/operation identity is rejected.

Snapshot copying precedes ClearMap and includes manifest-declared files only.
Acquire exclusive host ownership before copying; verify size/digest and complete
inventory before returning. Read/copy/close/ownership errors abort and unwind
exactly the acquired members. Snapshot/source hashes from different read epochs
do not prove a consistent set. All buffers, member counts and aggregate byte
capacity require reviewed bounds before code; per-journal limits are not a
generation storage budget. No general directory scan or orphan adoption.

The host boundary must show how all relevant worlds, tools and backup/cleanup
writers are excluded, and how ownership loss prevents further mutation. Merely
creating a private directory, making a pathname read-only or holding an in-process
token is insufficient. No OS locking/ACL strategy has been implemented or tested.
The immutable snapshot remains pinned through restoration/census/admission or is
released only when a freshly acquired admission proof covers the ownership gap.

Proposed ABI names are contract labels, not installed exports: acquire_snapshot,
require_snapshot_member, open_level_member, hash_binary_member, release_snapshot.
Do not add call_ext bindings until the provider binary/version, argument/result
encoding, failure behavior and native savefile integration are reviewed. The
native implementation must preserve NUL/all byte values and count bytes, not
text units. Publication and account-domain CAS use separate reviewed contracts.

## Versioned offline reference source

`tests/extraction/test_generation_contract.py` uses only Python standard-library
temporary files and counted immutable byte copies. It never launches a process, loads a
native library, accesses production storage or claims host exclusion. It is a
reference oracle for expected outcomes, not the chosen production snapshot ABI.
All its assertions are authored, UNPARSED and UNRUN under the execution hold.

Prepared cases:

- Opaque A/B byte labels and replace/truncate/delete/rename injections at acquire,
  hash, validation and decode: consume pinned A or refuse before the modeled
  ClearMap boundary. The correct and intentionally reopening decoder use the same
  `PINNED_A_CONSUMPTION` assertion; the violating decoder must reach its named
  failure. These byte labels are not native valid version-2 saves.
- Partial acquisition failure tracks exact acquired/released member identities;
  mandatory metadata, level and manifest labels share one modeled acquisition.
  The frozen nonempty roster requires exact paths and all contiguous levels,
  rejects missing/extra members, caps members at 16 and checks aggregate declared
  and read-byte budgets before modeled ClearMap. Normal acquisition reads 4096-byte
  chunks, not whole-file read_bytes. The deliberately violating decoder retains
  read_bytes solely as its omission. Byte accounting is not measured resident
  memory: immutable joins/copies, Python objects and fixtures add overhead.
  Production whole-set storage/memory limits remain a separate reviewed gate.
  Captured digest/size records copy validated scalar fields into fresh immutable
  tuples. Caller list/dictionary mutation cannot update proof, roster or budget;
  a changed source file still rejects before modeled ClearMap. An additional
  source vector grows an actual temporary file after preflight and checks the
  counted-read capacity rejection. Both controls remain unrun.
- Explicit operation/member tokens capture an epoch and refuse wrong-operation
  reuse, ownership loss at each phase and post-release reuse. Loss before decode
  refuses before ClearMap; loss after modeled ClearMap refuses consumption and
  requires recovery. These tokens are model identities, not OS/host exclusion.
- SHA-256 parity for empty, NUL/all-byte data, 63/64/65 byte lengths, more than
  64 KiB and the 1 MiB oracle limit, with strides 1/63/64/65/4096. Oversized chunk,
  capacity overflow, invalid chunk and reader exception reject rather than
  returning an empty digest. Fixed empty/abc known answers supplement same-library
  chunk parity. This measures neither native streaming nor memory.
- A proposed canonical tagged grammar distinguishes null/Boolean/integer/text/
  array/record; sorts UTF-8 keys; preserves normalization differences and NUL;
  rejects surrogate, float, range and cyclic inputs. Fixed record/numeric and
  intent/batch domain byte preimages supplement round-trip parity. Acyclic intent-to-batch
  derivation and distinct domain inputs differ. It is not a reviewed schema or
  duplicate/unknown-key decoder; Python dict input cannot establish duplicate-key
  rejection. Those remain necessary production checks.

## Separate acceptance gates after explicit execution release

1. Run the offline oracle with a verified full Python path; review failures and
   frozen byte grammar. Passing it establishes only reference behavior.
2. Implement the reviewed host adapter separately and run the same injections
   against its actual snapshot members and native 516.1681 consumers. Validate
   actual metadata and valid v2 A/B saves with different restored identities.
   The hash-then-reopen native omission must fail its exact named assertion.
3. Prove partial-acquire cleanup, ownership loss and error/empty distinction with
   real native identities/counts. Verify SHA-256/UTF-8 parity against the oracle
   and bounded buffers including whole-member-set capacity, not just one chunk.
4. Test publication crash/reservation/CAS readback and independent host-writer
   exclusion as separate gates. A publication pass cannot prove reader pinning.
5. Review the unified custody/async fence inventory, then v2-v4 restore/reconcile/
   admission controls and ordinary null-policy behavior. Shared patch review,
   pinned-build execution and explicit ownership release remain prerequisites.

No CI job, suite selection, library installation or execution is added by this
preparation. Existing standard compilation excludes this offline source and
cannot establish its assertions or native compatibility.

## Replacement resource preflight proposal (not executed)

The previous one-attempt offline lease was consumed by a prestart CIM memory
query returning Access denied. Python never started. A future attempt requires a
new specific lease; neither this plan nor an older free-memory receipt releases
the execution hold.

The existing adapter reviewed as source is
`D:/GitHub/Civ13/.worktrees/opendream-savefile-cleanup/tests/savefile_cleanup/guard-windows.py`,
with matching declarations in `tests/memory_roots/guard-windows.py` in that
worktree. The coordinator supplied source head
`2e589f689c81232896be83f250c8c2653da5427c`; the savefile guard's raw file SHA-256
was independently read as
`111F7B53CB3493C8F0B244E225E6E664472DCBF76A68A94693DEBC3E3E42A8A4`.
The worktree HEAD at review was
`a49ab0d2f64de6d703732aaf25e3d0cc90175e47`; the guard bytes still match the
supplied hash. No foreign file was changed or executed.

`MemoryStatus` contains two DWORD fields and seven unsigned 64-bit fields.
`free_bytes()` sets `length` to the structure size, calls
`kernel32.GlobalMemoryStatusEx` with a structure pointer and BOOL return, raises
`OSError(get_last_error())` on a false return, and returns `available` physical
bytes on success. This API declaration/adapter should be reused, rather than
inventing another resource query. Its synchronous call has no independent timeout;
polling intervals are not a bound on a hung API call.

The existing guard's `--inspect` prints UTC, available physical bytes and watcher
private bytes, then exits without creating a Job or starting its test. Its normal
path is specific to the savefile `run.py` and a .NET executable; it cannot run the
extraction oracle through its current arguments. It checks a 6 GiB physical floor,
sets a 2 GiB aggregate Job commit cap and kill-on-close, starts a gated child,
assigns it to the Job before releasing its stdin gate, then polls owned PIDs,
private bytes and host free bytes every 0.5 seconds. Unknown live PID measurements
fail closed. Process handles close in `finally`; normal guard teardown terminates
the Job, waits up to ten seconds for its root and up to ten seconds for remaining
owned PIDs, closes the Job handle and validates its owned temporary path before
removal. Its receipt includes stop reason and cleanup errors. Setup operations
before its main `try` require care when adapting exception cleanup.

Proposed future extraction-specific reuse, subject to source review and a fresh
lease: retain those API declarations and ownership cleanup, use an extraction-owned
wrapper with one child, a 60-second child deadline, 0.1-second sampling, a hard
256 MiB aggregate Job commit cap and a 6 GiB host physical floor before launch
and during polling. Private bytes are a separate sampled diagnostic; Job commit
is not working-set memory. The watcher itself is outside the child Job. Fail
closed on query errors, missing measurements, Job assignment failure, deadline,
unexpected descendants or cleanup failure. Create only a unique guarded temporary
directory and receipt/logs; do not install libraries or alter foreign guards.
Ensure the oracle body cannot run before assignment; the original oracle has no
stdin gate, so a reviewed gate adaptation is necessary before granting execution.

The intended child argv is the verified bundled interpreter
`C:/Users/valza/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`,
`-I`, `-B`,
`D:/GitHub/Civ13/.worktrees/extraction-survival/tests/extraction/test_generation_contract.py`,
`-v`. This is a proposed child command, not a runnable replacement guard command.
Pin the future complete wrapper/oracle source head and interpreter hash before
requesting the lease. The oracle source remains unchanged from
`8e2314d58b2a1735e53a08ac9ede036565a8db1c`, unparsed and unrun. No current memory
availability, host ownership or native acceptance is inferred from this review.

### Extraction wrapper source prepared after design authorization

`tests/extraction/guard-oracle-windows.py` now implements the proposed adaptation
as SOURCE ONLY. It reuses the reviewed structures and API signatures, binds the
oracle to the required raw SHA-256, writes the captured bytes to its own temporary
directory and executes that copy after a successful Job assignment and fresh
deadline/floor check. The child is the same interpreter under `-I -B`, with a
minimal `runpy` stdin gate. It does not import or parse the oracle before the
gate. The Job permits one process, has a hard 256 MiB aggregate commit cap and
kill-on-close; unexpected descendants and unknown live PID measurements fail.
The 60-second deadline includes setup; teardown adds bounded root/Job waits of
up to ten seconds each. Synchronous Windows calls themselves have no independent
timeout. The parent watcher is outside the child Job.

The wrapper closes process and Job handles, preserves logs/receipt, and deletes
only its successfully created `owned-temporary` directory after confirmed
cleanup. Cleanup uncertainty retains that directory and produces a nonzero
result. Prestart refusal before directory creation prints a receipt without
creating storage. Child environment changes do not change the parent environment.
The commit label is supplied by the caller, not independently verified by the
wrapper; the lease owner must independently check clean exact HEAD, wrapper and
interpreter hashes. Hash binding/copying is not host-writer exclusion.

The proposed future command is the verified interpreter followed by `-I -B`,
the absolute `tests/extraction/guard-oracle-windows.py` path, `--directory` with
a new absolute extraction-owned receipt directory, `--source-head` with the
complete reviewed wrapper commit, and `--oracle-sha256`
`11d3a26ffffedf142b5fd63c5f3b15a01886d8fc6ecfd2a9f56b0065518a5a6a`.
That raw oracle hash was read without executing Python. The source oracle is
unchanged from `8e2314d58b2a1735e53a08ac9ede036565a8db1c`.

Independent review of this exact wrapper source and ONE renewed execution grant
are still required. Neither wrapper nor oracle has been parsed or executed;
no fresh memory query, native/client run or shared serializer change occurred.
