# Snapshot broker candidate architecture

Source proposal for automated architecture review. No broker, protocol, database,
service account or production adapter is implemented or installed. This is the
next candidate after the native reader probe demonstrated same-world mutability.
The selected goal is same-server faction save/restore with interrupted recovery;
cross-server transfer follows only after that boundary is established.

## Process and storage boundary

Use one host broker process as the only publisher and journal writer. Run the
game consumer under a different non-administrator identity. The broker owns a
configured local storage root containing `staging/`, `generations/` and
`journal/custody.sqlite`; these names describe a proposed layout, not existing
paths. The journal and recovery directory must be outside the selected world's
rollback/import namespace. Never point a prototype at production data. Consumer input is an opaque
generation/member identifier, not a filename supplied by the caller.

On Windows, the selected root must use a filesystem with enforced ACLs. The game
identity receives directory traversal and file read access to published members,
without write, delete, permission modification or parent-directory replacement.
On Linux, a separate broker UID owns the root and published files; the game UID
has only traversal/read access. The broker itself must refuse rewriting or
replacing a published generation, including while a reader is active. Initial
tests must inspect effective permissions rather than infer them from read-only
attributes, Unix file mode alone, or a successful ordinary read. Sealing must also
close or exclude retained writer handles and protect ancestors from replacement;
changing permissions does not prove those existing handles lost their rights.

Host administrators/root, processes with equivalent privileges, compromised
broker code and storage hardware that lies about persistence are outside this
candidate's exclusion guarantee. An unlisted ordinary writer, inherited ACL,
symlink/reparse escape or same-identity game process is a failed configuration.
Network shares and cross-volume publication are excluded from the first candidate.
Exact OS, filesystem, runtime and identity identifiers belong in every receipt.

BYOND 516.1681 must actually open and consume these read-only backing files without
requiring write access. This remains untested. If native savefile opening needs
write rights, this candidate is unavailable; do not relax permissions or reopen
mutable source files as a fallback. A different native consumer/interface then
needs architecture review.

## Proposed bound-reader ABI

Version the proposed protocol as `civ13.snapshot-broker.candidate.v1`; this is a
design identifier, not an available provider version. Use a bounded authenticated
local channel between the configured identities. Transport selection and BYOND
integration remain unresolved; file polling or a helper must not be assumed to
supply authenticated process identity.

The host protocol proposal consists of `publish(staging, expected_manifest)`,
`reserve_restore(operation, generation, expected_members)`,
`close_selection(selection)`, `finalize_restore(operation, recovery_id, decision)`
and `recover_pending()`. Publication returns a generation receipt; reservation
returns exact scoped member records and a persistent recovery ID. Finalization
records admission completion, and recovery enumerates unfinished reservations.
These calls are not implemented. The serializer-facing adapter maps its proposed
`acquire_selected` and read methods onto a reserved selection.

`acquire_selected(operation, generation, manifest)` returns a selection bound to
the caller process instance, operation identity, generation, exact level/metadata
membership, raw lengths and SHA-256 digests. Reject unknown fields, duplicate or
missing members, unavailable publication, expired process binding and size limits
before any world mutation. Broker-created member records expose only their own
published backing paths to the serializer adapter.

`read_level` and `read_metadata` require that exact live selection/member binding.
Validation, allocation, recursive restoration and metadata consume the same
published members. A successful pathname hash before/after use is insufficient.
`close_once` closes native readers and releases only transient selection ownership;
it cannot cancel persistent recovery custody. Caller restarts invalidate transient
handles, while the broker's recorded recovery remains.
Loss of channel or process-identity binding rejects further mutation and retains
recovery. Reconnection cannot silently refresh an expired selection.

## Publication and recovery ordering

### Smallest existing game adapter seam

The current production seam is `map_storage.restore_policy`, consumed by
`gameticker.loadmap()` in `code/modules/persistence/functions.dm`. It is optional
to preserve ordinary map loading. Its base implementation rejects a provider
attempt; no production broker subclass or authenticated host channel exists.

