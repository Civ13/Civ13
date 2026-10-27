# Character discoveries and berry smell

## Player behavior

Use **Smell** on berries, or the existing non-harm secondary action. The existing
reagent-derived smell is shown and a conscious living character remembers that
observation. Open **IC > Notes** to find the **Discoveries** section. Smelling the
same berry type, context and observation again does not add another entry,
even if the sample is renamed. The first learned display label is retained. A different observed smell is retained as a separate observation.
Personal notes and stored memories remain untouched and editable as before.

These entries say what a character noticed in a sample. They do **not** identify
hidden effects, prove edibility, or assert that every berry of that type has the
same composition. An injected, processed, renamed or otherwise changed sample
can produce a different observation. A changed or unavailable world berry
configuration marks old records historical; those records are not silently
rewritten into facts about the new world.

No food preference randomization, nutrition system, mood changes, or benefit
from liked meals is implemented here. Future tastes can call the same learning
API only at their actual discovery event, with a category and a context that
identifies that character's preference generation. Hidden preferences must not
be supplied to the UI or pre-populated as discoveries.

## Capacity and input bounds

Each character can retain at most **256 automatic discovery records**, of which
at most **64 can be berry-smell observations**. Repeated mixtures cannot consume
all the space intended for future tastes. At capacity a new record is rejected;
existing knowledge is never evicted or overwritten. Notes displays the relevant
capacity notice. Normal Smell chat still works, and personal notes remain
available; the automatic store does not silently claim to have saved rejected
observations. A future taste implementation must check its category coverage
against this available capacity before using the store.

All fields must be nonempty text. Limits in native DM `length()` units are:
category 64, identity 256, context 128, display label 96, observation 256.
Overlong records are rejected whole, not truncated into potentially misleading
knowledge. Rename-only repetition retains the original label and single record.

Notes inspects at most 256 stored slots, including malformed slots. It checks key
length (at most 32) and all field limits before escaping/rendering; invalid or
oversized imported records are omitted with a notice. At most 256 bounded rows
can appear, even when imported data bypassed the insertion limits. No rendering
operation prunes, rewrites or evicts saved records, including hidden over-limit
imports. These are UI/admission bounds, not retroactive repair of an already
oversized save; existing private notes/memory are outside this automatic-store
limit and are not changed.

## Source audit and integration

- `code/modules/reagents/reagent_containers.dm`: berries inherit the generic
  Smell action. `smell_description()` retains the existing reagent calculation:
  zero `taste_mult` is skipped; nutriment uses its actual data; other reagents use
  amount times `taste_mult`; only descriptors strictly above 15% are emitted.
  Empty output remains `something indescribable`. The action sends the escaped
  description, then calls an opt-in subtype hook with that **same** description.
  Secondary action passes its explicit actor, not an ambient `usr`.
- `code/game/objects/structures/berries.dm`: the berry hook requires a conscious
  living actor whose mind's current body is that actor. It records only the
  descriptor already disclosed. It never reads the hidden effect row to derive
  a safety label. Of particular importance, berry `New()` changes
  `nutriment_desc` *after* snack `New()` has created nutriment; using that field
  instead of the actual reagent data would not reproduce the existing smell.
  This implementation deliberately does not fix or reinterpret that mechanic.
- `code/datums/mind.dm`: minds represent IC characters. The nullable,
  non-static `learned_discoveries` list is allocated on the first observation.
  `learn_discovery(category, identity, context, label, observation)` rejects
  empty/non-text or overlong fields and deduplicates category, identity, context
  and observation, excluding the mutable display label. It does not
  modify `notes` or `memory`. Rendering escapes label/observation; identity,
  category and context are never rendered. Existing Notes now additionally
  requires the recipient to hold this mind reference.

The berry identity is the concrete type plus `randeffect`; a mutable display name
is only a label, not the identity. Context is an opaque MD5 of a version tag,
map type and `berryeffects`. MD5 here is a compact deduplication/change key, not a
security primitive. Neither that key nor hidden effect data is sent to the UI.
The version tag must change if the meaning of berry observations changes.

Context describes the world configuration **at observation time**, not the
sample's origin or a guarantee about its chemistry. Equal configurations share a
context, including a reset that happens to produce identical rows. This is
intentional semantic versioning, not a unique world-instance ID. Every entry is
still historical sample wording and carries the no-safety-inference notice;
matching a context must never be used to label new berries safe.

## Character lifecycle and persistence

`mind_initialize()` preserves an existing mind on reconnect; `transfer_to()`
preserves it when the same IC character changes body. Normal respawn goes through
`abandon_mob()` into a new lobby whose Login creates a fresh mind. No client or
account preference field receives discoveries. The ghost keeps the existing
corpse-mind reference, as with the pre-existing Notes behavior.

