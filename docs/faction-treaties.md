# Treaties

Code: `code/game/mob/groups/faction_treaties.dm`. Tests: `python3 tests/faction_treaties/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_treaties/probe.dm`.

Second round, step 2 of the bureaucracy and currency plan. Everything is in the **Faction
Treaties** verb (Faction tab).

## Making a treaty

Anyone with a faction's diplomacy power (the leader, an office given "make and sign treaties", or
the bearer of such an office's seal; see `docs/faction-offices.md`) drafts a treaty with one to
five other factions of this land: a title (up to 60 letters) and its terms (up to 600). The drafting
faction signs at once, and every party's members online hear of it.

Each other party's diplomacy power reads the draft and signs or refuses it. Once every party has
signed, the treaty is in force and all parties hear of it. A refused draft is closed.

## Breaking a treaty

Any party's diplomacy power can renounce a treaty in force, with a reason. The treaty stays in the
register marked as renounced, with who did it and why. The game enforces no treaty; the parties do.

## The register

Anyone can read every treaty of the land: its terms, its parties, who signed for each and when,
and its history. The diplomacy power can write out a copy on a blank sheet of paper to seal and
hand around. The register keeps up to 60 treaties; when full, the oldest refused or renounced one
makes room, and drafts and treaties in force are never dropped.

## Saved state

`map.faction_recruitment["treaties"]`: list("seq", "treaties" = id -> list("title", "terms",
"drafted by", "parties" = faction -> list(signer, time) or 0, "status", "made", "history")). Party
names follow `faction_roster_rename()`; `faction_roster_normalize()` drops malformed treaties.
