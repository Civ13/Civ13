/obj/covers

	name = "floor covers"
	desc = ""
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/base_icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_covered = FALSE
	var/origin_water_level = 0
	var/not_movable = FALSE //if it can be removed by wrenches
	var/health = 100
	var/maxhealth = 100
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.1
	level = 2
	var/amount = FALSE
	var/wall = FALSE
	var/wood = TRUE
	var/onfire = FALSE
	flammable = TRUE
	var/current_area_type = /area/caribbean
	var/incomplete = FALSE
	explosion_resistance = TRUE
	var/list/bullethole_count = list()
	var/list/bullethole_overlays = list()
//	invisibility = 101 //starts invisible
	var/material = "Wood" //Depending on mat, depending on what harms it.
	var/buildstackamount = 8
	var/buildstack = /obj/item/stack/material/wood
	var/adjusts = FALSE //if it adjusts acording to neighbouring sprites

	var/hardness = 50 //for projectile penetration
/*

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	switch(material)
		if ("Wood")
			//Do nothing, anything can cut through wood.
		else if ("Stone")
			//Swords no work on stone, unga dunga no knify wifey the wall.
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				return
			else
				//Damage the wall.
		else if ("Metal" || "steel")
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				return
			else
				//Damage the wall.
		else
			//Do nothing, you're not important.
			..()*/

/obj/covers/proc/run_decay()
	if (!src || !wall)
		return
	decay()
	spawn(24000)
		if (src && wall)
			run_decay()
			return
		else
			return

/obj/covers/ex_act(severity)
	switch(severity)
		if (1.0)
			Destroy(src)
			return
		if (2.0)
			health -= initial(health)/2
			return
		if (3.0)
			health -= initial(health)/10
			return
		else
	return

/* Stone Floors starts here*/

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

/* Sandstone Floors -End*/
/* Smoothing Road Floors*/

/obj/covers/roads
	name = "road"
	icon = 'icons/turf/roads.dmi'
	icon_state = "road"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.98
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	var/vertical = FALSE
	buildstack = null
	var/roadtype = "road"

/obj/covers/roads/modern
	name = "modern road"
	icon_state = "tarmac"
	roadtype = "tarmac"

/obj/covers/roads/dirt
	name = "dirt road"
	icon_state = "d_road"
	roadtype = "d_road"

/obj/covers/roads/roman
	name = "roman road"
	icon_state = "r_road"
	roadtype = "r_road"

/obj/covers/roads/cobble
	name = "cobble street"
	icon_state = "street"
	roadtype = "street"

/obj/covers/roads/sandstone
	name = "sandstone road"
	icon_state = "s_stone"
	roadtype = "s_stone"

