/* Tables and Racks
 * Contains:
 *		Tables
 *		Glass Tables
 *		Wooden Tables
 *		Reinforced Tables
 *		Racks
 *		Rack Parts
 */

/*
 * Tables
 */

/obj/structure/table
	name = "table"
	desc = "A square piece of metal standing on four metal legs. It can not move."
	icon = 'icons/obj/structures_FO13.dmi'
	icon_state = "table"
	density = TRUE
	anchored = TRUE
	layer = 2.8
	climbable = TRUE
	var/frame = /obj/structure/table_frame
	var/framestack = /obj/item/stack/rods
	var/buildstack = /obj/item/stack/material/iron
	var/busy = FALSE
	var/buildstackamount = TRUE
	var/framestackamount = 2
	var/deconstructable = TRUE
	var/flipped = FALSE // WIP?
	var/health = 100
	throwpass = TRUE

/obj/structure/table/New()
	..()
	for (var/obj/structure/table/T in loc)
		if (T != src)
			qdel(T)
	update_icon()
	for (var/direction in list(1,2,4,8,5,6,9,10))
		if (locate(/obj/structure/table,get_step(src,direction)))
			var/obj/structure/table/T = locate(/obj/structure/table,get_step(src,direction))
			T.update_icon()

/obj/structure/table/Destroy()
	for (var/direction in list(1,2,4,8,5,6,9,10))
		if (locate(/obj/structure/table,get_step(src,direction)))
			var/obj/structure/table/T = locate(/obj/structure/table,get_step(src,direction))
			T.update_icon()
	..()

