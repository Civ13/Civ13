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
	var/apply_thermal_conductivity
	var/apply_heat_capacity

	var/build_type      // Unbuildable if not set. Must be /obj/item/stack.
	var/build_cost = TRUE  // Stack units.
	var/build_time = FALSE  // BYOND ticks.

	var/descriptor = "tiles"
	var/flags
	var/can_paint

/decl/flooring/grass
	name = "grass"
	desc = "Do they smoke grass out in space, Bowie? Or do they smoke AstroTurf?"
	icon = 'icons/turf/flooring/grass.dmi'
	icon_base = "grass"
	has_base_range = 3
	damage_temperature = T0C+80
	flags = TURF_REMOVE_SHOVEL

/decl/flooring/asteroid
	name = "coarse sand"
	desc = "Gritty and unpleasant."
	icon = 'icons/turf/flooring/asteroid.dmi'
	icon_base = "asteroid"
	flags = TURF_HAS_EDGES | TURF_REMOVE_SHOVEL
	build_type = null


/decl/flooring/carpet
	name = "carpet"
	desc = "Imported and comfy."
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_base = "carpet"
	damage_temperature = T0C+200
	flags = TURF_HAS_EDGES | TURF_HAS_CORNERS | TURF_REMOVE_CROWBAR | TURF_CAN_BURN | SMOOTH_ONLY_WITH_ITSELF

/decl/flooring/tiling
	name = "floor"
	desc = "Scuffed from the passage of countless greyshirts."
	icon = 'icons/turf/flooring/tiles.dmi'
	icon_base = "steel"
	has_damage_range = 2 //RECHECK THIS. MAYBE MISTAKE
	damage_temperature = T0C+1400
	flags = TURF_REMOVE_CROWBAR | TURF_CAN_BREAK | TURF_CAN_BURN
	can_paint = TRUE

/decl/flooring/tiling/new_tile
	name = "floor"
	icon_base = "tile_full"
	flags = TURF_CAN_BREAK | TURF_CAN_BURN | TURF_IS_FRAGILE
	build_type = null

/decl/flooring/tiling/new_tile/cargo_one
//	name = "cargo one"
	icon_base = "cargo_one_full"

/decl/flooring/tiling/new_tile/kafel
//	name = "kafel"
	icon_base = "kafel_full"

/decl/flooring/tiling/new_tile/techmaint
//	name = "techmaint"
	icon_base = "techmaint"

/decl/flooring/tiling/new_tile/monofloor
//	name = "monofloor"
	icon_base = "monofloor"

/decl/flooring/tiling/new_tile/monotile
//	name = "monotile"
	icon_base = "monotile"

/decl/flooring/tiling/new_tile/steel_grid
//	name = "steelgrid"
	icon_base = "steel_grid"

/decl/flooring/tiling/new_tile/steel_ridged
//	name = "steelridged"
	icon_base = "steel_ridged"


/decl/flooring/tiling/steel
	name = "floor"
	icon_base = "steel"

/decl/flooring/tiling/white
	name = "floor"
	desc = "How sterile."
	icon_base = "white"

/decl/flooring/tiling/dark
	name = "floor"
	desc = "How ominous."
	icon_base = "dark"


/decl/flooring/wood
	name = "wooden floor"
	desc = "Polished redwood planks."
	icon = 'icons/turf/flooring/wood.dmi'
	icon_base = "wood"
	has_damage_range = 6
	damage_temperature = T0C+200
	descriptor = "planks"
	flags = TURF_CAN_BREAK | TURF_IS_FRAGILE | TURF_REMOVE_SCREWDRIVER
