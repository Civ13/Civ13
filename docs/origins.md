# Peoples and origins

A new character on a Nomads land belongs to one people for life. The people
gives the mother tongue, a style of name and the usual hair, eye and skin
tones. The character records `origin_id` (the people) and `origin_land` (the
land of birth); both are saved with the character and shown under **Origin**
in the character's notes.

All of it is data in `code/game/mob/living/carbon/human/origins.dm`:

- `/datum/origin` - one people: `id`, `name`, `language`, `name_style`
  (`species.get_random_[name_style]_name`), `hair`, `eyes`, `skin`.
- `land_origin_tables()` - map ID to `climate = origin id`, with a `default`
  row for climates the land has no people for.

| Land | Peoples |
| --- | --- |
| Gaia (also Continental, Pangea) | Northmen, Latins, Hellenes, Egyptians, Swahili, Yamato |
| Europe | Northmen, Gaels, Hellenes, Latins |
| Africa | Swahili, Zulu, Egyptians, Arabs |
| Asia | Mongols, Koreans, Han, Persians, Yamato, Viet |
| Northern Americas | Inuit, Cherokee, Sioux, Navajo, Aztecs |
| Southern Americas | Inca, Tupi, Caribs |
| Jungle | Caribs, Maya |
| Desert | Arabs, Egyptians |

`nomads_spawn()` calls `choose_origin(climate)` on these lands. A player at
the keyboard is asked which people of the land they belong to (default: the
people of the birthplace) and whether to take a name and looks of that people
or keep their character setup. Characters without a client, such as agents,
get the people of their birthplace. A restored character is never asked again.
An agent may ask for a people of the land when it makes a character
(`character_spawn` with `origin`: an id or a name); its character state then
carries `origin` and `languages` (name, score, level, speech key, and which
one is the mother tongue and the default).

## Admin tools

`code/modules/admin/verbs/origin_languages.dm`, all in the Admin tab:

- **Check Origin and Languages** - a character's people, birthplace and every
  language score. Read-only.
- **Set Origin** - moves a character to any people and records a birthplace;
  optionally makes them a native speaker of that people's language. Name,
  looks and other languages are left alone.
- **Set Language Score** - sets one language from 0 to 100. Below Broken the
  language leaves the spoken list; the last language a character speaks
  cannot be taken away.

Changes are logged and announced to admins.

To add a people: add a `/datum/origin` subtype and put its id in a land's
table. `tests/origins/test_origins.py` checks that the language, name
generator and colour names exist and that every land covers every climate.
