# Per-use divine approval foundation

Scope: a server-only, runtime-only authorization state machine.
Publication is authorized in public source; in-game discovery remains restricted
to eligible players. This foundation does not implement that presentation layer.
Stop after opening a draft PR and reporting exact-head checks; no merge or deploy.

No UI, prayer routing, magic effect, cipher book or feature activation is added.
The approval and ritual datums are included in civ13.dme for full-game compiler
coverage. No production object creates a covenant or request, so this is a
reviewable foundation, not an implemented player feature.

Each requested use requires its own explicit deity-operator approval. Granting
knowledge alone is not sufficient. Request fields and the effect/cost scope ID
must be created by a trusted server adapter, never populated from browser data.
The same client, body, origin tiles, covenant revision, spell and target are
required when consuming it. Current mismatches, revocation, expiry and second
consumption fail closed. Checks are snapshots, not a lifecycle event history:
moving out and back or temporarily losing then regaining a role/client can be
invisible unless the adapter invalidates the covenant revision on that event.
Integration MUST invalidate on movement, logout/body switch, role/operator change
and every region-transfer boundary, including returns to the same coordinates.
These runtime objects do not survive restart. No lifecycle hooks are added here.

The future adapter must validate gameplay eligibility/resources and perform
consume, charging and effect dispatch without sleeping between them. This file
is not a resource transaction engine and must not be represented as one.
Operator disconnect currently invalidates approval; persistent approval while an
operator is offline is intentionally unsupported. Denied/consumed requests must
be retained by the future audit owner as needed, then explicitly qdeleted.

## Verification

Run `python3 -m unittest discover -s tests/divine_approval -v` for structural
contracts. These source checks are not runtime or gameplay proof.

`probe.dm` defines a native behavioral probe procedure with stubbed connection/
authorization boundaries; it is not a standalone world and does not invoke
itself. A reviewed isolated harness must include it and call
`divine_approval_probe()` instead of normal world startup. Compile with the pinned
compiler after the game, following the isolated-fixture guide. Do not simply
launch a full game with this file appended. It must not run without OS-level
initial-bind and outbound-network containment. This task does not authorize
launching the existing unrestricted native runner.

## Remaining integration gates

- Durable deity/covenant identity, server-owned permission assignment and revoke.
- Per-use beseeching inbox, all-god channel, divine-name alerts and direct reply.
- Antagonist/secret-society rules and initiated-only projections without concrete
  confirmation for outsiders. Generic failures must not falsely claim progress.
- Cipher advancement books: server-side authorization before plaintext/content
  projection and every progress write. Mathematicians may recognize or attempt
  the cipher without magic eligibility or progress. No client-hidden plaintext.
- Influence from active followers, including unaware faction subordinates,
  contribution caps, persistence and exactly-once transfer.
- Native channel tests, real-client visibility and audit tests.

## God's book (`code/modules/divine/divine_book.dm`)

Included in the game build; the verb lives in `code/modules/admin/verbs/divine_book.dm`. Staff playing a god use the admin verb Write God's
Book to write that god's one original and hand it to a player (or drop it where
they stand). While an original of that god (matched by name, ignoring case)
exists anywhere in this world, including restored from a save, another cannot
be written; burning, destroying or deleting it frees the god to write a new one,
and staff are told when it is gone. The verb waits while a save runs or a load
is still restoring characters. Players can copy the original with a printing
press or a monk, which makes an ordinary book; only the god writes in the
original. `test_divine_book.py` guards these rules from source.

## Group channel contract (2026-11-14)

`ritual.dm` extends one approved request rather than issuing a second token. It
copies an explicitly enrolled roster (proposed prototype: leader plus two to
seven other conscious, connected players), locks their session/body/origin and
an ordinary held focus, and requires same-z visibility within at most three tiles.
These counts, radius and a default 30-second channel are balance proposals, not
user-mandated final values. No special magical item identity is introduced.
NPC crowds, disconnected bodies and duplicate sessions are rejected. Enrollment
is an adapter obligation: proximity alone never consents a player to a rite.
Unaware followers can join a mundane-facing ceremony without learning its purpose.

`start_channel()` needs explicit prior approval with enough lifetime remaining;
it never refreshes the original expiry. `consume()` checks elapsed channel time,
current context and the parent's exact-target/scope, approver and single-use
checks. It does not charge slots/resources, heal, harm, or dispatch any effect.
There is no per-frame loop or timer. A future bounded scheduler must call
`current()` and send `invalidate_channel()` on movement, hand change, logout,
body switch, role/covenant changes, incapacitation, transfer and save boundaries.
Snapshot polling alone cannot detect leave-and-return between observations.
Pending/channelling/approved state must never be restored after restart.
The adapter owns cleanup of terminal requests and retains audit evidence first.

`ritual_probe.dm` supplies optional actual-DM assertions with stubbed connection
boundaries; include after `probe.dm` in an authorized isolated fixture and invoke
`divine_ritual_probe()`. Its manual clock-boundary assertion is not a duration or
scheduler measurement. No native fixture is launched by offline tests or CI
admission in this change. Full-game compile covers the production types only.

### Playable integration and initial spell plan

The ledger is not authority to cast; initiation, patron-granted learning and
per-use permission remain independent. Build the shared adapter before effects:

1. Resolve a durable character/covenant and a learned invocation server-side.
2. Select target and, for a rite, explicitly enrolled participants and held
   ordinary focus. Freeze effect version, intensity, duration and cost in the
   server-generated scope specification shown to the patron.
3. Patron approves that one request. A different roster, target or cost needs a
   new request. Never expose hidden details to unauthorized reader projections.
4. Start the channel, hook all cancellation boundaries, and check legality/costs.
5. Revalidate, consume permission, charge resources and dispatch synchronously
   without a yield. Failure after consumption cannot silently refund permission.
   Add idempotent effect/audit receipts before connecting persistence or recovery.

Proposed first invocations (none implemented by this PR):

| Invocation | Effect and delivery | Limit |
| --- | --- | --- |
| Mercy | Touch-channel modest pain/exhaustion relief | Not injury repair, organ regrowth or resurrection |
| Affliction | Short visible-target weakness/pain | Bounded duration/magnitude, ordinary symptom messages |
| Omen | Patron-authored private clue | No automated omniscient tracking or secret fact lookup |
| Vigil of Recovery | Group channel around one patient | Bounded support through existing recovery rules, not universal cure |

One spell slot plus fatigue and qualified rest recovery are initial cost
proposals. Recovery belongs to character state, not book replacement/copying.
Keep ordinary Wizard Boy spells separate: their public names, projectiles,
`revive()`/`gib()` and unrestricted dispatch violate this system's constraints.
Disease rites require later immunity, treatment, contagion, offline protection
and persistence tests. Weather rites need capped footprint/lifetime and actual
moving-storm validation. Book-burning rites additionally need provenance and
anti-copy farming; destroyed physical books cannot be implicitly refunded.
