// Floor Repair Item.

/obj/item/weapon/covers
	name = "floor cover"
	desc = "Use this to cover holes."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired2"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 0
	flags = FALSE
	
/obj/covers/repairedfloor
	name = "repaired floor"
	desc = "a repaired wood floor."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired"
	layer = 1.98
	flammable = TRUE
	explosion_resistance = FALSE

/obj/covers/repairedfloor/New()
	..()
	spawn(15)
		var/turf/T = get_turf(src)
		if (istype(T, /turf/floor/beach/water/deep/saltwater) && map.ID != MAP_RIVER_KWAI && map.ID != MAP_VOYAGE && map.ID != MAP_MISSIONARY_RIDGE && map.ID != MAP_CAMPAIGN)
			visible_message("The [src] sinks!")
			qdel(src)
			return

// Floors

/obj/covers/repairedfloor/ship
	name = "ship floor"
	desc = "a wooden ship floor."
	icon_state = "wood_ship"
	material = "Wood"
	passable = TRUE
	amount = 1
	layer = 1.99

/obj/covers/repairedfloor/ship/two
	icon_state = "tatami1"

/obj/covers/repairedfloor/ship/three
	icon_state = "wooden_floor_s4"

/obj/covers/repairedfloor/ship/try_destroy()
	if (health <= 50)
		name = "weak floor"
		desc = "a weakened ship floor."
		maxhealth = 50
		icon_state = "wood_ship_repaired"
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
		Destroy()

/obj/covers/repairedfloor/ship/Destroy()
	if(istype(src.loc, /turf/floor/beach/water))
		var/turf/T1 = get_step(src.loc,pick(NORTH,NORTHWEST))
		if(T1)
			new/obj/effect/flooding(T1)
		var/turf/T2 = get_step(src.loc,pick(EAST,NORTHEAST))
		if(T2)
			new/obj/effect/flooding(T2)
		var/turf/T3 = get_step(src.loc,pick(WEST,SOUTHWEST))
		if(T3)
			new/obj/effect/flooding(T3)
		var/turf/T4 = get_step(src.loc,pick(SOUTH,SOUTHEAST))
		if(T4)
			new/obj/effect/flooding(T4)
	..()
/obj/covers/repairedfloor/ship/south
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "boat_floor_south1"

/obj/covers/repairedfloor/rope
	name = "grappling hook rope"
	desc = "a piece of rope attached to a grappling hook"
	icon = 'icons/obj/objects.dmi'
	icon_state = "grapplehook_line_bridge"
	flammable = FALSE
	explosion_resistance = TRUE
	var/origin = null
	layer = 3.999

	New()
		..()
		if(icon_state == "grapplehook_line_bridge")
			icon_state = pick("grapplehook_line_bridge","grapplehook_line_bridge1","grapplehook_line_bridge2")

/obj/covers/repairedfloor/rope/end
	icon_state = "grapple_bridge_overlay"
	layer = 3.15

/obj/covers/repairedfloor/rope/proc/develop(var/obj/norigin)
	if (!origin)
		origin = norigin
	dir = norigin.dir
	update_icon()
	for(var/obj/structure/window/barrier/B in loc)
		B.density = FALSE

/obj/covers/repairedfloor/rope/Destroy()
	for(var/obj/structure/window/barrier/B in loc)
		B.density = TRUE
	for(var/obj/O in loc)
		loc.Entered(O)
	for(var/mob/living/M in loc)
		loc.Entered(M)
	..()
/obj/covers/wood
	name = "wood floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "wood"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

/obj/covers/thatch
	name = "thatch floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "thatch1"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

/obj/covers/thatch2
	name = "thatch floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "thatch2"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

/obj/covers/fancywood
	name = "wood floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "fancywood"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

/obj/covers/wood/stairs
	name = "wood stairs"
	icon = 'icons/obj/stairs.dmi'
	icon_state = "wood2_stairs"
	material = "Wood"

/* Bamboo*/

/obj/covers/tatami
	name = "horizontal tatami floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "tatami0"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Bamboo"

/obj/covers/tatami_vertical
	name = "vertical tatami floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "tatami1"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Bamboo"

