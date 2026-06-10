/turf/wall/sub_hull
	name = "submarine pressure hull"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "metal0"
	opacity = 1
	density = 1
	var/hull_integrity = 1000
	flags = TURF_HAS_EDGES

/turf/wall/sub_hull/New(var/newloc)
	..(newloc,"iron")

/turf/wall/sub_bulkhead
	name = "internal bulkhead"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "metal0"
	opacity = 1
	density = 1
	var/health = 200
	flags = TURF_HAS_EDGES

/turf/wall/sub_bulkhead/New(var/newloc)
	..(newloc,"iron")

/turf/wall/sub_bulkhead/sub_shielding
	name = "lead reactor shielding"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "solid0"
	opacity = 1
	density = 1
	// custom variable to block rad vectors
	var/rad_dampening = 1.0 
	flags = TURF_HAS_EDGES

/turf/wall/sub_bulkhead/sub_shielding/New(var/newloc)
	..(newloc,"steel")

/turf/floor/sub_deck
	name = "deck floor"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"
	var/water_depth = 0 // in cm, max 200
	var/blocked_airlocks = 0