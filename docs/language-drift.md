# Language drift

Approved by Val on 2026-11-21 after a player asked whether languages evolve as
eras pass, the way Latin became French and Spanish. This file covers part 1:
drift tracking and the admin view. Splitting into daughter languages at an era
change, naming them and the language family tree come in later parts.

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
least 5 living natives).