| Current implemented call | Proposed host responsibility | Missing input |
| --- | --- | --- |
| `policy.begin_attempt(storage)` | Bind one process instance, operation, generation and exact member set; acquire a selected reader set | Authenticated host identity/channel and immutable member custody |
| `storage.validate_world_save()` | Validate the same selected level/metadata bytes later consumed | Serializer reader adapter; current pathname validation is not pinned selection proof |
| `attempt.before_mutation()` | Commit reservation and conservatively durable mutation-started before returning exact TRUE | Journal writer, durable commit barrier and bound reservation/transition receipt |
| `attempt.fail(phase, error, mutation_started)` | Preserve journal recovery; return a failure receipt bound to the attempt | Authoritative recovery lookup and unfinished-operation admission gate |
| `attempt.release_transients()` | Close selected readers exactly once without finalizing or deleting recovery | Host close-selection acknowledgment and ownership lifecycle |
| No current call | `finalize_restore` after restored world, metadata and custody verification | New explicit finalize/admission seam; transient cleanup cannot substitute |
| No current call | `recover_pending` before game or account admission | Startup reconciliation owner and admission integration |

The existing wrapper returns success after world/metadata restoration and transient
release. That success is not broker finalization, admission approval or faction
asset ownership proof. Do not implement a provider that hides finalization inside
`release_transients`: the wrapper invokes that method on both success and failure.
The ordinary null-policy path is not a durable faction-war activation path.

The wrapper's `mutation_started = TRUE` immediately before `ClearMap()` is only
a local failure-accounting flag. There is no provider callback between the
reservation hook and first disposal. For the smallest existing-seam candidate,
`before_mutation()` must conservatively commit both reserved and mutation-started
in the durable journal before returning TRUE. A later binding rejection or abort
before disposal may therefore leave a mutation-started record and retain recovery.
Never infer that the world is untouched from journal state alone. An alternative
requires a new explicit durable transition hook before `ClearMap()`; it cannot
rely on the existing Boolean as a host receipt.

Before adding a production subclass, the host owner must supply the selected
API's authenticated caller/process binding, persistent operation/recovery identity,
generation/member schema and durable journal location outside every rollback-world
namespace. The serializer owner must select the acquire/read/close adapter that
consumes the reserved members. The admission owner must identify the actual startup,
reconnect, deployment and cross-server transfer entry points to gate. These are
required inputs, not tasks delegated to a new competing provider.

The smallest proposed transaction contract is monotonic: reserved, mutation
started, restore verified, finalized. Each unfinished durable state blocks
admission; process death or channel loss does not erase it. A retry of the same
operation with the same generation and members returns the existing recovery
record. Reuse of an operation identity with different generation, members or
decision rejects. Retry binding also includes the world/root/server identity and
every durable reservation field. A newly authenticated process may reconcile an
existing recovery record, but must acquire a newly bound transient selection;
it cannot silently reuse the previous process's handles. Finalize retries return the journal's existing decision only
when all binding fields match; a conflicting decision never overwrites it.
Restart reconciliation reads journal state rather than inferring completion from
world contents, a callback return, absent native handles or a lost acknowledgment.

This is a source contract proposal, not an implemented journal or a tested host
transaction. A bounded next candidate must supply the durable mutation-started
bridge as well as the explicit finalize/startup gate
only after the above owners provide their exact APIs and integration entry points.
No synthetic receipt should be accepted as durable provider evidence.

Initial source locations for the admission owner's inventory include
`code/setup.dm` and `code/modules/persistence/admin.dm` callers of `loadmap`,
extraction `mode.dm` admission/deployment, `groups.dm` party deployment,
`vehicle_raid.dm` vehicle deployment, `code/game/jobs/job_controller.dm` extraction
admission, and `native_market.dm` re-admission after settlement. This is a starting
inventory, not exhaustive faction/reconnect/cross-server ownership coverage or
authorization to edit another owner's entry points.

