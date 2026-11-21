# Language drift

Approved by Val on 2026-11-21 after a player asked whether languages evolve as
eras pass, the way Latin became French and Spanish. Part 1 tracks drift;
part 2 splits drifted communities into daughter languages at an era change.
The language family tree comes in part 3.

## Speech communities

A speech community is one nation's native speakers of one language: members
of a `civilization` whose mother tongue (their people's language, else their
default) is that language. Nationless characters belong to no community.

## What moves drift

Only heard speech counts (`hear_say.dm` calls `language_drift_heard`). A line
counts for the listener's community when the listener is a native speaker in a
nation, at most one line every 20 seconds per listener:

- a line from a member of the same nation is **use**;
- a line from a Conversational speaker of another nation, or of none, is
  **contact**.

Every half hour, each community that heard at least 10 lines moves by
`0.5 * (1 - 2 * contact share)`, kept between 0 and 100. A nation that only
talks among itself gains 1 drift an hour of talk, so about 60 hours to reach
the split threshold of 60. Hearing outsiders in a quarter of its lines halves
that; above half, drift falls back. A language nobody speaks does not change.

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
least 5 living natives), and those waiting for a name.

## Splitting at an era change (part 2, `daughter.dm`)

When the world enters a new era (a capstone in `book_research_node_finished`
or `complete_node`), `language_era_advanced` makes every community with at
least 60 drift and 5 living natives **ready to split**, unless its root
language already has 2 daughters on this world. Members are told; the
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

A daughter community that drifts past 60 again does not split again: at the
next era change it loses 10 kinship with its parent (never below 40) and its
drift halves.

Daughters write in their root language's script, so papers stay readable.
Every daughter shares one type, so identity checks use `language_same` and
kinship tables use `language_kin_key` (name for daughters, type otherwise).

Records are in `language_lineage_state["daughters"]`; ready communities in
`["pending"]`. A traveller carries the records of the daughters they know, and
a land that has never heard of one saves it as `imported`, which never counts
towards that land's cap.

`tests/language_drift/probe.dm` drives this natively:
`python3 tests/ecology_spawning/run_linux.py . tests/language_drift/probe.dm`.