/obj/structure/table/update_icon()
	spawn(2) //So it properly updates when deleting
		var/dir_sum = FALSE
		for (var/direction in list(1,2,4,8,5,6,9,10))
			var/skip_sum = FALSE
			for (var/obj/structure/window/W in loc)
				if (W.dir == direction) //So smooth tables don't go smooth through windows
					skip_sum = TRUE
					continue
			var/inv_direction //inverse direction
			switch(direction)
				if (1)
					inv_direction = 2
				if (2)
					inv_direction = TRUE
				if (4)
					inv_direction = 8
				if (8)
					inv_direction = 4
				if (5)
					inv_direction = 10
				if (6)
					inv_direction = 9
				if (9)
					inv_direction = 6
				if (10)
					inv_direction = 5
			for (var/obj/structure/window/W in get_step(src,direction))
				if (W.dir == inv_direction) //So smooth tables don't go smooth through windows when the window is on the other table's tile
					skip_sum = TRUE
					continue
			if (!skip_sum) //means there is a window between the two tiles in this direction
				if (locate(/obj/structure/table,get_step(src,direction)))
					if (direction <5)
						dir_sum += direction
					else
						if (direction == 5)	//This permits the use of all table directions. (Set up so clockwise around the central table is a higher value, from north)
							dir_sum += 16
						if (direction == 6)
							dir_sum += 32
						if (direction == 8)	//Aherp and Aderp.  Jezes I am stupid.  -- SkyMarshal
							dir_sum += 8
						if (direction == 10)
							dir_sum += 64
						if (direction == 9)
							dir_sum += 128

		var/table_type = FALSE //stand_alone table
		if (dir_sum%16 in cardinal)
			table_type = TRUE //endtable
			dir_sum %= 16
		if (dir_sum%16 in list(3,12))
			table_type = 2 //1 tile thick, streight table
			if (dir_sum%16 == 3) //3 doesn't exist as a dir
				dir_sum = 2
			if (dir_sum%16 == 12) //12 doesn't exist as a dir.
				dir_sum = 4
		if (dir_sum%16 in list(5,6,9,10))
			if (locate(/obj/structure/table,get_step(loc,dir_sum%16)))
				table_type = 3 //full table (not the TRUE tile thick one, but one of the 'tabledir' tables)
			else
				table_type = 2 //1 tile thick, corner table (treated the same as streight tables in code later on)
			dir_sum %= 16
		if (dir_sum%16 in list(13,14,7,11)) //Three-way intersection
			table_type = 5 //full table as three-way intersections are not sprited, would require 64 sprites to handle all combinations.  TOO BAD -- SkyMarshal
			switch(dir_sum%16)	//Begin computation of the special type tables.  --SkyMarshal
				if (7)
					if (dir_sum == 23)
						table_type = 6
						dir_sum = 8
					else if (dir_sum == 39)
						dir_sum = 4
						table_type = 6
					else if (dir_sum == 55 || dir_sum == 119 || dir_sum == 247 || dir_sum == 183)
						dir_sum = 4
						table_type = 3
					else
						dir_sum = 4
				if (11)
					if (dir_sum == 75)
						dir_sum = 5
						table_type = 6
					else if (dir_sum == 139)
						dir_sum = 9
						table_type = 6
					else if (dir_sum == 203 || dir_sum == 219 || dir_sum == 251 || dir_sum == 235)
						dir_sum = 8
						table_type = 3
					else
						dir_sum = 8
				if (13)
					if (dir_sum == 29)
						dir_sum = 10
						table_type = 6
					else if (dir_sum == 141)
						dir_sum = 6
						table_type = 6
					else if (dir_sum == 189 || dir_sum == 221 || dir_sum == 253 || dir_sum == 157)
						dir_sum = TRUE
						table_type = 3
					else
						dir_sum = TRUE
				if (14)
					if (dir_sum == 46)
						dir_sum = TRUE
						table_type = 6
					else if (dir_sum == 78)
						dir_sum = 2
						table_type = 6
					else if (dir_sum == 110 || dir_sum == 254 || dir_sum == 238 || dir_sum == 126)
						dir_sum = 2
						table_type = 3
					else
						dir_sum = 2 //These translate the dir_sum to the correct dirs from the 'tabledir' icon_state.
		if (dir_sum%16 == 15)
			table_type = 4 //4-way intersection, the 'middle' table sprites will be used.
		switch(table_type)
			if (0)
				icon_state = "[initial(icon_state)]"
			if (1)
				icon_state = "[initial(icon_state)]_1tileendtable"
			if (2)
				icon_state = "[initial(icon_state)]_1tilethick"
			if (3)
				icon_state = "[initial(icon_state)]_dir"
			if (4)
				icon_state = "[initial(icon_state)]_middle"
			if (5)
				icon_state = "[initial(icon_state)]_dir2"
			if (6)
				icon_state = "[initial(icon_state)]_dir3"
		if (dir_sum in list(1,2,4,8,5,6,9,10))
			dir = dir_sum
		else
			dir = 2

/obj/structure/table/ex_act(severity, target)
	..()
	if (severity == 3)
		if (prob(25))
			table_destroy(1)
/*
/obj/structure/table/attack_tk() // no telehulk sorry
	return*/

/obj/structure/table/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || (height==0)) return TRUE
	if (istype(mover,/obj/item/projectile))
		return (check_cover(mover,target))
	if (flipped == TRUE)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return TRUE
	if (istype(mover) && mover.checkpass(PASSTABLE))
		return TRUE
	if (locate(/obj/structure/table) in get_turf(mover))
		return TRUE
	return FALSE

//checks if projectile 'P' from turf 'from' can hit whatever is behind the table. Returns TRUE if it can, FALSE if bullet stops.
/obj/structure/table/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover
	if (flipped==1)
		cover = get_turf(src)
	else if (flipped==0)
		cover = get_step(loc, get_dir(from, loc))
	if (!cover)
		return TRUE
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return TRUE
	if (get_turf(P.original) == cover)
		var/chance = 20
		if (ismob(P.original))
			var/mob/M = P.original
			if (M.lying)
				chance += 20				//Lying down lets you catch less bullets
		if (flipped==1)
			if (get_dir(loc, from) == dir)	//Flipped tables catch mroe bullets
				chance += 20
			else
				return TRUE					//But only from one side
		if (prob(chance))
			health -= P.damage/2
			if (health > 0)
				visible_message("<span class='warning'>[P] hits \the [src]!</span>")
				return FALSE
			else
				visible_message("<span class='warning'>[src] breaks down!</span>")
				break_to_parts()
				return TRUE
	return TRUE

