# Persisted marker release reconciliation

Source-only review revision 3, responding to the P1 finding on `c69063190`.
The reader-pinning and checked-cleanup design in revision 2 is retained. Its
release schema, owner selection and marker-memory acknowledgement are superseded
by this contract. No shared implementation or adapter has landed. Mutation-fence
coverage remains partial pending the subtype, custody and asynchronous unified
patch. Local execution and shared implementation remain held.

Revision 4 in `extraction-persistence-review-v4.md` refines G2-local marker
correspondence, acyclic digest preimages, the single pending candidate and
external input pinning. Those refinements take precedence over this revision.

## One map selection and one release batch

Use one coordinator journal per exact map identity and dimensions, rooted at
`[accounts.store.root]_world_handoff/maps/[sha256(map.ID)]/`, outside all world
generation and backup directories. Verify the exact original map ID inside the
record; a path digest is not permission to accept another map. The journal owner
key is the literal `map`, using the existing account-store envelope and CAS.

The map record selects exactly ONE generation digest and exactly ONE active
batch ID. A batch contains at most 32 owner operations, at most one per owner
and one per unique house marker; this matches the bounded house registry rather
than granting independent owner-specific world selection. All operations in the
batch bind the SAME generation G and manifest operation-set digest. No second
batch can acquire the map fence or publish a competing selection while the
active batch is unsettled. A per-owner operation record cannot change selection.

The map CAS binds its previous journal revision/content digest, exact previous
selected generation and active batch. Operation CAS additionally binds expected
phase/content and its membership in that selected batch. Selector changes,
missing operation members or a conflicting journal block the entire map's
restore/admission, not merely the affected owner. Ordinary saves cannot change
the external selection implicitly.

The strict map extra-field schema is `world_handoff = {schema: 2, map_id,
dimensions, selected_generation, active_batch, roster, sealed_checkpoint}`.
`active_batch` is null or one 64-character digest; `roster` maps up to 32 operation
digests to fixed account-domain record keys. `sealed_checkpoint` is null or
`{generation_digest, predecessor_generation_digest, predecessor_journal_digest,
batch_digest, owner_proofs, marker_proofs, excluded_nodes}`. Owner/marker proof
sets retain the exact revisions, byte digests, marker keys and before/after field
maps needed for validation, not just a terminal hash. Reject unknown fields and
invalid active/sealed combinations. Only the map record selects a generation.

## Authoritative external intent and completion

The batch roster and operation records are account-domain journal records. They
are never taken from G or copied with backups. Each operation's strict field set
is the following; extra/missing fields and invalid state-specific nulls reject:

```text
{
  schema: 1,
  operation_id: 64-character unique operation digest,
  batch_id: 64-character batch digest,
  map_id: exact original map ID,
  dimensions: [maxx, maxy, maxz],
  owner: canonical owner,
  phase: prepared | runtime_retired | generation_committed | release_intent | released,
  generation_digest: null until committed, then exact selected G digest,
  marker_key: {level, entry_ref, type, room, x, y, z},
  marker_saved_digest: exact digest of G's serialized marker record,
  marker_before_fields: exact saved durable field/value map,
  marker_after_fields: same map with replica_owner=null, replica_revision=0, replica_digest=null,
  before_binding: exact existing eight-field account home_replica binding,
  root_graphs: exact root ID -> graph digest map,
  root_nodes: exact unique nested persistent-ID set,
  account_before_revision: exact expected account revision,
  account_before_payload_digest: digest of exact committed account bytes,
  account_after_revision: exact before_revision+1,
  account_after_payload_digest: digest of exact intended committed account bytes,
  account_after_slot_digest: existing store md5 of exact payload plus newline,
  intended_account_blob: immutable account-domain payload reference and hash,
  completion: null until released, then {
    generation_digest, batch_id, operation_id,
    account_revision, account_payload_digest, account_slot_digest,
    marker_key_digest, marker_before_digest, marker_after_digest
  }
}
```

