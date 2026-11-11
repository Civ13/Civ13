# Faction membership and recruitment authority

Stage 1 of the recruitment station design (#4237). `faction_membership.dm`
holds the shared rules:

- `can_recruit_for_faction`: the stored leader, or a current member holding
  the Recruitment permission, may recruit for their own faction.
- `can_manage_faction_permissions`: the stored leader manages every
  permission; a member holding Permission Management may manage only
  Announcements and Giving Titles. A mob's `leader` flag is not trusted,
  because granting Recruitment used to set it.
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

## Leadership lifecycle

The membership layer also owns `faction_leader_record`,
`clear_faction_leader` and `change_faction_leader`. Cleanup compares object
identity, never character names. A transition checks the expected current
leader and both memberships immediately before changing the record and role
powers; a null expected leader means claiming a vacancy. Map eligibility and
nearby selection remain in the verbs. Research-role and title strings remain
unchanged during a transfer, matching the previous behavior.

The native probe covers duplicate names, stale leader flags, departure/death
cleanup, cancellation, self-transfer, changed membership/leadership, dead
participants, vacancy claims and restored record references. Native execution
and real-client/save-load acceptance must be reported separately from the
offline source contracts.