/obj/structure/table/CheckExit(atom/movable/O as mob|obj, target as turf)
	if (istype(O) && O.checkpass(PASSTABLE))
		return TRUE
	if (flipped==1)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return TRUE
	return TRUE


/obj/structure/table/MouseDrop_T(atom/movable/O, mob/user)
	..()
	if ((!( istype(O, /obj/item/weapon) ) || user.get_active_hand() != O))
		return
	if (!user.drop_item())
		return
	if (O.loc != loc)
		step(O, get_dir(O, src))
	return

/obj/structure/table/proc/break_to_parts(full_return = FALSE)
	var/list/shards = list()
	var/obj/item/weapon/material/shard/S = null
	if (buildstack)
		new buildstack (loc)
/*	if (carpeted && (full_return || prob(50))) // Higher chance to get the carpet back intact, since there's no non-intact option
		new /obj/item/stack/tile/carpet(loc)*/
	else if (full_return || prob(20))
		new /obj/item/stack/material/steel(loc)
	else
		var/material/M = get_material_by_name(DEFAULT_WALL_MATERIAL)
		S = M.place_shard(loc)
		if (S) shards += S
	qdel(src)
	return shards

/obj/structure/table/proc/tablepush(obj/item/I, mob/user)
	if (get_dist(src, user) < 2)
		var/obj/item/weapon/grab/G = I
		if (G.affecting.buckled)
			user << "<span class='warning'>[G.affecting] is buckled to [G.affecting.buckled]!</span>"
			return FALSE
		if (G.state < GRAB_AGGRESSIVE)
			user << "<span class='warning'>You need a better grip to do that!</span>"
			return FALSE
		if (!G.confirm())
			return FALSE
		G.affecting.loc = loc
		G.affecting.Weaken(2)
		G.affecting.visible_message("<span class='danger'>[G.assailant] pushes [G.affecting] onto [src].</span>", \
									"<span class='userdanger'>[G.assailant] pushes [G.affecting] onto [src].</span>")
		add_logs(G.assailant, G.affecting, "pushed")
		qdel(I)
		return TRUE
	qdel(I)

/obj/structure/table/attackby(var/obj/item/I, mob/user, params)
	if (istype(I, /obj/item/weapon/grab))
		tablepush(I, user)
		return

	if (istype(I, /obj/item/weapon/screwdriver))
		if (istype(src, /obj/structure/table/reinforced))
			var/obj/structure/table/reinforced/RT = src
			if (RT.status == TRUE)
				table_destroy(2, user)
				return
		else
			table_destroy(2, user)
			return

	if (istype(I, /obj/item/weapon/wrench))
		if (istype(src, /obj/structure/table/reinforced))
			var/obj/structure/table/reinforced/RT = src
			if (RT.status == TRUE)
				table_destroy(3, user)
				return
		else
			table_destroy(3, user)
			return

	user.drop_item(loc)
	playsound(loc, I.dropsound, 100, TRUE)

	//Center the icon where the user clicked if we can.
	var/list/click_params = params2list(params)
	if (!click_params || !click_params["icon-x"] || !click_params["icon-y"])
		return
	//Clamp it so that the icon never moves more than 16 pixels in either direction (thus leaving the table turf)
	I.pixel_x = Clamp(text2num(click_params["icon-x"]) - 16, -(world.icon_size/2), world.icon_size/2)
	I.pixel_y = Clamp(text2num(click_params["icon-y"]) - 16, -(world.icon_size/2), world.icon_size/2)

/*
 * TABLE DESTRUCTION/DECONSTRUCTION
 */

#define TBL_DESTROY TRUE
#define TBL_DISASSEMBLE 2
#define TBL_DECONSTRUCT 3

