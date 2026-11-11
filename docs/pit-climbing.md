# Dug pits and one-floor climbing

New shovel/ant tunnel shafts have no automatically supplied lower ladder. Existing
mapped tunnels and old saved tunnel exits are not removed. No world migration runs.

Use five leaves (any leaf-stack subtype) on a new dug hole to disguise it. This
is a three-second interruptible action; it rechecks the hand, reach and payment
at completion. Clicking the cover uncovers it. A living creature crossing the
hole falls to a clear lower cell, breaks the cover, takes 10 brute damage and is
briefly stunned. Clicking an uncovered hole lowers the character down carefully.
Camouflage is visual, not server-enforced invisibility or an anti-metagaming rule.

To escape, stand below the opening, face a cardinal direction toward a clear
solid rim and use **IC > Climb Up**, with at least one hand free. The same verb
climbs a neighboring solid wall to a supported upper ledge when there is open air
over the character. It waits three seconds and rechecks the actor, terrain,
direction, occupancy, map grace restriction and save movement barrier. It does
not create levels, pass through a ceiling or wall, levitate, carry another person,
or permit climbing while restrained, lying down or buckled.

Design reference: [Pocket Stronghold wall interaction](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/a354dae33450a698deeb48238896615f072a5369/code/game/turfs/closed/_closed.dm).
Its timed wall-to-upper-ledge interaction inspired this implementation. Its
transient-flight fallback and unconditional forceMove are not imported. Civ13
uses its logical level mapping, including the appended underground level.

## Validation boundaries

`tests/pit_climbing/test_pit_climbing.py` checks source contracts and the reused
DMI icon state, not executed DM behavior. The full game must compile with the
pinned compiler. Native collision, connected-client controls and saved-state
round trips still need an isolated acceptance run before claiming gameplay works.

Acceptance checklist:
- New shovel and ant shafts, up/down, fixed levels and appended caves: no lower
  ladder; five-leaf payment only once; interruption costs nothing.
- Walk across disguised and uncovered pits with aligned and sub-tile humans and
  animals; cover breaks once and fall lands below without a repeated callback.
- Manual descent and Climb Up in all four directions; displaced/interrupted
  character, changed facing, newly blocked ledge, closed ceiling, water/lava,
  unsupported sky and a second hole must not teleport the character.
- Standalone wall climb onto a roof/floor; no destination allocation or flying.
- Save/restore covered and uncovered holes; recheck disguise and logical level.
- Mapped tunnels, old save exits and ordinary constructed ladders remain usable.

Current conservative limitations: falls refuse a structurally blocked landing and
linked bodies (pulling, pulled or buckled). These cases require a group-aware
movement design; living occupants alone do not block falls. Transfers align sub-tile
offsets using the existing trench-climbing helper. This draft does not silently split a pull pair. The new covering
interaction applies to dug holes, not mechanical bear traps or existing punji
items (which already have their own deployment/disguise behavior).

## Local evidence (2026-11-11 UTC)

- BYOND 516.1688 full Gaia DEBUG compile: 0 errors, 0 warnings.
- Ten focused offline source contracts pass; these do not execute movement.
- Nineteen crafting projection contracts pass after the precise tunnel changes
  were added to the reviewed inverse and the disabled whole-file hash refreshed.
- Independent source review identified occupied-bottom suppression and retained
  sub-tile offsets; both corrected before publication.
- No DreamDaemon, live-server action, connected-client acceptance or save round
  trip was performed. Keep this draft until the native checklist is completed.
