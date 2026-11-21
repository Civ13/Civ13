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

## Still to come

Born into a community (new characters take the people of the settlement they
start in), splits after long isolation with little contact between factions,
blending in mixed settlements, "Raised among", and a family view of peoples.

## Tests

- `python3 -m unittest tests/origins/test_peoples.py tests/origins/test_origins.py tests/origins/test_travel.py`
- Native: `python3 tests/ecology_spawning/run_linux.py . tests/origins/peoples_probe.dm`
