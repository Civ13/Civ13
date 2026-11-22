# Peoples that grow from the world

Plan approved by Val on 2026-11-21. Peoples are no longer only fixed
real-world labels with set looks: they become living groups that form where
communities settle, blend when they live together, and split after long
isolation. This keeps a character's people a story of this world and never a
target for real-world racism or Fail RP.

Code: `code/game/mob/living/carbon/human/peoples.dm`; roots and land tables in
`origins.dm` (docs/origins.md); admin verbs in
`code/modules/admin/verbs/peoples_admin.dm`.

## Records

The peoples in `origins.dm` are the roots. A people that forms in play is a
record saved with the world in `map.language_lineage_state["peoples"]`, next to
the daughter languages:

    id = list("name", "root", "parents", "language", "homeland", "nation", "year"[, "imported"])

`origin_by_id()` builds a runtime `/datum/origin` from a record, so the mother
tongue, notes, travel and admin tools treat roots and formed peoples alike. A
formed people keeps its root's name style and dress (`origin_root()`). `year`
is the world calendar year (`world_calendar_year()`: four seasons, 4 real
hours by default, the same on every land). Each `/datum/origin` also carries
`world_name` and `body_plan` (Earth, human) for peoples of other worlds later.

## Gaia's own peoples

Gaia is not Earth, so its roots carry names of the land and keep the
languages and name styles of the roots they replace:

| Climate | Gaia people | Language | Was |
| --- | --- | --- | --- |
| Tundra, taiga | Fjordfolk | Old Norse | Northmen |
| Temperate, semiarid (and default) | Hearthlanders | Latin | Latins |
| Sea | Isleborn | Greek | Hellenes |
| Desert | Dunefolk | Egyptian | Egyptians |
| Savanna | Grasslanders | Swahili | Swahili |
| Jungle | Mistwood Folk | Japanese | Yamato |

A character born on Gaia, Continents or Pangea under an old name takes the
Gaia people at their next login (`settle_people_record()`). Earth lands keep
their real peoples.

## Names

A new people's name, and a new daughter language's, must be 3 to 24 letters,
unused, and pass `config/people_names_blocked.txt`: plain words block a name
with that whole word (with common endings such as -s, -ish, -ian, -ese), and
`*` entries block a name containing them anywhere (slurs). The names of every
root people and its language are always blocked. Admins may add to the file.

## A people is never a target

No game rule reads a character's people, and examine never names it
(`tests/origins/test_origins.py`, `PeoplesAreNeverATarget`). Joining a
faction never changes anyone's people.

## Admin tools

All in the Admin tab, logged and announced to admins:

- **Check Peoples** - every formed people: parents, language, where and when it
  formed, living members.
- **Found People** - record a people by hand from any people. Nobody joins it
  until an admin uses **Set Origin**, which now lists formed peoples too.
- **Rename People** - a new name for a formed people; members' notes follow.
- **Merge People Back** - members return to the first parent and the record
  goes. Characters away at the time follow at their next login. A people that
  another formed from cannot be merged until that one is.

## Travel

A traveller carries the records of their people and every formed people it
grew from (`tongues["peoples"]`). A land that has never heard of it records it
as imported.

## Born into a community

A new character who starts among people is born into that community. The
community is every living character with a people within 40 tiles of the
start on the same level (`community_peoples()`, `PEOPLE_COMMUNITY_RANGE`); with
fewer than 3 (`PEOPLE_COMMUNITY_MIN`) the start counts as the wild. Among
people, the most common people there is the default and the player may pick
any other people living there. In the wild, nothing changes: the root of the
birthplace, or another root of the land.

A character who returns close to where the account's last one died (the
death legacy, docs/death-legacy.md) keeps that people, if it lives there or
the start is in the wild. The death record carries `"people"` for this.

## Splits after long isolation

Code: `peoples_split.dm`. Splits are rare on purpose: contact between factions
is watched, and only a nation that stays out of touch for a long time becomes
a people of its own. Research eras play no part.

A community is one nation's members of one people. While the drift tick runs,
it notes which communities had a member playing that year, and which nations
had contact with another faction or with someone of none: hearing their
speech (3 lines in a year), or standing within 10 tiles of them (trade,
visits, a shared settlement). At each new calendar year:

| That year | Years apart |
| --- | --- |
| Nobody of the community played | unchanged |
| Played, no contact | +1 |
| Played, contact | halved |

At 180 years apart (`PEOPLE_SPLIT_YEARS`, about a month of real time), with at
least 5 living members (`PEOPLE_SPLIT_MIN`) who are at least half of the
nation, the community is ready. The nation's Discord-verified leader names it
with **Name Our People** (IC tab, offered at login too), picking one of the
suggested names (see Naming below). The living members of that nation and people join the new people,
whose mother tongue is the one most of them speak natively, which may be a
daughter language. Nobody else changes.

Admins: **Check Peoples** lists every community's years apart and any waiting
split; **Force People Split** makes one ready and may name it at once.

## Blending

Code: `peoples_blend.dm`. A nation of at least 4 living members
(`PEOPLE_BLEND_MIN`) where its two largest peoples each make up a quarter of
them counts a year together for every played year (a year the mix fails
halves it). After 30 such years (`PEOPLE_BLEND_YEARS`, about 5 real days), the
nation's verified leader names a people of both with **Name Our People**. Its
parents are both peoples and its mother tongue is the larger group's. Nobody's
own people changes: the blend is the default for newcomers born among that
nation (`community_blend_people()`), who may still pick a people living there.
A nation blends the same two peoples once.

## Naming

Code: `peoples_names.dm`. A leader never types a people's name; they pick one
of three suggestions, each a word of the tongue the new people will speak
(`people_pending_tongue()`), built from two or three of that language's
syllables and seeded by what the name means:

- **Place:** the climate most of the nation stands in, such as "the people of
  the frost".
- **Trait:** one of eight, chosen by the community, such as "the steadfast".
- **Elder:** "the children of" the eldest living member's first name.

The same meaning always gives the same word in the same tongue. **Suggest
other names** gives new words for the same meanings, up to 5 times. Every
suggestion passes `people_name_problem()`, so the blocklist and taken names
still apply. The chosen meaning is kept in the record (`"meaning"`), told to
the members, and shown in **Check Peoples**. Admins still type names:
**Found People**, **Force People Split** and **Rename People** (a rename drops
the old meaning).

## Belonging

A character who plays a year in a community whose most common people is not
their own counts one year raised among that people (`people_raised`). After
20 such years (`PEOPLE_RAISED_YEARS`, about 3 real days) their notes read
"Raised among the X". That people's leader may then welcome them with
**Welcome Among Us** (IC tab, within 3 tiles), which adds "Welcomed among the X
by ..." to their notes. Both are records only: a character keeps their birth
people for life and no game rule reads either.

## Still to come

A family view of peoples beside the language families view (Fable).

## Tests

- `python3 -m unittest tests/origins/test_peoples.py tests/origins/test_origins.py tests/origins/test_travel.py`
- Native: `python3 tests/ecology_spawning/run_linux.py . tests/origins/peoples_probe.dm`
