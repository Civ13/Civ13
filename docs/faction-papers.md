# Census, citizenship papers and border doors

Code: `code/game/mob/groups/faction_papers.dm`, faction doors in
`code/game/objects/structures/key_doors/key_door.dm`. Tests: `python3 tests/faction_papers/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_papers/probe.dm`.

Second round, step 1 of the bureaucracy and currency plan. Everything is in the **Faction Papers**
verb (Faction tab).

## Census

Any member can read the census: each member on the roster with the date they joined, dues paid and
plots registered to them, each office and its holder, and how many papers are in force.

## Papers

Anyone with the faction's papers power (the leader, an office given "issue papers and keep the
border", or the bearer of such an office's seal; see `docs/faction-offices.md`) issues papers to a
person standing beside them. Each takes a blank sheet of paper from the issuer's hands or feet.

- **Citizenship papers** are good until revoked.
- **Travel passes** are good for 1 to 30 days.

- **Building permits** and **trading licences** (`docs/faction-permits.md`) last 1 to 30 days, or
  until revoked. They never open a border door.

Papers name their holder and are numbered in the faction's register (up to 200 in force). They
count only for the account they were issued to, so stolen or copied papers open nothing. The power
can revoke any papers; examining papers that have run out or been revoked says so.

## Border doors

Standing beside one or more of the faction's doors, the papers power sets who they open for:
members only (the default), members and citizens, or members, citizens and pass holders. Papers
count when carried in the hands or worn directly, not inside a bag. Examining a door set this way
shows who it opens for. Nothing else in the game turns anyone away; guards and tolls are up to the
players.

## Saved state

`map.faction_recruitment["papers"]`: faction -> list("seq", "open" = serial -> list(kind, holder name,
holder account, issued, expires or 0, issued by)). Renamed through `faction_roster_rename()` and
cleaned by `faction_roster_normalize()`. Faction doors keep `admits` (0, 1 or 2).