/obj/covers/roads/update_icon()
	..()
	spawn(1)
		overlays.Cut()
		var/list/sideslist = list()
		for (var/direction in list(NORTH,SOUTH,EAST,WEST))
			for(var/obj/covers/roads/R in get_step(src,direction))
				sideslist += direction
				continue
		for (var/direction in list(NORTHEAST,NORTHWEST,SOUTHEAST,SOUTHWEST))
			var/turf/T = null
			switch(direction)
				if (NORTHEAST)
					T = locate(src.x+1,src.y+1,src.z)
				if (NORTHWEST)
					T = locate(src.x-1,src.y+1,src.z)
				if (SOUTHEAST)
					T = locate(src.x+1,src.y-1,src.z)
				if (SOUTHWEST)
					T = locate(src.x-1,src.y-1,src.z)
			if (T)
				for(var/obj/covers/roads/R in T)
					sideslist += direction
					continue

		if ((NORTHWEST in sideslist) && (NORTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nwc")
		if ((NORTHEAST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nec")
		if ((SOUTHEAST in sideslist) && (SOUTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]sec")
		if ((SOUTHWEST in sideslist) && (SOUTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]swc")

		if ((WEST in sideslist) && (EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]+" //4 sides
			base_icon_state = icon_state
			return

		if (icon_state == "[roadtype]vr")
			if (WEST in sideslist)
				if (!(NORTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
						base_icon_state = icon_state
				else if (!(SOUTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]nw" //Turn, NORTH-WEST
						base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
					base_icon_state = icon_state
			else if (EAST in sideslist)
				if (!(NORTH in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
					return
				else if (!(SOUTH in sideslist))
					icon_state = "[roadtype]ne" //Turn, NORTH-EAST
					base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
					base_icon_state = icon_state
		else
			if (NORTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]nw" //Turn, NORTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					if (SOUTH in sideslist)
						icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]ne" //Turn, NORTH-EAST
						base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
					base_icon_state = icon_state
			else if (SOUTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tswe" //T, EAST SOUTH WEST
					base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (EAST in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
			base_icon_state = icon_state
		if ((EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
			base_icon_state = icon_state

/obj/covers/roads/New()
	..()
	spawn(2)
		if (vertical)
			dir = 1
		else
			dir = 4
		for(var/obj/covers/roads/R in range(1,src))
			R.update_icon()
		update_icon()

/* Road Destruction*/

/obj/covers/roads/modern/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/dirt/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O, /obj/item/weapon/material/shovel/bone))
		playsound(src, 'sound/effects/shovelling.ogg', 85, 1)
		user << "<span class='notice'>You begin filling over in the earth of \the [src].</span>"
		if (do_after(user,60,src))
			user << "<span class='notice'>You finish filling over \the [src].</span>"
			qdel(src)
	else if (istype(O, /obj/item/weapon/material/shovel))
		playsound(src, 'sound/effects/shovelling.ogg', 85, 1)
		user << "<span class='notice'>You begin filling over in the earth of \the [src].</span>"
		if (do_after(user,30,src))
			user << "<span class='notice'>You finish filling over \the [src].</span>"
			qdel(src)

/obj/covers/roads/roman/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/cobble/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/sandstone/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)

/* Road Destruction - End*/

/* Smoothing Road Floors -End*/

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

/* Metal Floors - End*/
/* Vehicle Floors*/

/obj/covers/wood_ship
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99
	material = "Wood"

/* Vehicle Floors - End*/
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
//Continue

/* Doors*/

/obj/covers/saloon_door
	name = "saloon door"
	desc = "A wood door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "saloon"
	passable = TRUE
	not_movable = TRUE
	density = FALSE
	opacity = FALSE
	amount = 2
	layer = 3
	health = 90
	wall = FALSE
	explosion_resistance = 3
	material = "Wood"


/obj/covers/saloon_door/Crossed(mob/living/human/M as mob )
	if (ismob(M) && !isghost(M) && M.mob_size >= MOB_MEDIUM)
		visible_message("[M] pushes \the [src].","You push \the [src]")
		icon_state = "saloon_opening"
		update_icon()
		spawn(20)
			icon_state = "saloon"
			update_icon()

/* Doors - End*/
/* Wood Walls*/

/obj/covers/wood_wall
	name = "soft wood wall"
	desc = "A wood wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "b_wood_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 4
	layer = 3
	health = 150
	wall = TRUE
	explosion_resistance = 5
	material = "Wood"
	hardness = 75

/obj/covers/wood_wall/nonadjustable
	icon_state = "new_wood0"
	base_icon_state = "new_wood"
	adjusts = FALSE

/obj/covers/wood_wall/adjustable
	icon_state = "woodwall0"
	base_icon_state = "woodwall"
	adjusts = TRUE

/obj/covers/wood_wall/medieval
	name = "medieval wall"
	desc = "A dark-ages wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "medieval_wall"
	health = 180

/obj/covers/wood_wall/medieval/x
	name = "medieval wall crossbeam"
	desc = "A dark-ages wall with an x shaped support."
	icon = 'icons/turf/walls.dmi'
	icon_state = "medieval_wall_x"
	health = 185

/obj/covers/wood_wall/medieval/y/r
	name = "medieval wall crossbeam"
	desc = "A dark-ages wall with an slanted support."
	icon = 'icons/turf/walls.dmi'
	icon_state = "medieval_wall_y1"
	health = 185

/obj/covers/wood_wall/medieval/y/l
	name = "medieval wall crossbeam"
	desc = "A dark-ages wall with an slanted support."
	icon = 'icons/turf/walls.dmi'
	icon_state = "medieval_wall_y2"
	health = 185

/* Asia-Themed Walls - End*/

/obj/covers/wood_wall/oriental
	name = "oriental wall"
	desc = "A east-oriental style wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental"
	health = 180

/obj/covers/wood_wall/oriental/b
	name = "braced oriental wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "orientalb"
	health = 185

/obj/covers/wood_wall/oriental/doorway
	name = "oriental doorway"
	desc = "A east-oriental style doorway."
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental-door"
	density = FALSE
	opacity = FALSE
	health = 180

/obj/covers/wood_wall/oriental/twop
	name = "two panelled oriental wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental_twop"
	health = 180

/obj/covers/wood_wall/oriental/twop/b
	name = "two panelled braced oriental wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental_twopb"
	health = 185

/obj/covers/wood_wall/oriental/threep
	name = "three panelled oriental wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental_threep"
	health = 180

/obj/covers/wood_wall/oriental/threep/b
	name = "three panelled braced oriental wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental_threepb"
	health = 185

/obj/covers/wood_wall/shoji
	name = "shoji wall"
	desc = "A shoji paper wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "shoji_wall2"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 3
	layer = 3
	health = 70
	wall = TRUE
	explosion_resistance = 1
	material = "Wood"
	hardness = 30

/obj/covers/wood_wall/shoji_divider
	name = "shoji dividing wall"
	desc = "A shoji paper wall. This one is more meant to divide rooms."
	icon = 'icons/turf/walls.dmi'
	icon_state = "shoji_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 3
	layer = 3
	health = 50
	wall = TRUE
	explosion_resistance = 1
	material = "Wood"
	hardness = 20

/obj/covers/wood_wall/bamboo
	name = "bamboo wall"
	desc = "A wall made from bamboo."
	icon = 'icons/obj/bamboostuff.dmi'
	icon_state = "bamboo"
	health = 80
	amount = 3
	layer = 3
	health = 70
	wall = TRUE
	explosion_resistance = 3
	material = "Wood"
	hardness = 40

/obj/covers/wood_wall/bamboo/door //for mappers
	name = "bamboo doorway"
	desc = "A doorway made from bamboo."
	icon = 'icons/obj/bamboostuff.dmi'
	icon_state = "bamboo-door"
	density = FALSE
	opacity = FALSE
	health = 80
	amount = 3
	layer = 3
	health = 70
	wall = TRUE
	explosion_resistance = 3
	material = "Wood"
	hardness = 40

/* Asia-Themed Walls - End*/

/obj/covers/wood_wall/log
	name = "log wall"
	desc = "A log wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "log_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 4
	layer = 3
	health = 180
	wall = TRUE
	explosion_resistance = 7
	material = "Wood"
	hardness = 80

/obj/covers/wood_wall/log/corner
	icon_state = "log_wall_corner"
	material = "Wood"

/* Wood Walls - End*/

/obj/covers/stone_wall
	name = "stone wall"
	desc = "A stone wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "b_stone_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 400
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 7
	material = "Stone"
	hardness = 100
	buildstack = /obj/item/stack/material/stone
	adjusts=FALSE

/obj/covers/stone_wall/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if(istype(W, /obj/item/weapon/chisel))
		var design = "smooth"
		if (!istype(H.l_hand, /obj/item/weapon/hammer) && !istype(H.r_hand, /obj/item/weapon/hammer))
			user << "<span class = 'warning'>You need to have a hammer in one of your hands to use a chisel.</span>"
			return
		else
			var/display = list("Smooth", "Cave", "Underground Cave", "Carved Brick", "Cobbled", "Tiled", "Cancel")
			var/input =  WWinput(user, "What design do you want to carve?", "Carving", "Cancel", display)
			if (input == "Cancel")
				return
			else if  (input == "Smooth")
				user << "<span class='notice'>You will now carve the smooth design!</span>"
				design = "smooth"
			else if  (input == "Cave")
				user << "<span class='notice'>You will now carve the cave design!</span>"
				design = "cave"
			else if  (input == "Underground Cave")
				user << "<span class='notice'>You will now carve the cave design!</span>"
				design = "undercave"
			else if  (input == "Carved Brick")
				user << "<span class='notice'>You will now carve the brick design!</span>"
				design = "carvedbrick"
			else if  (input == "Cobbled")
				user << "<span class='notice'>You will now carve the cobbled design!</span>"
				design = "cobbled"
			else if  (input == "Tiled")
				user << "<span class='notice'>You will now carve the tiled design!</span>"
				design = "tiled"
			visible_message("<span class='danger'>[user] starts to chisel a design!</span>", "<span class='danger'>You start chiseling a design.</span>")
			playsound(src,'sound/effects/pickaxe.ogg',60,1)
			if (do_after(user, 60, src))
			//Designs possible are "smooth", "cave", "carvedbrick", "cobbled", "tiled"
				if(design == "smooth")
					src.icon_state = "b_stone_wall"
					base_icon_state = icon_state
					src.name = "stone wall"
					src.desc = "A cave wall carved smooth."
				else if(design == "cave")
					src.icon_state = "rocky"
					base_icon_state = icon_state
					src.name = "underground cave wall"
					src.desc = "A cave wall."
				else if(design == "undercave")
					src.icon_state = "rock"
					base_icon_state = icon_state
					src.name = "cave wall"
					src.desc = "A cave wall."
				else if(design == "carvedbrick")
					src.icon_state = "b_brick_stone_wall"
					base_icon_state = icon_state
					src.name = "stone brick wall"
					src.desc = "A cave wall carved to look like its made of stone bricks."
				else if(design == "cobbled")
					src.icon_state = "b_cobbled_stone_wall"
					base_icon_state = icon_state
					src.name = "cobbled stone wall"
					src.desc = "A cave wall carved to look like piled up stones."
				else if(design == "tiled")
					src.icon_state = "b_tiled_stone_wall"
					base_icon_state = icon_state
					src.name = "tiled stone wall"
					src.desc = "A cave wall carved to have a tiled stone pattern."
				return
	..()

/obj/covers/sandstone_smooth_wall
	name = "sandstone wall"
	desc = "A sandstone wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_smooth"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 400
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 7
	material = "Stone"
	hardness = 100
	buildstack = /obj/item/stack/material/sandstone

/obj/covers/sandstone_wall
	name = "sandstone brick wall"
	desc = "A sandstone wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_brick"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 400
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 7
	material = "Stone"
	hardness = 100
	buildstack = /obj/item/stack/material/sandstone

/obj/covers/dirt_wall
	name = "dirt wall"
	desc = "A dirt wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drydirt_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 90
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 3
	hardness = 65
	buildstack = /obj/item/weapon/barrier

/obj/covers/straw_wall
	name = "straw wall"
	desc = "A straw wall. Looks flimsy."
	icon = 'icons/turf/walls.dmi'
	icon_state = "straw_wallh"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 75
	wood = TRUE
	wall = TRUE
	explosion_resistance = 2
	material = "Wood"
	hardness = 30

/obj/covers/dirt_wall/blocks
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 110
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 4

/obj/covers/dirt_wall/blocks/incomplete
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 30
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE

/obj/covers/dirt_wall/blocks/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/barrier))
		if (stage == 3)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding dirt to the wall, completing it."
				qdel(W)
				new /obj/covers/dirt_wall/blocks(loc)
				qdel(src)
				return
		else if (stage <= 2)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 2)
					user << "You finish adding dirt to the wall."
					stage = (stage+1)
					icon_state = "drysod_wall_inc[stage]"
					base_icon_state = icon_state
					health = (20*stage)
					qdel(W)
					return
	..()

/obj/covers/clay_wall
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 150
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6
	material = "Stone"
	hardness = 75
	buildstack = /obj/item/weapon/clay/claybricks/fired

/obj/covers/clay_wall/claydoorway //if you actually wanted to summon one.
	name = "clay block doorway"
	desc = "A clay block doorway."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clay_doorway"
	passable = TRUE
	not_movable = TRUE
	density = FALSE
	opacity = FALSE

/obj/covers/clay_wall/redearth
	name = "red earthern bordered wall"
	desc = "A red earthen bordered wall."
	icon_state = "red_earth_smooth_b"
	health = 210
	explosion_resistance = 7

/* Additional red-earth types seperately defined for mapping/spawning purposes*/

/obj/covers/clay_wall/redearth/smooth
	name = "red earthern smooth wall"
	desc = "A red earthen smooth wall."
	icon_state = "red_earth_smooth"

/obj/covers/clay_wall/redearth/pillared
	name = "red earthern pillared wall"
	desc = "A red earthen pillared wall."
	icon_state = "red_earth_pillared"

/obj/covers/clay_wall/redearth_doorway
	name = "red earthern doorway"
	desc = "A red earthen doorway."
	icon_state = "red_earth_doorway"
	density = FALSE
	opacity = FALSE

/* Red Earth Types -End*/

/obj/covers/clay_wall/attackby(obj/item/W as obj, mob/user as mob)  //this list doesn't like multi arguements, single type per stucco catalyst unless you know what you're doing please.
	if (istype(W, /obj/item/weapon/stucco/generic))
		user << "You start adding stucco to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding stucco to the wall, rendering it."
			qdel(W)
			var/obj/covers/clay_wall/redearth/S = new /obj/covers/clay_wall/redearth(loc)
			qdel(src)
			var/choice = WWinput(user, "What type of wall?","Red Earth Walls Walls","Normal",list("Red Earth Bordered Wall","Red Earth Smooth Wall","Red Earth Wall","Red Earth Pillared Wall"))
			if (choice == "Red Earth Bordered Wall")
				return
			else if (choice == "Red Earth Smooth Wall")
				S.icon_state = "red_earth_smooth"
				base_icon_state = icon_state
				S.name = "red earthen smooth wall"
				var/choice1 = WWinput(user, "Which orientation?","Red Earth Smooth Wall","Direction",list("Vertical","Horizontal"))
				if (choice1 == "Vertical")
					S.dir = SOUTH
				else if (choice1 == "Horizontal")
					S.dir = EAST
			else if (choice == "Red Earth Wall")
				S.icon_state = "red_earth_wall"
				base_icon_state = icon_state
				S.name = "red earthen wall"
			else if (choice == "Red Earth Pillared Wall")
				S.icon_state = "red_earth_pillared"
				base_icon_state = icon_state
				S.name = "red earthen pillared wall"
			return
	..()

/obj/covers/claydoorway/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/generic))
		user << "You start adding stucco to the doorway..."
		if (do_after(user, 20, src))
			user << "You finish adding stucco to the doorway, rendering over it."
			qdel(W)
			new /obj/covers/clay_wall/redearth_doorway(loc)
			qdel(src)

/obj/covers/clay_wall/incomplete
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 40
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/clay_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/claybricks/fired))
		if (stage >= 2)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding clay blocks to the wall, completing it."
				qdel(W)
				var/obj/covers/clay_wall/S = new /obj/covers/clay_wall(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of construction?","Clay Constructions","Normal",list("Wall", "Alternative Brick Style", "Doorway"))
				if (choice == "Wall")
					return
				else if (choice == "Alternative Brick Style")
					S.icon_state = "clay_block_alt"
					base_icon_state = icon_state
					S.name = "clay block wall"
				else if (choice == "Doorway")
					new /obj/covers/clay_wall/claydoorway(S.loc)
					qdel(S)
				return
		else if (stage <= 1)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 1)
					user << "You finish clay block to the wall."
					stage += 1
					icon_state = "claybrickwall_inc[stage]"
					base_icon_state = icon_state
					health = (30*stage)
					qdel(W)
					return
	..()

/obj/covers/clay_wall/sumerian
	name = "sumerian clay wall"
	desc = "A sumerian style clay wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "sumerian-wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 150
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6
	material = "Stone"

/obj/covers/clay_wall/sumerian/doorway //if you actually wanted to summon one.
	name = "sumerian clay doorway"
	desc = "A sumerian style clay doorway."
	icon_state = "sumerian-door"
	density = FALSE
	opacity = FALSE

/obj/covers/clay_wall/sumerian/incomplete
	name = "sumerian clay wall"
	desc = "A sumerian style clay wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "sumerian-wall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 40
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/clay_wall/sumerian/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/claybricks/fired))
		if (stage >= 2)
			user << "You start adding clay to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding clay to the wall, completing it."
				qdel(W)
				var/obj/covers/clay_wall/sumerian/S = new /obj/covers/clay_wall/sumerian(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of wall?","Sumerian Clay Walls","Normal",list("Normal","Doorway","Window","Corner"))
				if (choice == "Normal")
					return
				else if (choice == "Doorway")
					S.icon_state = "sumerian-door"
					base_icon_state = icon_state
					S.name = "sumerian clay door"
					S.density = FALSE
					S.opacity = FALSE
				else if (choice == "Window")
					new /obj/structure/window_frame/sumerian(S.loc)
					qdel(S)
				else if (choice == "Corner")
					S.icon_state = "sumerian-corner1"
					base_icon_state = icon_state
					var/choice1 = WWinput(user, "Which corner?","Clay Walls","North-West",list("North-West","North-East","South-West","South-East"))
					if (choice1 == "North-West")
						S.dir = SOUTH
					else if (choice1 == "North-East")
						S.dir = EAST
					else if (choice1 == "South-West")
						S.dir = NORTH
					else if (choice1 == "South-East")
						S.dir = WEST
				return
		else if (stage <= 1)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 1)
					user << "You finish adding clay to the wall."
					stage += 1
					icon_state = "sumerian-wall_inc[stage]"
					base_icon_state = icon_state
					health = (30*stage)
					qdel(W)
					return
	..()

/obj/covers/brick_wall
	name = "brick wall"
	desc = "A red brick wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "new_brick0"
	base_icon_state = "new_brick"
	adjusts = TRUE
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 450
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 7
	material = "Stone"
	hardness = 92
	buildstack = /obj/item/weapon/clay/advclaybricks/fired

/obj/covers/cement_wall
	name = "concrete wall"
	desc = "A concrete wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "cement_wall0"
	base_icon_state = "cement_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 650 //until there are stronger alternatives.
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 8
	material = "Stone"
	hardness = 95
	adjusts = TRUE
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/covers/vault
	name = "vault wall"
	desc = "A very strong wall of concrete wall."
	icon = 'icons/obj/structures.dmi'
	icon_state = "vault"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 800
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	hardness = 100
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

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
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	hardness = 100

/obj/covers/cement_wall/incomplete
	name = "incomplete concrete wall"
	desc = "A cement brick wall."
	icon = 'icons/turf/walls.dmi'
	base_icon_state = "cement_wall_inc"
	icon_state = "cement_wall_inc0"
	adjusts = FALSE
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 80
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/covers/cement_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/advclaybricks/fired/cement))
		user << "You start adding cement to the wall..."
		if (do_after(user, 20, src) && W)
			user << "You finish adding cement to the wall, completing it."
			qdel(W)
			new /obj/covers/cement_wall(loc)
			qdel(src)
			return
	..()

/obj/covers/brick_wall/incomplete
	name = "incomplete brick wall"
	desc = "A red brick wall."
	icon = 'icons/turf/walls.dmi'
	base_icon_state = "new_brick_inc"
	icon_state = "new_brick_inc0"
	adjusts = FALSE
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 80
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/brick_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/advclaybricks/fired))
		user << "You start adding bricks to the wall..."
		if (do_after(user, 20, src) && W)
			user << "You finish adding bricks to the wall, completing it."
			var/choice = WWinput(user, "What type of wall?","Brick Walls","Wall",list("Wall","Window","Full Window"))
			if (choice == "Wall")
				qdel(W)
				new /obj/covers/brick_wall(loc)
				qdel(src)
				return
			else if (choice == "Window")
				qdel(W)
				new /obj/structure/window_frame/brick(loc)
				qdel(src)
				return
			else if (choice == "Full Window")
				qdel(W)
				new /obj/structure/window_frame/brickfull(loc)
				qdel(src)
				return
	..()