The broker bounds member count, per-member bytes and aggregate bytes before and
during streaming copy. It hashes raw bytes while copying to a new staging
directory. Source files must already be closed and held under the save operation's
writer custody; copying a file while its producer changes it is not a snapshot.
Reject symlinks/reparse points and unexpected members. Flush/close copied files,
verify digests, seal permissions, publish within the configured volume, and commit
the journal reference only after the publication durability barriers succeed.
Readers use only journal-admitted generations. Unreferenced staging/published
orphans are unavailable and retained for bounded recovery classification.

Prototype the journal with a pinned SQLite build and one broker writer. On every
actual writer connection, set `PRAGMA journal_mode=DELETE` and
`PRAGMA synchronous=EXTRA`, then read back journal mode DELETE (using canonical
or case-insensitive comparison) and synchronous=3;
reject the connection if either setting is rejected or differs. Other rollback
modes are not substitutes for this candidate. SQLite's
[synchronous documentation](https://www.sqlite.org/pragma.html#pragma_synchronous)
describes additional directory synchronization for EXTRA with DELETE mode;
this does not verify the selected filesystem or power-loss behavior. The exact
SQLite build/VFS and file/directory flush implementation remain required inputs.
An atomic rename claim cannot substitute for verified publication persistence.

Before ClearMap, commit a reservation linking operation, generation, current world
identity and recovery location. Record mutation-started before the first disposal.
If the game or broker stops after that point, restart retains recovery and blocks
ordinary admission until reconciliation. The prior world is not claimed untouched.
Only full restore, metadata and custody/admission verification may finalize the
reservation. Lost replies never imply release; repeated requests use the same
operation identity and return the recorded decision.

## First executable prototype and omission controls

Implement a standalone broker and test client in temporary storage before adding
production DM plumbing. Inject broker crashes by terminating the test-owned broker
at explicit copy, permission seal, publication, journal commit, reservation,
mutation-started and final-admission checkpoints. Restart from that same isolated
root, check generation/recovery classification and preserve process/log receipts.
Also terminate and restart the test-owned game/native consumer after reservation,
first mutation, metadata, admission and finalization acknowledgment. Drop its
channel and attempt reconnection using its stale process-instance identity.
Verify unfinished operations retain recovery and block admission; finalized
operations recover only their journal-authorized decision, never an inferred
rollback. Old handles must not resume or acquire a replacement binding silently.
Broker-only crashes do not establish game-death recovery. Process termination
tests do not establish hardware power-loss durability.

Run actual game-identity and foreign-identity write/rename/replace attempts against
selected backing paths during every native consumer phase. Negative controls grant
write/delete access, replace a backing member, omit a digest/size/binding check,
skip the reservation barrier and infer release from timeout. Each must fail its
own intended assertion, with unrelated counterpart failures rejecting acceptance.
Test raw zero/high bytes, truncation, capacity limits, member substitutions,
wrong process/operation/generation and partial acquisition cleanup. Include
storage/quota exhaustion classification once budgets are selected:
pre-mutation failure leaves the world untouched, while later failure retains
recovery and blocks admission.
All effects stay inside verified temporary roots; identity creation/ACL changes and process
execution require a separate exact scope and runtime grant.

The unresolved choices are the configured identities and filesystem, native
read-only compatibility, authenticated local transport, pinned broker/SQLite
runtime, effective byte/storage budgets and platform publication barriers.
Selected faction roots, map/schema compatibility and recovery/admission policy
are also unresolved; the first synthetic prototype need not invent those values.
Memory/host owner selects the platform custody implementation, serializer owns
reader propagation, and core owns operation/recovery reconciliation. These inputs
block production activation, while source review and a bounded prototype remain
useful independent work.
