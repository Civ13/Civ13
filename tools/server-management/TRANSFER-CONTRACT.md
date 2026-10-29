# Mutual shard transfer contracts: source-only proposal

This is a data-contract and deterministic model-checking slice, not an accepted
transfer implementation. It adds no server protocol handler, listener, credential,
certificate/key generation, trust-store changes, game hooks or inventory effects.
The launcher remains optional for gameplay. Standard BYOND/DreamSeeker users keep
existing verification and access rules; neither a launcher nor Social SDK session
is an authorization credential for inventory. The authoritative game/server owns
items, progression, account ownership, provenance, escrow and custody decisions.
The launcher can later help configure explicitly approved local shard groups.

Current source reference: `067478b82c7ad9f1b83759a221e6f22080ba865a`.
The merged P0 contract is `11e5a26e0c3d53889a5330c9085a7d582e07e50e`.
P0 model/test files were verified unchanged in the selected current source.
This slice does not touch the launcher, experimental native extensions, existing
lifecycle adapters, save serialization or live configuration. No new coordinator
is created. `TransferTransitions` is a pure evidence reducer, not a running agent.

## Mutual directional permission

For A to send to B, all of these are required at each admission/commit boundary:

1. Both stable server identities are enrolled, current and unrevoked in the same
   explicitly operator-approved trust group. A hostname, public CA certificate,
   self-signed key or locally generated identity alone supplies no membership.
2. A's policy explicitly permits exports to B; B's policy explicitly permits
   imports from A. B-to-A requires B's exports and A's imports separately.
   Group membership never implies a full-mesh transfer permission.
3. Both policies allow the item kinds, aggregate quantities and original economy
   authorities. Their exact canonical digests, not just revision numbers, are
   pinned in the manifest, alongside group and peer identity epochs.
   Both active key IDs are pinned too, so a changed key cannot reuse an old epoch's
   pending authorization. The registry must still advance epochs monotonically.
4. An authoritative provenance/ownership adapter verifies the required origin/taint
   dimensions, item revision and quantity, source generation and account owner. DTO fields,
   item names and a sender's signature are not independent provenance evidence.

The origin authority survives every hop. An official intermediary cannot relabel
private-origin resources as official. Re-export, transforms, splits/merges and
crafting must preserve conservative origin/taint lineage in the authoritative
inventory model; this slice does not implement those operations. A valid signature
only authenticates a key/issuer and unchanged bytes, not honest item production.
There is no automatic trust delegation, public federation, trust-on-first-use or
transitive authorization through a permitted intermediary.

Each server must evaluate its own current local policy; a peer's claimed policy
digest is not a substitute. The destination's prepare evidence binds the complete
manifest/policy hashes, and the destination rechecks its import policy before
credit. A source cannot supply an older destination policy to override a new deny.

Local enrollment automation is a future privileged operator workflow confined
to a named preapproved group, host/shard identity scope and permissions. It must
not enroll an arbitrary downloaded world or automatically add it to an official
economy. Community groups and official economy groups remain separate unless an
explicit reviewed policy and independently verified provenance permit a route.
This proposal stores only public key references/epochs in DTOs, not key material.

## Official operation without a receipt archive

Resolved user decision (2026-10-26): official servers may keep minimal current
transfer state and per-peer sequence numbers alongside inventory saves, with the
small storage/write cost explicit. This permits the correctness boundary below;
it does not approve real keys, trust configuration, storage deployment or transfers.

The user explicitly excludes optional receipt/audit retention for official servers.
**Official operation has no archive service, receipt database, historical receipt
collection, audit writer, retained envelope payloads or archive lookup dependency.**
The core contains no optional archival hook that official servers must invoke.
Community archival, if later desired, is a separate opt-in component and resource
budget; its failure must never be required for transfer settlement. Existing
management logging must not silently retain transfer bodies/items under another
name. No archive implementation is included here for any server.

The provenance verifier must not conceal a transfer-receipt archive dependency.
Official operation uses authoritative current inventory/origin/taint metadata and
approved authority evidence already needed for item eligibility, not a retained
hop-by-hop receipt trail. Mixed/unverifiable origin must stay conservatively
restricted or be denied, rather than relabelled by an intermediary. If a proposed
provenance mechanism can work only by adding historical receipt storage, it is
incompatible with official no-retention and must be redesigned or that route
disabled. Additional current-item metadata/verification cost is an explicit
eligibility tradeoff, not an excuse to require optional archival overhead.

| Data | Official proposal | Community option |
|---|---|---|
| Authenticated envelope/signature | Transient wire verification; release after use | May copy to an explicitly enabled external archive |
| Active transfer | One bounded manifest/reservation/phase/decision and latest chain digest per directional channel | Same minimal correctness state |
| Completed transfer | Remove active record after atomic settlement; no per-transfer row or receipt history | May retain a separately budgeted audit record |
| Replay fence | Persist only channel epoch and contiguous settled-sequence watermark in authoritative inventory state | Same minimal fence |
| Old retry | Reject settled sequence without reconstructing a historical receipt; inspect current authoritative custody | Optional archive may aid diagnosis, never create authority |

