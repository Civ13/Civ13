// Floor Repair Item.

/obj/item/weapon/covers
	name = "floor cover"
	desc = "Planks for covering a hole or extending an upper floor. Face the hole or the open air beside you and use it in hand, or click that spot with it."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired2"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 0
	flags = FALSE
	
/obj/covers/repairedfloor
	name = "repaired floor"
	desc = "A repaired wood floor."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired"
	layer = 1.98
	flammable = TRUE
	explosion_resistance = FALSE

/obj/covers/repairedfloor/New()
	..()
	spawn(15)
		var/turf/T = get_turf(src)
		if (afloat)
			return
		if (istype(T, /turf/floor/beach/water/deep/saltwater) && map.ID != MAP_RIVER_KWAI && map.ID != MAP_VOYAGE && map.ID != MAP_MISSIONARY_RIDGE && map.ID != MAP_BATTLE_SHIPS)
			visible_message("The [src] sinks!")
			qdel(src)
			return

// Floors

/obj/covers/repairedfloor/ship
	name = "ship floor"
	desc = "A wooden ship floor."
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
		desc = "A weakened ship floor."
		maxhealth = 50
		icon_state = "wood_ship_repaired"
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
		Destroy()

/obj/covers/repairedfloor/ship/south
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "boat_floor_south1"

/obj/covers/repairedfloor/rope
	name = "grappling hook rope"
	desc = "A piece of rope attached to a grappling hook"
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

/obj/covers/wood/alt
	icon_state = "woodalt"
/obj/covers/wood/alt/two
	icon_state = "woodalt2"
/obj/covers/wood/alt/three
	icon_state = "woodalt3"
/obj/covers/wood/alt/four
	icon_state = "woodalt4"
/obj/covers/wood/alt/five
	icon_state = "woodalt5"
/obj/covers/wood/alt/six
	icon_state = "woodalt6"
/obj/covers/wood/alt/seven
	icon_state = "woodalt7"
/obj/covers/wood/alt/eight
	icon_state = "woodalt8"
/obj/covers/wood/alt/nine
	icon_state = "woodalt9"
/obj/covers/wood/alt/ten
	icon_state = "woodalt10"
/obj/covers/wood/alt/eleven
	icon_state = "woodalt11"

// Recipe outputs retain the mapped patterns without giving old mapped or saved
// covers the salvage of a player-built floor. Refunds key on the exact type.
/obj/covers/wood/alt/constructed
	name = "narrow plank floor"

/obj/covers/wood/alt/two/constructed
	name = "basketweave wood floor"

/obj/covers/wood/alt/three/constructed
	name = "dark herringbone wood floor"

/obj/covers/wood/alt/four/constructed
	name = "herringbone wood floor"

/obj/covers/wood/alt/five/constructed
	name = "double herringbone wood floor"

/obj/covers/wood/alt/six/constructed
	name = "diamond parquet floor"

/obj/covers/wood/alt/seven/constructed
	name = "checkered parquet floor"

/obj/covers/wood/alt/eight/constructed
	name = "pinwheel parquet floor"

/obj/covers/wood/alt/nine/constructed
	name = "woven strip wood floor"

/obj/covers/wood/alt/ten/constructed
	name = "redwood plank floor"

/obj/covers/wood/alt/eleven/constructed
	name = "nailed board floor"

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

// These fitted mats reuse the mappers' trim art without creating an invisible
// decal marker or a second floor object. The stateless underlay is rebuilt on
// construction/load; normal cover behavior owns the floor slot and recovery.
/obj/covers/tatami/trim
	name = "edged tatami floor"
	desc = "A tatami mat with bamboo trim. Use Rotate Tatami Trim from beside it to line up the edge."
	icon = 'icons/turf/flooring/decals.dmi'
	icon_state = "tatami_frame"
	var/directional_trim = TRUE

/obj/covers/tatami/trim/New()
	..()
	underlays += image(icon = 'icons/turf/floors.dmi', icon_state = "tatami0")
	if (!directional_trim)
		verbs -= /obj/covers/tatami/trim/verb/rotate_trim

/obj/covers/tatami/trim/persistence_runtime_var(key)
	// The base mat is derived on construction; only the cover type and direction need saving.
	return key == "underlays" || ..()

/obj/covers/tatami/trim/verb/rotate_trim()
	set name = "Rotate Tatami Trim"
	set category = null
	set src in oview(1)
	if (!directional_trim || !isliving(usr) || usr.incapacitated() || !usr.Adjacent(src))
		return
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	// Diagonal construction facings use their north/south component.
	var/cardinal_dir = dir & (NORTH | SOUTH)
	if (!cardinal_dir)
		cardinal_dir = dir
	set_dir(turn(cardinal_dir, 90))

/obj/covers/tatami/trim/angle
	name = "inside-corner tatami floor"
	icon_state = "tatami_frame_angle"

/obj/covers/tatami/trim/corner
	name = "outside-corner tatami floor"
	icon_state = "tatami_frame_corner"

