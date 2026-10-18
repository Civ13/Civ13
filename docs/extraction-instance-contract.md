# Shared extraction instance contract v1

Status: inactive foundation extracted from the legacy PR #3082 proposal. `instances.dm` is deliberately
not included in `civ13.dme` yet. No runtime activation, world resizing, disk
durability, map projection, or serializer integration is implemented here.

The logical record has exactly six fields: `schema` (1), `instance_id`,
`party_id`, `kind` (`dagger` or `safehouse`), `template_id`, and positive integer
`template_revision`. IDs contain 1-64 ASCII letters, digits, underscores or
hyphens. The caller supplies durable party identity; temporary raid groups in
`groups.dm` are not that identity. Coordinates and map generation are excluded.
One party may have more than one logical record; this slice sets no home-count,
membership, bed, life, respawn, refill or travel policy.

The template descriptor has exactly seven fields: `schema` (1), `template_id`,
`revision`, `width`, `height`, ordered `decks`, and `berths`. Each deck has exactly
`layer` (contiguous 1..N) and unique `id`. Berth IDs are unique. Dagger requires
four decks and two berths. The confirmed map ABI is `dagger_home_draft_v4`,
revision 1, width 30, height 102, decks `ground`, `upper_1`, `upper_2`, `roof`,
and berths `raid_west`, `raid_east`. Manifest schema 2 is not template revision 2.
Relative local z 0..3 maps to descriptor layers 1..4. Template footprint is
inclusive `[0,0,29,101]`.

`extraction_instance_limits` supplies configurable implementation budgets,
defaulting to 32 instances, 512 tiles width/height and four decks. Safehouse
validation currently permits 1..max_decks and zero to two berths. These are
validator limits, not promises about a finished safehouse design. Templates
outside them fail closed. Bounds and limits are trusted configuration inputs;
callers must retain one registry for the entire allocation scope, keep its
configuration immutable while leases exist, and not edit its internal tables.

Private homes reserve whole inclusive z intervals. Two parties cannot share a
home z interval even when XY footprints differ. Rectangles must fit the supplied
world bounds. Identical acquire requests return the same opaque handle; a changed
request for the same logical instance fails. Release requires the current handle,
map ID and fresh map-load generation. Replayed, old-generation and prior-registry
handles fail. Generation must identify each new runtime map incarnation, including
reloads of the same save. It must never be reused from a save's generation field.
Release retains the immutable logical record and template binding: the same ID
can relocate with a fresh lease, but cannot change party, kind, template revision
or template geometry. The instance budget counts bound logical IDs over the
registry's lifetime, including released homes, so churn cannot grow that table
without bound. The caller must seed a fresh registry from its validated ledger;
the registry does not authenticate caller-provided identities itself.

Destination berth occupancy is separate from private-home reservations. Its key
is destination identity plus `raid_west` or `raid_east`; each has its own token.
Occupying one leaves the other available. It is an exclusive claim, so another
acquire of an occupied berth fails; only private-home acquire is idempotent.
This is an occupancy primitive pending a transaction wrapper with authenticated
owner/request identity for safe acquire replay.
These claims do not validate geometry. Dagger's demonstration destination berth
origins `[72,72,5]` and `[130,72,5]` share z 5..8, with padded XY reservations
`[66,66,107,179]` and `[124,66,165,179]`. Those clearance rectangles are not the
30x102 template footprint. Demonstration side-by-side home placements are not
production home allocation policy. Map masks, anchors, projection collision,
physical travel versus portals, and berth-to-home routing need a later explicit
contract with the map owner.

The ledger exports a strict `{schema:1, instances:[...]}` logical snapshot and
validates a whole replacement before mutation. Snapshot copies detach caller
data. This JSON-compatible model is not a disk transaction. A future adapter must
persist logical records, validate templates, reconstruct all physical leases in a
fresh registry, and only then permit object decode or relocation. Never serialize
the runtime registry, opaque handles or occupancy tables through the general
world saver. Integration requires explicit runtime exclusions and the existing
custody/retirement fences; this source slice changes none of them.

Offline preparation checks:

```powershell
& 'C:/Users/valza/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -m unittest discover -s tests/extraction/instances -p 'test_*.py' -v
```