/obj/covers/jail/
	name = "jail"
	desc = "Do not use this."
	icon = 'icons/turf/walls.dmi'
	icon_state = "woodjail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 100000
	wall = TRUE
	explosion_resistance = 100
	material = "Wood"
	hardness = 15

/obj/covers/jail/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE

	else if (istype(mover, /obj/item/projectile))
		return TRUE
	else
		return FALSE

/obj/covers/jail/woodjail
	name = "wood jail bars"
	desc = "To keep prisoners in."
	icon = 'icons/turf/walls.dmi'
	icon_state = "woodjail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 200
	wall = TRUE
	explosion_resistance = 5
	buildstackamount = 8
	buildstack = /obj/item/stack/material/wood
	opacity = 0
	material = "Wood"

/obj/covers/jail/steeljail
	name = "steel jail bars"
	desc = "To keep prisoners in better."
	icon = 'icons/turf/walls.dmi'
	icon_state = "steeljail"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 800
	wall = TRUE
	explosion_resistance = 5
	buildstackamount = 8
	buildstack = /obj/item/stack/rods
	opacity = 0
	material = "Steel"

/obj/covers/jail/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You pound the bars uselessly!"//sucker
	else if (istype(W,/obj/item/weapon/wrench))//if it is a wrench
		user << "<span class='notice'>You start disassembling the [src]...</span>"
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		if (do_after(user, 30, target = src))
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			qdel(src)
			return
	return TRUE

