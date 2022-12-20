#define NORTH_EDGING	"north"
#define SOUTH_EDGING	"south"
#define EAST_EDGING		"east"
#define WEST_EDGING		"west"

/turf/floor/wood
	name = "floor"
	icon_state = "wood"
	stepsound = "wood"

/turf/floor/wood/ship
	name = "floor"
	icon_state = "wood_ship"
	stepsound = "wood"

/turf/floor/wood/fancywood
	name = "floor"
	icon_state = "fancywood"

/turf/floor/blackslateroof
	name = "roof"
	icon = 'icons/turf/roofs.dmi'
	icon_state = "black_slateroof_dm"

/* when this is a subtype of /turf/floor/wood, it doesn't get the right icon.
 * not sure why right now - kachnov */

/turf/floor/wood_broken
	name = "floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "broken0"
	stepsound = "wood"

/turf/floor/wood_broken/New()
	..()
	icon_state = "broken[rand(0,6)]"
/turf/floor/plating
	name = "plating"
	icon_state = "plating"
	floor_type = null
	intact = FALSE

/turf/floor/plating/ex_act(severity)
		//set src in oview(1)
	switch(severity)
		if (1.0)
			ChangeTurf(get_base_turf_by_area(src))
		if (2.0)
			if (prob(40))
				ChangeTurf(get_base_turf_by_area(src))
	return

/turf/floor/grass
	name = "Grass patch"
	icon = 'icons/turf/floors.dmi'
	icon_state = "grass0"
	var/deadicon = 'icons/turf/floors.dmi'//Rad stuff what to turn into
	var/deadicon_state = "ndead_grass1"//Rad stuff what to turn into
	var/grassamt = 1
	New()
		icon_state = "grass[pick("0","1","2","3")]"
		deadicon_state = "dead_grass[pick("0","1","2","3")]"//Rad stuff what to turn into
		..()
		spawn(4)
			if (src)
				update_icon()
				for (var/direction in cardinal)
					if (istype(get_step(src,direction),/turf/floor))
						var/turf/floor/FF = get_step(src,direction)
						FF.update_icon() //so siding get updated properly

/turf/floor/carpet
	name = "Carpet"
	icon_state = "carpet"
	icon = 'icons/turf/flooring/carpet.dmi'
	flooring = null
	New()
		if (!icon_state)
			icon_state = "carpet"
		..()
		spawn(4)
			if (src)
				update_icon()
				for (var/direction in list(1,2,4,8,5,6,9,10))
					if (istype(get_step(src,direction),/turf/floor))
						var/turf/floor/FF = get_step(src,direction)
						FF.update_icon() //so siding get updated properly

//Carpets - To be Expanded Upon

/turf/floor/carpet/pinkcarpet
	name = "Pink Carpet"
	icon_state = "gaycarpet"

/turf/floor/carpet/redcarpet
	name = "Red Carpet"
	icon_state = "carpet"

/turf/floor/carpet/orangecarpet
	name = "Orange Carpet"
	icon_state = "oracarpet"

/turf/floor/carpet/purplecarpet
	name = "Purple Carpet"
	icon_state = "purcarpet"

/turf/floor/carpet/bluecarpet
	name = "Blue Carpet"
	icon_state = "blucarpet"

/turf/floor/carpet/tealcarpet
	name = "Teal Carpet"
	icon_state = "sblucarpet"

/turf/floor/carpet/greencarpet
	name = "Green Carpet"
	icon_state = "turcarpet"

/turf/floor/carpet/blackcarpet
	name = "Black Carpet"
	icon_state = "bcarpet"

/turf/floor/carpet/whitecarpet
	name = "White Carpet"
	icon_state = "wcarpet"
//Continue

/turf/floor/plating/ironsand/New()
	..()
	icon = 'icons/turf/floors.dmi'
	name = "Iron Sand"
	icon_state = "ironsand[rand(1,15)]"

/turf/floor/grass/jungle
	name = "jungle grass"
	overlay_priority = 0
	is_diggable = TRUE
	may_become_muddy = TRUE
	initial_flooring = null

/turf/floor/grass/edge
	name = "grass edge"
	icon_state = "grass_edges"
	is_diggable = FALSE
	may_become_muddy = FALSE

/turf/floor/grass/edge/dead
	name = "dead grass edge"
	icon_state = "dead_grass_edges"
	is_diggable = FALSE
	may_become_muddy = FALSE

