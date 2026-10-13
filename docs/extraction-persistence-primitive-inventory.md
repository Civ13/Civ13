# Extraction persistence primitive inventory

Source-only follow-up to the design-level v4 review. Baseline for this inventory:
`e0042c92e7bbd3f43d4e7e6c5a597a9181f6a323`, pinned compiler target BYOND
516.1681. No compiler, helper, native library or runtime API was executed for
this inventory. Shared persistence implementation remains held. The experimental
serializer PR3105 is not the accepted baseline.

## Available source interfaces and unresolved native behavior

| Candidate | Signature or source | Established evidence | Missing acceptance |
| --- | --- | --- | --- |
| DM file object | `file(Path)` | Live official reference describes a file object. | No immutable binary reader, stable open-handle identity or streaming guarantee established on 516.1681. |
| Native whole-file hashes | `md5(F)`, `sha1(F)` with a file argument | Live official reference documents file-content hashes. | Neither supplies the v4 SHA-256 primitive; exact pinned build behavior and concurrent replacement remain untested. |
| Native savefile | `new /savefile(filename, timeout)`, `Lock(timeout)`, `Unlock()` | Live official reference documents exclusive savefile locking and reader sharing after unlock. | No claim of protection against arbitrary host writes, renames, directory replacement or another world bypassing the savefile API. |
| Text file APIs | `file2text(File)`, `text2file(Text, File)` | Reference documents whole-file text reading and appending. | Not a binary chunk reader or exclusive create/publish operation; UTF-8 bytes and normalization unverified. |
| Checked-in rust-g bindings | `code/__defines/_rust_g.dm:120-125` | `rustg_file_read(fname)`, `rustg_file_write(text, fname)`, `rustg_file_append(text, fname)`, line count/seek macros call named external exports. | No checked-in binary snapshot, chunk SHA-256, reader-token or lock/CAS binding found in this file. DLL presence does not prove exports, version, UTF-8 or failure semantics. |
| External dispatch | `_rust_g.dm:41-49` | DM_VERSION >= 515 selects `call_ext`; `rustg_get_version()` has a source binding. | Neither the installed native version nor export availability was probed. Do not infer new exports from newer upstream docs. |
| Existing extraction digest | `ipc_crypto.dm:3-11,38` | Text conversion rejects non-ASCII and more than 65536 units; byte hashing also rejects more than 65536 entries. | Cannot implement a canonical UTF-8/binary generation digest or bounded streaming state as currently written. |
| Existing account limits | `EXTRACTION_PROFILE_LIMIT` and `account_store.dm` | Encoded payload length and digest checks exist. | Character/unit length is not accepted as verified UTF-8 byte capacity; ordinary profile JSON is not the proposed typed canonical encoding. |