`prepare.py --prepare-only --output <new-directory>` freezes the exact production
source and standalone fixture, with SHA-256 inputs. It never launches a compiler
or daemon. The fixture covers two parties with disjoint four-deck homes, logical
JSON reconstruction before future decode, occupied/free berth independence,
stale/replayed handles, unknown schema/fields, missing/duplicate decks, bounds,
budgets, and zero mutation on rejection. Native compilation/execution and disk
roundtrips remain unrun until a fresh bounded test grant. Offline packaging tests
do not establish DM semantics or gameplay acceptance.

## Standalone CI proposal

`tests/extraction/instances/run_ci.py` reads the production model and authored
probe from exact full-SHA Git objects. It adapts only the include path in temporary
output, preserving the committed model and probe. `--prepare-only` writes a new
directory containing the baseline and generated mutation cases without invoking
BYOND. Native execution is admitted only on the separate ephemeral Linux CI job
using its pinned BYOND directory and a new child of `RUNNER_TEMP`.

The baseline must report all 35 unique authored assertions and the successful
terminator. The overlap control must fail `XY-separated homes cannot share z
interval`; the generation control must fail `wrong scope acquire rejected`.
Both controls must still report the complete assertion set and their matching
failure count. Other failed assertions are reported separately as collateral;
the acceptance oracle requires the named target, rather than claiming a frozen
complete native failure set. Diagnostic, compiler, process, timeout and missing-result failures
invalidate evidence. Synthetic oracle tests verify rejection logic only; they
do not establish that either mutated DM program has run.

Each compiler has 60 seconds wall time, 30 CPU seconds and 1 GiB address space;
each daemon has 30 seconds wall time, 15 CPU seconds and 128 MiB address space.
The entire native sequence has a 300-second deadline. Each child has a 16 MiB
per-file limit, disabled core dumps, and its own process group. The leader stays
unreaped until group cleanup, preventing a reused PID from receiving cleanup.
Source manifests, generated cases, binary hashes and logs are retained. No
current host files, full-game startup, external account service or client is
part of this test. See [CI selection](ci-selection.md) for admission and limits.

## Offline map ABI adapter

`tests/extraction/instances/map_adapter.py` validates the strict seven-field
descriptor against the map owner's explicit template revision and calculates
both destination projections. It performs no runtime allocation or movement.
Its fixture `dagger_map_abi.json` was extracted from immutable map-owner commit
`d1cdc2c426799687b98ccd2a846bcc045c1cb8fa`:
`maps/WIP/dagger_train_home.template.json` and the relevant geometry fields of
`maps/WIP/dagger_train_home.layout.json`. The fixture records the SHA-256 of both
original files. These provenance hashes describe that source extraction; the
offline test does not fetch or verify another checkout's present state.

West origin `[72,72,5]` projects through `[101,173,8]`; east origin `[130,72,5]`
projects through `[159,173,8]`. Each has four decks and 12,240 cells, fits its
reserved clearance and world bounds, and does not overlap the other destination.
Template revision 1 remains distinct from manifest schema 2. Malformed revision,
deck order, coordinates, clearance and overlap fail without changing the inputs.
The map's example home placements do not define production home privacy.

## Integration boundary

The legacy extraction proposal at commit
`52963b5e1f873a08838fa1d5948320c7e3e5e384` has account-private homes, an ephemeral
deployment party and a server-wide vote for the next round. Those legacy modules
are not part of this foundation PR. It does not yet have stable
party identity, a party-selected live raid, shared home ownership or occupant
travel through this registry. The destination preflight in `groups.dm` must
remain before group journal submission; existing bodies and item graphs move
only after durable debits commit. Invalid or full destinations must leave the
accounts and occupants home. Postcommit interrupted travel requires an explicit
recovery state, with no inferred refund or duplicate loadout.

Stable roster lifetime, party ballot electorate, party versus account home
privacy and partial-return/failed-travel lease release remain design decisions.
Neither this descriptor adapter nor the logical lease snapshot supplies them.
The next integrated test must combine two accounts, a stable roster, a chosen
live destination, the real berth adapter and original occupants across outward
and return travel, including pre-receipt rejection and post-receipt interruption.
Existing per-account extraction, forfeiture, loot and insurance authority stays
the baseline for that work. Native and physical-travel acceptance remain unrun.
