/obj/covers

	name = "floor covers"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_density = FALSE
	var/origin_water_level = 0
	var/origin_move_delay = 0
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.8
	level = 2
//	invisibility = 101 //starts invisible


/obj/covers/wood
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE

/obj/covers/New()
	..()
	spawn(15)
		var/turf/T = get_turf(loc)
		if (passable)
			origin_density = T.density
			T.density = FALSE
			spawn(15)
				updateturf()
		return TRUE
/*
	for(var/obj/Ob in get_turf(src))
		if (Ob.invisibility == 0)
			Ob.invisibility = 101
	for(var/mob/Mb in get_turf(src))
		if (Mb.invisibility == 0)
			Mb.invisibility = 101 */

/obj/covers/updateturf()
	var/turf/T = get_turf(loc)
	if (passable)
		origin_density = T.density
		origin_move_delay = T.move_delay
		origin_water_level = T.water_level
		T.density = FALSE
		T.water_level = 0
		T.move_delay = 0
	return TRUE


/obj/covers/Destroy()
	var/turf/T = get_turf(loc)
	if (origin_density)
		T.density = origin_density
		T.water_level = origin_water_level
	..()
	return TRUE

// the item you can use to repair a hole
/obj/item/weapon/covers
	name = "floor cover"
	desc = "Use this to cover holes."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired"
	w_class = 2.0

/obj/covers/repairedfloor
	name = "repaired floor"
	desc = "a repaired wood floor."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired"
	var/wood_ammount = FALSE

/obj/item/weapon/covers/attack_self(mob/user)
	var/your_dir = "NORTH"

	switch (user.dir)
		if (NORTH)
			your_dir = "NORTH"
		if (SOUTH)
			your_dir = "SOUTH"
		if (EAST)
			your_dir = "EAST"
		if (WEST)
			your_dir = "WEST"

	var/covers_time = 80

	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	if (WWinput(user, "This will start building a floor cover [your_dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc))
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/carbon/human/H = user
				H.adaptStat("crafting", 3)
		return