/obj/covers/jail/woodjail/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench or hammer since im wood..
		user << "You pound the bars uselessly!" //sucker
	else if (istype(W,/obj/item/weapon/wrench) || istype(W,/obj/item/weapon/hammer))//if it is a wrench or hammer since im wood.
		user << "<span class='notice'>You start disassembling the [src]...</span>"
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		if (do_after(user, 30, target = src))
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			qdel(src)
			return
	return TRUE

/obj/covers/jail/bullet_act(var/obj/item/projectile/P)
	return PROJECTILE_CONTINUE

/obj/covers/jail/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		return TRUE
	..()


/obj/covers/New()
	..()
	initial_opacity = opacity
	maxhealth = health
	spawn(5)
		updateturf()
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE


/obj/covers/updateturf()
	..()
	var/turf/T = get_turf(src)
	if (T)
		origin_water_level = T.water_level
		T.water_level = 0
		T.move_delay = 0
	return TRUE


/obj/covers/Destroy()
	var/area/caribbean/CURRENTAREA = get_area(src)
	if (!istype(CURRENTAREA, /area/caribbean/void/caves))
		if (wall && !incomplete)
			new current_area_type(get_turf(src))
		var/turf/floor/T = get_turf(loc)
		if (T)
			T.water_level = origin_water_level
			T.move_delay = initial(T.move_delay)
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
	if (wall == TRUE)
		for(var/obj/roof/R in range(2,src))
			R.collapse_check()
	..()
	spawn(1)
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE

