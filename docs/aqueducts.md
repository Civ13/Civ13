# Aqueducts

Code: `code/modules/1713/aqueducts.dm`. Art: `icons/obj/aqueducts.dmi` from
`tests/sprites/create_aqueducts.py`. Probe: `tests/aqueducts/probe.dm`.

Water runs by gravity along aqueduct pieces laid on adjacent tiles, from an
intake to the town below. All pieces are built from the crafting menu once the
Irrigation node (313 B.C.) is known.

- **Intake** (4 stone): set on the bank of fresh water (not sea or coast
  water). Swamp water, or water near a fouled sewer outfall, is foul.
- **Noria** (12 wood): a water wheel on a flowing river. It lifts the water
  two levels above the river. Still water does not turn it.
- **Channel** (2 stone): laid on the ground. Water can enter it only if it
  stands at least as high as the ground there; it then sits at that ground.
- **Arches** (5 stone) and **timber flume** (3 wood): raised pieces that keep
  the water's level across lower ground. People walk under them.
- **Qanat shaft** (3 stone): an underground run that keeps the level through
  higher ground.

- **Clay water pipe** (1 clay) and **lead water pipe** (1 lead, Sanitation,
  1013): carry the water under pressure, down a dip and back up to the level
  it came in at. A tap or fountain fed by a lead pipe next to it picks up a unit
  of lead now and then (a quarter of the minutes), given with what is drawn.

Levels come from the map's terrain heights (`terrain_height_at`). On a map
without height data everything is level and water reaches every piece.

Once a minute every network is walked from all its intakes at once
(`aqueduct_flow_all`, at most 800 pieces per intake). Every tile next to a wet
piece is fed:

- a **public fountain** (6 stone) fills by 200 units, up to 600, and fills
  from nothing else;
- a **water tap** (2 bronze, Sanitation) fills like a fountain, up to 300;
- a **public bath** (4 stone, Hygiene) fills, and drains five minutes after
  the water stops. Bathing (10 s, undressed) sets hygiene to clean and lifts
  mood; with a lit brazier, fire or engine near it the water is warm and the
  bather warms up. Foul bath water makes bathers ill instead;
- a **cistern** fills by 200;
- a **mill wheel** turns on the mill race for 90 seconds;
- a clogged **sewer drain** is flushed clear.

A dead body or loose waste lying in a channel fouls the water from that piece
on. Fountains below give foul water (5% cholera, like a dirty well) until the
channel is cleared. Breaking a piece cuts off every piece below it.

Wet state is runtime only (`tmp`); it is rebuilt on the first walk after a
load. Fountain volume and dirtiness are saved like a sink's.