The prepared fields are computed before retirement; generation/marker entry
references are finalized only from the pinned committed G before release_intent.
In prepared/runtime_retired, generation_digest, marker_saved_digest and
marker_key.entry_ref are null; the remaining marker tuple and durable before/after
maps are already fixed. generation_committed fills those three nulls only from
G after verifying its saved marker exactly matches the fixed before state.
Completion is durable operation-bound evidence of the intended reconciliation,
not a claim that G contains the mutated marker. A marker key is NOT a new UUID:
it identifies the exact native saved entry and its unique type/room/coordinate
tuple. Require exact serialized entry reference/type plus one matching runtime
marker after load; zero or multiple matches reject. `session` is runtime-only
and must be absent/inactive. All saved inherited fields remain unchanged; only
the three replica-binding fields may transition. Moving a marker, changing room,
changing any inherited saved field or replacing it with an ambiguous duplicate
requires recovery, not searching for a convenient replacement.

The release_intent CAS occurs BEFORE account or marker mutation. It binds the
immutable intended full account payload, with only the reviewed home binding
transition and store revision increment. The existing `commit_profile` checks
the caller's current revision, copies it and writes revision+1; do not increment
the argument first. Predict the exact candidate bytes separately and verify
the actual committed slot generation/payload/intent/commit digest by readback.
If re-encoding produces different bytes, retain release_intent and block. No
successful CAS is inferred from an unbound profile or a runtime digest alone.
An unreadable/pending journal or later unexpected account revision also blocks.

Before release_intent, the committed G's physical entry/contents/reference graph
must exclude every retired root and nested node, and the complete constructor
census must agree. Retain this proof in G's manifest and the operation-set digest.
An empty live location does not establish exclusion. No account decode occurs
while reconciliation or final census is incomplete.

## Deterministic restore of G

Acquire the selected immutable G and capture the external batch plus operation
journal revisions/digests under exclusive map/account ownership BEFORE ClearMap.
Pin all input bytes/handles as in revision 2. Perform normal restore under the
same token, then reconcile markers after all entry restoration, metadata and
after_load callbacks, but BEFORE census completion, account decode or admission.

For each selected operation, require the loaded marker to equal either its exact
recorded before_fields from G or its exact after_fields. A marker in a third or
partial state rejects. Validate current external operation membership/revision,
the actual account slots and committed root-exclusion proof again. Reconciliation
has no equipment codec decode, constructor issuance, identity allocation, refund
or root recreation. It only applies the fixed marker field transition.

If the account is EXACT before revision/payload, leave the marker bound and
admission blocked; explicit operation recovery may finish the exact account CAS
from the immutable intended payload while still fenced. If it is EXACT after
revision/payload with valid commit readback and phase release_intent or released,
reapply the exact after_fields to a before marker, or verify an already-after
marker. Guard before/after mutation and callbacks, then verify all durable fields.
Phase release_intent may CAS to released only after account readback and marker
verification. Phase released reuses its exact completion, but still performs
these checks and deterministic reconciliation on EVERY restore of G.

Do not use marker state as proof that account commit happened. A marker already
after while the account is before is a contradiction and remains recovery-blocked.
The mutation fence prevents login and delayed actions from observing an unbound
marker before the operation proof/census is complete. Missing/conflicting external
intent or completion after account unbind rejects, even if G's marker looks valid.

## Crash and restart table

Every row assumes exact selected G, valid immutable bytes/root exclusion, complete
ledger coverage and the same pinned external batch. Failure of any assumption
blocks recovery and decode.

| Interruption | Durable external/account state | Restored marker in G | Required recovery before admission |
| --- | --- | --- | --- |
| Before account CAS | release_intent; account exact before | Exact before binding | Keep bound. Only explicit recovery can CAS intended account bytes, then reconcile/complete. |
| During account intent/snapshot/commit | release_intent; account journal pending | Exact before binding | Keep bound; offline exact-snapshot recovery only. Do not choose an older account slot or infer unbind. |
| After account CAS, before marker mutation | release_intent; account exact after and commit readback valid | Exact before binding | Under fence, apply exact after marker fields; verify; CAS released; finish census. No roots issued. |
| During marker mutation | release_intent; account exact after | G still exact before; current runtime may be partial | Restart G and reconcile exact before. Without restart, partial runtime marker is blocked and requires explicit recovery. |
| After marker mutation, before released CAS | release_intent; account exact after | G exact before | Reapply exact marker transition under fence, verify, CAS released and complete census. Prior runtime acknowledgement is irrelevant. |
| During released journal write | Journal pending; account exact after | G exact before | Keep blocked until exact journal recovery resolves; never infer completion from account/marker. |
| After released CAS | released completion matches actual account commit | G exact before | Revalidate external completion/account, reapply exact marker transition under fence on this restore, then finish census. |
| Repeated restart of G | Same exact released proof/account | G exact before each time | Same idempotent reconciliation; no root decode during reconciliation and no receipt rewrite needed. |
| Account changed after release | Account revision/payload differs from completion | G exact before | Block stale G until a new reviewed map-generation transition binds current account obligations. |
| Unknown/moved/duplicate marker or missing/conflicting guard | Any | Not the exact selected saved marker | Block. No permissive marker matching or automatic release. |

