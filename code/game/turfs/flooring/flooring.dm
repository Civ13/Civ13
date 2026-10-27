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
	var/tier = 0 // Natural floor hierarchy. Higher tier shows edge against lower.

/decl/flooring/grass
	name = "grass patch"
	desc = "Simple grass."
	icon = 'icons/turf/floors.dmi'
	icon_base = "grass"
	has_base_range = 3
	damage_temperature = T0C+80
	flags = TURF_HAS_EDGES
	tier = 5

/decl/flooring/grass/savanna
	name = "dry grass patch"
	desc = "Dry savanna grass."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dry_grass"
	has_base_range = 0
	damage_temperature = T0C+80
	flags = TURF_HAS_EDGES
	tier = 5

/decl/flooring/dirt
	name = "dirt patch"
	desc = "Simple dirt."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 4

/decl/flooring/dirt/burned
	name = "burnt ground"
	desc = "Scorched earth."
	icon = 'icons/turf/floors.dmi'
	icon_base = "burned_dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 4

/decl/flooring/dirt/underground
	name = "underground rock"
	desc = "Solid rock."
	icon = 'icons/turf/walls.dmi'
	icon_base = "rocky"
	has_base_range = 0
	tier = 0

/decl/flooring/dirt/dry_lava
	name = "dried lava"
	desc = "Cooled volcanic rock."
	icon = 'icons/turf/floors.dmi'
	icon_base = "lava_dry"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 4

/decl/flooring/dirt/ploughed
	name = "ploughed field"
	desc = "Tilled soil ready for planting."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 4

/decl/flooring/dirt/space
	name = "space"
	desc = "vast emptyness."
	icon = 'icons/turf/floors.dmi'
	icon_base = "space"
	has_base_range = 0
	damage_temperature = T0C+3000
	tier = 4

/decl/flooring/dust
	name = "dry dirt patch"
	desc = "Simple dry dirt."
	icon = 'icons/turf/floors.dmi'
	icon_base = "dust"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/flooded
	name = "flooded plains dirt patch"
	desc = "The dirt left after a flood recesses."
	icon = 'icons/turf/floors.dmi'
	icon_base = "flood_dirt"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 4

/decl/flooring/water
	name = "shallow water"
	desc = "Simple water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/water_salt
	name = "saltwater"
	desc = "Salt water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/water/ice
	name = "frozen water"
	desc = "A sheet of ice."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow_frozen"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/water_deep
	name = "deep water"
	desc = "Deep water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seadeep"
	has_base_range = 0
	damage_temperature = T0C+8000
	flags = TURF_HAS_EDGES
	tier = 1

/decl/flooring/water_deep_salt
	name = "deep saltwater"
	desc = "Deep salt water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seadeep"
	has_base_range = 0
	damage_temperature = T0C+8000
	flags = TURF_HAS_EDGES
	tier = 1

/decl/flooring/water_deep_underwater
	name = "deep saltwater"
	desc = "Deep salt water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "underwater"
	has_base_range = 0
	damage_temperature = T0C+8000
	flags = TURF_HAS_EDGES
	tier = 1

/decl/flooring/water_deep_salt/shipline
	icon_base = "ship_line"
	tier = 0

/decl/flooring/water_swamp
	name = "swamp water"
	desc = "Simple water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow_swamp"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/water_jungle1
	name = "jungle river water"
	desc = "Simple water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow_jungle1"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/water_jungle2
	name = "jungle flooded land"
	desc = "Simple water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow_jungle2"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/water_jungle3
	name = "deep jungle river water"
	desc = "Simple water."
	icon = 'icons/turf/beach.dmi'
	icon_base = "seashallow_jungle3"
	has_base_range = 0
	damage_temperature = T0C+3000
	flags = TURF_HAS_EDGES
	tier = 2

/decl/flooring/sand
	name = "sand"
	desc = "Simple sand."
	icon = 'icons/turf/floors.dmi'
	icon_base = "sand"
	has_base_range = 0
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/sand/drywater
	name = "dry riverbed"
	desc = "A dried up riverbed."
	icon = 'icons/turf/floors.dmi'
	icon_base = "sand1"
	has_base_range = 0
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/sand_beach
	name = "sand"
	desc = "Simple sand."
	icon = 'icons/turf/beach.dmi'
	icon_base = "sand"
	has_base_range = 0
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/desert
	name = "desert sand"
	desc = "Simple desert sand."
	icon = 'icons/turf/beach.dmi'
	icon_base = "desert"
	has_base_range = 0
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES
	tier = 3

/decl/flooring/sand/dark
	name = "dark sand"
	desc = "Simple dark sand."
	icon = 'icons/turf/floors.dmi'
	icon_base = "darksand"
	has_base_range = 0
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES
	tier = 3


/decl/flooring/snow
	name = "snow"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "snow"
	has_base_range = 0
	damage_temperature = T0C+30
	flags = TURF_HAS_EDGES
	tier = 6


/decl/flooring/snow_grass
	name = "snowy grass"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "snowgrass"
	has_base_range = 0
	damage_temperature = T0C+30
	flags = TURF_HAS_EDGES
	tier = 6

/decl/flooring/snow_dirt
	name = "snowy dirt"
	desc = "Simple snow."
	icon = 'icons/turf/snow.dmi'
	icon_base = "dirt"
	has_base_range = 0
	damage_temperature = T0C+30
	flags = TURF_HAS_EDGES
	tier = 6
/decl/flooring/carpet
	name = "carpet"
	desc = "Imported and comfy."
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_base = "carpet"
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES | TURF_HAS_CORNERS | TURF_REMOVE_CROWBAR | TURF_CAN_BURN | SMOOTH_ONLY_WITH_ITSELF

/decl/flooring/carpet/blue
	icon_base = "blucarpet"

/decl/flooring/carpet/green
	icon_base = "turcarpet"

/decl/flooring/carpet/black
	icon_base = "bcarpet"

/decl/flooring/carpet/bluelight
	icon_base = "sblucarpet"

/decl/flooring/carpet/pink
	icon_base = "gaycarpet"

/decl/flooring/carpet/purple
	icon_base = "purcarpet"

/decl/flooring/carpet/orange
	icon_base = "oracarpet"

/decl/flooring/carpet/white
	icon_base = "wcarpet"

/decl/flooring/wood
	name = "wooden floor"
	desc = "Polished redwood planks."
	icon = 'icons/turf/flooring/wood.dmi'
	icon_base = "wood"
	has_damage_range = 6
	damage_temperature = T0C+200
	descriptor = "planks"
	flags = TURF_CAN_BREAK | TURF_IS_FRAGILE | TURF_REMOVE_SCREWDRIVER
