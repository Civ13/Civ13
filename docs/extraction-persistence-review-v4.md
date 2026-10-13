# Generation correspondence and pinned release inputs

Source-only revision 4 following review of `326f4e218`. Revision 3's external
release reconciliation, one map selector/32-owner same-G batch and bounded
sealed-G2 rotation remain. This revision refines generation-local marker proofs,
digest construction, pending publication and journal pinning. Nothing is
implemented. Shared edits and local execution remain held; binary APIs/types,
account byte prediction and exhaustive asynchronous mutation coverage are pending.

## G2 derives its own marker proof

Build G2's marker index from its actual closed, pinned native entries. For each
retained intent, find exactly one entry by stable map/type/room/x/y/z correspondence;
reject missing/duplicate/moved markers or altered type/room. Resolve durable
fields using G2's own reference tables. Its entry reference, serialized-record
digest and canonical resolved-field digest belong to G2, not G. Entry numbers
are not identities across generations.

Compare G2's resolved fields with the immutable intent's exact after_fields;
inherited fields must equal the fixed before inherited fields. Only the three
replica fields may change. Unsupported referenced values block correspondence.
Byte digests may differ from G after entry/reference reordering without implying
a semantic field change. Store `{intent_digest, stable_marker_key, g2_entry_ref,
g2_record_digest, g2_resolved_fields_digest, expected_after_fields_digest}` in the
G2 checkpoint. G references/digests belong only to predecessor proof. G2 restore
uses its own index exclusively; bind the full correspondence set before map CAS.

Required negative control: reorder saved entries so G2's house moves to a new
entry reference and another marker occupies G's old reference. Correct unique
correspondence succeeds; a control reusing G's ref/digest fails its named G2
assertion. Reordering with changed inherited fields must reject. These are test
requirements, not executed or implemented controls.

## Canonical acyclic digest preimages

Define one typed canonical byte encoder C. Strings use exact valid UTF-8 bytes
with byte-length prefixes; no silent Unicode normalization. Integer fields use
unsigned canonical decimal with no leading zero except zero, within reviewed
exact ranges; floats/exponents reject. Null, Boolean, integer, text, array and
record have distinct tags. Arrays include count/order; record keys sort by UTF-8
bytes with explicit counts and no duplicate/unknown keys. ID sets sort unique
exact ID bytes. Native JSON iteration order is not digest authority.

Define H(domain, body) = SHA256(C([domain, body])). Digest-storing fields are
excluded from their own bodies. Mutable phase, runtime refs, CAS revisions of
the record storing the result, completion and current selection are excluded
from immutable intent/batch/manifest bodies.

| Digest and exact ASCII domain | Immutable body |
| --- | --- |
| intent_digest: `civ13.world-handoff.intent.v1` | Unique request nonce; map/dimensions; owner; stable marker key without generation entry ref; fixed before/after durable field maps; before binding; sorted root graph/node sets; expected before-account revision/byte digest; intended after revision/byte/slot digests and immutable payload blob digest. |
| intent_set_digest: `civ13.world-handoff.intent-set.v1` | Sorted unique `[owner, stable_marker_key, intent_digest]` roster, <=32 and unique owners/markers; no phases or future generation digest. |
| batch_digest: `civ13.world-handoff.batch.v1` | Unique batch nonce; map/dimensions; predecessor selected generation or initial null; predecessor journal revision and exact committed payload digest captured BEFORE reservation; intent_set_digest. |
| candidate_id: `civ13.world-handoff.candidate.v1` | Unique candidate nonce; kind initial/sealed_successor; batch_digest; intent_set_digest; predecessor selection and predecessor map CAS inputs. |
| marker_set_digest: `civ13.world-handoff.markers.v1` | Sorted intent/stable-key/generation-local-entry-ref/record-byte-digest/resolved-fields-digest/expected-fields-digest records derived from that candidate's closed files. |
| manifest_digest: `civ13.world-handoff.manifest.v1` | Schema; candidate_id; map/dimensions; predecessor manifest digest or null; batch_digest; intent_set_digest; sorted exact file names/lengths/byte hashes; marker_set_digest; root-exclusion proof set/digest bound to those files. No current manifest_digest or external completion. |
| checkpoint_digest: `civ13.world-handoff.checkpoint.v1` | G2 manifest_digest; predecessor manifest/journal proofs; batch/intent-set digests; G2 correspondence set; exact retained account proofs and root exclusions. No checkpoint_digest or containing journal digest. |

