// ============================================================
// The world links (docs/world-links.md)
// ------------------------------------------------------------
// Written by tools/world_links/build.py from tools/world_links/world_links.json.
// Do not edit by hand: change the JSON and run the script.
// ============================================================

// Region id = the map edges walked over, in the shape of
// /obj/map_metadata/var/edge_crossings (region_edge.dm): side = list(region id =
// list(from, to)), the stretch of that edge counted west to east or south to north.
var/global/list/world_links = list(
	"africa" = list("east" = list("asia" = list(0.68, 1))),
	"asia" = list("west" = list("africa" = list(0, 0.45), "europe" = list(0.45, 1))),
	"europe" = list("east" = list("asia" = list(0, 1))),
	"northamerica" = list("south" = list("southamerica" = list(0, 1))),
	"southamerica" = list("north" = list("northamerica" = list(0, 1)))
)

// The same for the edges ships sail over, into and out of the oceans.
var/global/list/world_sea_links = list(
	"africa" = list("east" = list("indian" = list(0, 0.68)), "south" = list("southern" = list(0, 1)), "west" = list("atlantic" = list(0, 1))),
	"antarctica" = list("north" = list("southern" = list(0, 1))),
	"arctic" = list("south" = list("pacific" = list(0, 0.12), "northamerica" = list(0.12, 0.32), "atlantic" = list(0.32, 0.42), "europe" = list(0.42, 0.6), "asia" = list(0.6, 1))),
	"asia" = list("east" = list("pacific" = list(0, 0.85), "northamerica" = list(0.85, 1)), "north" = list("arctic" = list(0, 1)), "south" = list("indian" = list(0, 1))),
	"atlantic" = list("east" = list("africa" = list(0, 0.42), "europe" = list(0.5, 1)), "north" = list("arctic" = list(0, 1)), "south" = list("southern" = list(0, 1)), "west" = list("southamerica" = list(0, 0.4), "northamerica" = list(0.4, 1))),
	"europe" = list("north" = list("arctic" = list(0, 1)), "west" = list("atlantic" = list(0, 1))),
	"indian" = list("east" = list("oceania" = list(0, 1)), "north" = list("asia" = list(0, 1)), "south" = list("southern" = list(0, 1)), "west" = list("africa" = list(0, 1))),
	"northamerica" = list("east" = list("atlantic" = list(0, 1)), "north" = list("arctic" = list(0, 1)), "west" = list("pacific" = list(0, 0.85), "asia" = list(0.85, 1))),
	"oceania" = list("east" = list("pacific" = list(0, 1)), "north" = list("pacific" = list(0, 1)), "south" = list("southern" = list(0, 1)), "west" = list("indian" = list(0, 1))),
	"pacific" = list("east" = list("southamerica" = list(0, 0.45), "northamerica" = list(0.45, 1)), "north" = list("arctic" = list(0, 1)), "south" = list("oceania" = list(0, 0.3), "southern" = list(0.3, 1)), "west" = list("oceania" = list(0, 0.35), "asia" = list(0.35, 1))),
	"southamerica" = list("east" = list("atlantic" = list(0, 1)), "south" = list("southern" = list(0, 1)), "west" = list("pacific" = list(0, 1))),
	"southern" = list("north" = list("pacific" = list(0, 0.25), "southamerica" = list(0.25, 0.3), "atlantic" = list(0.3, 0.42), "africa" = list(0.42, 0.48), "indian" = list(0.48, 0.65), "oceania" = list(0.65, 1)), "south" = list("antarctica" = list(0, 1)))
)

// Ocean id = list(width, height, name, chart x, chart y, wrap sides).
var/global/list/world_oceans = list(
	"atlantic" = list(600, 900, "Atlantic Ocean", 7, 5, list()),
	"pacific" = list(900, 900, "Pacific Ocean", 25, 5, list()),
	"indian" = list(600, 600, "Indian Ocean", 17, 0, list()),
	"arctic" = list(1000, 300, "Arctic Ocean", 12, 13, list("west")),
	"southern" = list(1200, 300, "Southern Ocean", 12, -3, list("west"))
)

// Ocean id = list(land id = list(x0, y0, x1, y1)): the waters of an island land
// inside this ocean. Sailing into the box crosses to the land; leaving the land
// by a sea edge comes out on that side of the box.
var/global/list/world_insets = list(
	"atlantic" = list("gaia" = list(250, 560, 299, 594), "greenland" = list(200, 780, 239, 829))
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
