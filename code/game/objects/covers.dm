/obj/covers

	name = "floor covers"
	desc = "A floor cover."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_density = FALSE
	var/origin_water_level = 0
	var/origin_move_delay = 0
	var/not_movable = FALSE //if it can be removed by wrenches
	var/health = 50
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.1
	level = 2
	var/amount = FALSE
//	invisibility = 101 //starts invisible


/obj/covers/wood
	name = "wood floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "wood"
	passable = TRUE
	amount = 1

/obj/covers/cobblestone
	name = "cobblestone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_vertical_dark"
	passable = TRUE
	not_movable = TRUE
	amount = 0

/obj/covers/wood_ship
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE
	not_movable = TRUE
	amount = 1

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
	layer = 2.12

/obj/covers/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && not_movable == TRUE)
		return
	..()

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
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
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
	layer = 2.11

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


/obj/covers/fire_act(temperature)
	if (prob(35 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)


/obj/covers/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(75) && density)
			visible_message("<span class = 'warning'>The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * 0.75
		if ("brute")
			health -= W.force * 0.1

	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/covers/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The [src] is broken into pieces!</span>")
		qdel(src)
		return


/obj/covers/bullet_act(var/obj/item/projectile/proj)
	if (prob(proj.damage - 30)) // makes shrapnel unable to take down trees
		visible_message("<span class = 'danger'>[src] collapses!</span>")
		qdel(src)