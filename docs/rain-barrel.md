# Rain barrels

Wood barrels and steel barrels collect water. There is no separate dew
collector any more. A new empty barrel starts with its lid off; using a barrel
in hand toggles the lid.

Set an open barrel down outdoors with no roof over its tile. A continuous minute
of rain or monsoon adds 10 units of water. A continuous minute of clear Night,
Dark Night or Early Morning weather at above freezing and at most 30 C adds
2 units of dew. Collection stops when the barrel is full. Snow, sandstorms,
blizzards, heat waves, radiation, indoor or roofed placements, closed lids and
carried barrels produce nothing. Jerrycans and fuel tanks never collect. Rain
mixes into whatever the open barrel already holds. These are explicit game
rules, not a humidity simulation.

Every barrel registers with the object loop when created, restored or opened;
the first tick drops closed barrels and jerrycans/fuel tanks again. The lid and
contents use existing native persistence. Partial minutes are runtime state and
reset on load. Lag and offline time do not produce a backlog.

Legacy dew collectors (old saves or admin spawns) keep their saved type so
loads still accept them. On their first object tick, outside any load, each one
becomes a wood barrel at the same spot holding its water, closed if its cover
was closed. The collector recipe and its research mapping are retired.

`tests/rain_barrel/run.py` checks rates, exposure, timing, capacity, lid and
registration, jerrycans, native disk round trips and the legacy conversion.
Its exposure, timing, persistence, lid and legacy controls must each fail at the
named assertion. Success does not prove an ordinary-player walkthrough or
live-server behavior.