// the item you can use to repair a hole
/obj/item/weapon/covers
	name = "floor cover"
	desc = "Use this to cover holes."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired2"
	w_class = 2.0
	flammable = TRUE
	value = 0
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
		if (istype(T, /turf/floor/beach/water/deep/saltwater))
			visible_message("The [src] sinks!")
			qdel(src)
			return

/obj/item/weapon/covers/attack_self(mob/user)
	var/covers_time = 80
	if (ishuman(user))
		var/turf/targetfloor = get_turf(get_step(user, user.dir))
		if (istype(targetfloor, /turf/wall) || istype(targetfloor, /turf/floor/beach/water/deep/saltwater))
			visible_message("<span class='notice'>You can't build here!</span>")
			return
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	if (WWinput(user, "This will start building a floor cover [user.dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc) && src)
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 3)
		return


/obj/covers/fire_act(temperature)
	if (prob(35 * (temperature/500)) && wood == TRUE)
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)



/obj/covers/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(75) && density)
			visible_message("<span class = 'warning'>\The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && not_movable == TRUE)
		return
	if (istype(W, /obj/item/weapon/hammer))
		if (!wall)
			user << "You start removing \the [src]..."
			if (do_after(user, 70, src))
				user << "You removed \the [src] from the floor."
				qdel(src)
				return
	if (wall)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (istype(W, /obj/item/weapon/poster/religious))
			user << "You start placing the [W] on the [src]..."
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/religious/RP = new/obj/structure/poster/religious(get_turf(src))
				var/obj/item/weapon/poster/religious/P = W
				RP.religion = P.religion
				RP.symbol = P.symbol
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/weapon/poster/faction))
			user << "You start placing the [W] on the [src]..."
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/faction/RP = new/obj/structure/poster/faction(get_turf(src))
				var/obj/item/weapon/poster/faction/P = W
				RP.faction = P.faction
				RP.bstyle = P.bstyle
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/flashlight/torch) && wood == TRUE)
			var/obj/item/flashlight/torch/T = W
			if (prob(33) && T.on)
				onfire = TRUE
				visible_message("<span class='danger'>\The [src] catches fire!</span>")
				start_fire()
		if (istype(W, /obj/item/stack))
			var/obj/item/stack/S = W
			if (S.amount <= 0)
				qdel(S)
			else
				repair(S, user)
				playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
				user.do_attack_animation(src)
				return
		else
			switch(W.damtype)
				if ("fire")
					health -= W.force * 0.7
				if ("brute")
					health -= W.force * 0.2

		playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
		..()
	else
		return

