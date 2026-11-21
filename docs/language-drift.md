# Language drift

Approved by Val on 2026-11-21 after a player asked whether languages evolve as
eras pass, the way Latin became French and Spanish. Part 1 tracks drift;
part 2 splits drifted communities into daughter languages; part 3 shows
language families in Check Known Languages.

Val, 2026-11-21: eras follow research, which players drive, so splits are not
tied to eras. Drift must be rare: nations that meet each other are observed by
each other and do not drift; only a nation isolated for too long does.

## Speech communities

A speech community is one nation's native speakers of one language: members
of a `civilization` whose mother tongue (their people's language, else their
default) is that language. Nationless characters belong to no community.

## What moves drift

Only heard speech counts (`hear_say.dm` calls `language_drift_heard`). A line
counts for the listener's community when the listener is in a nation, at most
one line every 20 seconds per listener:

- a line in the listener's mother tongue from a member of the same nation is
  **use**;
- a line in any language from anyone outside the nation (another nation or
  none) is **contact**.

Every half hour each community moves:

- 3 or more contact lines: drift falls by 5, and the split hold restarts;
- otherwise 10 or more use lines: drift rises by 0.25;
- otherwise nothing changes. A language nobody speaks does not change.

A nation cut off from everyone needs about 120 hours of its own talk to reach
the split level of 60, and one half hour of real contact undoes 10 hours of
it. One or two passing lines from a stranger are not contact.

Numbers are `LANGUAGE_DRIFT_*` and `LANGUAGE_SPLIT_*` in
`code/__defines/species_languages.dm`.

## Saving

Drift is saved with the durable world metadata in the map field
`language_lineage_state` (durable map field version 6) as
`list("drift" = list("Nation|Language" = drift), "daughters" = list())`.
Older saves restore it empty. Lines heard since the last half-hour update are
not saved.

## Admin view

Admin > **Check Language Drift** lists every community with drift, its living
native speakers, and whether it is ready to split (drift at least 60 and at
least 5 living natives, held for 7 days without contact), and those waiting
for a name.

## Splitting after long isolation (part 2, `daughter.dm`)

After every drift update, `language_split_check` records when a community's
drift first reached 60 (`["held"]`, in real minutes). A community that stays
there for 7 real days with no contact tick, and has 5 living natives, becomes
**ready to split**, unless its root language already has 2 daughters on this
world. Contact, or drift falling below 60, restarts the wait. Research and
eras play no part. Members are told; the
nation's leader gets **Name Our Language** (IC tab), which needs a
Discord-verified account. Naming is the split. An admin can make any
community ready, and name it, with **Force Language Split**.

At the split:

- the daughter is a runtime `/datum/language/daughter` registered under its
  own name, with its own two-letter say key and its parent's syllables run
  through 3-5 sound changes picked by a seed from its name;
- the nation's living natives get it at their score in the parent; it becomes
  their mother tongue (`native_tongue`) and default language; they keep the
  parent;
- parent and daughter follow 80% of each other; the parent's relatives follow
  the daughter at their share of that; sister daughters at least 60%;
- the community's drift starts again at 0.

A daughter community that holds a drift of 60 again for 7 isolated days does
not split again: it loses 10 kinship with its parent (never below 40) and its
drift halves.

Daughters write in their root language's script, so papers stay readable.
Every daughter shares one type, so identity checks use `language_same` and
kinship tables use `language_kin_key` (name for daughters, type otherwise).

Records are in `language_lineage_state["daughters"]`; ready communities in
`["pending"]` (when they became ready), communities waiting out the hold in
`["held"]`. A traveller carries the records of the daughters they know, and
a land that has never heard of one saves it as `imported`, which never counts
towards that land's cap.

`tests/language_drift/probe.dm` drives this natively:
`python3 tests/ecology_spawning/run_linux.py . tests/language_drift/probe.dm`.

## Language families (part 3)

Check Known Languages adds a **Language families** section when one of the
player's languages has relatives on this world: one card per root language,
its daughters indented under their parents with the nation and era they grew
among, the player's own languages marked (mother tongue, speaks it, learning),
and how much each pair follows of the other in plain words. Data comes from
`language_family_rows()` (daughter.dm) as the `families` key; kinship is the
lower of the two directions rounded to 5, and drift is never sent. Layout by
Fable.

## Undoing and renaming (part 4, `daughter_admin.dm`)

Admins can **Merge Language Back**: everyone in the world who has the daughter
keeps the better of their two scores in its parent, gets the parent back as
mother tongue and default where the daughter was, and the daughter's record,
say key, kinship, drift and any wait to split are forgotten. A daughter with
daughters of its own is merged only after them. **Rename Language** moves
scores, mother tongues, today's learning, notes, kinship, drift and child
records to the new name. Travellers already in another land keep the old
name there.
