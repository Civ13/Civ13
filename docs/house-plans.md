# House plans

`code/game/objects/house_plan.dm` (the plan), `house_plan_checks.dm` (the
checks and part descriptions), `house_designer.dm` (the window). Defines in
`code/__defines/house_plans.dm`. Tests in `tests/house_plans`.

A ship's draught (1 wood, Papermaking) can carry a house plan as well as a
ship, submarine, vehicle, airship or space station. Holding a blank sheet and
a pen or pencil, **Draw a house on the sheet** opens the house designer. The
plan builds nothing and costs nothing: it is a drawing that tells a builder,
before any material is used, what the game will refuse and what they will
regret.

## The plan

- 20 by 20 tiles a storey, north to the top; 6 storeys (what concrete carries).
- A tile of a storey holds one floor, one piece and one roofing.
- Pieces: timber wall, stone wall, concrete wall, door, timber window, stone
  window, roof support, stone pillar, concrete pillar, stairs, ladder.
- Floors: wood, stone, concrete. On the ground a stone or concrete floor is a
  foundation.
- Roofing: thatch, wood, clay tile, concrete, glass. A roof is the floor of the
  storey above, as in the game.
- Up to 12 notes of 80 plain characters, each pinned to a tile.

A piece stands for its class: "timber wall" is any wall that carries two
storeys, "stone wall" any that carries four. The bill of materials uses one
usual recipe for each (a log wall, a stone wall, a wooden door and so on) and
says so.

## Design code

`C13HOUSE/1/<name>/<storey,x,y,count,keys>;.../<storey,x,y,note>;...`

Each run is `count` tiles eastwards holding the same three keys (floor, piece,
roof; `-` for none). A note's spaces are underscores. Pasting works on any
ship's draught, like the other kinds (`draught_kinds`).

## Checks (kind `house_plan`)

Errors are what the roof builder refuses. The plan reads the same rules as
`building_slab_info()`, `building_support_base()`, `building_column_carries()`
and `building_design_error()` in `building_levels.dm`:

| Fault | Meaning |
| --- | --- |
| none | no wall or window within 1 tile, pillar within 2, roof support within 3 (a door holds its own tile) |
| soft | the storey is above the second and the ground-floor supports have no foundation |
| weak | the supports in reach, or the storeys under them, do not carry this storey (timber 2, stone 4, concrete 6) |
| air | the supports in reach stand on no roof tile of the storey below |
| column | an upstairs support has nothing as strong within a tile of it on the floor below |
| span | from the second storey up, one distant pillar: no support beside the tile or on a second side |

plus anything upstairs drawn over a tile with no roof below it, and a blank sheet.

Warnings are things the game allows: stairs or a ladder roofed over or coming
up beside no floor, a storey nothing leads up to or tiles cut off from its
stairs, ground-floor tiles walled in with no door, tiles inside the walls with
no roof over them on any storey, a plan with no roof at all.

Notes are advice: roofed tiles not closed in by walls, windows and doors;
stone walls on soft ground in a two-storey house (a third storey would need a
foundation laid first); upper-floor tiles at an open edge.

The plan cannot see the ground it will be built on, so it treats bare ground as
soft. Rock under the walls is a foundation in the game; a house planned without
a stone floor may therefore go higher on rock than its plan says.

When the game follows the first support it finds under an upstairs wall and
the plan accepts any, the two could differ for a wall with two candidate
supports beneath it of which only one is itself carried. The probe has no such
case and none has been seen.

## The window

One storey at a time, drawn with plan symbols on a canvas. The storey buttons
show which storeys hold something and which have a fault. Upstairs the pieces
of the storey below show through faintly and the opening over stairs or a
ladder is marked. "Drag a box" draws a room's outline with walls and fills with
floors, roofing or the eraser. "Roof this storey" roofs everything inside the
walls, wall tiles included, and leaves the tile over stairs and ladders open.
"Copy the walls below" stands the walls, windows and pillars of the storey
below on this one; a door becomes a window. Clicking a check rings its tiles
and steps to its storey.

Every change is sent to the server in parts, read as a design code and
answered with the figures and the checks, so the window never disagrees with
the sheet.

## Pegging a plan out

Val (2026-11-23): a plan can be marked out on the ground as build markers.
`house_plan_pegs.dm` does it with builders' pegs (`docs/build-markers.md`).

- Use the house plan and choose "Peg it out on the ground". The tile the
  builder stands on takes the south-west corner of the drawing; north on the
  sheet is north on the ground. Every tile of the ground floor with something
  drawn on it gets a peg tagged with what to build there.
- The sheet remembers the site (`peg_set`, `peg_x`, `peg_y`, `peg_z`, saved
  with the sheet). For an upper storey the builder stands on that storey and
  chooses "Peg out the storey I stand on": the storey lands over the first.
  Tiles with no floor under them yet are skipped and counted, so the storey is
  pegged again as the roof below is laid.
- A peg asks only for what is not built: pegging a storey again after building
  some of it, or after redrawing it, pulls that level's old pegs and lays the
  rest. The sheet's menu says what the pegs still ask for.
- "Pull up the pegs and forget the site" removes them and lets the plan be
  pegged out somewhere else.
- A note pinned to a tile rides on that tile's peg and keeps the peg standing
  after the tile is built, until someone pulls it.

## Not done

- The window has not been opened in a BYOND client.
- Pegging a plan out has not been tried in a BYOND client.
- A standing building cannot yet be drawn onto a sheet.
- Cellars and underground levels are not planned.
- Buttresses and corbels, which let a wall reach a tile further, are not on
  the palette.