Order: intents -> intent set -> batch -> candidate -> closed-file/marker/exclusion
proofs -> manifest -> external selection/completion -> successor checkpoint.
A manifest may bind its predecessor, never itself or the future checkpoint.
Mutable records reference these digests; they are not recursively inside their
preimages. Readback checks mutable-record CAS bytes separately. Later journal
revisions never alter the batch's fixed predecessor input.

Verified canonical encoding and binary/streaming hashing remain required.
`extraction_crypto_bytes` only accepts ASCII text <=65,536 units; it is not a
verified UTF-8/binary/large-manifest primitive. No file2text, truncation or ASCII
conversion of save bytes. Future vectors cover reordered keys, domain swaps,
phase-only changes and circular inputs. No encoder capability is claimed here.

## One authoritative pending candidate

Extend the strict map schema with one nullable pending_candidate:
`{candidate_id, kind, batch_digest, intent_set_digest, predecessor_selection,
predecessor_revision, predecessor_payload_digest, canonical_candidate_directory,
stage, committed_manifest_digest, declared_file_set_digest, cleanup_obligation}`.
Stages: reserved, files_closed, manifest_committed, selection_unknown,
cleanup_required. Unknown fields/stages/conflicting identities reject. Manifest
and file-set digests stay null until checked at the applicable stage. Cleanup
obligation identifies only that exact candidate directory/declared files.

CAS reserve BEFORE creating files or publishing. A non-null slot blocks new
publication, rotation and batch creation. An ambiguous reservation CAS blocks
all three even if the caller saw no success; authoritative readback must resolve
it first. Retrying cannot allocate another candidate nonce/directory.

After ambiguous selection CAS, inspect exact committed authoritative slots. If
selection equals this verified candidate manifest/batch, finish its exact readback
transition. If predecessor remains committed and the pending candidate matches,
retain predecessor and reconcile or safely retire only that candidate. Pending,
unreadable or conflicting slots stay recovery-blocked. Never scan/adopt a valid
orphan by newest file/date or assume a failed CAS means no write.

Retirement requires an explicit cleanup_required journal transition after proving
no selected/checkpoint/operation record references the candidate. Preserve identity
and cleanup obligation until exact inventory proves safe retirement under separately
authorized cleanup. Error/incomplete inventory keeps the slot occupied; no new
candidate follows. Selected generations and guard journals are not cleanup targets.
Clearing the slot is itself readback-verified CAS, not a memory reset.

Bound one candidate/orphan in addition to selected generation and active/checkpoint
records. Account for its <=1 MiB journal payload and exact declared files BEFORE
reservation; projected capacity overflow rejects. Publication failure cannot create
a second unrecorded orphan. Unexpected extra generation directories invalidate
inventory and block maintenance; no arbitrary adoption/deletion or unbounded retry.

## Pin external inputs through admission

Before ClearMap, acquisition captures the map journal revision/byte/slot digest,
selection and pending state, batch/roster digest, EVERY referenced operation's
revision/byte/slot digest, immutable intent/blob bytes, checkpoint proofs and actual
owner account revision/payload/slot digests. Verify all committed slots and reject
pending/unreadable members under exclusive map/account writer ownership. Pinning
G's files does not pin these external inputs.

Unrelated account/journal commits, admission, trade, IPC recovery and delayed
actions must reject/defer. Read leases do not grant writer authority. Host writer
exclusivity remains mandatory; in-process ownership is not an OS lock. Only
explicit token-bound release CAS may change a pinned input, updating its exact
expected revision/digest after verified readback. Unexpected roster/member changes
never join the operation through opportunistic reread.

Revalidate the ENTIRE pin set and captured policy/token epoch:

1. Before and after EACH marker reconciliation, including callbacks.
2. Before and after each authorized CAS/readback; only its exact transition updates pins.
3. Before and after finish_restore and complete census publication.
4. At admission, before decode and immediately before physical issuance; recheck
   after any yield/async callback before its side effect.

No stale proof survives an ownership gap. Admit under the same fence using a
token-bound session/account CAS, or acquire fresh exclusive admission ownership,
repin journals/accounts and validate selected-generation/census epoch. Issuance
consumes that capability once; another session or changed profile cannot replay
it. End ownership invalidates unused capabilities. Unexpected policy/journal/account
changes invalidate the entire proof and retain recovery blocking.

Future controls cover roster/member/account changes on both sides of reconciliation
and finish, policy removal/replacement, authorized CAS pin updates, unrelated
writer refusal and account change after fence release before issuance. Design
review does not establish exhaustive subtype/custody/async or native crash acceptance.
