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
