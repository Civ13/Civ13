/* this code has deviated so far from the original flamethrower code,
 * that there's almost no point in even keeping its parent type
 * around. This may as well become /obj/item/weapon/flammenwerfer - Kachnov */

/obj/item/weapon/flamethrower/flammenwerfer
	name = "flammenwerfer"
	desc = "You are a firestarter!"
	icon = 'icons/obj/flamethrower.dmi'
	icon_state = "fw_off"
	item_state = "fw_off"
	var/pressure_1 = 100
	status = TRUE
	nothrow = TRUE
	var/fueltank = 1.00
	var/obj/item/weapon/storage/backpack/flammenwerfer/backpack = null
	var/rwidth = 5
	var/rheight = 3
	var/max_total_range = 8

/obj/item/weapon/flamethrower/flammenwerfer/nothrow_special_check()
	return nodrop_special_check()

/obj/item/weapon/flamethrower/flammenwerfer/update_icon()
	if (lit)
		icon_state = "fw_on"
		item_state = "fw_on"
	else
		icon_state = "fw_off"
		item_state = "fw_off"
	update_held_icon()

/obj/item/weapon/flamethrower/flammenwerfer/Destroy()
	..()

/obj/item/weapon/flamethrower/flammenwerfer/afterattack(atom/target, mob/user, proximity)
	if (!proximity) return
	// Make sure our user is still holding us
	if (user && user.get_active_hand() == src)
		var/turf/target_turf = get_turf(target)
		if (target_turf)
			var/turflist = getturfsbetween(user, target_turf) | list(target_turf)
			flame_turfs(turflist, get_dir(get_turf(user), target_turf))

/obj/item/weapon/flamethrower/flammenwerfer/process()
	if (!lit)
		processing_objects.Remove(src)
		return null
	var/turf/location = loc
	if (istype(location, /mob/))
		var/mob/M = location
		if (M.l_hand == src || M.r_hand == src)
			location = M.loc
	// made this stop starting fires where we are standing. fuck.
	return

