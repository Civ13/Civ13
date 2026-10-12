# Constructed vehicle key contract

This staged contract is not implemented or accepted. Native/screen testing and
live activation remain on hold. Existing modular frames use numeric door codes
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
