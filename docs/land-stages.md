# Land stages

Every land of a region group has a settlement stage. The stage is the first
step toward letting players start on other continents
([plan](https://claude.ai/artifact/UcXGgkJvXhxV91dKbfwtcS)): later steps use it to decide where
faction members and new characters may start. For now it is shown and set
only; no stage changes who may start where.

| Stage | Shown as | Meaning |
| --- | --- | --- |
| `MAINLAND` | mainland | The group's mainland. Every new character starts here. Fixed. |
| `CLOSED` | unexplored | Default. Nobody travels there yet. |
| `FRONTIER` | frontier | Explorers travel there. A bed there keeps their home. |
| `COLONY` | colonised | A faction has settled there. |
| `OPEN` | settled | New characters may also start in its wilds. |

A land can also be **paused**: it keeps its stage, but new starts there wait.

## Where it lives

- The group coordinator keeps the stages in its database (`land` table) and
  sends every agent the full list on each home pass (`/homes`, keys `lands`
  and `land_done`). A land no admin has set is `CLOSED`.
- Each world reads its agent's copy (`/lands`) about once a minute
  (`code/modules/persistence/land_stage.dm`) and shows it in the Regions panel.
- Only lands of kind `SURFACE`, `OCEANIC`, `UNDERGROUND` or `OTHER` take a
  stage; transit, event, practice and battle worlds never do.
- A stage change never moves a home or a character.

## Readiness numbers

Each world posts its population to its agent about once a minute
(`/land/sample`: players connected, living characters owned by an account).
The coordinator adds each fresh sample (under 3 minutes old) to an hourly
bucket per land (`land_hour`, kept 8 days) and reports, per land, over the
last 7 days:

- `homes`: accounts whose home is that land in the ledger;
- `players_avg` / `players_peak`: average and peak players;
- `living`: living characters at the latest sample;
- `suggest`: a change for an admin to consider, never applied by itself.

Suggestions need at least 24 hours of mainland numbers in the window. The
thresholds are placeholders in `tools/transfer_storage/coordinator.py`:

| Suggestion | When |
| --- | --- |
| `OPEN` | A frontier or colonised land has at least 10 homes, the mainland averages at least 20 players, and the land has no more living characters than the mainland. |
| `PAUSE` | A settled land while the mainland averages under 15 players or the land has more living characters than the mainland. |
| `RESUME` | A paused settled land once the `OPEN` population rules hold again. |

Admins see the numbers and suggestions in **Admin > Land Status** and get one
admin message when a land's suggestion appears or changes. The host tool's
`status` adds each land's stage and numbers (`land`, read-only from the
coordinator database), and the launcher's region board and rows show them.

## Setting a stage

- In game: **Admin > Land Status** shows every land and lets an admin choose a
  land, its stage and, for colonised or settled lands, whether it is paused.
  The change is queued in that world's agent (`/land/set`) and decided on the
  coordinator's next pass; every land sees it within a minute.
- On the host: `python tools/transfer_storage/coordinator.py --db <coordinator.sqlite> --group <group> --mainland <id> --set-land europe=frontier`
  (add `,paused` to pause). `--lands` prints every stage as JSON.

## Faction members

Val's rules (2026-11-14): factions have a member limit, and an account may
start new characters with a faction only after joining it in play.

- **Roster.** Each faction keeps a roster of member accounts in
  `map.faction_recruitment` (`rosters`, `limits`), so it saves with the world
  and follows renames. An account is added when its character founds the
  faction, is recruited or is accepted at a recruitment station
  (`enroll_in_faction`), or logs in as a living member. Leaving the faction
  removes it. Death does not. An account that has not played a member for
  `FACTION_ROSTER_IDLE_DAYS` (14) drops off.
- **Limit.** `FACTION_MEMBER_LIMIT` (20) accounts per faction; a leader may set
  a lower one with **Faction > Set Member Limit**. A full faction cannot enrol
  a new account; accounts already on the roster are never refused by it.
- **Member start.** On a starting land (a Nomads map with `new_player_start_z`, `nomads_start.dm`), an account on a roster is asked at Join where to
  start: in the wilds as usual, or with one of its factions. The character
  starts beside one of that faction's recruitment stations and is a member at
  once. Without a station there is no member start. Nobody else is offered the
  choice. Code: `code/game/mob/groups/faction_roster.dm` and `faction_start.dm`.

## Colonies

- **Factions travel by id.** A traveller in a faction carries
  `civ:<land>:<name>` (the land the faction was founded in) and whether they
  lead it (`region_travel_payload` "faction", "faction_leader"). On arrival
  they rejoin that faction if it lives here: at home, or as a standing colony.
- **Colony charter.** Crafted from 8 soft wood planks (economy & production).
  A faction's leader who has travelled into another land, and has no faction
  there, plants it: that founds the faction in this land under the same name,
  led by them, with this land's research (knowledge travels in books). If the
  colony already exists but lost its charter, planting a new one puts it back.
- **Standing.** A colony counts only while a charter bound to it stands, so
  raiders can take it down. Each world reports its standing colonies (parent,
  name, age in hours, living members) with its population sample; the
  coordinator keeps them in its `colony` table, shows them in `/lands`, and
  suggests COLONY for a CLOSED or FRONTIER land once one has stood for
  `COLONY_SECONDS` (3 days) with `COLONY_MEMBERS` (3) living members. An admin
  confirms the stage. Code: `code/game/mob/groups/colony_charter.dm`.
- **Colony start.** In the faction's own land, a member (an account on its
  roster) is also offered "With <colony> in <land>" for each standing colony
  in a COLONY or OPEN land (a pause stops wild starts only). Choosing it sends
  `/account` op `colony` with the faction id; the coordinator checks the
  request came from the faction's own land and the colony stands there, moves
  the account's home to that land and grants the start (`colony_grant`, sent
  to that land's agent). There, a HOME claim carries the grant, the lobby
  offers "With <colony>", the character starts beside the colony charter (or
  one of the colony's stations) and joins it, and `colony_used` clears the
  grant. On lands without random starts, job relocation places the body
  (`faction_start_turf`).

## Open-land wild start

At Join, a player whose account is past its first two days
(`new_player_marks.is_new`) is also offered "In the wilds of <land>" for every
OPEN, unpaused land. Choosing it sends `/account` op `start`; the coordinator
accepts it only from the account's home land and only while the land is OPEN
and unpaused, and moves the home there. The player then joins that land and
starts as any new character there (at random on a land with
`new_player_start_z`, otherwise at its usual join points). A death there
without a bed sends the home back to the mainland as before, where the choice
is offered again. Brand-new players always start on the mainland.