/obj/structure/table/proc/table_destroy(destroy_type, mob/user)
	if (!deconstructable)
		return

	if (destroy_type == TBL_DESTROY)
		for (var/i = TRUE, i <= framestackamount, i++)
			new framestack(get_turf(src))
		for (var/i = TRUE, i <= buildstackamount, i++)
			new buildstack(get_turf(src))
		qdel(src)
		return

	if (destroy_type == TBL_DISASSEMBLE)
		user << "<span class='notice'>You start disassembling [src]...</span>"
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		if (do_after(user, 20, target = src))
			new frame(loc)
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			qdel(src)
			return

	if (destroy_type == TBL_DECONSTRUCT)
		user << "<span class='notice'>You start deconstructing [src]...</span>"
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		if (do_after(user, 40, target = src))
			for (var/i = TRUE, i <= framestackamount, i++)
				new framestack(get_turf(src))
			for (var/i = TRUE, i <= buildstackamount, i++)
				new buildstack(get_turf(src))
			playsound(loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
			qdel(src)
			return

/*
 * Glass tables
 */
/obj/structure/table/glass
	name = "glass table"
	desc = "What did I say about leaning on the glass tables? Now you need surgery."
	icon_state = "glass_table"
	buildstack = /obj/item/stack/material/glass

/obj/structure/table/glass/tablepush(obj/item/I, mob/user)
	if (..())
		visible_message("<span class='warning'>[src] breaks!</span>")
		playsound(loc, "shatter", 50, TRUE)
		new frame(loc)
		new /obj/item/weapon/material/shard(loc)
		qdel(src)

/obj/structure/table/glass/proc/shatter()
	visible_message("<span class='warning'>[src] shatters!</span>")
	playsound(loc, "shatter", 50, TRUE)
	new frame(loc)
	new /obj/item/weapon/material/shard(loc)
	for (var/mob/living/L in climbers|(loc.contents))
		L.Weaken(5)
	qdel(src)

/*
 * Iron tables
 */


/obj/structure/table/iron
	name = "iron table"
	desc = "A very hard table."
	icon_state = "table"
	frame = /obj/structure/table_frame
	framestack = /obj/item/stack/material/iron
	buildstack = /obj/item/stack/material/iron

/obj/structure/table/marble
	name = "marble table"
	desc = "A very hard table."
	icon_state = "table"
	frame = /obj/structure/table_frame
	framestack = /obj/item/stack/material/marble
	buildstack = /obj/item/stack/material/marble

/*
 * Wooden tables
 */

/obj/structure/table/wood
	name = "wooden table"
	desc = "Do not apply fire to this. Rumour says it burns easily."
	icon_state = "wood_table"
	frame = /obj/structure/table_frame/wood
	framestack = /obj/item/stack/material/wood
	buildstack = /obj/item/stack/material/wood

/obj/structure/table/wood/poker //No specialties, Just a mapping object.
	name = "gambling table"
	desc = "A seedy table for seedy dealings in seedy places."
	icon_state = "pokertable"
	buildstack = /obj/item/stack/tile/carpet


/* Reinforced tables */

/obj/structure/table/reinforced
	name = "reinforced steel table"
	desc = "A reinforced version of the four legged table, much harder to simply deconstruct."
	icon_state = "reinftable"
	var/status = 2
	frame = /obj/structure/table_frame
	framestack = /obj/item/stack/material/steel
	buildstack = /obj/item/stack/material/steel

/obj/structure/table/reinforced/attackby(obj/item/weapon/W, mob/user, params)
	if (istype(W, /obj/item/weapon/weldingtool))
		var/obj/item/weapon/weldingtool/WT = W
		if (WT.remove_fuel(0, user))
			if (status == 2)
				user << "<span class='notice'>You start weakening the reinforced table...</span>"
				playsound(loc, 'sound/items/Welder.ogg', 50, TRUE)
				if (do_after(user, 50, target = src))
					if (!src || !WT.isOn()) return
					user << "<span class='notice'>You weaken the table.</span>"
					status = TRUE
			else
				user << "<span class='notice'>You start strengthening the reinforced table...</span>"
				playsound(loc, 'sound/items/Welder.ogg', 50, TRUE)
				if (do_after(user, 50, target = src))
					if (!src || !WT.isOn()) return
					user << "<span class='notice'>You strengthen the table.</span>"
					status = 2
			return
	..()