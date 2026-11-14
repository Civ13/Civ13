# Per-use divine approval foundation

Scope: a disabled, server-only, runtime-only authorization state machine.
Publication is authorized in public source; in-game discovery remains restricted
to eligible players. This foundation does not implement that presentation layer.
Stop after opening a draft PR and reporting exact-head checks; no merge or deploy.

No UI, prayer routing, magic effect, cipher book or feature activation is added.
The file is not included in civ13.dme yet. This is a reviewable foundation, not
an implemented player feature. The native probe includes production source
explicitly. No production object creates a covenant or request.

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
- Full game inclusion/build/preflight, real-client visibility and audit tests.

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

## Wizard gear stays ordinary (`test_mundane_gear.py`)

Val's rule (2026-11-14): on persistent worlds a wizard's gear must look like
ordinary items to everyone (name, description, sprite, examine text). Magic
comes from the wizard, not from a unique item type; a sharpened stick can serve
as a wand, and any decoration on it is a cosmetic change anyone can make to any
item. The only exception is a god's original book.

Audit at the time of writing: no wizard gear is reachable on persistent worlds.
Wands, wand parts, robes, potions, brooms and magic swords belong to Wizard Boy
and a few fantasy round maps, and every drop of a wand part from ordinary
objects (tables, beds, branches, pigeons) is gated to Wizard Boy. The test keeps
it that way: no magic-module type on persistent-world maps (`maps/nomads`,
`maps/sea`, `maps/space`) or in crafting recipes, magic recipes stay on Wizard
Boy, and code outside the module only creates magic gear behind a Wizard Boy
check or in the listed round-map files. Run
`python3 -m unittest tests.divine_approval.test_mundane_gear -v`.