The admission path must consult selected map proof AND per-owner released proof,
not simply absence of home_replica. It permits ordinary account decode only after
the complete restore/census and exact account revision remain valid, and existing
session/ownership guards prevent second issuance in the same world. Native
reconnect/duplicate-issuance acceptance remains unrun.

## Finite capacity, retention and safe rotation

Proposal limits are maintenance protocol limits, not item/mail entitlement limits:
one active batch of <=32 operations; <=64 roots per operation; <=2048 unique root
nodes across the entire active batch. Reject over-budget preparation without
changing accounts, markers or claims. Use separate fixed-roster operation records
so a map selector is not a single growing profile containing every historical
payload. Each encoded journal profile and immutable intended-account blob must
fit <=1,048,576 text units AND verified UTF-8 bytes, below the existing store's
2,097,152 payload-length check. No truncation or best-effort serialization.

Retain the active batch, its records/blobs and one previous sealed checkpoint;
never evict obligations to create capacity. Rotation is permitted ONLY during
exclusive maintenance BEFORE admission resumes:

1. All active operations have exact released account proofs and deterministically
   reconciled markers; their retired roots remain absent while the fence is held.
2. Publish a successor immutable generation G2 containing those exact after marker
   fields. Verify its closed bytes, full census, current account proofs, batch
   digest and root exclusion. No intervening decode/reissue is allowed.
3. CAS the map journal from exact G/batch to G2/sealed checkpoint, binding the
   predecessor journal/manifest/batch digests and complete owner/marker proof set.
   Failed CAS leaves G selected; G2 is an orphan, not a recovery shortcut.
4. Read back the sealed map CAS and G2 proof, then mark the old operation roster
   retired in the account domain. Only records NOT referenced by selected G2 or
   the retained checkpoint are cleanup candidates. Cleanup failure leaks bounded
   storage, never changes selection or admission policy. A new batch cannot start
   until obsolete roster/blob cleanup is verified, keeping at most two 32-record
   rosters plus the one map record and their declared blobs. Do not accumulate
   failed-cleanup rosters across rotations.

The sealed checkpoint retains <=32 exact owner/account and marker proofs plus
root-node exclusion set, within the same 1 MiB bound. It replaces the active
operation obligations only because G2 itself contains the reconciled markers;
it is not a digest-only summary losing recovery requirements. Old G/G backups
are permanently rejected by the independent selection CAS. G2 restarts verify
the checkpoint and exact after markers without needing old runtime acknowledgements.
Opening the next batch requires a settled sealed checkpoint and a newly reviewed
ownership census; later account changes do not silently inherit its old proof.

Existing two-slot journal revisions stop at 1,000,000. Do not reset that counter,
delete the selected journal or wrap it as rotation. Stop new maintenance before
exhaustion. Migration to a new journal epoch requires a separately reviewed
durable external selector/CAS protocol and is NOT provided here. Likewise, no
automatic deletion of selected world generations or authoritative guard files
is authorized. Missing records after cleanup or corruption fail closed.

## Remaining implementation gates

This is a deterministic recovery design, not executable source. Serializer review
must confirm marker reconciliation and map-level cardinality/rotation. Verified
binary pinning/digests, exact callback types and complete mutation/constructor
coverage still block the applyable unified patch. Account payload byte prediction,
slot readback, pending-journal recovery, each crash row, repeated G restart,
competing batches, over-limit refusal and G2 rotation require native and omission
controls after an explicit execution lease. None ran for this revision.