/turf/floor/grass/jungle/savanna
	name = "dry grass"
	icon_state = "dry_grass"
	initial_flooring = null

/turf/floor/grass/jungle/savanna/New()
	..()
	icon_state = "dry_grass"
	deadicon_state = "dead_grass[pick("0","1","2","3")]"//Rad stuff what to turn into

/turf/floor/winter
	name = "snow"
	icon = 'icons/turf/snow.dmi'
	icon_state = "snow"
	is_diggable = TRUE
	available_snow = 3
	initial_flooring = /decl/flooring/snow

/turf/floor/winter/ex_act(severity)
	return

/turf/floor/winter/grass
	name = "snowy grass"
	icon = 'icons/turf/snow.dmi'
	icon_state = "grass2"
	is_diggable = TRUE
	available_snow = 2
	initial_flooring = /decl/flooring/snow_grass
	var/deadicon = 'icons/turf/snow.dmi'//Rad stuff what to turn into
	var/deadicon_state = "dead_snowgrass"//Rad stuff what to turn into

/turf/floor/winter/grass/New()
	..()
	icon = 'icons/turf/snow.dmi'
	icon_state = "grass[rand(0,6)]"
	initial_flooring = null

/turf/floor/beach
	name = "beach"
	icon = 'icons/misc/beach.dmi'
	initial_flooring = null

/turf/floor/beach/drywater
	name = "dry riverbed"
	icon = 'icons/turf/floors.dmi'
	icon_state = "sand1"
	is_diggable = FALSE
	initial_flooring = null

/turf/floor/beach/drywater2
	name = "dry riverbed"
	icon = 'icons/turf/floors.dmi'
	icon_state = "sand1"
	is_diggable = FALSE
	initial_flooring = null

/turf/floor/beach/sand
	name = "sand"
	icon_state = "sand"
	is_diggable = TRUE
	available_sand = 22
	initial_flooring = /decl/flooring/sand_beach

/turf/floor/beach/sand/edges
	name = "sand"
	icon_state = "sand_edges"
	is_diggable = TRUE
	available_sand = 11
	initial_flooring = /decl/flooring/sand_beach

/turf/floor/beach/sand/dark
	name = "dark sand"
	icon = 'icons/turf/floors.dmi'
	icon_state = "darksand"
	is_diggable = TRUE
	available_sand = 4
	initial_flooring = null

/turf/floor/beach/coastline
	name = "coastline"
	icon = 'icons/misc/beach2.dmi'
	icon_state = "sandwater"
	watertile = TRUE
//water level is measured in centimeters. the maximum is 200 (2 meters). up to 1.5 will make movement progressively slower, up from that you will drown if you stay for too long.

/turf/floor/beach/water
	name = "shallow water"
	desc = "Water. Seems to be shallow."
	icon_state = "seashallow"
	move_delay = 3
	water_level = 30 // in centimeters
	salty = FALSE
	var/sickness = 1 //amount of toxins, from 0 to 3
	initial_flooring = /decl/flooring/water
	watertile = TRUE
	var/image/water_overlay = null

/turf/floor/beach/water/New()
	..()
	water_turf_list += src
	spawn(1)
		water_overlay = image(icon='icons/misc/beach.dmi')
		water_overlay.icon_state= "[icon_state]_ov"
		water_overlay.layer= 10

/turf/floor/beach/water/coastwater
	name = "coast water"
	desc = "lovely water hitting the coast line"
	icon_state = "beach"

/turf/floor/beach/water/coastwater/corner
	name = "coast water corner"
	desc = "lovely water hitting the coast line"
	icon_state = "beachcorner"

/turf/floor/beach/water/coastwater/layer
	name = "coast water"
	desc = "lovely water hitting the coast line"
	icon_state = "seashallow_edgesX"

/turf/floor/beach/water/shallowsaltwater
	name = "saltwater"
	salty = TRUE
	initial_flooring = /decl/flooring/water_salt

/turf/floor/beach/water/deep
	name = "deep water"
	icon_state = "seadeep"
	desc = "Water. Seems to be very deep, you cant see the bottom."
	water_level = 200
	density = FALSE
	initial_flooring = /decl/flooring/water_deep
	move_delay = 20

/turf/floor/beach/water/deep/saltwater/shipline
	icon_state = "ship_line"
	initial_flooring = /decl/flooring/water_deep_salt/shipline

