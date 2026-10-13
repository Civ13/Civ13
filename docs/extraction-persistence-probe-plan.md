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