/obj/covers/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
		qdel(src)
		return


/obj/covers/bullet_act(var/obj/item/projectile/proj)
	if (istype(proj, /obj/item/projectile/arrow/arrow/fire) && wood == TRUE)
		health -= proj.damage * 0.25
		if (prob(25))
			onfire = TRUE
			visible_message("<span class='danger'>\The [src] catches fire!</span>")
			start_fire()
		try_destroy()
	else
		if (wall)
			if (istype(proj, /obj/item/projectile/shell))
				var/obj/item/projectile/shell/S = proj
				if (S.atype == "HE")
					visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
					qdel(src)
					return
				else
					if (prob(60))
						visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
						qdel(src)
			else
				if (istype(proj, /obj/item/projectile/bullet) && bullethole_count.len < 13)
					new_bullethole()
				health -= proj.damage * 0.1
				try_destroy()
			return
		else
			return

/obj/covers/proc/start_fire()
	if (onfire && wood)
		var/obj/effect/fire/NF = new/obj/effect/fire(src.loc)
		start_fire_dmg(NF)

/obj/covers/proc/start_fire_dmg(var/obj/effect/fire/SF)
	spawn(80)
		if (health > 0)
			health -= 10
			start_fire_dmg()
			return
		else
			try_destroy()
			qdel(SF)
			return

///////////////////////////////COVER WALL BORDERS//////////////////////////////
/obj/covers/proc/check_relatives(var/update_self = FALSE, var/update_others = FALSE)
	if (!adjusts)
		return
	var/junction
	if (update_self)
		junction = FALSE
	for (var/checkdir in cardinal)
		var/turf/T = get_step(src, checkdir)
		for(var/obj/covers/CV in T)
			if (!can_join_with(CV))
				continue
			if (update_self)
				if (can_join_with(CV))
					junction |= get_dir(src,CV)
			if (update_others)
				CV.check_relatives(1,0)
	if (!isnull(junction))
		icon_state = "[base_icon_state][junction]"
	return

/obj/covers/proc/can_join_with(var/obj/covers/W)
	if (istype(W,src))
		return TRUE
	return FALSE

/obj/covers/update_icon()
	..()
	check_relatives(1,1)
	overlays.Cut()
	overlays |= bullethole_overlays
	if (moldy>0)
		overlays += image(icon = 'icons/turf/walls.dmi', icon_state = "mold[moldy]", layer = src.layer+0.02)
	if (cracked>0)
		overlays += image(icon = 'icons/turf/walls.dmi', icon_state = "cracks[cracked]", layer = src.layer+0.01)
/obj/covers/New()
	..()
	check_relatives(1,1)

/obj/covers/Destroy()
	check_relatives(0,1)
	..()

/obj/covers/proc/new_bullethole()
	if (bullethole_count.len >= 13)
		return
	if (!wall)
		return
	var/list/opts = list(1,2,3,4,5,6,7,8,9,10,11,12,13)
	for(var/i in bullethole_count)
		opts -= i
	if (isemptylist(opts))
		return
	var/chnum = pick(opts)
	var/tmp_bullethole = image(icon = 'icons/turf/walls.dmi', icon_state = "bullethole[chnum]", layer = src.layer+0.01)
	bullethole_overlays += tmp_bullethole
	bullethole_count += list(chnum)
	update_icon()

////////////////////////////////////////////////////////////

/obj/covers/wood_wall/aztec
	name = "aztec wood wall"
	desc = "A wood wall, in aztec style."
	icon_state = "aztec0"
	base_icon_state = "aztec"
	adjusts = TRUE

/obj/covers/wood_wall/nordic
	name = "nordic wood wall"
	desc = "A wood wall, in northern european style."
	icon_state = "nordic0"
	base_icon_state = "nordic"
	adjusts = TRUE

/obj/covers/stone_wall/roman
	name = "roman stone wall"
	desc = "A roman-style stone wall."
	icon_state = "roman0"
	base_icon_state = "roman"
	adjusts = TRUE

/obj/covers/stone_wall/egyptian
	name = "egyptian sandstone wall"
	desc = "An egyptian-style sandstone wall."
	icon_state = "egyptian0"
	base_icon_state = "egyptian"
	adjusts = TRUE
	buildstack = /obj/item/stack/material/sandstone

/obj/covers/stone_wall/egyptian/archway
	name = "egyptian archway"
	desc = "A egyptian style sandstone archway."
	icon_state = "egyptian_archway"
	base_icon_state = "egyptian_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/mayan
	name = "mayan stone wall"
	desc = "A mayan-style stone wall."
	icon_state = "mayan0"
	base_icon_state = "mayan"
	adjusts = TRUE