The custom world serializer's generic datum path includes non-initial fields,
and its typed encoder supports nested associative lists. Starting
`learned_discoveries` at null makes learned data a non-initial field. The saved
human references its mind; normal saved-body reclaim returns that same body and
mind graph. Legacy minds with no field remain empty. Durable metadata already
saves `berryeffects`, so restoring the same configuration preserves the context.
No save schema, map policy, ownership/admission rule, or reclaim fallback changes.

The reconnect, respawn and full saved-body reclaim descriptions above are
audited source contracts. The narrower native mind-graph round-trip described
below has now passed; it does not establish full-body reclaim or live reconnect.

## Verification and remaining acceptance

Run the focused offline suite:

```sh
python -B tests/character_discoveries/test_discoveries.py -v
```

It executes fail-closed line-by-line Python projections of the actual learning
and rendering procedures and source contracts for smell, privacy, lifecycle and
serializer integration. It covers empty knowledge, deduplication, distinct
observations, two minds, legacy data, invalid inputs, escaped text, version
changes, a future category, repeated renames, field boundaries, both capacity limits,
malformed imported keys/rows, bounded escaped output and no-eviction behavior. The JSON round-trip checks only record data
shape; it is **not** BYOND JSON parity, native savefile persistence, browser UI,
or full gameplay acceptance. Unknown projected statements fail rather than being
ignored. This offline suite does not launch a native server or compiler.

### Recorded native evidence

A one-shot hosted test passed against feature head
`9c54e1b57097035d51c35e4ea9cb755e7aa12a92`, using controller commit
`f13308820a5a9d95a564b2f49575ef9a20fbc61b`:
[run 40215733119](https://github.com/Civ13/Civ13/actions/runs/40215733119).
The controller is isolated test tooling, not a production gameplay change.

- BYOND **516.1688**: five fixture variants compiled with zero errors/warnings;
  seven daemon phases completed, with verified owned-process cleanup for all
  twelve compiler/daemon invocations.
- Baseline: **43** ordered round-trip assertions, **4** writer assertions and
  **11** assertions in a separate fresh reader process. Production berry
  `smell_for()` and the explicit-actor secondary action exercised actual reagent
  descriptions, observation-before-learning, hidden-configuration non-disclosure,
  private Notes ownership/escaping, deduplication and capacity/input bounds.
- Four causal controls each failed its exact expected assertion: disabled smell
  recording, disabled learned-label escaping, removed overall capacity check,
  and omitted discoveries from the production generic serializer.
- Production `mind_initialize()`/`transfer_to()` retained knowledge; fresh minds
  stayed empty. Production generic mind/list serialization preserved learned
  records and private notes across writer/reader processes. Restart file hashes
  matched after verified writer cleanup.
- Independent offline replay verified **226 retained files**, the pinned
  source/controller hashes, generated overlays, exact ordered native oracles,
  restart receipts and cleanup. Owned readiness listener snapshots were empty;
  this is not a continuous global no-listener claim.

This fixture is deliberately headless. Only the chat/Notes output sinks and
Notes client-presence check were adapted; real connected-client rendering and
`usr` verb routing were not exercised. Inert human construction skips normal
physiology. The saved mind graph deliberately detaches body references, so this
is **not** full-human save/reclaim, live reconnect, or real lobby respawn
acceptance. No production smell calculation or hidden berry effect was changed.

### Remaining gameplay acceptance

The recorded run does not close the following broader checks:

1. Full production startup and gameplay behavior beyond the isolated compiled
   fixture; normal physiology and connected-client routing remain untested.
2. Actual Smell and secondary-click behavior, including 15%/just-over-15%,
   zero-strength, missing reagents and indescribable output. Compare chat and
   Notes using plain, mixed and injected samples without revealing hidden rows.
3. Repeated observations do not duplicate; independent characters remain empty;
   Add Note, role notes and memory edits survive discovery and Notes reopening.
4. Native production save/load/reclaim retains the mind's records; legacy saves
   stay empty; same-character reconnect and body transfer retain knowledge;
   fresh respawn does not inherit it. This requires the real world serializer,
   not a replacement list serializer.
5. Restored berry configurations keep their context; a genuinely different
   configuration marks previous entries historical. Equal rows must never
   produce a claim of safety or sample provenance.
6. A real connected client's Notes window displays escaped malicious labels and
   descriptors as text, never markup, and does not show another mind's records.

The recorded evidence does not authorize another native run or merge. No
account/security or Gaia changes are part of this feature.