/obj/covers/tatami_dark
	name = "horizontal tatami floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "tatami_dark0"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Bamboo"

/obj/covers/tatami_dark_vertical
	name = "vertical tatami floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "tatami_dark1"
	passable = TRUE
	amount = 1
	layer = 1.99
	material = "Bamboo"

/* Stone Floors*/

/obj/covers/slate
	name = "slatestone wall"
	desc = "A slate wall."
	icon = 'icons/obj/structures.dmi'
	icon_state = "slate"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 500
	hardness = 100
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/cobblestone
	name = "cobblestone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_vertical_dark"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/cobblestone/stairs
	name = "stone stairs"
	icon = 'icons/obj/stairs.dmi'
	icon_state = "rampup"
	material = "Stone"

/obj/covers/road
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "road_1"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"

/obj/covers/road/New()
	..()
	icon_state = pick("road_1","road_2","road_3")
	base_icon_state = icon_state

/obj/covers/road_yellowline
	name = "road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "road_yellowline"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"

/obj/covers/romanroad
	name = "roman road"
	icon = 'icons/turf/floors.dmi'
	icon_state = "roman_road"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/stone/slab/decorative
	name = "stone decorative slab floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "decorative_stone_slab"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/stonebrickfloor
	name = "stone brick floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "stone_bricks"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stonebrick

/* Marble Floors starts here*/

/obj/covers/marblefloor
	name = "marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "marble"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/ornatemarblefloor
	name = "ornate marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "ornate_marble"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/raw_marblefloor
	name = "raw marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "raw_marble0"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/raw_marblefloor/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("raw_marble0", "raw_marble1", "raw_marble2")
	update_icon()

/obj/covers/marbletile
	name = "marble tiles"
	icon = 'icons/turf/floors.dmi'
	icon_state = "marble_tile0"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/marbletile/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("marble_tile0", "marble_tile1", "marble_tile2")
	update_icon()

/obj/covers/ornate_marbletile
	name = "ornate marble tile"
	icon = 'icons/turf/floors.dmi'
	icon_state = "ornate_marble"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/decorative_marbletile
	name = "decorative marble tile"
	icon = 'icons/turf/floors.dmi'
	icon_state = "decorative_marble_tile0"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/decorative_marbletile/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("decorative_marble_tile0", "decorative_marble_tile1", "decorative_marble_tile2")
	update_icon()

/obj/covers/marble_checkerboard
	name = "marble checkerboard floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "marble_checkerboard"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/marble_checkerboard/reverse
	name = "reverse marble checkerboard floor"
	icon_state = "marble_checkerboard_reverse"

/obj/covers/marble_grid
	name = "marble grid tile floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "marble_grid"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/* Black Marble Floors*/

/obj/covers/ornatemarblefloor/black
	name = "ornate black marble tile"
	icon = 'icons/turf/floors.dmi'
	icon_state = "ornate_black_marble"

/obj/covers/decorative_marbletile/black
	name = "decorative black marble tile"
	icon = 'icons/turf/floors.dmi'
	icon_state = "decorative_black_marble_tile0"

/obj/covers/decorative_marbletile/black/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("decorative_black_marble_tile0", "decorative_black_marble_tile1", "decorative_black_marble_tile2", "decorative_black_marble_tile3")
	update_icon()

/obj/covers/raw_marblefloor/black
	name = "raw black marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "black_marble0"

/obj/covers/raw_marblefloor/black/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("black_marble0", "black_marble1", "black_marble2", "black_marble3")
	update_icon()

/obj/covers/marbletile/black
	name = "black marble tiles"
	icon = 'icons/turf/floors.dmi'
	icon_state = "black_marble_tile0"

/obj/covers/marbletile/black/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("black_marble_tile0", "black_marble_tile1", "black_marble_tile2", "black_marble_tile3")
	update_icon()

/* Pink Marble Floors*/

/obj/covers/raw_marblefloor/pink
	name = "raw pink marble floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "pink_marble0"

/obj/covers/raw_marblefloor/pink/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("pink_marble0", "pink_marble1", "pink_marble2")
	update_icon()

/obj/covers/decorative_marbletile/pink
	name = "decorative pink marble tile"
	icon = 'icons/turf/floors.dmi'
	icon_state = "decorative_pink_marble_tile0"

