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
- Only lands of kind `SURFACE`, `OCEANIC`, `UNDERGROUND`, `OTHER` or `EXPEDITION` take a
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
- **Limit.** A faction's limit is what its hall and colonies support (see
  "Faction halls"), never above the server's `FACTION_MEMBER_LIMIT` (50). A
  leader may set a lower one with **Faction > Set Member Limit**. A full
  faction cannot enrol a new account; accounts already on the roster are never
  refused by it.
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
  Founding a new colony on a continent requires the leader and one other active
  member of the same faction to stand beside the charter on separate signed-in
  BYOND accounts. This does not restrict travel or trade, change expedition-island
  claims, or revoke an existing colony when only one member remains.
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
- **Quiet colonies pause.** A colony that reports fewer than 2 living members
  for 3 days (`COLONY_KEEP_MEMBERS`, `COLONY_QUIET_SECONDS` in coordinator.py)
  is marked `paused` in the land list: it takes no colony starts and adds
  nothing to its faction's hall limit until 2 members live there again. The
  charter still stands and travellers still rejoin it.

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

## Faction halls

Val (2026-11-14): factions (and later nations) grow through meaningful
infrastructure. Without a hall a faction holds 10 accounts. A leader
designates a **faction hall seat** (crafted from 20 soft wood planks) and
members deliver materials to raise it a tier at a time:

| Tier | Limit | Needs the | Indoors | Materials |
| --- | --- | --- | --- | --- |
| Council fire | 15 | Stone Age | no | 40 wood, 40 stone |
| Longhouse | 25 | Classical Age | yes | 150 wood, 100 stone, 30 cloth |
| Town hall | 35 | Medieval Age | yes | 300 stone, 60 iron, 40 glass |
| Capitol | 50 | Industrial Age | yes | 600 stone, 150 steel, 80 glass, 20 gold |

The highest tier among the faction's standing halls counts; an indoor tier
moved outdoors counts for nothing, and a destroyed hall takes its tiers with
it. Each standing colony of the faction in another land adds 5. The numbers
are placeholders. Code: `code/game/mob/groups/faction_hall.dm`.

The leader, or an officer with the **works** power (`docs/faction-offices.md`),
can move the hall: right-click it, **Fasten or Unfasten** (5 seconds), pull it
to its new place and fasten it again. It keeps its faction, tier and delivered
materials. A loose hall counts for nothing until it is fastened, and an indoor
tier must be fastened indoors to count. Anyone can pull a loose hall, but only
the leader or a works officer can fasten it. The same verb moves the faction's
nation assembly seat, recruitment stations, colony charter and strongbox. Code:
`code/game/mob/groups/faction_fixtures.dm`.

## Nations

Val (2026-11-14): factions band together into nations that represent them all
while each keeps its own leaders, research, treasury and members, and may still
oppose the others. The coordinator keeps the registry for the whole group
(`tools/transfer_storage/nations.py`), so a nation can hold factions from
several lands. A faction is known by its land-qualified id; a colony's members
are citizens of their parent faction's nation, but only leaders in the
faction's own land act for it.

Leaders use the **Nation** verb (Faction tab):

- **Found**: two faction leaders of the same land stand together, name the
  nation and both agree. The one who asked becomes its head.
- **Apply**: a faction outside any nation applies to one; the member factions'
  leaders vote, and a majority of members admits it (half or more refusing
  ends it). Applications lapse after 3 days.
- **Vote for a head**: a majority of member factions chooses the head, whose
  role is symbolic.
- **Secede**: at any time. The faction cannot reapply to that nation for 3
  days, and a nation left with one faction dissolves. A seceding head passes
  the title to the longest-standing member until a vote.

These are the rules of a **Confederation**, every nation's default
government. A nation may choose another system of government, which changes
who heads it, admits members and sets the common money, how much notice a
seceding faction gives and how many factions it holds: see
[nation-government.md](nation-government.md).

A request waits with the world's agent (`/nation/request`) until the
coordinator's next pass; its outcome comes back with `/homes` and the world
tells the leader on its next read of `/nations` (kept 7 days). Examining a
character shows their nation. A faction renamed in its own land keeps its
place (`rename` op).

### Nation assemblies

A nation holds 3 factions. A member faction's leader designates a **nation
assembly seat** (30 soft wood planks) in the faction's own land, and members
raise it like a faction hall:

| Tier | Factions | Needs the | Indoors | Materials |
| --- | --- | --- | --- | --- |
| Meeting ground | 4 | Classical Age | no | 120 wood, 120 stone |
| Assembly hall | 6 | Medieval Age | yes | 400 stone, 80 iron, 40 glass, 60 cloth |
| Parliament | 8 | Industrial Age | yes | 800 stone, 200 steel, 100 glass, 40 gold |

The best standing assembly of any member counts. Each world compares its
member factions' assemblies with the registry when it reads it and reports a
change (`assembly` op), so a burned or unroofed assembly lowers the cap within
a few minutes. A lower cap removes no one; it only stops new members. Code:
`code/game/mob/groups/nation.dm`.

## New accounts start near people

On a land with random starts, an account in its first two days starts 40 to 80
tiles from the largest group of awake players standing outdoors on the
starting level, on a tile that passes the usual safe-start checks
(`newcomer_start.dm`). A faction station or a home bed still comes first. With
nobody about, or no safe tile in the band, the ordinary random start applies.
The newcomer is not put into any faction. Tests: `tests/newcomer_start`.