/obj/covers/stone_wall/classic
	name = "stone block wall"
	desc = "A stone block wall."
	icon_state = "stone_block_wall0"
	base_icon_state = "stone_block_wall"
	adjusts = TRUE

/obj/covers/stone_wall/classic/archway
	name = "stone block archway"
	desc = "A stone block archway."
	icon_state = "stone_block_archway"
	base_icon_state = "stone_block_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/classic/villa
	name = "villa wall"
	desc = "A roman style villa wall."
	icon_state = "villa_wall"
	adjusts = FALSE

/obj/covers/stone_wall/classic/villa/relief
	name = "villa wall relief"
	desc = "A roman style villa wall with a large empty relief."
	icon_state = "villa_wall_l_relief"


/* Additional roman villa types seperately defined for mapping/spawning purposes*/

/obj/covers/stone_wall/classic/villa/pillared
	name = "pillared villa wall"
	desc = "A roman style pillared villa wall."
	icon_state = "villa_pillared"

/obj/covers/stone_wall/classic/villa/relief/gladiator
	name = "villa wall relief of a gladiator"
	desc = "A roman style villa wall with a chiselled relief of a gladiator."
	icon_state = "villa_wall_l_relief_gladiator"

/obj/covers/stone_wall/classic/villa/relief/aquila
	name = "villa wall relief of a aquila"
	desc = "A roman style villa wall with a chiselled relief of a aquila."
	icon_state = "villa_wall_l_relief_aquila"

/obj/covers/stone_wall/classic/villa/relief/greek
	name = "villa wall relief of a hoplite"
	desc = "A roman style villa wall with a chiselled relief of a hoplite."
	icon_state = "villa_wall_l_relief_greek"

/obj/covers/stone_wall/classic/villa_doorway
	name = "villa doorway"
	desc = "A roman style villa doorway."
	icon_state = "villa_door"
	base_icon_state = "villa_door"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/* Additional roman villa types - End*/

/obj/covers/stone_wall/classic/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/roman))
		user << "You start adding roman stucco to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding roman stucco to the wall, rendering it."
			qdel(W)
			var/obj/covers/stone_wall/classic/villa/S = new /obj/covers/stone_wall/classic/villa(loc)
			qdel(src)
			var/choice = WWinput(user, "What type of wall?","Roman Villa Walls","Normal",list("Villa Wall","Villa Pillared Wall","Villa Wall With Clear Relief", "Villa Wall With Gladiator Relief", "Villa Wall With Aquila Relief", "Villa Wall With Hoplite Relief"))
			if (choice == "Villa Wall")
				return
			else if (choice == "Villa Pillared Wall")
				S.icon_state = "villa_pillared"
				base_icon_state = icon_state
				S.name = "pillared villa wall"
				S.desc = "A roman style pillared villa wall."
			else if (choice == "Villa Wall With Clear Relief")
				S.icon_state = "villa_wall_l_relief"
				base_icon_state = icon_state
				S.name = "villa wall relief"
				S.desc = "A roman style villa wall with a large empty relief."
			else if (choice == "Villa Wall With Gladiator Relief")
				S.icon_state = "villa_wall_l_relief_gladiator"
				base_icon_state = icon_state
				S.name = "villa wall relief of a gladiator"
				S.desc = "A roman style villa wall with a chiselled relief of a gladiator."
			else if (choice == "Villa Wall With Aquila Relief")
				S.icon_state = "villa_wall_l_relief_aquila"
				base_icon_state = icon_state
				S.name = "villa wall relief of a aquila"
				S.desc = "A roman style villa wall with a chiselled relief of a aquila."
			else if (choice == "Villa Wall With Hoplite Relief")
				S.icon_state = "villa_wall_l_relief_greek"
				base_icon_state = icon_state
				S.name = "villa wall relief of a hoplite"
				S.desc = "A roman style villa wall with a chiselled relief of a hoplite."
			return
	..()

/obj/covers/stone_wall/classic/archway/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/roman))
		user << "You start adding roman stucco to the archway..."
		if (do_after(user, 20, src))
			user << "You finish adding roman stucco to the archway, rendering over it."
			qdel(W)
			new /obj/covers/stone_wall/classic/villa_doorway(loc)
			qdel(src)
			return

	if (istype(W, /obj/item/weapon/stucco/greek))
		user << "You start adding greek stucco to the archway..."
		if (do_after(user, 20, src))
			user << "You finish adding greek stucco to the archway, rendering over it."
			qdel(W)
			new /obj/covers/stone_wall/classic/grecian_archway(loc)
			qdel(src)
			return

/obj/covers/stone_wall/classic/grecian
	name = "smooth and bordered grecian wall"
	desc = "A grecian style bordered stone wall."
	icon_state = "grecian_smooth_b"
	adjusts = FALSE

/obj/covers/stone_wall/classic/grecian_archway
	name = "grecian archway"
	desc = "A impressive grecian archway."
	icon_state = "grecian_archway"
	base_icon_state = "grecian_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/* Additional grecian types seperately defined for mapping/spawning purposes*/

/obj/covers/stone_wall/classic/grecian/smooth
	name = "smooth grecian wall"
	desc = "A grecian style smooth stone wall."
	icon_state = "grecian_smooth"

/obj/covers/stone_wall/classic/grecian/cobbled
	name = "cobbled grecian wall"
	desc = "A grecian style cobbled stone wall."
	icon_state = "grecian_cobbled"

/obj/covers/stone_wall/classic/grecian/cobbled_bordered
	name = "cobbled and bordered grecian wall"
	desc = "A grecian style borde stone wall."
	icon_state = "grecian_cobbled_b"