This is not a claim that durability is free. A
crash-safe transfer with retries requires **minimal durable correctness state**:
the authoritative item ownership/reservation and inventory revision, in-flight
commit/abort decision, and per-enrolled-peer directional epoch/sequence fence.
There is also a bounded unacknowledged response/outbox obligation until the peer
has recorded the corresponding decision. This is active protocol state, not a
receipt archive, and must not accumulate after settlement.

The user has permitted those minimal fields with inventory saves. Therefore the
official design requires that bounded state; it does not silently choose weaker
delivery or a hidden receipt archive. A host that cannot commit that state with
inventory must disable automatic transfers until a reviewed backend is available.
Memory-only deduplication loses its barrier on restart; blindly retrying can
duplicate items, and blindly refunding an uncertain commit can lose/duplicate
custody. Actual crash safety remains unproven until backend fault tests pass.

## Bounded identity and replay model

The authoritative transfer identity is the directional channel (group, stable
source and destination IDs), transfer epoch and monotonically increasing sequence.
`TransferId` is the SHA-256 digest of the canonical, domain-labelled tuple; it is
an identifier, not an authentication proof. Every envelope also binds the complete
manifest digest, account, source generation, immutable item claims and policy/key
epochs. Reverse direction has a separate sequence space. Sender reboots do not
reset epochs/sequences. A receiver never accepts a new epoch just because the
sender supplied a larger number; epoch changes require explicit reconciliation
of both peers' active state under the group's approved control plane.

One active sequence per configured directional channel permits a single contiguous
settled watermark rather than an unbounded set of transfer IDs. A gap is refused;
the next sequence cannot begin while the prior one is uncertain. Capacity and
fairness are bounded by explicitly configured group/peer limits, not remote
requests. This serializes a channel and can reduce throughput. Shard groups may
use separately preapproved bounded channels later, with no silent channel fanout.

Within an active transfer, only the latest receipt digest and current step/version
are kept. Receipt ID is derived from transfer ID plus step sequence. Exact latest
retry returns an idempotent status without effects; older steps return a generic
stale result, not archived receipt contents. After settlement, the active record
is discarded and any sequence at/below the watermark is refused without lookup.
Current authenticated transport access is still required to query status.

`TransferChannelFence` and `TransferState` are immutable proposals. They do not
persist anything and cannot establish that caller-supplied state is trustworthy.
The backend must CAS the channel, transfer phase, inventory ownership/reservation
and transactional outbox together. Separate file writes followed by game mutation
are insufficient. Cross-transfer asset claims also require an exclusive inventory
revision/reservation check, even when different channel/transfer IDs are used.

`InventoryTransferBoundary` binds the current channel/active record to the same
inventory generation and revision. It rejects mismatched generations, missing
active decisions and retained terminal rows after channel closure. Source garbage
collection requires terminal custody, an increased inventory revision and an
atomic publication of the compacted watermark with inventory state. Destination
checkpoint cleanup has the same real-backend atomic boundary requirement. The DTO
cannot detect a maliciously supplied expected generation or make separate writes
atomic; expected metadata must come from the authoritative inventory commit.

## Prepare, commit, abort and recovery

| Step | Issuer -> recipient | Required authoritative effect before signed evidence |
|---|---|---|
| Escrow | Source -> destination | Atomically reserve source asset revisions, prevent spending and bind active channel/manifest |
| Prepare | Destination -> source | Reserve compatible destination capacity; no playable credit |
| Commit | Source -> destination | Atomically persist irreversible commit decision, rechecking both policies/identities/provenance |
| Import | Destination -> source | Verify commit; atomically mark sequence/custody and grant at most one destination credit |
| Finalize | Source -> destination | Retire source escrow permanently; establish terminal custody and bounded settlement acknowledgement |
| Abort | Source -> destination | Only before commit decision; durably decide not to commit |
| Tombstone | Destination -> source | Durably refuse commit/import for the active sequence |
| Return | Source -> destination | Only after tombstone; release the original source escrow at most once |

The reducer accepts evidence of these transactions, not instructions to perform
them. Receipt sequence and previous-envelope digest bind the active chain. Each
server must be able to recover its own atomic phase/outbox and retransmit/query
the latest decision. The game adapter, not the launcher, produces inventory
effects and receipts after authoritative transactions. A malicious enrolled
server remains a trust risk; signatures alone cannot repair that assumption.

Network timeout is not abort proof. Before commit, abort requires the destination's
durable no-import fence before source return. After commit, source refund/abort
is forbidden. Lost acknowledgements require authenticated status reconciliation;
never issue a new transfer ID to repeat the same escrow. Keep uncertain assets
explicitly reserved, rather than deleting them or silently returning them.