/obj/covers/tatami/trim/cee
	name = "three-sided tatami floor"
	icon_state = "tatami_frame_cee"

/obj/covers/tatami/trim/full
	name = "fully framed tatami floor"
	desc = "A tatami mat with bamboo trim on all sides."
	icon_state = "tatami_frame_full"
	directional_trim = FALSE

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

/obj/covers/cobblestone/vertical
	name = "light running cobblestone floor"
	icon_state = "cobble_vertical"

/obj/covers/cobblestone/horizontal
	name = "light crosswise cobblestone floor"
	icon_state = "cobble_horizontal"

/obj/covers/cobblestone/horizontal/dark
	name = "dark crosswise cobblestone floor"
	icon_state = "cobble_horizontal_dark"

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

/obj/covers/road/whiteline
	icon_state = "road_line"

/obj/covers/road/yellowline
	icon_state = "road_yellowline"

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

/obj/covers/stone/slab/decorative/mossy
	name = "mossy old stone floor"
	icon_state = "stone_old"

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

/obj/covers/carpet/arcade
	name = "arcade mat"
	desc = "For those 80s vibes!"
	icon = 'icons/turf/floors.dmi'
	icon_state = "arcadefloor1"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE

/obj/covers/disco
	name = "disco floor"
	desc = "Get your groove on."
	icon_state = "disco1"
	material = "Steel"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	layer = 1.99

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
	layer = 1.99// Decorative flooring pieces for dungeon and ordinary map construction.
// These are full, passable floor covers, not door objects or fake openings.
// Place one cover per cell and set dir explicitly on directional map pieces.

/obj/covers/cobblestone/sill
	name = "cobble sill"
	desc = "A flat cobbled threshold with a dressed stone rib."
	icon = 'icons/turf/flooring/cobble_trim.dmi'
	icon_state = "sill_center"

/obj/covers/cobblestone/sill/cap_left
	name = "left cobble sill cap"
	icon_state = "sill_cap_left"

/obj/covers/cobblestone/sill/cap_right
	name = "right cobble sill cap"
	icon_state = "sill_cap_right"

/obj/covers/cobblestone/trim
	name = "cobble border"
	desc = "A dressed edge for a cobbled floor."
	icon = 'icons/turf/flooring/cobble_trim.dmi'
	icon_state = "trim_straight"

/obj/covers/cobblestone/trim/inside
	name = "inside cobble corner"
	icon_state = "trim_corner_inside"

/obj/covers/cobblestone/trim/outside
	name = "outside cobble corner"
	icon_state = "trim_corner_outside"

/obj/covers/cobblestone/trim/stop
	name = "cobble border stop"
	icon_state = "trim_stop"

/obj/covers/cobblestone/trim/stop/reverse
	name = "reverse cobble border stop"
	icon_state = "trim_stop_reverse"

/obj/covers/stone/slab/decorative/terracotta
	name = "terracotta floor"
	desc = "A floor made from kiln-fired clay tiles."
	icon = 'icons/turf/flooring/terracotta.dmi'
	icon_state = "terracotta"

/obj/covers/stone/slab/decorative/terracotta/edge
	name = "terracotta border"
	icon_state = "terracotta_edge"

/obj/covers/stone/slab/decorative/terracotta/inside
	name = "inside terracotta corner"
	icon_state = "terracotta_inner"

/obj/covers/stone/slab/decorative/terracotta/outside
	name = "outside terracotta corner"
	icon_state = "terracotta_outer"

/obj/covers/stone/slab/decorative/terracotta/inset
	name = "patterned terracotta inset"
	icon_state = "terracotta_inset"

// The same sill and border cut for the dark cobblestone floors.
/obj/covers/cobblestone/sill/dark
	name = "dark cobble sill"
	icon = 'icons/turf/flooring/cobble_trim_dark.dmi'
	icon_state = "sill_center"

/obj/covers/cobblestone/sill/dark/cap_left
	name = "left dark cobble sill cap"
	icon_state = "sill_cap_left"

/obj/covers/cobblestone/sill/dark/cap_right
	name = "right dark cobble sill cap"
	icon_state = "sill_cap_right"

/obj/covers/cobblestone/trim/dark
	name = "dark cobble border"
	icon = 'icons/turf/flooring/cobble_trim_dark.dmi'
	icon_state = "trim_straight"

/obj/covers/cobblestone/trim/dark/inside
	name = "inside dark cobble corner"
	icon_state = "trim_corner_inside"

/obj/covers/cobblestone/trim/dark/outside
	name = "outside dark cobble corner"
	icon_state = "trim_corner_outside"

/obj/covers/cobblestone/trim/dark/stop
	name = "dark cobble border stop"
	icon_state = "trim_stop"

/obj/covers/cobblestone/trim/dark/stop/reverse
	name = "reverse dark cobble border stop"
	icon_state = "trim_stop_reverse"
