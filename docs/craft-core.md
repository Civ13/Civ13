# Craft core

The shared base for everything that moves as a whole: ships today, and later
airships, spacecraft, pods and trains. It lives in `code/modules/craft/` and
its constants in `code/__defines/craft.dm`. The ideas come from a review of
how Shiptest moves ships; all code and art here are Civ13's own.

Nothing in the game calls the core yet. Existing vessels, helms and saves
behave exactly as before.

## The pieces

| Type | File | What it is |
| --- | --- | --- |
| `/datum/craft` | `craft.dm` | Identity only: name, body, drives, register, chart token, berth, carrier and carried crafts. |
| `/datum/craft_body` | `craft.dm` | How the craft occupies and crosses the map. `template` wraps a `datum/vessel`. |
| `/datum/craft_drive` | `craft.dm` | One source of push: thrust, fuel, on or off. |
| `/datum/craft_register` | `craft_register.dm` | Owning party, crew roles, join mode, requests, barred list, memo. Saves as text. |
| `/obj/structure/berth` | `berth.dm` | A place a craft may arrive: size, owner, who is welcome. Hands out `/datum/berth_ticket`s. |
| `/datum/chart` | `chart.dm` | A map of tokens, sites and hazards, in mirror mode (tokens follow real positions) or steered mode. |
| `/datum/plane_pool` | `plane_pool.dm` | Claim and release of whole z-levels. `orbit` wraps the orbit registry. |

## Rules

- `datum/vessel` is not renamed or replaced. Helms save its type path, so a
  template body wraps it. `craft_of_vessel(V)` makes the craft on first use
  and `craft_at(turf)` finds the craft a tile belongs to.
- A vessel tells its craft about every hop and turn from `relocate()`, whoever
  asked for the move (the wheel, the hop timer or a body): `craft.on_hop(old_origin)`
  and `craft.on_turn(angle)`.
- When a craft turns, everything aboard gets `craft_turned(craft, angle)`.
  Objects and creatures turn their facing with the hull, and loose items also
  turn their pixel offset. A type whose facing must not follow the hull
  overrides `craft_turned()`. `craft_moved(craft, old_loc)` is for bodies that
  move things one at a time; a template body moves whole tiles and does not
  call it.
- Turn angles are the ones `turn()` takes (counter-clockwise positive). Use
  `craft_turn_angle(old_dir, new_dir)`.
- A craft nobody registered is open to anyone. Once a party owns it,
  `craft.may_steer(user)` asks the register.
- A berth is asked with `request(craft)` and answers with a ticket. A ticket
  that is not `granted()` carries the reason in `refusal`. `complete()` docks
  the craft and `cast_off()` frees the berth.
- Saved fields hold text and numbers only, never object references.

## Built bodies and sailing

`/datum/craft_body/built` (`built_body.dm`) is a hull the players laid as
`/obj/covers` floors over water. It keeps the hull as offsets from a pivot
tile, one level only, at most `BUILT_HULL_MAX_TILES`. A move snapshots what
stands on every tile, carries it to the matching tile of the new place and
hands the water level from the floors that leave a tile to the floors that
arrive; a turn rotates the offsets about the pivot. `built_hull_survey()`
finds the hull around a tile and refuses one still joined to the shore, to a
vessel or to another craft.

`under_way.dm` gives every craft the telegraph, anchor, hop timer, path
warning and delayed turn that vessels have, on top of `body.move_cells()`,
`can_move_to()`, `move_to()`, `turn_to()` and `turn_corner()`. A new kind of
body that implements those sails without more code. `craft.max_speed()` is
where drives will set the top telegraph step; a hull with none makes slow
ahead.

`/obj/structure/hull_tiller` (`naval/built_hull.dm`) is the helm of a built
hull: it commissions, refits and strikes the hull, steers her, keeps the
papers and saves the hull as offsets from its own tile.

## Drives aboard

`naval/hull_drives.dm`: anything standing on a craft can be a drive by
answering `craft_drive()` with a `/datum/craft_drive/fitted`. `craft.fit_drives()`
collects them (on commission, when a speed is rung and before each hop), and
`craft.max_speed()` weighs their push against the tiles of hull: half ahead
needs `CRAFT_THRUST_HALF` per tile, full ahead `CRAFT_THRUST_FULL` per tile
from drives whose `top_step` reaches full ahead. A rigged ship mast is a sail
drive of `CRAFT_SAIL_THRUST` that tops out at half ahead.

A running engine loose on a deck (`/obj/structure/engine`, not on a vehicle
frame) is an engine drive: it pushes its current `maxpower` and can make full
ahead. After each hop `craft.burn_drives()` asks every drive to pay for it at
`speed / VESSEL_SPEED_FULL` of full power; an internal engine pays from its
own fuel tank (`craft_burn()`, `engines/internal_combustion.dm`) and stalls
when it cannot, and an external engine's heat source is its fuel.

## Plane pools

`craft/plane_pool.dm`. `orbit_pool()` is the pool of an orbit world, over the
plane registry. Besides claiming and releasing planes it:

- empties a plane: `clear(z)` deletes everything on it and puts the base turf
  and area back, and `clear_refusal(z)` says why it will not (a character
  there, awake, asleep or logged out, or a bunk kept as home).
  `release(z, TRUE)` empties first and keeps the plane when it cannot;