Policy changes, expiry, membership changes or rotation stop new inventory admission
under the pinned snapshot. Abort cleanup and source retirement after a confirmed
import can outlive an expired/changed transfer policy, but both still require
current authenticated enrolled peers. Retirement follows confirmed Import and
does not require a destination tombstone. A destination tombstone is specifically
required for abort/return before source escrow can be released.
After an irreversible decision, policy revocation does not erase custody or
justify a refund: hold/quarantine the active record until an explicitly authorized
recovery policy resolves it. Previously imported items cannot be credited again.
Historical last-step replay acknowledges no new effects; it is not a renewed
credential or a way around an endpoint's current access policy.

`Settle` models source compaction after source retirement/return has committed.
If its final envelope is lost, the source can freshly authenticate a current
`ChannelCheckpoint` (pair/group/epoch and closed-through watermark), generated
from those bounded fields without an old receipt lookup. The destination may
compact from that proof only if its own inventory is already imported or its
abort tombstone is durable; merely prepared inventory cannot be promoted by a
checkpoint. The checkpoint has a separate protected message type, issuer/recipient,
key/group epoch and short validity window. It grants no new inventory effects.
The source must not compact earlier or drop a still-uncommitted outbox obligation.
Actual two-sided atomic phase/outbox recovery and checkpoint interleavings still
require backend fault tests before active records can be deleted. Old backups must not rewind a settled fence
or resurrect consumed escrow. Inventory/epoch rollback needs a coordinated
restore/reconciliation contract; no automatic rollback or clearing of replay
state is authorized. An unavailable/revoked peer can hold a channel indefinitely:
safety takes precedence over unsupported availability claims.

## Authentication and canonical encoding references

Use a vetted JOSE/TLS/X.509 implementation, never a custom signature or handshake.
The proposed receipt profile uses protected `alg`, `kid` and `typ`, fixes the
algorithm to fully specified `Ed25519`, binds issuer and recipient, and resolves
keys only through the approved group identity registry. No `none`, algorithm
negotiation from untrusted payload, remote `jku`/`x5u` fetch or self-signed admission.
Keys/certificates need validity bounds, revocation and overlap/rotation policy;
stable server identity is independent of the current credential. Unknown or stale
revocation status must fail closed for new admissions, not silently trust a cache.

- [RFC 7515](https://www.rfc-editor.org/rfc/rfc7515): JWS protected-header/payload signing input.
- [RFC 9864](https://www.rfc-editor.org/rfc/rfc9864), updating [RFC 8037](https://www.rfc-editor.org/rfc/rfc8037): fully specified JOSE algorithm identifiers, including Ed25519.
- [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785): canonical JSON; this encoder is deliberately limited to fixed sorted ASCII fields/tokens and safe integers, not a general JCS parser.
- [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280): X.509 identity/validity/path and CRL concepts if certificates are selected.
- [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446): TLS 1.3 baseline and its current updates/successors must be reviewed when selecting the actual transport profile.

No cryptographic signing/verifying or certificate implementation is included.
`ITransferSignatureVerifier` and `IItemProvenanceVerifier` are trusted adapter seams;
the tests use deterministic lookup doubles. SHA-256 here is a standard digest,
not proof of an honest producer. The generated signing input is the standard JWS
base64url(header) + dot + base64url(payload); actual wire parsing, critical header
validation, strict Ed25519 verification, transport peer binding, revocation fetch,
clock-skew policy and platform provider acceptance remain separate work.

## Main-review questions and acceptance gaps

1. Product decision resolved: minimal inventory-integrated active state and per-peer
   epoch/watermarks are permitted, without receipt history. Which concrete backend
   can atomically persist that boundary and prove crash/retry safety?
2. Which entity approves trust groups and stable server IDs? Which local shard
   enrollment scopes may be automated, and who authorizes rotation/revocation?
3. Which authoritative item/account/lineage schema covers transforms and mergers?
   Whole-claim transfers only are modelled; no partial-stack split API is added.
4. Which backend can atomically commit inventory, reservations, channel watermarks
   and outbox/decisions, with crash-safe settlement and anti-rollback backups?
5. What post-commit revocation/quarantine and unavailable-peer recovery policy is
   acceptable without weakening destination permission or minting a source refund?
6. Which maintained crypto/transport provider and protocol profile will pass
   interoperable vectors, key rotation/revocation, malformed JWS and endpoint tests?

Offline mocks cover mutual/asymmetric permission, unknown/revoked peers, wrong
recipient, tampering, replay, deterministic concurrency/crash interleavings,
policy changes and untrusted provenance. They do not establish real cryptography,
disk durability, distributed exactly-once operation or game/save compatibility.
Publishing this proposal for code review does not authorize release, deployment,
actual transfers or operational enrollment.
