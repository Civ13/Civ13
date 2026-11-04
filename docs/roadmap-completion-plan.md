# Roadmap completion plan

Status: working plan, checked on 2026-11-04 against master `ff0a643`
(after #3610) and the merged/open pull requests. It covers every goal on the
[public roadmap](https://civ13.github.io/roadmap.html) plus Val's 2026-11-04
remaining-work summary. Goals are not release promises. This document does not
authorize merging, deployment, live-server work or feature activation.

## How to read this plan

Each goal gets one of four tracks:

- **Agent**: offline source work an agent can implement, compile and test now.
- **Owned**: another project thread already owns it; do not duplicate.
- **Val's hands**: needs a real client, Val's PC, a live/Gaia save or a
  production server. Agents prepare probes and instructions; Val runs them.
- **Decision**: needs a product decision from Val before more code is useful.

"Done" for a goal means its remaining items below are merged and, where the
item says so, accepted on a real client or save. Anything that is design-only
on the roadmap stays design-only until Val schedules it.

## Corrections to the public roadmap page

The page lags master. These should be refreshed when the page is next edited
(the page lives outside this repository):

- Extraction survival: #3082 (safe houses) and #3118 (mall raid) are both
  merged; the page still says "under review" and "draft".
- Smooth movement: #3343 (vendor NPC motion), #3347 (held crafting menus) and
  #3367 (smooth pulling, on by default) are merged; the page still calls these
  a draft, under review and incomplete. #3607 also lets players keep moving during world saves.
- Diet: the balanced-diet system (#3597, #3602) is merged; penalties stay off
  pending #3598.
- Paper editor: enabled by #3610.
- Hydroponics: the shared crop-stage helper (#3404) is merged; trays are not.
- Server manager: read-only registered view, log contracts and the launcher's
  read-only management menu (#3354, #3432, #3436, #3536) are merged.

## Status by goal

### In progress on the roadmap

| Goal | Verified on master | Remaining work | Track |
| --- | --- | --- | --- |
| Smoother saves | Chunked moving saves, pointer exclusion, failure reports, move-during-save (#3147, #3192, #3194, #3409, #3607) | Smaller save batches; complete interruption recovery; #3590 real-save and late-join measurement | Agent (batches/recovery), Val's hands (#3590) |
| Extraction survival | Safe houses and mall raid merged (#3082, #3118) | Combined persistence, transport and recovery acceptance on a real run | Val's hands |
| A train home for your party | Dagger four-level home map (#3193), train crafting re-enabled (#3532) | Expanded compartments, airlock/survival rules, working transport, instanced saves, raid travel | Agent after sharding foundations; map review by Val |
| Geographic layers and elevation | Layer/elevation foundation (#3301) | Temperature coupling, mountain profiles, precipitation consistency | Agent |
| Snow shaped by local weather | Ground snow, shovelling, Gaia probe (#3300, #3593, #3595) | Real-client visual and footstep check | Val's hands (#3594) |
| Persistent world editing and map authoring | Editing (#3304); offline save-to-map core for synthetic JSON (#3303) | Native `.sav` extraction, map metadata, playable-map validation, mapper guide | Agent |
| Safe persistence and transfer foundations | Inert transfer policy/state DTOs (#3330); backend chosen 2026-11-04: SQLite per region plus coordinator ([design](../tools/server-management/TRANSFER-STORAGE-SQLITE.md)) | Region agent and coordinator store, save/load reconcile, DM bridge, two-region pilot | Agent |
| Desktop launcher and connection core | Launcher, companion transport, read-only manager menu (#3325, #3335, #3536, #3538) | Safe Linux process ownership; compile, new game, resume, shutdown, update, restart flows; real process observations and log sources; GUI shard view | Agent (source), Val's hands (live host) |
| Procedural worlds | Surface and oceanic generators (#3331, #3338) | Cavern generator; native playability, survival resources, save preservation | Agent (caverns), Val's hands (playability) |
| Smooth movement and interaction | Players, vendors, pulling, animals opt-out (#3337-#3367, #3535) | Wildlife sub-tile movement (#3509, disabled) fails arrival timing; idle-guard fix not on master | Agent |
| Authoritative line of sight | Geometric LOS, wall faces, opacity refresh (#3340, #3579) | Gameplay adapters, hidden-information protection, reconnect/save restoration; cost profile | Agent (adapters), Val's hands (#3582) |
| Lighting for oversized sprites | #3225 | General rendering issues; connected-client acceptance | Val's hands |
| Authored-room escape mode (Liminal) | Topology and scenario manifests (#3346, #3348, #3349) | Revised room layouts (first set rejected), native export, period policy, mode integration, playable acceptance | Decision (layouts), then Agent |
| Powered-gateway exploration (Backrooms) | Design and default-off power-state foundation (#3350, #3351) | Physical gateways, transfers, paid supplies, rescue, paired-world saves | Agent after sharding/transfer foundations |
| Diet, preferences and food discovery | Balanced diet, hidden tastes (#3314, #3315, #3345, #3597) | Diet source-review fixes; penalties after per-map food access (#3598); food art (#3599) | Owned (diet thread) |
| Windows server bot integration | Draft lives outside this repository | Review, activation, live Windows server check | Val's hands (chat relay bot thread covers the relay fix) |
| Discord social integration | Companion transport and inactive Windows provider (#3327, #3333, #3339) | Real SDK runtime, distribution terms, production startup wiring | Decision (terms), Val's hands |

### Planned on the roadmap

| Goal | Remaining work | Track |
| --- | --- | --- |
| Industrialization: pipes, pumps, foundries | Phased design #3609 awaiting Val; power sources (#3603) and stamp mill (#3601) merged | Owned (factory thread) |
| Real-time travel between servers | Depends on transfer foundations and two-region pilot | Decision, then Agent |
| Small USA regional persistence pilot | Manual discovery/wake/readiness path, on-demand start, idle shutdown, measured recovery | Agent (manager flows) + Val's hands |
| Player-built crossings and rail routes | Durable-transit design for offline intermediaries | Decision after pilot |
| Ocean voyages and offshore industry | Route and depth definitions | Decision (design only) |
| Submarines and underwater habitats | Depth model design | Decision (design only) |
| Advanced-era space mode | Altitude/orbital model design | Decision (design only) |
| Player-owned expedition regions | Offline migration design | Decision (design only) |
| Recovery when regions go offline | Needs authoritative custody and fenced ownership first | Agent after foundations |
| Map capability profiles | Measure build profiles before design | Agent (measurement tooling) |
| Compatible runtime and JIT research | Research only | Decision |

### Not on the roadmap page but in Val's summary

| Item | Remaining work | Track |
| --- | --- | --- |
| Hydroponics | Trays, reservoir, power, research, interactions, save lifecycle ([design](hydroponics-design.md)) | Agent, with five small product decisions |
| Ecology-driven spawning | Production population/habitat wiring, visibility checks, lifecycle adapters on top of the inactive heatmap (#3356) | Agent |
| Food progression | Protected cultivation, husbandry balance, aquaculture (#3048, #3049, #3051) | Owned (open-issues sweep) |
| Cooperative digging (#888), recipe audit (#3563) | Mechanics and item list | Decision |
| BYOND 516.1688 acceptance (#3310) | Runtime, client, saved-world acceptance | Val's hands |

## Work order

Val's suggested order is used, skipping work another thread owns:

1. **Hydroponics** (slices 3 and 4 of the design): dormant tray with reservoir,
   power, crop host, harvest and save lifecycle; then research, construction and
   interaction wiring. Product defaults are proposed in the PR and listed for
   Val to confirm.
2. **Server manager and launcher**: Linux process ownership, then the compile,
   new game, resume, shutdown, update and restart flows, with real process and
   log sources feeding the launcher's existing management view. Live-host
   acceptance goes to Val.
3. **Wildlife smooth movement**: land the idle-guard fix with an arrival-timing
   regression.
4. **Ecology-driven spawning**: wire population and habitat sources into the
   heatmap behind a config flag, with visibility checks and lifecycle adapters.
5. **Save-to-map export**: native save extraction into the canonical JSON the
   converter already accepts, map metadata, and a compile check on the result.
6. **Geography and procedural worlds**: elevation temperature coupling, then the
   cavern generator profile.
7. **Smoother saves**: smaller batches and interruption recovery.
8. **Line-of-sight adapters** and hidden-information protection.
9. **Liminal and Backrooms**, then **sharding/transfer**, in dependency order once
   Val has accepted room layouts and chosen a transfer backend.

Each step is one or more PRs with a filled `Changelog:` line where players see
a change, compiled and run through `scripts/agent_preflight.py all --write`.

## Decisions needed from Val

These block only the dependent step; everything else proceeds.

- Hydroponics: nutrient product and recipe; fragile-crop list and shortage
  timing; poor-weather damage; research bench tier and study price; dismantling
  refund. Defaults are proposed in the hydroponics PR.
- Sharding/transfer storage backend: decided 2026-11-04 (SQLite per region plus a
  small coordinator).
- Revised Liminal room layouts.
- #888 digging mechanics; #3563 which items become craftable.
- Discord SDK distribution terms.
- Design-only goals (ocean, submarines, space, expedition regions, JIT):
  whether to schedule any design work now.
