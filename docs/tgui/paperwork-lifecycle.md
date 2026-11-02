# Inactive authoring lifecycle contract

This local source slice extends the merged paper backend. It adds no player
route, renderer, feature switch, study action or language learning. Existing
classic editors/readers retain their gameplay handlers.

After a valid begin, a session subscribes to the selected paper, actual pen,
controller, current holder and movable ancestors. Setup plans at most fifteen
subjects and sixty-four forwarding edges before registering; one subject is
reserved for a bound UI. Cyclic/oversized graphs refuse without classifying paper
or starting a window. The existing moved, destroyed, name and stat observations
are reused. A private targeted notification bus has no global listener or timer.

Movement callbacks check physical/control bindings without serializing records.
Ordinary turf walking with a held page/pen remains valid. Direct custody
departures and nested returns retire the lease even if a callback restored loc.
Entering/changing containment retires the cached graph; explicit reopen rebuilds
it. Floor-page movement also rejects observed out-of-range/z excursions.
Raw persistence_set_loc notifies only this private bus after existing relocation
effects, preserving its deliberate absence of general Entered/Exited callbacks.

Targeted producers notify for actual hand switches and hand unequips, accepted
paper rename/crumple/fold/field/capacity/bundling changes, and successful legacy
erasure or canonical commits. Notifications follow committed content changes;
the existing atomic assignment section remains free of callbacks. A session's
own append exempts only itself and rotates its lease; other editors retire.
Rendering href-cache updates alone do not invalidate a session.

An optional bind_ui checks the actual controller, paper, current lease and single
UI ownership on the existing owner-checked TGUI adapter. A custom atom close-ref
is refused, and inherited machine-close logic is disabled. Existing Nano close,
logout and pre-client-transfer hooks notify before their normal early returns/
ownership changes, including sessions with no open UI. Retirement is idempotent:
clear authority/private state, unregister, then close the owned window. Callback
failure is logged without preventing peer retirement. Destruction/stat changes
also retire; unrelated movement listeners and unrelated machine state remain.

Captured old parent links and newly created current-parent forwarding chains are
pruned only when no listeners need them. Subscription/session/UI fields are
runtime-only, excluded from persistence. No record/language/text is sent through
lifecycle notifications. Existing per-section language checks/projection remain
the sole data boundary. Cancellation/retirement do not edit paper or grant XP.

Offline tests project complete selected procedures with explicit inert observer,
native list/reference, client and window seams. They test authority/state and
subscription traces, not native dispatch/GC ordering or browser delivery. Existing
core tests keep a clearly labelled no-observer seam; lifecycle tests exercise
the actual new registration/notification/cleanup bodies. Guard omissions must
produce behavioral assertions with zero preparation/test errors.

Before activation:
- Review this source, compile and run ordinary exact-head CI after publication.
- Add the player editor/action route, bind before opening, allow only guarded
  snapshot/append/cancel, and implement safe legacy fallback with no language
  write bypass or raw legacy HTML insertion into React.
- Make classified rename/crumple/fold compatible with the canonical record (or
  explicitly handle them): retirement prevents stale edits but does not repair a
  legacy mirror changed by those existing handlers.
- Validate native event subscription/counter cleanup, recursive/nested movement,
  new containment, multiple editors, exceptions, UI close/logout/pre-client body
  transfer, reconnect/reopen/cache/focus, pen replacement and physical mutations
  with real isolated clients and the canonical BYOND pin.
- Validate mixed-language nonleakage, invisible ink/signatures, cancellation,
  capacity and real save/reload without persisting session/UI/listener references.
- Review/admit a bounded native executor; no new native launch or live Gaia data
  is authorized here. Enablement/deployment remain separately held.

Arbitrary direct loc/hand/record writes that bypass the audited movement,
inventory and paper mutation APIs are not a universal interception guarantee.
Per-request fingerprints still refuse drift. Debug/admin writes or future
subtypes/producers require an adapter/audit before their activation.
Study remains a separate unimplemented dependency: durable character/text/version
progress, paced cancellable work and server-only earned reveals, without language
XP. Forms, stamp repair/templates and filing do not gate basic authoring.
