# Native reader-contract primitive probe

Source candidate, uncompiled and unrun. This slice adds a standalone primitive
experiment and fixture-only adapter checks. It changes no production loader,
save schema, engine, custody or provider binding. There is no production immutable
reader or durable-quarantine acceptance.

The selected production proposal remains an immutable private snapshot backed by
demonstrated exclusive host ownership. This probe measures a native candidate
boundary before choosing any provider implementation; savefile locks alone do not
satisfy that proposal.

## Reference and pinned verification boundary

The official live reference was fetched on 2026-10-13 at 17:11:27 UTC through
Civ13's bounded reference tools. Source SHA-256:
`fe2d0b6c33e7844a7ab028ca4de2be5e6a0761179144cad689b539dbf9c2359a`.
It may document behavior newer than the pinned compiler.

- [New(filename, timeout)](https://www.byond.com/docs/ref/info.html#/savefile/proc/New)
  specifies timeout in seconds; a timed-out open has an empty savefile name.
- [Lock(timeout)](https://www.byond.com/docs/ref/info.html#/savefile/proc/Lock)
  returns 1 or 0. Another world holding even an unlocked reader prevents a lock.
- [Unlock()](https://www.byond.com/docs/ref/info.html#/savefile/proc/Unlock)
  permits shared reading while preventing other worlds from locking until the
  retained readers close. Its return value is observed without inventing a
  Boolean success contract.
- [Flush()](https://www.byond.com/docs/ref/info.html#/savefile/proc/Flush)
  flushes pending writes. That description is not evidence of fsync, crash
  durability, atomic publication, antirollback or account-domain CAS.

Pinned BYOND 516.1681 compiler and runtime receipts are required separately.
OpenDream behavior is untested and cannot be inferred from BYOND observations.

## Two cooperating worlds

The versioned runner compiles `tests/world_save/reader_contract.dm` in a unique
temporary directory. It starts the owner, then the peer once the owner signals
that the synthetic selected savefile is locked. Both worlds are 1x1x1, close
their ports and omit all normal game startup. Every managed pathname is a fixed
relative fixture name within that directory. No production saves or caller paths
are opened. Signal files contain only handshake markers.

| Stage | Native observation and required receipt |
| --- | --- |
| Owner opens, locks, writes A and flushes | Open name is nonempty and Lock(0.1) returns exactly 1. |
| Same-world second handle writes LOCAL, then restores A | Record the retained first handle's read. This is a distinct in-world mutation boundary, not another world's lock. |
| Peer attempts New with positive timeout while owner is locked | Name must be empty; no failed handle is used for writes. |
| Owner unlocks while retaining its reader | Record raw Unlock return; both readers must see A. |
| Peer attempts a lock with owner reader still open | Lock(0.1) must return exactly 0; no write is attempted. |
| Peer closes shared reader, owner closes last reader | Handles are logically closed once and their last native savefile references released. |
| Peer reopens, locks, writes B, flushes and closes | Lock must return exactly 1; the owner then reopens and sees B. |

Unsupported native outcomes fail the check with role JSON and an
`UNSUPPORTED: <cause>` result. They never enable a provider or trigger a pathname
fallback. Engine diagnostics in either world's runtime log or captured streams
invalidate the experiment, including omission controls.

## Fixture adapter observations

The fixture owns a separate single-level savefile and bounded synthetic text.
`rc_selection.acquire_selected` accepts exactly level1 and metadata, rejects
duplicates before opening, and binds copied member records to an operation.
Reads reject a different operation, a foreign same-label member, an inactive
operation and a closed selection. An injected failure after the first acquisition
closes exactly the acquired member; repeated close is idempotent.

Metadata is a copied DM text value capped at 1024 native length units after reading.
The fixture checks a non-text value, a 1025-character ASCII value, independence from a
later file append, and records the native length of a UTF-8 e-acute character.
It does not establish normalization, arbitrary binary fidelity or a pre-read
memory bound. `file2text` still reads the whole file; only known small synthetic
files are used. No binary hash or immutable open-handle identity is provided.

These adapters exist only in the standalone fixture. The proposed production
boundary remains typed `acquire_selected(manifest, operation)` returning readers
with exact level/metadata membership, reads only through those bound readers, and
`close_once`. Provider availability, binary bounds/digests and host ownership
must be verified before implementing or wiring that ABI. A configured unavailable
provider must reject before ClearMap.

## Omission controls and execution limits

`binding` removes one fixture operation-identity check while keeping the argument
used and non-null. It must produce the exact owner result
`UNSUPPORTED: WRONG_OPERATION_REJECTED`.

`close` removes the one native savefile-reference release statement. Logical
close flags and counts still advance; the peer must fail the real post-close
native lock with exact result `UNSUPPORTED: PEER_LOCK_AFTER_OWNER_CLOSE`.
This distinguishes a release counter from actual cross-world handle release.
All mutations affect only the generated temporary source copy.

The runner allows one compiler with a 60-second timeout and at most two daemon
processes. Both worlds share one 45-second runtime deadline; each DM handshake
has a 20-second timeout. Result-bearing processes get up to two seconds to exit
cleanly. Remaining owned processes are terminated, then killed if needed, within
four plus two seconds per process. Cleanup records exact PIDs, return codes and
runner cancellation. A control's assertion-producing world must exit cleanly;
its waiting counterpart may be explicitly cancelled.
Any completed counterpart must have matching PASS receipt/result and exit cleanly;
an unrelated failure cannot satisfy an omission control. Cancellation is allowed
only for a pending counterpart without a receipt or result. Each log/receipt is capped
at 1 MiB on read. Logs and synthetic files remain for review.

This is not an OS memory cap or production storage budget. Local execution needs
a fresh coordinated slot, with time for all worst-case bounds and cleanup;
lease expiry never grants an extension. The existing selected world-save CI lane
runs the normal probe and both controls, under the existing opt-in policy.

The existing memory/engine owner is the named host-provider boundary owner.
Arbitrary host write/rename/replace tests, foreign binary extensions and platform
ownership adapters are not selected by this source slice. They need exact path,
effect, interface/version and execution review. In-process account leases cannot
be upgraded into host ABA exclusion, fsync/CAS or antirollback guarantees.