/obj/covers/stone_wall/classic/grecian/pattern
	name = "patterened grecian wall"
	desc = "A grecian style patterned stone wall."
	icon_state = "grecian_patterned"

/obj/covers/stone_wall/classic/grecian/bordered_pattern
	name = "patterened and bordered grecian wall"
	desc = "A grecian style patterned and bordered stone wall."
	icon_state = "grecian_patterned_b"

//grecian pattern N/E (smooth), S/W (cobbled), rotate it yourself.

/* Additional grecian types - End*/

/obj/covers/stone_wall/classic/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/greek))
		user << "You start adding greek stucco to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding greek stucco to the wall, rendering it."
			qdel(W)
			var/obj/covers/stone_wall/classic/grecian/S = new /obj/covers/stone_wall/classic/grecian(loc)
			qdel(src)
			var/choice = WWinput(user, "What type of wall?","Grecian Walls","Normal",list("Grecian Smooth Bordered Wall","Grecian Smooth","Grecian Smooth Patterned Wall","Grecian Smooth Bordered Patterned Wall", "Grecian Cobbled Bordered Wall", "Grecian Cobbled", "Grecian Cobbled Pattern", "Grecian Cobbled Bordered Pattern"))
			if (choice == "Grecian Smooth Bordered Wall")
				return
			else if (choice == "Grecian Smooth")
				S.icon_state = "grecian_smooth"
				base_icon_state = icon_state
				S.name = "smooth grecian wall"
				S.desc = "A grecian style smooth stone wall."
				var/choice1 = WWinput(user, "Which orientation?","Grecian Smooth","Direction",list("Vertical","Horizontal"))
				if (choice1 == "Vertical")
					S.dir = SOUTH
				else if (choice1 == "Horizontal")
					S.dir = EAST
			else if (choice == "Grecian Smooth Patterned Wall")
				S.icon_state = "grecian_pattern"
				base_icon_state = icon_state
				S.name = "smooth patterned grecian wall"
				S.desc = "A grecian style smooth patterned stone wall."
				var/choice2 = WWinput(user, "Which orientation?","Grecian Smooth Pattern","Direction",list("Vertical","Horizontal"))
				if (choice2 == "Vertical")
					S.dir = SOUTH
				else if (choice2 == "Horizontal")
					S.dir = EAST
			else if (choice == "Grecian Smooth Bordered Patterned Wall")
				S.icon_state = "grecian_pattern_b"
				base_icon_state = icon_state
				S.name = "smooth patterned and bordered grecian wall"
				S.desc = "A grecian style smooth, patterned and bordered stone wall."
				var/choice3 = WWinput(user, "Which orientation?","Grecian Smooth Bordered Pattern","Direction",list("Vertical","Horizontal"))
				if (choice3 == "Vertical")
					S.dir = SOUTH
				else if (choice3 == "Horizontal")
					S.dir = EAST
			else if (choice == "Grecian Cobbled Bordered Wall")
				S.icon_state = "grecian_cobbled_b"
				base_icon_state = icon_state
				S.name = "cobbled and bordered grecian wall"
				S.desc = "A grecian style cobbled and bordered stone wall."
			else if (choice == "Grecian Cobbled")
				S.icon_state = "grecian_cobbled"
				base_icon_state = icon_state
				S.name = "grecian cobbled wall"
				S.desc = "A grecian style cobbled stone wall."
				var/choice4 = WWinput(user, "Which orientation?","Grecian Cobbled","Direction",list("Vertical","Horizontal"))
				if (choice4 == "Vertical")
					S.dir = NORTH
				else if (choice4 == "Horizontal")
					S.dir = WEST
			else if (choice == "Grecian Cobbled Pattern")
				S.icon_state = "grecian_pattern"
				S.name = "grecian cobbled pattern wall"
				base_icon_state = icon_state
				S.desc = "A grecian style cobbled patterned stone wall."
				var/choice5 = WWinput(user, "Which orientation?","Grecian Cobbled Pattern","Direction",list("Vertical","Horizontal"))
				if (choice5 == "Vertical")
					S.dir = NORTH
				else if (choice5 == "Horizontal")
					S.dir = WEST
			else if (choice == "Grecian Cobbled Bordered Pattern")
				S.icon_state = "grecian_pattern_b"
				S.name = "grecian cobbled pattern and bordered wall"
				base_icon_state = icon_state
				S.desc = "A grecian style cobbled pattern and bordered stone wall."
				var/choice6 = WWinput(user, "Which orientation?","Grecian Cobbled Pattern","Direction",list("Vertical","Horizontal"))
				if (choice6 == "Vertical")
					S.dir = NORTH
				else if (choice6 == "Horizontal")
					S.dir = WEST
			return
	..()

/obj/covers/stone_wall/brick
	name = "stone brick wall"
	desc = "A stone brick wall."
	icon_state = "new_stonebrick0"
	base_icon_state = "new_stonebrick"
	adjusts = TRUE
	health = 550
	buildstack = /obj/item/stack/material/stonebrick

/obj/covers/stone_wall/brick/archway
	name = "stone brick archway"
	desc = "A stone brick archway."
	icon_state = "new_stonebrick_archway"
	base_icon_state = "new_stonebrick_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/fortress
	name = "fortress brick wall"
	desc = "A dense fortress brick wall."
	icon_state = "fortress_brickwall0"
	base_icon_state = "fortress_brickwall"
	adjusts = TRUE
	health = 650
	explosion_resistance = 7
	buildstack = /obj/item/stack/material/stonebrick

/obj/covers/stone_wall/fortress/archway
	name = "fortress brick archway"
	desc = "A fortress brick archway."
	icon_state = "fortress_brickwall_archway"
	base_icon_state = "fortress_brickwall_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE
