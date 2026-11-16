# Faction offices and elections

Code: `code/game/mob/groups/faction_offices.dm`. Tests: `python3 tests/faction_offices/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_offices/probe.dm`.

Step 6 of the bureaucracy and currency plan. Factions get offices that carry real powers, and
members can elect their leader and officers.

## Offices and powers

The **Faction Offices** verb (Faction tab) lists the offices, their holders and any election.
The leader can create up to 12 offices, toggle each office's powers, abolish an office, appoint a
member (for 0-60 days, 0 for no term), dismiss a holder, and set the faction's term.

| Power | Lets the holder |
| --- | --- |
| treasury | open the strongbox and collect taxes (`docs/faction-treasury.md`) |
| registry | register land and manage plots (`docs/land-registry.md`) |
| seals | cut and revoke faction seals (`docs/faction-seals.md`) |
| mint | cut coin dies (`docs/coin-mint.md`) |
| justice | hold court (`docs/faction-justice.md`) |
| papers | issue citizenship papers, travel passes and permits, set border doors and permit rules (`docs/faction-papers.md`, `docs/faction-permits.md`) |
| diplomacy | make and sign treaties (`docs/faction-treaties.md`) |
| works | unfasten and move the hall, assembly seat, recruitment stations, colony charter and strongbox (`docs/land-stages.md`, "Faction halls") |

A faction that has not changed its offices has a Treasurer (treasury) and a Registrar (registry).
The leader holds every power. A member acts for an office while appointed to it, or while holding
an in-force seal cut for that office, so a seal lends the office's powers to whoever carries it.
Abolishing an office or taking a power away from it also takes it from that office's seals.
`faction_power(H, faction, power)` is the single check.

## Elections

The leader can call an election for the leadership or for any office. Any member can call a
leadership election if the seat is vacant, or if the leader has served longer than the faction's
term. An election runs for 30 minutes. Members stand as candidates and vote, one vote per account,
and every online member is told. The most votes wins, and a tie goes to whoever stood first.

- An elected leader takes the leadership through `change_faction_leader()`. The winner must still
  be a living member.
- An elected officer is appointed for the faction's term.

Elections close on a timer, and also the next time anyone opens the offices (so a restart cannot
leave one open). Only one election runs at a time.

## Saved state

`map.faction_recruitment["offices"]`: faction -> offices (name -> powers), holders (name ->
account, name, until), term in days, the current leader's account and start time, and any open
election. The data is renamed through `faction_roster_rename()` and cleaned by
`faction_roster_normalize()`.
