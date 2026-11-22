# Alternate and emergency vessel entries

Plan: vessels can be boarded through openings other than their intended
door, and each vehicle type gets the emergency exits it historically had.

Every opening is one of three kinds:

- **Entry**: a way in and out in ordinary use. The crew can secure it from
  inside; someone outside can only knock (or, in later phases, force it).
- **Emergency exit**: opens from inside only and is never a way in.
- **Breach**: made by damage and open both ways until repaired.

An opening below the waterline floods a chamber first. No opening moves a
player who is held while being sent to another region (`travel_held()`,
docs/region-admin-send.md).

## Phase 1: the submarine lock-out hatch

`code/modules/1713/machinery/modular_vehicles/ships/seabed.dm`

Using a lock-out hatch from inside a submerged boat opens a menu:

- **Lock out (diving suit)**: as before, a sealed diver floods out onto the
  seabed.
- **Escape to the surface**: the escape trunk. A crew member without a suit
  floods the chamber and makes a free ascent to the open sea above the
  hatch. From the shelf it costs a little breath; from open water it costs a
  lot of breath and some injury; from the deep and the abyss it is refused.
  Something floating above the hatch, or rock against it, also refuses it.
- **Dog / Free the outer hatch**: two seconds at the wheel. A dogged hatch
  refuses anyone locking in from the seabed; they hammer on it instead and
  the crew hear it (at most once every five seconds). Anyone going out
  through the hatch undogs it on the way.

`outer_dogged` is saved with the hull section, so a dogged hatch stays dogged
across a save. Probe: `tests/submarine/probe.dm` ("Hatch security and the
escape trunk").

## Phase 2: breaches and breakable glass

`code/modules/1713/machinery/modular_vehicles/vehicle_breaches.dm`

- A modular vehicle wall shot or blown down to no health is a **breach**: a
  hole people pass through both ways. Before this a wrecked wall kept
  blocking, because passage only checked for an empty or open wall.
  `try_destroy()` in `frame.dm` calls `breach_wall()`; the frame keeps the
  wall it was in `breached_walls`. Wrecked doors hang open, as before.
  Submarine pressure hulls stay shut (`breach_passable()`), since their
  damage is the leak count.
- **Welding shut:** steel in one hand, a welding tool in the other, use the
  steel on the frame: 2 sheets, 8 seconds (mechanic skill speeds it). The
  wall comes back as it was, at 20 health.
- **Glass** (windows, windshields, glazed doors, not armour or a
  submarine's pressure glass): on harm intent, hit it with anything of force
  5 or more. From inside the vehicle it takes 1.5 seconds, so every bus and
  car window is an emergency window; from outside it takes 5 seconds. The
  smashed pane is a breach. Inside, with more than one pane, you pick the side.

Trains need nothing here: their cars are open platforms that riders already
walk between and step off.

## Phase 3: submarine torpedo tubes

`code/modules/naval/sub_torpedo_tubes.dm` (hooks in `torpedoes.dm`)

- The ordinary torpedo tube (25 steel) can stand in a submarine's bow
  row. Submarine sheets have it as fitting **T**; a tube anywhere else on a
  sheet is an error. Hand assembly bolts it down with the other fittings.
- A tube in a submarine fires along her heading, whichever way it was
  trained. Submerged she fires from periscope depth: the torpedo runs on the
  surface above her bow, or along the sea layer when something floats
  there, where it can strike another submerged boat.
- **Diver lock-out:** from inside a submerged boat the tube's menu offers
  Fire, Lock out through the tube (a sealed diver, 20 seconds, empty tube
  only, out onto the seabed ahead of her bow) and Open / Shut the outer door
  for divers. A diver can come back in only through an open outer door and an
  empty tube: 20 seconds with bank air, 40 seconds pumped by hand. The door
  shuts behind them. At a shut door a diver hammers for the crew.
- The tube cannot fire or be loaded while a diver is in it.

## Phase 4: gun ports, barred gates and cargo hatches

`code/modules/naval/hull_ports.dm` (sprites `icons/obj/vessel_openings.dmi`,
made by `tests/sprites/create_vessel_openings.py`)

- **Gun ports:** a wooden gun port (4 wood, Cannons) or steel gun port
  (4 steel, Steelmaking) is a gate in her side the height of a deck. Ship
  sheets have them as **GP** and **GS** under Sides; like a gangway, each
  must stand on her edge facing out, and closes that side instead of a
  gunwale. Shut, a port is a wall: shots do not pass and nobody climbs
  over it. Open, guns fire through it and anyone comes through it, crew or
  boarders from a boat or the water.
- **Water:** an open port on a deck that is awash ships 4 bucketfuls a
  minute into its compartment until it is shut.
- **Barring:** every gate in her side (gangways and gun ports) can be barred
  and unbarred from aboard ("Bar or Unbar"), only while shut. From outside a
  barred gate does not open: a boarder can only hammer on it for the crew to
  hear, or break it down.
- **Cargo hatch** (6 wood, Cooperage; sheet piece **CH** under Between decks,
  which must be drawn over her hold): open, crates dragged onto it are
  lowered into the hold, and someone standing on it climbs down. Shut, it is
  deck.

## Phase 5: land vehicle emergency exits

`code/modules/1713/machinery/modular_vehicles/vehicle_exits.dm` (hook in
`vehicle_door_hold.dm`)

- **Inside release:** a locked car or bus door opens from inside after a
  moment at the handle or emergency release, and is left unlocked and open.
  From outside a locked door still opens only with its key.
- **Tank escape hatch:** a vehicle on a heavy axis has an escape hatch in its
  belly. From inside, while she is stopped, "Drop through the escape hatch"
  takes 6 seconds and puts the crewman, prone, on the nearest clear ground
  within three tiles that is not under her. It is an exit only.
- Trains are open platforms in Civ13 and need no end doors or emergency
  windows; breakable glass (phase 2) covers bus and car windows.

## Later phases

6. Aircraft bailout and canopy jettison, ship lifeboat stations.

Val approved all phases on the recommended answers (2026-11-22); new art comes from
Fable 5.2 where it adds sprites.