/obj/covers/decorative_marbletile/pink/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("decorative_pink_marble_tile0", "decorative_pink_marble_tile1", "decorative_pink_marble_tile2")
	update_icon()

/obj/covers/marbletile/pink
	name = "pink marble tiles"
	icon = 'icons/turf/floors.dmi'
	icon_state = "pink_marble_tile0"

/obj/covers/marbletile/pink/New()
	..()
	icon = 'icons/turf/floors.dmi'
	icon_state = pick("pink_marble_tile0", "pink_marble_tile1", "pink_marble_tile2")
	update_icon()

/obj/covers/marble_checkerboard/pink
	name = "pink marble checkerboard floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "pink_marble_checkerboard"

/obj/covers/marble_checkerboard/pink/reverse
	name = "reverse pink marble checkerboard floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "pink_marble_checkerboard_reverse"

/* Marble Floors -End*/

/obj/covers/slatefloor
	name = "slate floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "slatefloor"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/* Stone Floors -End*/
/* Sandstone Floors*/

/obj/covers/sandstone
	name = "sandstone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "sandstone_floor"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	material = "Stone"

/obj/covers/sandstone/stairs
	name = "sandstone stairs"
	icon = 'icons/obj/stairs.dmi'
	icon_state = "sandstone_stairs"
	material = "Stone"

/obj/covers/sandstone
	buildstack = /obj/item/stack/material/sandstone

/obj/covers/sandstone/brick
	name = "sandstone brick floor"
	icon_state = "sandstone_brick"

/obj/covers/sandstone/slab
	name = "sandstone slab floor"
	icon_state = "sandstone_slab"

/obj/covers/sandstone/slab/red
	name = "red sandstone slab floor"
	icon_state = "red_sandstone_slab"

/obj/covers/sandstone/tile
	name = "sandstone tile"
	icon_state = "sandstone_tile"

/obj/covers/sandstone/tile/decorative
	name = "sandstone decorative tile"
	icon_state = "sandstone_decorative_tile"

/obj/covers/sandstone/tile/decorative/red
	name = "red sandstone decorative tile"
	icon_state = "red_sandstone_decorative_tile"

/* Metal Floors*/

/obj/covers/steelplating
	name = "steel floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "floor"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 3
	material = "Steel"
	buildstack = /obj/item/stack/material/steel

/obj/covers/steelplating/white
	name = "white floor"
	icon_state = "white"
	material = "Steel"

/* Metal Floors - End*/
/* Concrete Floors*/

/obj/covers/concretefloor
	name = "concrete floor"
	icon_state = "concrete6"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 4
	material = "Stone"
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/covers/concretefloor/New()
	..()
	icon_state = pick("concrete6","concrete7")
	base_icon_state = icon_state

/obj/covers/sidewalk
	name = "sidewalk"
	icon_state = "sidewalk"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	material = "Stone"
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement //it is made from stone but for the purposes of immersion takes cement bricks.

/* Vehicle Floors*/

/obj/covers/wood_ship
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

//Carpets - To be Expanded upon Later

/obj/covers/carpet/
	name = "Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "carpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/pinkcarpet
	name = "Pink Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "gaycarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/redcarpet
	name = "Red Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "carpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/orangecarpet
	name = "Orange Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "oracarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/purplecarpet
	name = "Purple Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "purcarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/bluecarpet
	name = "Blue Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "blucarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/tealcarpet
	name = "Teal Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "sblucarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/greencarpet
	name = "Green Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "turcarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/blackcarpet
	name = "Black Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "bcarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/carpet/whitecarpet
	name = "White Carpet"
	desc = "Fluffy and Flammable!"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "wcarpet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/catwalk
	name = "catwalk"
	desc = "A cat wouldn't like this"
	icon_state = "catwalk_plated"
	material = "Steel"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99

/obj/covers/catwalk/white
	name = "white catwalk"
	desc = "A cat wouldn't like this"
	icon_state = "catwalk_platedwhite"
	material = "Steel"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99

/obj/covers/catwalk/dark
	name = "white catwalk"
	desc = "A cat wouldn't like this"
	icon_state = "catwalk_plateddark"
	material = "Steel"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99