/turf/floor/beach/water/deep/Crossed(atom/A)
	..()
	check_sinking(A)
/turf/floor/beach/water/deep/Entered(atom/movable/A)
	..()
	check_sinking(A)

/turf/floor/beach/water/proc/check_sinking(atom/movable/A)
	if(iscovered())
		return
	if (!istype(A, /mob) && !istype(A, /obj/structure/vehicle) && !istype(A, /obj/structure/fishing_cage) && !istype(A, /obj/covers) && !istype(A, /obj/structure/barricade) && !istype(A, /obj/effect/sailing_effect))
		spawn(60)
			var/turf/TF = A.loc
			if (istype(TF,/turf/floor/beach/water/deep) && !TF.iscovered())
				qdel(A)
	if(istype(A, /mob/living))
		var/mob/living/ML = A
		if (ishuman(ML))
			var/mob/living/human/H = ML
			if (H.driver_vehicle)
				return
			if (istype(H.wear_suit, /obj/item/clothing/suit/lifejacket))
				return
		if (ML && ML.stat == DEAD)
			spawn(60)
				if (A && A.loc == src)
					qdel(A)
/turf/floor/beach/water/deep/jungle
	name = "deep jungle river"
	icon_state = "seashallow_jungle3"
	desc = "Water. Seems to be very deep, you cant see the bottom."
	water_level = 200
	density = FALSE
	initial_flooring = /decl/flooring/water_jungle3

/turf/floor/beach/water/deep/swamp
	name = "deep swamp"
	icon_state = "seashallow_swamp"
	desc = "Water. Seems to be very deep, you cant see the bottom."
	water_level = 200
	density = FALSE
	initial_flooring = /decl/flooring/water_swamp

/turf/floor/beach/water/deep/saltwater
	name = "deep saltwater"
	salty = TRUE
	initial_flooring = /decl/flooring/water_deep_salt

/turf/floor/beach/water/deep/saltwater/underwater
	name = "deep saltwater"
	salty = TRUE
	initial_flooring = /decl/flooring/water_deep_salt


