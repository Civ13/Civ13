// ============================================================
// Barren world ground and area (space settlement phase 0, inactive)
// ------------------------------------------------------------
// Outdoor ground for the barren-world region: cold, dry and without
// breathable air. No shipped map uses these turfs yet. "Outside" is a
// turf property, so the open surface costs nothing per tick; only sealed
// habitats carry air (see habitat_ledger.dm).
// Reuses the dry-dirt sprite with a tint; no new art.
// ============================================================

#define BARREN_AMBIENT_C -60
#define BARREN_COLD_SNAP_DROP_C 35

// Whether a person standing here in the open could breathe. Habitat
// modules (phase 3) answer for the turfs they enclose.
/turf/proc/outside_air_breathable()
	return TRUE

// The open-air temperature this ground imposes, or null to keep the
// ordinary weather and climate rules.
/turf/proc/outside_ambient_c()
	return null

// TRUE for unsheltered barren ground, where surface hazards reach people.
/turf/proc/barren_open_ground()
	return FALSE

// The barren surface temperature now: a cold snap (surface_hazards.dm)
// drives it lower for a while.
/proc/barren_ambient_c()
	return BARREN_AMBIENT_C - (barren_cold_seconds > 0 ? BARREN_COLD_SNAP_DROP_C : 0)

/turf/floor/dirt/dust/regolith
	name = "regolith"
	desc = "Loose, rusty dust and grit over bare rock. Nothing grows in it."
	color = "#c98a62"
	uses_winter_overlay = FALSE
	may_become_muddy = FALSE
	soil_nutrition = 0
	max_soil_nutrition = 0

/turf/floor/dirt/dust/regolith/crater
	name = "crater floor"
	desc = "Dark, packed grit at the bottom of an old impact."
	color = "#8f5c45"

/turf/floor/dirt/dust/regolith/outside_air_breathable()
	return FALSE

/turf/floor/dirt/dust/regolith/outside_ambient_c()
	return barren_ambient_c()

/turf/floor/dirt/dust/regolith/barren_open_ground()
	return TRUE

// Outdoor area for a barren-world region map. The desert climate turns wet
// weather away in the dry seasons and its extreme weather is a dust storm.
// Seasonal temperatures and rain are not yet barren-specific (phase 4).
/area/caribbean/nomads/barren
	name = "Barren Plain"
	base_turf = /turf/floor/dirt/dust/regolith
	icon_state = "red3"
	ambience = list("sound/ambience/desert.ogg")
	climate = "desert"
