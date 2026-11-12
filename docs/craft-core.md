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
