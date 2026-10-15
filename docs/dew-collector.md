# Dew collector

Implementation in progress. Build a dew collector from eight softwood planks
after Basic Agriculture. It starts empty, stores at most 200 units, and reuses
the existing wooden-barrel sprite.

Open the cover by hand and place it outdoors without a roof. A continuous minute
of clear Night, Dark Night or Early Morning weather at above freezing and at most
30 C produces 2 units of water. Rain or monsoon produces 10 units per minute.
Snow, sandstorms, blizzards, heat waves, radiation and indoor/roofed placements
produce nothing. These are explicit game rules, not a humidity simulation.

Use an open container held in hand to draw water after a short action. The cover
setting and actual reagent contents use existing native persistence. Partial
minutes and in-progress drawing are runtime state and reset on load. Closing
the cover or losing eligible conditions cancels partial collection. Lag and
offline time do not produce a backlog. Retirement unregisters the collector.

Acceptance requires production construction/research, exposure/time/weather,
capacity, transfer conservation/cancellation, repeated lifecycle and native disk
round-trip checks with mutation controls. No gameplay, runtime or CI pass is
claimed by this draft document.
