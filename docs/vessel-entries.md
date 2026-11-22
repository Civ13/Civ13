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

## Later phases

3. Submarine torpedo tubes, with a slow one-at-a-time diver lock-out.
4. Ship gun ports, scuttles and cargo hatches.
5. Tank belly hatch, bus emergency door release, train end doors.
6. Aircraft bailout and canopy jettison, ship lifeboat stations.

Val approved all phases on the recommended answers (2026-11-22); new art comes from
Fable 5.2 where it adds sprites.
