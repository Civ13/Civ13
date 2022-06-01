var/list/flooring_types

/proc/get_flooring_data(var/flooring_path)
	if (!flooring_types)
		flooring_types = list()
	if (!flooring_types["[flooring_path]"])
		flooring_types["[flooring_path]"] = new flooring_path
	return flooring_types["[flooring_path]"]

// State values:
// [icon_base]: initial base icon_state without edges or corners.
// if has_base_range is set, append FALSE-has_base_range ie.
//   [icon_base][has_base_range]
// [icon_base]_broken: damaged overlay.
// if has_damage_range is set, append FALSE-damage_range for state ie.
//   [icon_base]_broken[has_damage_range]
// [icon_base]_edges: directional overlays for edges.
// [icon_base]_corners: directional overlays for non-edge corners.

/decl/flooring
	var/name = "floor"
	var/desc
	var/icon
	var/icon_base

	var/has_base_range
	var/has_damage_range
	var/has_burn_range
	var/damage_temperature
	var/apply_heat_capacity

	var/build_type	  // Unbuildable if not set. Must be /obj/item/stack.
	var/build_cost = TRUE  // Stack units.
	var/build_time = FALSE  // BYOND ticks.

	var/descriptor = "tiles"
	var/flags
	var/can_paint

/decl/flooring/grass
	name = "grass"
	desc = "Simple grass."
	icon = 'icons/turf/floors.dmi'
	icon_base = "grass"
	has_base_range = 3
	damage_temperature = T0C+80
//	flags = TURF_HAS_EDGES

/decl/flooring/dirt
	name = "dirt"
	desc = "Simple dirt."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/dirt/space
	name = "space"
	desc = "vast emptyness."
	icon = 'icons/turf/floors.dmi'
	icon_base = "space"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/dust
	name = "dry dirt"
	desc = "Simple dry dirt."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dust"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/flooded
	name = "flooded plains dirt"
	desc = "The dirt left after a flood recesses."
	icon = 'icons/turf/floors.dmi'
	icon_base = "flood_dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water
	name = "water"
	desc = "Simple water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_salt
	name = "saltwater"
	desc = "Salt water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_deep
	name = "deep water"
	desc = "Deep water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seadeep"
	has_base_range = 0
	damage_temperature = T0C+8000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_deep_salt
	name = "deep saltwater"
	desc = "Deep salt water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seadeep"
	has_base_range = 0
	damage_temperature = T0C+8000
//	flags = TURF_HAS_EDGES
/decl/flooring/water_deep_salt/shipline
	icon_base = "ship_line"

/decl/flooring/water_swamp
	name = "swamp water"
	desc = "Simple water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow_swamp"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_jungle1
	name = "jungle river water"
	desc = "Simple water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow_jungle1"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_jungle2
	name = "jungle flooded land"
	desc = "Simple water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow_jungle2"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/water_jungle3
	name = "deep jungle river water"
	desc = "Simple water."
	icon = 'icons/misc/beach.dmi'
	icon_base = "seashallow_jungle3"
	has_base_range = 0
	damage_temperature = T0C+3000
//	flags = TURF_HAS_EDGES

/decl/flooring/sand
	name = "sand"
	desc = "Simple sand."
	icon = 'icons/turf/floors.dmi'
	icon_base = "sand"
	has_base_range = 0
	damage_temperature = T0C+200
//	flags = TURF_HAS_EDGES

/decl/flooring/sand_beach
	name = "sand"
	desc = "Simple sand."
	icon = 'icons/misc/beach.dmi'
	icon_base = "sand"
	has_base_range = 0
	damage_temperature = T0C+200
//	flags = TURF_HAS_EDGES

/decl/flooring/desert
	name = "desert sand"
	desc = "Simple desert sand."
	icon = 'icons/misc/beach.dmi'
	icon_base = "desert"
	has_base_range = 0
	damage_temperature = T0C+200
//	flags = TURF_HAS_EDGES


/decl/flooring/snow
	name = "snow"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "snow"
	has_base_range = 0
	damage_temperature = T0C+30
//	flags = TURF_HAS_EDGES


/decl/flooring/snow_grass
	name = "snowy grass"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "snowgrass"
	has_base_range = 0
	damage_temperature = T0C+30
//	flags = TURF_HAS_EDGES

/decl/flooring/snow_dirt
	name = "snowy dirt"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "dirt"
	has_base_range = 0
	damage_temperature = T0C+30
//	flags = TURF_HAS_EDGES
/decl/flooring/carpet
	name = "carpet"
	desc = "Imported and comfy."
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_base = "carpet"
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES | TURF_HAS_CORNERS | TURF_REMOVE_CROWBAR | TURF_CAN_BURN | SMOOTH_ONLY_WITH_ITSELF

/decl/flooring/wood
	name = "wooden floor"
	desc = "Polished redwood planks."
	icon = 'icons/turf/flooring/wood.dmi'
	icon_base = "wood"
	has_damage_range = 6
	damage_temperature = T0C+200
	descriptor = "planks"
	flags = TURF_CAN_BREAK | TURF_IS_FRAGILE | TURF_REMOVE_SCREWDRIVER
