# Constructed vehicle key contract

The first source implementation is staged but not compiled or accepted on its
integrated head. Native/screen testing and live activation remain on hold.
Existing modular frames use numeric door codes
and generic keys; the constructed-car contract must not reuse that authority.

Assign each constructed vehicle one immutable durable ID and a positive integer
rekey generation. Prefer the existing stable axis identity in extraction saves;
ordinary native world saves must preserve the same identity and generation.
An exact vehicle-key type binds both values. Key possession authorizes lock and
ignition use; account names, registration text and generic key codes do not.
Keep unrelated legacy vehicles compatible through explicit opt-in key authority.

Paid construction produces the actual vehicle and matching initial key together.
Preflight placement and inventory capacity before consuming paid materials.
Failure must expose neither a key nor a partial free vehicle. Save, garage,
deployment, extraction and custody transfer preserve vehicle/key identities and
generation. A key is an actual tradeable item, not an account flag. Do not grant
a replacement automatically on login, reload, transfer or extraction.

Copying a valid key requires physical vehicle access, the current matching key,
an advanced locksmith tool, a reachable powered workshop and paid blank/materials.
Copying preserves generation. Losing all keys requires a separate costly rekey
operation based on physical custody, not original-account entitlement. The car
must be physically secured at a powered, equipped workshop, stopped and
unoccupied, with an adjacent operator holding the required tools and materials.
Traded, recovered and stolen cars may undergo this expensive service. Mere
proximity outside the secured service bay grants no recovery authority. Provide
a reachable ordinary construction/workshop progression path
so recovery never requires starting the inaccessible vehicle.

Rekeying requires a stopped, unoccupied vehicle, advanced tools, workshop power,
substantial paid materials and a long interruptible action. Quote exact costs,
duration and old-key invalidation before confirmation. Reserve the vehicle and
inputs; block concurrent copying, rekeying, driving and transfer while reserved.
Check actor life, proximity, tool/input identity, power and vehicle state after
the wait. Cancellation, death, movement or removal releases reservations without
charging or changing generation. Runtime reservations must never be serialized.

Only successful completion atomically consumes the reserved payment, increments
generation and issues the new actual key. All old keys then fail immediately.
Do not destroy or edit remote old-key objects; generation comparison invalidates
them without a world scan. Journal ambiguous completion and block vehicle access
until reconciliation rather than replaying payment or issuing another key.
Notify nearby players before service and the actor on completion that previous
copies are invalid. No remote or Discord recovery bypass is permitted. The audit
event records operator, service, vehicle ID, old/new generation and costs, not
permanent account ownership. Bound generations and
refuse overflow before payment. No perpetual per-key timers or global key scans.

Before shared edits, agree authority placement with the existing extraction
vehicle codec, account/custody journal and ordinary native saver. The container
key presentation catalog remains separately owned by the mall worker.

Create a new keyed vehicle ID only at successful paid construction. Constructors,
loaders and reconnect paths must not mint one. Existing legacy cars retain their
explicit legacy policy until a separately defined migration; they must not gain
free replacement identities or keys by passing through the extraction codec.

Acceptance needs wrong-vehicle/generation/generic-key ignition and lock rejection;
valid copies; copy/rekey/drive races; cancellation/death/movement/tool removal;
exactly-once construction/payment/issuance; old-key invalidation; native save,
restart, garage/deployment/extraction and crash recovery. Use actual DMI previews
for obtainable keys. Public wiki availability follows verified integration, not
this contract or local fixture results. Costs and duration remain tuning choices
until concrete source-backed defaults and meaningful tests are reviewed.

## Current source and remaining acceptance

`vehicle_keys.dm` binds exact vehicle keys to a durable constructed axis ID and
generation. The workshop issues a key after paid construction. Keyed cars check
door actions, driving-wheel ignition and direct engine activation. The extraction
vehicle codec stores the binding and reads older graphs without assigning keys.
The equipment codec preserves actual key identity and binding. Native load calls
do not mint keys or identities.

Workshop service currently proposes 2 steel/1 copper and 30 seconds for a copy,
or 20 steel/5 copper and 300 seconds for rekey, plus a carried wrench/welding
tool and 20 cable power. These are initial tuning values, not approved balance.
The actual stopped, empty car must fit the northeast 4x4 service bay. The private
garage workshop exposes the same service. Transfer is rejected while service is
reserved. The per-vehicle two-slot journal records pending/committed service,
generation, operator, costs and issued key identity. An ambiguous write or a
generation mismatch blocks access; there is no automatic refund or replacement.
History caps at 128 records and rejects further service rather than deleting
records. Archival/admin reconciliation and integration with the full economic
ledger remain unfinished.

Native assertions cover constructor non-minting, one-time issuance, actual key
graph disk reload, wrong binding, zero generation, pending quarantine and old-key
invalidation. They are authored but unrun. Timed paid service, cancellation,
concurrency, ordinary whole-world save/reload and integrated extraction crash
acceptance still require meaningful fixtures and runtime verification. In
particular, service-journal commits alone do not prove whole-world material/key
save ordering after a crash.

![Actual vehicle key sprite](images/extraction-vehicle-key.png)

The preview is the nonempty `key.dmi` modern state used by the real item, not a
gameplay capture. Regenerate with `tests/extraction/preview_vehicle_keys.py`.
