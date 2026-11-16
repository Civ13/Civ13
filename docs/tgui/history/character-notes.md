# Character Notes presentation

This independent reader slice uses the existing modern adapter for the IC Notes
verb. It changes presentation only: stored notes/memory bytes, Add Note prompts,
admin memory editing, discovery learning, save formats and gameplay are unchanged.
The source baseline is master `fb0e5c41cd4fc7f399cb6cf90d7dbf9cb6741c62`.
It does not depend on the unmerged Photo Viewer proposal.

## Conservative compatibility contract

Each explicit open first builds the complete original classic HTML snapshot,
including exactly one call to the existing filtered `discoveries_html()`.
The modern model accepts only text, balanced attribute-free `b`/`i`, and `br`.
Case-insensitive tag names and normal trailing whitespace/self-closing breaks
are accepted. Text is decoded exactly once as inert React text. Named entities
are limited to `amp`, `lt`, `gt`, `quot`, `apos`, `AMP`, `LT`, `GT`, `QUOT` and
valid decimal numeric references; unknown, ambiguous or unsupported forms use
classic rendering. No new markup dialect or raw HTML insertion is introduced.

One unsupported, malformed, improper/control-containing, excessively nested or
over-budget fragment selects the **complete original classic snapshot**. There
is no partial modern result and no truncation or repair of saved content. The
aggregate limits are 65,536 native `length()` units, 2,048 structural/run nodes,
and 32 nested emphasis tags. The frontend independently caps 65,536 UTF-16 text
units and 2,048 nodes. These units are deliberately distinguished: a conservative
frontend rejection also requests classic fallback through the existing root
error boundary. Offline character/UTF-8 indexing projections are boundary probes,
not proof of BYOND Unicode/JSON parity.

The cached classic snapshot stays server-side. Unsupported content is not sent
as a partial modern model. Capability, startup, manual or malformed-payload
fallback returns that exact snapshot through the reader subtype; it does not
parse it into a new HTML host or add scripts/authority. Existing classic HTML
behavior is retained. Reopening Notes explicitly refreshes the snapshot; manager
updates only check status. Classic fallback remains sticky for that UI instance.

## Ownership and lifecycle

Admission remains `recipient.mind == src` with a client. An owner-only update
state binds both the reader mob and mind and rechecks before any HTML delivery.
Ghosts retaining their mind reference keep access, without requiring that the
mind's current body equals the reader. Another mob/body cannot inherit this
lease: after transfer the new body must explicitly reopen its own Notes view.
Logout or mind reassignment invalidates the lease. No private data is broadcast.
The original discovery filter supplies only its existing visible labels,
observations and warnings, including historical observations; internal keys,
identities and context are not added to the model. Invalid/over-limit records
retain their original omission notices and remain stored unchanged.

There are no domain actions or new asynchronous prompts. Closing is the reader's
cancel operation; it clears the cached snapshot, unregisters through the parent
and invalidates its generation. An idempotent reader-local close prevents a late
old close callback from clearing a newly reopened window. The inherited
`using_object` close side effect is disabled, preserving unrelated machine use.
Existing adapter owner/status/generation and handshake guards remain unchanged.
The fixed optional presentation hook lets existing isolated core-mind fixtures
continue using the original renderer without importing the UI subsystem.

## Verification boundary

Focused offline tests cover parser/entity/malformed/depth/Unicode/aggregate
limits, read-only ownership, ghost/transfer/logout, snapshot preservation,
idempotent close and the exact original classic builder preimage. The existing
25 discovery contracts remain required. Component tests and the production
bundle/browser smoke exercise formatted inert text, Unicode, replacement of old
snapshots and malformed-payload fallback. Browser transport is simulated.

No BYOND compiler, DreamDaemon, DreamSeeker, native client or live server was
run for this local candidate. Native asset/cache delivery, actual Topic routing,
close/focus/movement, ghost and transfer sequencing, Unicode behavior and
concurrent-window noninterference remain unverified. Publication, merge and
deployment require the next review step; this document does not claim them.