/turf/floor/beach/water/deep/CanPass(atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		return TRUE
	else if (istype(mover, /mob) && !iscovered())
		if (ishuman(mover))
			var/mob/living/human/H = mover
			if(istype(H.wear_suit, /obj/item/clothing/suit/lifejacket))
				return TRUE
		return FALSE
	else
		return ..()

/turf/proc/iscovered()
	for(var/obj/covers/C in src.contents)
		return TRUE
	for (var/obj/structure/vehicleparts/frame/ship/S in src.contents)
		return TRUE
	for(var/obj/structure/STR in src.contents)
		var/obj/structure/vehicleparts/frame/ship/S
		if (S in src.contents)
			return TRUE
		else
			return FALSE
	for(var/obj/item/OB in src.contents)
		var/obj/structure/vehicleparts/frame/ship/S
		if (S in src.contents)
			return TRUE
		else
			return FALSE
	for(var/obj/structure/multiz/ladder/ST in src.contents)
		return TRUE
	for (var/obj/structure/vehicleparts/axis/ship/SA in src.contents)
		return TRUE
	for (var/obj/structure/vehicleparts/shipwheel/SW in src.contents)
		return TRUE
	for (var/obj/structure/vehicleparts/movement/sails/SM in src.contents)
		return TRUE
	for (var/obj/structure/vehicle/boat/B in src.contents)
		return TRUE
	for (var/obj/structure/vehicle/raft/R in src.contents)
		return TRUE
	return FALSE
/turf/floor/beach/water/swamp
	name = "swamp"
	move_delay = 3
	icon_state = "seashallow_swamp"
	sickness = 3
	initial_flooring = /decl/flooring/water_swamp

/turf/floor/beach/water/jungle
	name = "jungle river"
	move_delay = 5
	icon_state = "seashallow_jungle1"
	sickness = 2
	initial_flooring = /decl/flooring/water_jungle1

/turf/floor/beach/water/flooded
	name = "flooded riverbed"
	move_delay = 5
	icon_state = "seashallow_jungle2"
	sickness = 2
	initial_flooring = /decl/flooring/water_jungle2

/turf/floor/beach/water/proc/Extinguish(var/mob/living/L)
	if (istype(L))
		L.ExtinguishMob()
		L.fire_stacks = FALSE

/turf/floor/beach/water/ex_act(severity)
	return

/turf/floor/beach/water/ice
	name = "ice"
	icon_state = "seashallow_frozen"
	move_delay = 0
	initial_flooring = null

/turf/floor/beach/water/ice/salty
	name = "saltwater ice"

/turf/floor/beach/sand/desert
	name = "desert sand"
	icon = 'icons/misc/beach.dmi'
	icon_state = "desert1"
	interior = FALSE
	stepsound = "dirt"
	is_diggable = TRUE
	available_sand = 2
	initial_flooring = /decl/flooring/desert

/turf/floor/beach/sand/desert/New()
	..()
	icon_state = "desert[rand(0,4)]"

/turf/floor/plating/concrete
	name = "concrete"
	icon = 'icons/turf/floors.dmi'
	icon_state = "concrete6"
	interior = FALSE

/turf/floor/plating/marble
	name = "raw marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "raw_marble0"
	interior = FALSE

/turf/floor/plating/marble/ornate
	name = "ornate marble floor"
	icon_state = "ornate_marble"

/turf/floor/plating/marble/grid
	name = "marble grid floor"
	icon_state = "marble_grid"

/turf/floor/plating/marble/raw
	name = "raw marble floor"
	icon_state = "raw_marble0"
	New()
		..()
		icon_state = "raw_marble[rand(0,2)]"

/turf/floor/plating/marble/pink
	name = "pink marble floor"
	icon_state = "pink_marble0"
	New()
		..()
		icon_state = "pink_marble[rand(0,2)]"

/turf/floor/plating/marble/black
	name = "black marble floor"
	icon_state = "black_marble0"
	New()
		..()
		icon_state = "black_marble[rand(0,3)]"

/turf/floor/plating/marble/tile
	name = "marble tile floor"
	icon_state = "marble_tile0"
	New()
		..()
		icon_state = "marble_tile[rand(0,2)]"

/turf/floor/plating/marble/decorative_tile
	name = "decorative marble tile floor"
	icon_state = "decorative_marble_tile0"
	New()
		..()
		icon_state = "decorative_marble_tile[rand(0,2)]"

/turf/floor/plating/metro
	name = "Metro floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "metro"
	interior = FALSE

/turf/floor/plating/metroline
	name = "Metro floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "metroline"
	interior = FALSE

/turf/floor/plating/tiled
	name = "tiled floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wooden_floor_s1"
	interior = TRUE
/turf/floor/plating/tiled/dark
	icon_state = "wooden_floor_s2"

/turf/floor/plating/tiled/darker
	icon_state = "wooden_floor_s3"

/turf/floor/plating/tiled/woodh
	icon_state = "wooden_floor_s4"

/turf/floor/plating/tiled/woodv
	icon_state = "wooden_floor_s5"

/turf/floor/plating/road
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "road_1"
	interior = FALSE

/turf/floor/plating/road/whiteline
	icon_state = "road_line"

/turf/floor/plating/road/yellowline
	icon_state = "road_yellowline"

/turf/floor/plating/road/yellowline_center
	icon_state = "road_center_yellowline"

/turf/floor/plating/concrete/New()
	..()
	icon_state = pick("road_1","road_2","road_3")

/turf/floor/plating/concrete/New()
	..()
	if (icon_state == "concrete2")
		icon_state = pick("concrete2", "concrete3")
		return
	if (icon_state == "concrete6")
		icon_state = pick("concrete6", "concrete7")
		return
	if (icon_state == "concrete10")
		icon_state = pick("concrete10", "concrete11")
		return

/turf/floor/plating/steel
	name = "steel plated floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "floor"
	interior = TRUE

/turf/floor/plating/dark
	name = "dark plating"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dark"
	interior = TRUE

/turf/floor/plating/white
	name = "white plated floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	interior = TRUE

/turf/floor/plating/cobblestone
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_horizontal"
	interior = FALSE

/turf/floor/plating/stone_old
	name = "stone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "stone_old"
	interior = FALSE

/turf/floor/plating/cobblestone/dark
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_horizontal_dark"
	interior = FALSE

/turf/floor/plating/cobblestone/vertical
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_vertical"
	interior = FALSE

/turf/floor/plating/cobblestone/vertical/dark
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_vertical_dark"
	interior = FALSE