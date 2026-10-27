# Liminal Facility: finite authored-room mode design

Status: design milestone for review. Working name and original room layouts;
inspired by familiar-but-wrong indoor horror, without copying proprietary rooms,
art, characters or scenes. The private topology proof is not a playable mode.
Source audit baseline: Civ13 commit
`10d264e5896221b34949ee4b67c0fd2b94bde249`. Implementation is staged below;
this document does not activate a server mode or authorize native runs.

## Decisions

- Build one finite map offline before the round. No infinite reshuffling, runtime
  room replacement, dynamic z growth or changes to an existing player's world.
- Use a distinct INDOOR_LIMINAL authored-room backend/catalog. Reuse deterministic
  seed/config/version manifests, validation and artifact packaging from the
  terrain tools; do not rename SURFACE or emit Nomads rocks/trees as interiors.
- Prefer existing Civ13 materials, lights, sounds and threat mechanics. No asset
  port is needed for the first source slice. Per-file provenance review precedes
  any external art/audio transfer, including apparently compatible ports.
- First round target: a small cooperative expedition, provisionally 1-4 players.
  This is a design cap, not tested native capacity. The topology proof currently
  has one authored spawn; multiple safe starts require separate packing tests.
- Progress is shared, monotone round state. Discovery does not depend on a
  consumable or droppable key item. Native interaction, group ownership and
  death/escape behavior must be tested before claiming gameplay acceptance.
- Start with steady approved lights and existing handheld flashlights. Their
  audited unlimited-power behavior means battery scarcity is not a design input.
  Fuel-burning lantern/torch mechanics are distinct; no battery system is added.

## Mode loop and state

Players enter an arrival vestibule, identify a route marker in an office/alcove,
reach a contrasting service space, complete a service interaction, then return
to an opened extraction route. Repetition makes the office recognizable; an
offset floor plan, pillars, shelving and controlled thresholds create ambiguity.
The route is a program of authored spaces, not a random corridor maze.

The minimal required progression is:

1. ARRIVAL: one safe entry room, clear briefing and no immediate threat spawn.
2. DISCOVERY: inspect an authored marker site. Grant shared FOUND_MARKER once.
3. SERVICE: interact at a clear service site after discovery. Grant SERVICE_DONE.
4. EGRESS: SERVICE_DONE enables the final connection and extraction eligibility.
5. EXTRACTION: at least one conscious eligible participant remains in the
   extraction zone for an uninterrupted hold. Escape completes the round once.

The topology solver treats marker/service interactions as available zero-cost
symbolic actions at their anchors. That proves a route under stated assumptions;
it does not prove a real terminal, key, power network or extraction trigger.
The implementation must map these actions to explicit source-backed handlers.

Authoritative mode states:
PLANNED -> VALIDATED -> READY -> EXPLORING -> TASKS_DONE -> EXTRACTING -> ESCAPED.
EXTRACTING returns to TASKS_DONE if no eligible participant remains in the zone.
FAILED is terminal. Task grants are idempotent, shared and cannot revert. No
stage generates more rooms. A single owner handles completion and timer state;
duplicate interactions or victory checks cannot create duplicate loops.

Provisional extraction hold: 20 seconds, tunable 10-120. Compare elapsed engine
time using verified units; a poll count must not define duration. Provisional
round deadline: 15 minutes, tunable 10-30 minutes. These values require playtests,
not acceptance by analogy with Lights Out. Temporary incapacitation alone does
not fail a team. Failure occurs when no participant remains alive, or the finite
round deadline expires. Spectators and late joins cannot satisfy extraction.
Late joining, reconnect ownership, escaped-player handling and persistence are
explicit native integration tests, not assumptions of the topology proof.

## Existing source references and hazards of direct reuse

[Lights Out metadata](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/objects/map_metadata/lights_out.dm)
provides survivor/extraction concepts. Its constructor also creates jungle
hazards, schedules piranhas and deletes objects in unselected extraction areas.
Do not inherit/copy that constructor into an indoor mode. A separate metadata
adapter must select only reviewed behavior and its own approved area registry.

That file declares EXTRACTION_TIME_NEEDED = 300 with a 30-second comment, but adds
one per spawn(10) check. The observed code is nominally 300 one-second checks,
not 30 seconds; actual scheduler timing still needs native verification. Record
this mismatch and specify new elapsed-time behavior instead of copying it.

[Handheld lighting](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/modules/1713/lantern.dm#L237)
includes unlimited flashlight types and a reduced-range red darknight variant.
Existing imagery and lighting are reference capabilities, not proof of the
proposed room appearance, visibility or atmosphere.

[Transition effects](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/objects/effects/bump_teleporter.dm)
use matched IDs and persistence_set_loc. They are not automatically safe authored
level portals: matching targets, safe landing footprints, unique pair identity,
permissions and delayed-transition lifetime need explicit checks. The first
mode can remain on one finite level and needs no portal mechanic.

The root audit also verified echofiend sound investigation in
[monsters.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/mob/living/simple_animal/hostile/monsters.dm),
wired through [sound.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/sound.dm).
This is a design reference; it does not establish pursuit through generated
doors, player audibility, safe spawn selection or a balanced new mode.

## Threat, pacing, lighting and audio

The initial complete-mode target is at most one existing approved sound-reactive
threat. Keep native spawning disabled until pathing, doors and encounter safety
are verified. Its first eligible site must have a route to the exploration space
and cannot be an arrival, objective or extraction clearance reserve. Give the
arrival a provisional 30-second grace period; measure the actual native result.

Pacing has a safe arrival, repeated familiar office motif, one marked threshold,
a service-task pressure beat and a legible escape. Difficulty adjusts candidate
room families, optional detour length, threat eligibility and approved light/
sound choices; it never removes mandatory progression or clearance checks.
No runtime director, silent threat teleport or endless spawning is required.

Room light/sound tags are intent metadata. Begin with existing steady lighting,
approved ambience hooks and floor footsteps. Do not claim acoustic occlusion or
AI perception from a REVERBERANT/DAMPENED tag. Native tests must measure emitted
sounds, hearing range, illumination, doors and line of sight separately. Flicker,
custom shaders, new scare audio and imported textures remain later review items.
No hostile actor, sound or light loop is started by the offline assembler.

## Controls and scope of the first finite map

The design allows authored room catalog/version, seed, approved room-family mix,
instance budget, optional alcove, footprint clearance, progression recipe,
candidate/search budgets, native palette version and explicit layer mapping.
Difficulty presets expose a few of these; advanced settings remain bounded.
Mandatory socket, zoning, reachability, progression, licensing and output
integrity rules cannot be disabled. Unsupported settings reject before work.

The small topology proof implements one chapter: arrival -> one of five authored
office hubs -> threshold -> service -> exit, with an optional discovery alcove.
It demonstrates 10 original families through variants and catalog checks, but
does not generate a general facility. Larger repeated motifs, alternate loops,
multiple levels, portal episodes, group spawns and a longer narrative are staged
extensions with separate fixtures. No seed matching a show/game scene is claimed.

See ROOM-GENERATION.md for schema/contracts and SOURCE-AND-ACCEPTANCE.md for the
source/asset boundary, DMM plan, acceptance gates and implementation slices.
