# Disabled geometric visibility read core (#3233)

`CIV13_GEOMETRIC_LOS_CORE` is **0** in production source. There is no caller
constructing a context, activation verb, configuration switch, map opt-in,
renderer, client mask or transport change. Keep it disabled and this PR draft.

The first core provides synchronous hover/examine decisions from fresh bounded
raw opacity, closed-cell ray/convex-footprint geometry, unique first-hit wall/door
surfaces, connection/body ownership, and nested mutation tickets. Unsupported
operation names return DENY before target access. Snapshots are temporary inputs,
not reusable action leases. No lighting-cache value is used as blocker authority.

The unactivated slice admits only a 21x21x1 world, view7/15x15, a tile-centered
ordinary human with its own eye, exact plating/wall/simple-door/human identities,
and nonopaque lighting overlays. It admits at most two contexts, 16 concurrent
mutation tickets and 1,024 floor-level atom visits per capture. Unknown types,
partial movement, other cameras, incomplete HUD readiness, active persistence
operations, stale ownership and exhausted revisions deny world reads. Owned
screen-slot hover remains separate; arbitrary inventory examination is not admitted.
All new runtime datums are unsaveable. Logout, disconnect and context destruction
retire owned references/tickets; no reconnection cache is restored.

Hover checks precede target-name formatting. Examine checks precede messages and
target output. In the disabled-by-default candidate's *enabled-only* read adapter,
examination does not turn the actor: turning can invoke callbacks between a check
and information release. This is an explicit conservative proposal for Main review.
The OFF path retains baseline turning and other existing behavior. There is no
change to shared FOV state or to aiming/autofire code or semantics.

## Offline checks

Run with a verified interpreter (Windows example):

```powershell
$env:LOS_EVENT_BASE = '<full-40-character-event-base-commit>'
$env:LOS_EVENT_HEAD = (git rev-parse HEAD)
& '<verified-python.exe>' -B -m unittest discover -s tests/los_context -p test_offline.py -v
```

The file is explicitly registered in the bounded offline CI baseline. It does
not discover or invoke native runners. Tests project the actual DM arithmetic
helpers and three mutation methods through a constrained Python adapter, compare
1,764 footprint inputs and 1,764 ray-entry inputs with an independent rational
oracle, exercise openings/partial footprints/corner contact and nested/foreign
tickets, and reject contact, owner and adapter omissions. The float inputs are
integers/halves/quarters within the small slice; this is not a general float or
subtile precision claim. CI forwards the event's exact resolved base and head
from its validated selection receipt. The LOS check loads the five base files
from local Git objects, removes the LOS-only edits from the four affected
procedure bodies in each revision, then compares the disabled projections.
Unrelated edits outside those procedures, including DME includes, remain allowed.
Changes within those procedures require reconciliation with the base. A missing
or mismatched base/head fails clearly; the suite never fetches a branch or uses
moving master. Manual `workflow_dispatch` requires the `comparison_base` input:
an available, full 40-character commit SHA distinct from the head. The selector
validates it before publishing selection outputs and passes the same ID through
baseline, compilation and aggregate receipts. Other reusable callers retain
their existing selection behavior. Locally, provide both explicit immutable IDs.
Historical evidence
against `10d264e5896221b34949ee4b67c0fd2b94bde249` remains historical evidence,
not a required hash for future shared files.
Unsupported block comments or preprocessing directives in an affected adapter
also fail closed and require an explicit review of the projection.

The projection tests are **not DM compilation or native execution**. The retiring
client lifecycle, native view/InCone, custom save/import, actual input and pixels
are not executed. Source boundary checks do not prove every virtual method,
reflective writer or native callback is instrumented. Initial checker-development
failures (a contact control lacking an exact-contact witness, and a declaration
selector using a newline after splitlines) were corrected; no native run occurred.

## Gates before any activation

This is not an action-authority or rendering release. Direct examination overrides,
click/drag/Topic/weapon/agent operations are not wired to this core; their operation
names are denied by its API, but their existing gameplay implementations remain
unchanged. Do not enable the flag in an ordinary world and mistake the read
adapters for complete consumer coverage. Writers are read fresh for these
synchronous decisions; mutation tickets do not automatically wrap all production
writers, and do not establish proactive image withdrawal.

Main must review the enabled-only no-turn examination policy, exact-type scope,
and the missing action/writer adapters before expanding the slice. A separate
concrete decision is required for denied-click/hostage-trigger semantics and any
shared-FOV correction. Preserve ordinary cooldowns, permission checks and raw-loc
semantics. Compile/native client/save reconstruction and all renderer/transport
acceptance remain outstanding. No CPU/RAM/network or supported player count is claimed.

Reuse the existing #3225 lighting, #3236 capture and #3243 measurement owners;
this patch supplies none of their acceptance and spends no test allowance.
Cross-z, roofs, vehicles and oversized-canopy/post-shadow composition remain
deferred. Kestrel DM remains the engine direction; no OpenDream work is resumed.
