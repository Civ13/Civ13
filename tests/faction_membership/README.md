# Faction membership and recruitment authority

Stage 1 of the recruitment station design (#4237). `faction_membership.dm`
holds the shared rules:

- `can_recruit_for_faction`: the stored leader, or a current member holding
  the Recruitment permission, may recruit for their own faction.
- `can_manage_faction_permissions`: only the stored leader. A mob's `leader`
  flag is not trusted, because granting Recruitment used to set it.
- `faction_enrollment_block` / `enroll_in_faction`: the one join transition.
  It refuses the dead, current members, the 24-hour rejoin cooldown and (unless
  the caller allows a consenting switch) members of another faction, then
  clears leadership, permissions, title, research role and role verbs.

Offline: `python3 -m unittest discover -s tests/faction_membership -v`.

Native: `python3 tests/faction_membership/run.py --byond-bin <pinned bin>`
(source `byondsetup` first on Linux). It compiles the production helpers with
small stubs, runs DreamDaemon with `-safe` on port 0 and prints `PASS`.
`--negative-control cooldown`, `privileges`, `leader_flag` or `switch` each
removes one rule and must report its failure. It does not run the full game
or a save/load.