Native signatures above are **documented candidates**, not verified pinned-build
contracts. See the [official DM reference](https://www.byond.com/docs/ref/info.html)
topics `file`, `md5`, `sha1`, `file2text`, `text2file` and `savefile/New`,
`savefile/Lock`, `savefile/Unlock`. The live manual can exceed 516.1681.
No native SHA-256 or binary streaming primitive is established by this inventory.

## Minimal primitive contracts needed before implementation

These names describe proposed interfaces, not existing DM procs or native exports.

1. `encode_canonical(domain, typed_value, byte_limit)` produces exact canonical
   UTF-8 bytes and a byte count, rejecting malformed Unicode, unsupported/cyclic
   values, ambiguous numeric representation and overflow. Freeze field/type/order
   rules and the v4 exclusions before selecting an implementation. Include
   non-ASCII, NUL, empty/null, number boundaries and same-length-different-byte
   vectors. Reject invalid input rather than silently replacing characters.
2. `open_generation(manifest, owner)` acquires the complete declared immutable
   file set and returns a reader identity bound to its exact bytes, sizes and
   generation. Metadata, validation, recursive entry/list decode and restoration
   must consume those same readers. A mutable pathname or post-load hash is
   insufficient. Reader acquisition must unwind partially acquired resources.
3. `hash_reader(reader, algorithm, limit)` supplies whole binary SHA-256 with
   bounded streaming memory and a checked byte count. Errors cannot become an
   empty-file digest. Bind the digest to the same reader later consumed by the
   savefile loader, rather than independently hashing a pathname.
4. `publish_candidate(reservation, files)` checks exclusive host ownership,
   capacity, complete file inventory, flush/close outcome and exact readback;
   publication must not overwrite a selected generation. Crash or ambiguous
   publication retains the one pending reservation from v4.
5. `host_writer_ownership(scope)` must exclude every world, restore/admin helper,
   backup/cleanup job and account writer that can mutate the selected files or
   journals. Document OS/process/directory boundary and loss detection. Existing
   in-process read leases and wrapper Booleans do not satisfy this contract.

Choose a verified immutable private snapshot plus exclusive host writer ownership,
or a verified retained-reader implementation. Do not invent a savefile constructor
over a foreign binary handle. If neither can bind all consumers to the same bytes,
stop before ClearMap. A native extension would require its own reviewed binding,
pinned binary/version and isolated compatibility tests; none is authorized here.

## Proposed callback types

Use distinct typed datums for operation, generation proof, restore proof and
single-use admission capability. Do not overload a Boolean/list success value:

- Operation: captured storage/policy identity including null, kind, epoch, host
  ownership, reader set, journal/account pin set and active/failed state.
- Generation proof: owning operation, candidate/manifest identity, exact declared
  files and closed-byte digests. `accept_committed` must check exactly TRUE.
- Restore proof: same operation/reader identity, complete ledger/census epoch,
  reconciled markers and complete external pin set. `accept_restored` checks TRUE.
- Admission capability: exact owner/session/account revision, selected generation,
  current pin set and issuance epoch; consumed once, invalidated by ownership loss.

The v2 callback results and exception-safe cleanup remain mandatory. `require`,
`level_closed`, `refresh_restored`, `accept_*` and `end_operation` return exactly
TRUE or throw. Acquire/finalize callbacks return their specific non-null proof
type or throw; verify identity and type at every call boundary. Cleanup failure
retains the durable recovery block and does not hide the original exception.

## Unified custody and asynchronous fence audit still required

The following concrete paths establish audit obligations, not exhaustive coverage:

| Source path | Gap that the unified operation must close |
| --- | --- |
| `persistence/functions.dm:198-249` | Wrapper Boolean permits no overlapping wrapper call but is not a world custody fence; save yields before export and load validation precedes the exception scope. |
| `persistence/loading.dm:1-108` | `TICK_CHECK`, explicit sleep, constructors, reused-reference direct loc assignment and recursive legacy contents/reference calls need the same operation/reader token. |
| `persistence/loading.dm:113-150` | Typed entry/list recursion must carry token and reader membership; cached lists/references cannot cross operation epochs. |
| `persistence/loading.dm:161-241,371` | Clear/load/validation reopen level paths; metadata reads another pathname. Each must use the pinned set; revalidate around every yield and callback. |
| `extraction/equipment.dm:326-376` | Decode constructs objects, restores reference fields, force-moves roots/nodes and invokes after_load. Guard before construction and each callback/side effect; issuance requires a consumed capability. |
| `extraction/mode.dm` | Menus, extraction do_after, inventory drop, deployment/admission and checkpoint transitions need pre/post-yield epoch checks. Existing session checks are not the global restore fence. |
| `items/weapons/storage/storage.dm:426,478-508` | Direct loc insertion/removal/cascade paths require custody coverage. Linked surface-root rejection covers those roots, not every ordinary item during restore. |
| `gunsmithing/gun_configuration.dm:181,199-235,268` | Timed configuration, menu callbacks and direct attachment loc writes need resumption checks before consuming/moving actual components. |
| `extraction/vehicle_transfer.dm:95`, `vehicle_raid.dm` | Chassis/parts/seats/cargo and consenting rider account mutations must share the operation, including menu/wait continuations and rollback. |
| `extraction/account_store.dm`, settlement/mail/IPC consumers | Every journal write and recovery projection must honor captured global ownership; unrelated commits cannot invalidate pinned bytes without failing the operation. |
| Physical corpse/expiry/GC and inherited subtype callbacks | Actual root drop, deletion, stack merge, construction and after_load can mutate custody outside extraction entry points. Inventory their parent-call behavior and delayed continuations. |

Before calling the audit exhaustive, inventory all included DM sources for direct
loc/contents/reference mutations, subtype overrides, construction/deletion hooks,
delayed actions/process callbacks and external writers. Classify each reachable
path as guarded, explicitly operation-owned, safely deferred or blocking. A base
Move/forceMove hook cannot cover direct loc writes. A regex inventory alone cannot
prove parent calls, callback reachability or absence of asynchronous side effects.

Implementation order: verify primitive contracts after execution release; review
the frozen codec/proof types; serializer supplies one unified operation/fence and
reader plumbing; extraction supplies its owned journal/census/issuance adapters;
then run the v2-v4 boundary controls and ordinary null-policy regression. Keep
activation held until both shared patch review and meaningful native controls
pass. No step is accepted merely because the design review has no new blocker.