- shares a plane in slots: with a `slot_size`, `claim_slot(owner, z)` hands
  out squares of a plane (`slot_box(n)`), one per owner, kept in the registry's
  `slot_owners`;
- caps loaded sites: owners named `site:...` hold one plane each and at most
  `site_cap` together;
- can be paused: `set_paused()` is kept in the registry's `pool_paused` and
  stops pool claims. Admins flip it with Server > Toggle Orbit Site Loading.
  Stations claim their own decks and sectors through `orbit_claim_plane()` and
  are not paused.

## Wiring aboard

`craft/rigid_move.dm`: cables, engines, generators, batteries and connectors
drop their links when they are moved. A body that carries cargo wraps the move
in `craft_rigid_begin(things)` and `craft_rigid_settle(carry)`: while it runs,
`craft_carrying()` is TRUE for the cargo and those types keep their links;
afterwards `craft_carried(aboard)` on each thing cuts only the links to what
stayed behind. Both the built body and `datum/vessel/relocate()` do this, and a
cable swaps its `tiledir` on a quarter turn. Piped barrels still disconnect.

## Steered charts

On a chart in `CHART_MODE_STEERED` a token has momentum (`craft/chart.dm`).
`set_burn(heading, throttle)` pushes it along a heading in degrees clockwise
from north, a throttle of 0 lets it coast, `order_stop()` burns against its
motion until it lies still, and `lay_course(x, y, name)` makes for a place and
stops there (`arrived()` is the hook). `eta()` estimates the seconds from rest.
A full burn is `craft.thrust_per_tile() * CHART_ACCEL_PER_THRUST` squares per
second per second, paid for through each drive's `burn()`; a token with no
craft uses its own `accel`. `chart.wake()` starts a timer that calls
`run_step()` every `CHART_STEP_SECONDS` and stops when nothing moves; a step
also counts hazards down and calls `affect_craft()`. `contacts_of()` cuts the
sensor range by the `interference` of hazards at the viewer and at the target.

`craft/chart_helm.dm` is the console: `/obj/structure/chart_helm` reads the
chart and steers the token of the craft it stands on (burn, cut, full stop,
lay a course), behind the same helm access as a ship's wheel, and saves the
token's place and speed as plain numbers. It is a base with no recipe; a
subtype answers `chart()`.

`space/orbit_chart.dm` is the first steered chart: `orbit_chart()` on an orbit
world, 100 squares across with the arrival beacon in the middle and a station
token for every party that owns a plane, at a spot the plane registry keeps in
`chart_spots`. `/obj/structure/chart_helm/orbit` steers on it; no craft
carries one until the plane pool phase.

## Sea chart and harbours

`naval/craft_chart.dm`: `sea_chart(z)` is the mirror chart of a sea level, in
squares of `SEA_CHART_SQUARE` tiles. `refresh()` rebuilds its tokens from the
crafts and mooring posts really on that level; nothing ticks, the chart is
refreshed when read. `craft.sea_chart_text()` is what a helm shows: her square,
ships within her token's `sensor_range` (a `dark` token is an unknown contact)
and every harbour with the answer its berth would give her.

A mooring post (`/obj/structure/berth/quay`) is the first real berth. A craft
within `QUAY_DOCK_RANGE` calls `order_dock(post)`: the post's `request()` gives
a ticket, `berth_plans()` says where she would lie (along the shore, abreast of
the post, on the post's `water_side()`), the water is marked, `body.hold()`
stops her hops, and `finish_dock()` moves her `QUAY_DOCK_WARNING` later, makes
her fast and completes the ticket. `craft.on_hop()` and `on_turn()` cast off,
so a moored craft that moves is no longer moored. Moorings are not saved.

## Hails and running dark

`naval/craft_signals.dm`: `craft.hail(other, text, from)` calls across to a
craft within `lookout_range()` on the same level; both crews hear it and the
receiver keeps it in `last_hail`. `craft.set_dark(state)` sets `running_dark`
(not saved): her token is `dark`, `knows(other)` is false for crafts of other
owners, so charts, radar and hails call her "unknown contact" or "an unknown
ship". A dark craft makes slow ahead at most (`craft.max_speed()`,
`vessel.speed_cap()`), and a template ship's deck lights go out
(`body.dark_changed()`). New craft kinds get both from the base; a helm only
needs `hail_menu()` and `dark_menu()` entries.

## Ship's papers

`code/modules/naval/ship_papers.dm` is the first user of the register. The
ship's wheel has a "Ship's papers" entry: a player registers the ship to
their party, and owners or the captain sign crew on, change roles, bar
people, set how she takes new crew and write a memo. `craft.helm_access(user)`
answers `CRAFT_HELM_FREE` for owners and steering crew, `CRAFT_HELM_FORCE`
for anyone else while an owner is in the world (the wheel can be forced,
slowly, with the crew warned) and `CRAFT_HELM_CHAINED` when no owner is
about. `craft.fitting_refusal(user)` guards levers and the radar the same
way without the delay. The wheel saves the register in `register_state`.

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/craft_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/papers_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/built_hull_probe.dm 300
