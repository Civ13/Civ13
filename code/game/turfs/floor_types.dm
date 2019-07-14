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
	icon_state = "grass1"
	var/grassamt = 1

	New()
		icon_state = "grass[pick("0","1","2","3")]"
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

/turf/floor/grass/jungle/savanna
	name = "dry grass"
	icon_state = "grass_dry"
	initial_flooring = null

/turf/floor/grass/jungle/savanna/New()
	..()
	icon_state = "grass_dry"

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
	available_sand = 4
	initial_flooring = /decl/flooring/sand_beach

/turf/floor/beach/sand/dark
	name = "dark sand"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dust"
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
	var/salty = FALSE
	var/sickness = 1 //amount of toxins, from 0 to 3
	initial_flooring = /decl/flooring/water
	watertile = TRUE

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
	iscovered = FALSE
	initial_flooring = /decl/flooring/water_deep

/turf/floor/beach/water/deep/jungle
	name = "deep jungle river"
	icon_state = "seashallow_jungle3"
	desc = "Water. Seems to be very deep, you cant see the bottom."
	water_level = 200
	density = FALSE
	iscovered = FALSE
	initial_flooring = /decl/flooring/water_jungle3

/turf/floor/beach/water/deep/swamp
	name = "deep swamp"
	icon_state = "seashallow_swamp"
	desc = "Water. Seems to be very deep, you cant see the bottom."
	water_level = 200
	density = FALSE
	iscovered = FALSE
	initial_flooring = /decl/flooring/water_swamp

/turf/floor/beach/water/deep/saltwater
	name = "deep saltwater"
	salty = TRUE
	initial_flooring = /decl/flooring/water_deep_salt

/turf/floor/beach/water/deep/CanPass(atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		return TRUE
	else if ((istype(mover, /mob)) && !iscovered)
		return FALSE
	else
		return ..()

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

/turf/floor/beach/water/New()
	..()
//	if (!istype(src, /turf/floor/beach/water/ice))
//		overlays += image("icon"='icons/misc/beach.dmi',"icon_state"="water5","layer"=layer+0.09)

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
