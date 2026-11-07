// ============================================================
// The Moon (space settlement, second world)
// ------------------------------------------------------------
// The Moon is a barren world like Mars (barren_world.dm) with its own
// ground, area and map settings. It is a subtype of each barren type, so
// landers, habitat modules, mining, hazards and meteorites treat it as
// barren ground with no extra checks. Only three things differ:
//
// - the ground is grey and colder (MOON_AMBIENT_C instead of -60 C);
// - there is no air at all, so no weather and no dust storms;
// - its region id is "moon" (maps/space/moon.dmm, config/space/survey/moon.json).
//
// Every Moon region map uses /obj/map_metadata/nomads/barren/moon, so
// later Moon colonies (docs/connected-regions-plan.md) are more region maps
// of the same type with their own region ids.
// ============================================================

#define MOON_AMBIENT_C -100

// TRUE when this world is the Moon (or a Moon colony region).
/proc/moon_world()
	return istype(map, /obj/map_metadata/nomads/barren/moon)

// The open-ground temperature of this barren world before any cold snap.
/proc/space_world_base_ambient_c()
	return moon_world() ? MOON_AMBIENT_C : BARREN_AMBIENT_C

// Only a world with an atmosphere raises dust storms.
/proc/space_world_has_dust_storms()
	return !moon_world()

/turf/floor/dirt/dust/regolith/lunar
	name = "lunar regolith"
	desc = "Fine grey dust over bare rock, unmarked by wind or water. Nothing grows in it."
	color = "#9c9a96"

/turf/floor/dirt/dust/regolith/lunar/crater
	name = "crater floor"
	desc = "Dark, packed grey grit at the bottom of an old impact."
	color = "#6c6a68"

// Outdoor area for a Moon region map.
/area/caribbean/nomads/barren/moon
	name = "Grey Plain"
	base_turf = /turf/floor/dirt/dust/regolith/lunar
	ambience = list()

// Map settings for a Moon region (maps/space/moon.dmm).
/obj/map_metadata/nomads/barren/moon
	title = "The Moon"
	description = "A grey, airless world under a black sky. Settlers live in sealed habitats and walk the surface in pressure suits."
	battle_name = "settlement of the Moon"
	mission_start_message = "<big>A grey, airless world under a black sky. Settlers who land here live in sealed habitats and walk the surface in pressure suits.</big>"
	valid_weather_types = list(WEATHER_NONE)
	ambience = list()