// this has better range checking so we don't burn/overheat ourselves
/obj/item/weapon/flamethrower/flammenwerfer/flame_turfs(turflist, var/flamedir)

	var/turf/my_turf = get_turf(loc)

	if (!lit || operating)	return

	var/mob/living/carbon/human/my_mob = loc

	if (!my_mob || !istype(my_mob) || src != my_mob.get_active_hand())
		return

	if (!fueltank || fullness_percentage() <= 0.01)
		my_mob << "<span class = 'warning'>Out of fuel!</span>"
		return

	if (my_mob.back != backpack || !my_mob.back || !backpack)
		my_mob << "<span class = 'danger'>Put the backpack on first.</span>"
		return

	operating = TRUE
	playsound(my_turf, 'sound/weapons/flamethrower.ogg', 100, TRUE)

	var/list/blocking_turfs = list()

	for (var/turf/T in turflist)

		if (T == my_turf)
			continue

		switch (my_mob.dir)
			if (EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
				if (abs(my_turf.x - T.x) > rwidth || abs(my_turf.y - T.y) > rheight)
					continue
			if (NORTH, SOUTH)
				if (abs(my_turf.x - T.x) > rheight || abs(my_turf.y - T.y) > rwidth)
					continue

		// higher temperature = less missed turfs
		if (T != get_step(my_turf, my_mob.dir) && prob((get_dist(my_turf, T)+10)/get_temperature_coeff()))
			continue

		if (T.density)
			blocking_turfs += T
		else
			for (var/obj/structure/S in T.contents)
				if (S.density && !S.low && !S.throwpass)
					blocking_turfs += T
					break

		if (blocking_turfs.Find(T))
			continue

		for (var/turf/TT in blocking_turfs)
			if (get_step(TT, my_mob.dir) == T)
				continue

		if (my_turf)
			if (T.x <= my_turf.x)
				if (flamedir == EAST || flamedir == NORTHEAST || flamedir == SOUTHEAST)
					continue
			else if (T.x >= my_turf.x)
				if (flamedir == WEST || flamedir == NORTHWEST || flamedir == SOUTHWEST)
					continue
			else if (T.y >= my_turf.y)
				if (flamedir == NORTH || flamedir == NORTHEAST || flamedir == NORTHWEST)
					continue
			else if (T.y <= my_turf.y)
				if (flamedir == SOUTH || flamedir == SOUTHEAST || flamedir == SOUTHWEST)
					continue

		if (fueltank <= 0.00)
			break

		spawn (get_dist(my_turf, T))
			ignite_turf(T, flamedir)
		// we run out of fuel after flamming 4000 turfs (on min fuel)
		fueltank -= (1/4000) * get_temperature_coeff()
		fueltank = max(fueltank, 0.00)

	previousturf = null
	operating = FALSE
	for (var/mob/M in viewers(1, loc))
		if ((M.client && M.using_object == src))
			attack_self(M)
	return

/obj/item/weapon/flamethrower/flammenwerfer/attack_self(mob/user as mob)
	if (user.stat || user.restrained() || user.lying)	return
	user.set_using_object(src)
	if (!ptank)
		user << "<span class='notice'>Attach a plasma tank first!</span>"
		return
	var/dat = text({"<TT><b>Das Flammenwerfer (<a href='?src=\ref[src];light=1'>[lit ? "<font color='red'>Lit</font>" : "Unlit"]</a>)</b><BR>\n
	Fullness: [fullness_percentage()]%<BR>\n
	Amount to throw: <A HREF='?src=\ref[src];amount=-100'>-</A> <A HREF='?src=\ref[src];amount=-10'>-</A> <A HREF='?src=\ref[src];amount=-1'>-</A> [throw_amount] <A HREF='?src=\ref[src];amount=1'>+</A> <A HREF='?src=\ref[src];amount=10'>+</A> <A HREF='?src=\ref[src];amount=100'>+</A><BR>\n
	Fire Width ([rwidth]): <A HREF='?src=\ref[src];rwidth=-1'>-</A> <A HREF='?src=\ref[src];rwidth=+1'>+</A>
	Fire Height ([rheight]): <A HREF='?src=\ref[src];rheight=-1'>-</A> <A HREF='?src=\ref[src];rheight=+1'>+</A>
	<br>
	<A HREF='?src=\ref[src];close=1'>Close</A></TT>"})
	user << browse(dat, "window=flamethrower;size=600x300")
	onclose(user, "flamethrower")
	return

/obj/item/weapon/flamethrower/flammenwerfer/proc/fullness_percentage()
	return round(fueltank * 100)

/obj/item/weapon/flamethrower/flammenwerfer/Topic(href,href_list[])
	if (href_list["close"])
		usr.unset_using_object()
		usr << browse(null, "window=flamethrower")
		return
	if (usr.stat || usr.restrained() || usr.lying)	return
	usr.set_using_object(src)
	if (href_list["light"])
		if (fueltank <= 0) return
		if (!status)	return
		lit = !lit
		if (lit)
			processing_objects.Add(src)
	if (href_list["amount"])
		throw_amount = throw_amount + text2num(href_list["amount"])
		throw_amount = max(50, min(5000, throw_amount))
	if (href_list["rwidth"])
		var/mod = text2num(href_list["rwidth"])
		if (rwidth + mod + rheight > max_total_range)
			usr << "<span class = 'danger'>To increase the width of the fire any more, you have to decrease the height of the fire.</span>"
			return
		rwidth = rwidth + mod
		rwidth = Clamp(rwidth, 1, 7)
	if (href_list["rheight"])
		var/mod = text2num(href_list["rheight"])
		if (rheight + mod + rwidth > max_total_range)
			usr << "<span class = 'danger'>To increase the height of the fire any more, you have to decrease the width of the fire.</span>"
			return
		rheight = rheight + mod
		rheight = Clamp(rheight, 1, 3)

	// refresh
	for (var/mob/M in viewers(1, loc))
		if ((M.client && M.using_object == src))
			attack_self(M)

	update_icon()
	return

// how much fuel do we use based on throw_amount
/obj/item/weapon/flamethrower/flammenwerfer/proc/get_temperature_coeff()
	return 1.0 + (throw_amount-100)/100

// what is the multiplier put on our fire's heat based on throw_amount
// you will notice that the most efficient throw_amount is the default one,
// and at throw amounts > 700 its downright inefficient as the fire barely gets hotter
/obj/item/weapon/flamethrower/flammenwerfer/proc/get_heat_coeff()
	. = 1.0
	. += ((throw_amount-100)/100)/3
	. = min(., 3.0) // don't get too hot
	. += ((throw_amount-100)/100)/20 // give us a bit of extra heat if we're super high
	// for example, 200 throw amount = 1.38x
	// 500 = 2.53x
	// 700 = 3.3x
	// 1500 = 3.7x

/obj/item/weapon/flamethrower/flammenwerfer/ignite_turf(turf/target, flamedir)
	var/throw_coeff = get_heat_coeff()
	var/dist_coeff = 1.0

	switch (get_dist(get_turf(src), target))
		if (0 to 5)
			dist_coeff = 1.00
		if (5 to 10)
			dist_coeff = 1.50 // the center is hottest I guess - Kachnov
		if (10 to INFINITY)
			dist_coeff = 1.00

	var/time_limit = pick(20,30,40)

	var/extra_temp = 0

	for (var/obj/fire/F in get_turf(src))
		extra_temp += ((F.temperature / 100) * rand(15,25))
		time_limit += pick(10,20)
		qdel(F)

	var/temperature = (rand(500,600) * throw_coeff * dist_coeff) + extra_temp
//	log_debug("1: [temperature];[throw_coeff];[dist_coeff];[extra_temp]")
	target.create_fire(5, temperature, FALSE, time_limit)