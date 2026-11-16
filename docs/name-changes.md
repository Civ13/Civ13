# Taking a new name

Code: `code/game/mob/living/carbon/human/name_change.dm`; the clerk's option is in the **Faction
Papers** verb (`code/game/mob/groups/faction_papers.dm`). Tests: `python3 tests/name_change/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/name_change/probe.dm`.

Val asked (2026-11-16) for a way to change a character's name without marriage mechanics. People
took new names for a faith, a trade, exile or a fresh start. Only in persistent worlds.

## How

- **In a faction:** the change is filed with whoever holds the faction's papers power (the leader,
  an office with "issue papers and keep the border", or the bearer of its seal). Standing beside the
  member (or alone, for themselves), they pick **Record a change of name**. The member types the new
  name. The clerk's blank sheet becomes a *record of change of name*, given to the member, and the
  census lists the change.
- **In no faction:** **Take a new name** (IC tab).

Names are cleaned like a setup name, can't be the current name of anyone living in the region, and
the character then waits 7 real days before changing again. Taking a new name ends an adoption's
family name for good (no more Unadopt).

## The trail

- The character keeps its former names (up to 20) and a dated history. Both travel between regions.
- The region keeps a dated record per account in `map.faction_recruitment["names"]`.
- Admins see both in the player panel (Name history). Changes go to the game and admin logs.
- Bans, notes, rosters, warrants, fines and outlawry key on the account (ckey), so a new name
  dodges none of them.

## What follows the new name

- Papers of any faction held by the account: register and the paper itself, still in force.
- Office holders and election candidates; names on warrants, fines and outlaw rows (the court record
  notes "X now goes by Y").
- Plots in the character's own faction registered to the old name.
- Things keyed by a character name answer to former names too: fitted locks (owner and hidden
  catches found), pit traps the character set, craft crew places, and bars on a craft.

Books, paintings, signed papers, seals and other things already made keep the name they were made
under.
