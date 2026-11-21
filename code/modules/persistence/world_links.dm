// ============================================================
// The world links (docs/world-links.md)
// ------------------------------------------------------------
// Written by tools/world_links/build.py from tools/world_links/world_links.json.
// Do not edit by hand: change the JSON and run the script.
// ============================================================

// Region id = the map edges that lead on, in the shape of
// /obj/map_metadata/var/edge_crossings (region_edge.dm): side = list(region id =
// list(from, to)), the stretch of that edge counted west to east or south to north.
var/global/list/world_links = list(
	"africa" = list("east" = list("asia" = list(0.68, 1))),
	"asia" = list("west" = list("africa" = list(0, 0.45), "europe" = list(0.45, 1))),
	"europe" = list("east" = list("asia" = list(0, 1))),
	"northamerica" = list("south" = list("southamerica" = list(0, 1))),
	"southamerica" = list("north" = list("northamerica" = list(0, 1)))
)

// id = list(x, y, coasts, flight): x grows east, y grows north. coasts: the map
// edges with open deep water along them, best first. flight: TRUE when the map
// has a standing open-air level that aircraft fly on (aircraft_crossing.dm).
var/global/list/continent_layout = list(
	"northamerica" = list(0, 6, list("E", "W", "N", "S"), TRUE),
	"southamerica" = list(2, 0, list("E", "W", "S", "N"), TRUE),
	"gaia" = list(6, 7, list("W", "E"), TRUE),
	"europe" = list(11, 9, list("W", "N"), TRUE),
	"desert" = list(12, 4, list("N"), TRUE),
	"africa" = list(12, 3, list("W", "S", "E"), TRUE),
	"oceania" = list(21, 1, list("N", "S", "W", "E"), TRUE),
	"greenland" = list(6, 11, list("E", "S", "N"), TRUE),
	"antarctica" = list(10, -5, list("N", "E", "S", "W"), TRUE),
	"jungle" = list(13, 1, list("W"), TRUE),
	"asia" = list(18, 8, list("E", "S", "N"), TRUE)
)
