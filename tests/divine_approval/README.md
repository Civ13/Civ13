# Per-use divine approval foundation

Scope: a disabled, server-only, runtime-only authorization state machine.
Publication is authorized in public source; in-game discovery remains restricted
to eligible players. This foundation does not implement that presentation layer.
Stop after opening a draft PR and reporting exact-head checks; no merge or deploy.

The approval foundation adds no UI, prayer routing, magic effect or feature activation.
The journal slice below is separate from that approval foundation.
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

## Ordinary-book sealed ledger slice (2026-11-14)

`journal.dm` is included in the game and adds no new item type. Every ordinary
book retains its original appearance, name, description, inventory behavior,
writing, copying, printing and research interfaces. Optional sealed advancement
entries live separately from public `dat`, written pages and research chapters.
The existing content reader requests an authorized projection only; outsiders
receive exactly the prior public content, with no marker, count or extra menu.
Ordinary copies reproduce public content only, not sealed entries or permission.
A copy is not a new covenant or source of magic power. Destruction still destroys
the physical book; this slice is not an authoritative character progress store.

The default `can_read_divine_journal()` hook returns FALSE for everyone, including
admins. There is no provisioning UI, automatic journal creation or grant.
Integration with durable character initiation and progression is unfinished;
this is safe ordinary-book groundwork, NOT a playable magic research system.
Do not replace the hook with possession, a password, browser data or account-wide
staff privilege. Bind eligibility and revocation to the actual character.

The server-only `record_divine_advancement` API stores at most 32 entries with
80-character titles and 1024-character notes. Reads/writes recheck authorization.
Plaintext is HTML-escaped and only projected after that check. It never enters
ordinary cipher, copying, printing, study, chapter or public Atlas data. Writing
an entry does not teach, request, approve or cast a spell. Physical ledger data
uses ordinary item persistence; native save/load acceptance remains unverified.
Already disclosed text cannot be erased from a former reader's memory/window.

The latest requirement that magical gear look and behave like ordinary gear
superseded the initial standalone-journal prototype. No special journal subtype
or conspicuous deciphering interaction is published. The following are deferred:

- Durable initiation, character progress, patron ownership and revocation.
- A cipher-writing facade shared with ordinary books: mathematicians can attempt
  interpretation without gaining sealed knowledge or being told it is impossible.
  Existing normal ciphers gain real progress and show chapter metadata, so they
  cannot safely be reused unchanged for this purpose.
- Revealed chapters, material costs and advancement events from actual gameplay.
- Per-use spell requests, immutable effect/cost scopes and approved dispatch.
- Channelled group rites, participant validation and interruption handling.

Run `python3 -m unittest discover -s tests/divine_approval -v` for source contracts.
`journal_probe.dm` provides DM assertions with a test-only initiation override;
include after `probe.dm` in a reviewed isolated full-game fixture and explicitly
invoke `divine_journal_probe()`. Neither file is a runner or network sandbox.
No unrestricted native launch is authorized. Real-client UI, lifecycle revocation,
save/load and regional transfer are still acceptance work, not passed checks.

## God's book (`code/modules/divine/divine_book.dm`)

Included in the game build; the verb lives in `code/modules/admin/verbs/divine_book.dm`. Staff playing a god use the admin verb Write God's
Book to write that god's one original and hand it to a player (or drop it where
they stand). While an original of that god (matched by name, ignoring case)
exists anywhere in this world, including restored from a save, another cannot
be written; burning, destroying or deleting it frees the god to write a new one,
and staff are told when it is gone. The verb waits while a save runs or a load
is still restoring characters. Players can copy the original with a printing
press or a monk, which makes an ordinary book containing only public pages.
Ordinary writing, research, cipher and page-removal interactions remain unchanged. `test_divine_book.py` guards these rules from source.


## Ordinary-book confidentiality correction (2026-11-14)

The original-book subtype remains only for durable registry compatibility. It
inherits ordinary book appearance, examination and editing; new originals do not
label the author as a deity. Staff choose a mundane public title and optional
public pages separately from private contents. The latter are saved outside
`dat` and `written_pages` and shown only through the fail-closed initiation gate
introduced in #5154. Until that service is implemented, nobody can read them.
This change does not enable spells or grant initiation.

On `after_load`, an older original preserves both legacy `dat` and a copy of
`written_pages` in private saved fields before clearing their public projection.
The saved migration flag makes this one-time, preserving subsequent ordinary
writing. Only exact automatically generated author/description values are
cleared; chosen cover titles and other metadata are not rewritten. Legacy HTML
is escaped for private display. Ordinary printing, monk copying and torn pages
copy public material only, never private notes or original status.

Already distributed ordinary copies and text already read cannot be recalled or
identified reliably. Staff must inspect old chosen titles separately if they
reveal secrets. Live migration, native round trips, regional transfer and client
rendering remain unverified; no operational migration is performed by this PR.
