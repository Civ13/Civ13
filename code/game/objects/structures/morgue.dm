/* Morgue stuff
 * Contains:
 *		Morgue
 *		Morgue trays
 *		Creamatorium
 *		Creamatorium trays
 */

/*
 * Morgue
 */

/obj/structure/morgue
	name = "morgue"
	desc = "Used to keep bodies in untill someone fetches them."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "morgue1"
	dir = EAST
	density = TRUE
	var/obj/structure/m_tray/connected = null
	anchored = 1.0

/obj/structure/morgue/Destroy()
	if (connected)
		qdel(connected)
		connected = null
	return ..()

/obj/structure/morgue/proc/update()
	if (connected)
		icon_state = "morgue0"
	else
		if (contents.len)
			icon_state = "morgue2"
		else
			icon_state = "morgue1"
	return

/obj/structure/morgue/ex_act(severity)
	switch(severity)
		if (1.0)
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(loc)
				ex_act(severity)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
					ex_act(severity)
				qdel(src)
				return
		if (3.0)
			if (prob(5))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
					ex_act(severity)
				qdel(src)
				return
	return

/obj/structure/morgue/attack_hand(mob/user as mob)
	if (connected)
		for (var/atom/movable/A as mob|obj in connected.loc)
			if (!( A.anchored ))
				A.forceMove(src)
		playsound(loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		qdel(connected)
		connected = null
	else
		playsound(loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		connected = new /obj/structure/m_tray( loc )
		step(connected, dir)
		connected.layer = OBJ_LAYER
		var/turf/T = get_step(src, dir)
		if (T.contents.Find(connected))
			connected.connected = src
			icon_state = "morgue0"
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(connected.loc)
			connected.icon_state = "morguet"
			connected.set_dir(dir)
		else
			qdel(connected)
			connected = null
	add_fingerprint(user)
	update()
	return

/obj/structure/morgue/attackby(P as obj, mob/user as mob)
	if (istype(P, /obj/item/weapon/pen))
		var/t = WWinput(user, "What would you like the label to be?", text("[]", name), null, "text")
		if (user.get_active_hand() != P)
			return
		if ((!in_range(src, usr) && loc != user))
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if (t)
			name = text("Morgue- '[]'", t)
		else
			name = "Morgue"
	add_fingerprint(user)
	return

/obj/structure/morgue/relaymove(mob/user as mob)
	if (..(user))
		if (user.stat)
			return
		connected = new /obj/structure/m_tray( loc )
		step(connected, EAST)
		connected.layer = OBJ_LAYER
		var/turf/T = get_step(src, EAST)
		if (T.contents.Find(connected))
			connected.connected = src
			icon_state = "morgue0"
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(connected.loc)
			connected.icon_state = "morguet"
		else
			qdel(connected)
			connected = null
		return


/*
 * Morgue tray
 */
/obj/structure/m_tray
	name = "morgue tray"
	desc = "Apply corpse before closing."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "morguet"
	density = TRUE
	layer = 2.0
	var/obj/structure/morgue/connected = null
	anchored = TRUE
	throwpass = TRUE

/obj/structure/m_tray/Destroy()
	if (connected && connected.connected == src)
		connected.connected = null
	connected = null
	return ..()

/obj/structure/m_tray/attack_hand(mob/user as mob)
	if (connected)
		for (var/atom/movable/A as mob|obj in loc)
			if (!( A.anchored ))
				A.forceMove(connected)
			//Foreach goto(26)
		connected.connected = null
		connected.update()
		add_fingerprint(user)
		//SN src = null
		qdel(src)
		return
	return

/obj/structure/m_tray/MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
	if ((!( istype(O, /atom/movable) ) || O.anchored || get_dist(user, src) > 1 || get_dist(user, O) > 1 || user.contents.Find(src) || user.contents.Find(O)))
		return
	if (!ismob(O) && !istype(O, /obj/structure/closet/body_bag))
		return
	if (!ismob(user) || user.stat || user.lying || user.stunned)
		return
	O.forceMove(loc)
	if (user != O)
		for (var/mob/B in viewers(user, 3))
			if ((B.client && !( B.blinded )))
				B << "<span class='warning'>\The [user] stuffs [O] into [src]!</span>"
	return
/*

/*
 * Crematorium
 */

/obj/structure/crematorium
	name = "crematorium"
	desc = "A human incinerator. Works well on barbeque nights."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "crema1"
	density = TRUE
	var/obj/structure/c_tray/connected = null
	anchored = 1.0
	var/cremating = FALSE
	var/id = TRUE
	var/locked = FALSE
	var/_wifi_id
	var/datum/wifi/receiver/button/crematorium/wifi_receiver

/obj/structure/crematorium/initialize()
	..()
	if (_wifi_id)
		wifi_receiver = new(_wifi_id, src)

/obj/structure/crematorium/Destroy()
	if (connected)
		qdel(connected)
		connected = null
	if (wifi_receiver)
		qdel(wifi_receiver)
		wifi_receiver = null
	return ..()

/obj/structure/crematorium/proc/update()
	if (connected)
		icon_state = "crema0"
	else
		if (contents.len)
			icon_state = "crema2"
		else
			icon_state = "crema1"
	return

/obj/structure/crematorium/ex_act(severity)
	switch(severity)
		if (1.0)
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(loc)
				ex_act(severity)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
					ex_act(severity)
				qdel(src)
				return
		if (3.0)
			if (prob(5))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
					ex_act(severity)
				qdel(src)
				return
	return

/obj/structure/crematorium/attack_hand(mob/user as mob)
//	if (cremating) AWW MAN! THIS WOULD BE SO MUCH MORE FUN ... TO WATCH
//		user.show_message("<span class='warning'>Uh-oh, that was a bad idea.</span>", TRUE)
//		//usr << "Uh-oh, that was a bad idea."
//		src:loc:poison += 20000000
//		src:loc:firelevel = src:loc:poison
//		return
	if (cremating)
		usr << "<span class='warning'>It's locked.</span>"
		return
	if ((connected) && (locked == FALSE))
		for (var/atom/movable/A as mob|obj in connected.loc)
			if (!( A.anchored ))
				A.forceMove(src)
		playsound(loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		//connected = null
		qdel(connected)
	else if (locked == FALSE)
		playsound(loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		connected = new /obj/structure/c_tray( loc )
		step(connected, SOUTH)
		connected.layer = OBJ_LAYER
		var/turf/T = get_step(src, SOUTH)
		if (T.contents.Find(connected))
			connected.connected = src
			icon_state = "crema0"
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(connected.loc)
			connected.icon_state = "cremat"
		else
			//connected = null
			qdel(connected)
	add_fingerprint(user)
	update()

/obj/structure/crematorium/attackby(P as obj, mob/user as mob)
	if (istype(P, /obj/item/weapon/pen))
		var/t = WWinput(user, "What would you like the label to be?", text("[]", name), null, "text")
		if (user.get_active_hand() != P)
			return
		if ((!in_range(src, usr) > 1 && loc != user))
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if (t)
			name = text("Crematorium- '[]'", t)
		else
			name = "Crematorium"
	add_fingerprint(user)
	return

/obj/structure/crematorium/relaymove(mob/user as mob)
	if (..(user))
		if (user.stat || locked)
			return
		connected = new /obj/structure/c_tray( loc )
		step(connected, SOUTH)
		connected.layer = OBJ_LAYER
		var/turf/T = get_step(src, SOUTH)
		if (T.contents.Find(connected))
			connected.connected = src
			icon_state = "crema0"
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(connected.loc)
			connected.icon_state = "cremat"
		else
			qdel(connected)
			connected = null
		return

/obj/structure/crematorium/proc/cremate(atom/A, mob/user as mob)
//	for (var/obj/machinery/crema_switch/O in src) //trying to figure a way to call the switch, too drunk to sort it out atm
//		if (var/on == TRUE)
//		return
	if (cremating)
		return //don't let you cremate something twice or w/e

	if (contents.len <= 0)
		for (var/mob/M in viewers(src))
			M.show_message("<span class='warning'>You hear a hollow crackle.</span>", TRUE)
			return

	else
		if (!isemptylist(search_contents_for (/obj/item/weapon/disk/nuclear)))
			usr << "You get the feeling that you shouldn't cremate one of the items in the cremator."
			return

		for (var/mob/M in viewers(src))
			M.show_message("<span class='warning'>You hear a roar as the crematorium activates.</span>", TRUE)

		cremating = TRUE
		locked = TRUE

		for (var/mob/living/M in contents)
			if (M.stat!=2)
				if (!iscarbon(M))
					M.emote("scream")
				else
					var/mob/living/carbon/C = M
					if (!(C.species && (C.species.flags & NO_PAIN)))
						C.emote("scream")

			//Logging for this causes runtimes resulting in the cremator locking up. Commenting it out until that's figured out.
			//M.attack_log += "\[[time_stamp()]\] Has been cremated by <b>[user]/[user.ckey]</b>" //No point in this when the mob's about to be deleted
			//user.attack_log +="\[[time_stamp()]\] Cremated <b>[M]/[M.ckey]</b>"
			//log_attack("\[[time_stamp()]\] <b>[user]/[user.ckey]</b> cremated <b>[M]/[M.ckey]</b>")
			M.death(1)
			M.ghostize()
			qdel(M)

		for (var/obj/O in contents) //obj instead of obj/item so that bodybags and ashes get destroyed. We dont want tons and tons of ash piling up
			qdel(O)

		new /obj/effect/decal/cleanable/ash(src)
		sleep(30)
		cremating = FALSE
		locked = FALSE
		playsound(loc, 'sound/machines/ding.ogg', 50, TRUE)
	return


/*
 * Crematorium tray
 */
/obj/structure/c_tray
	name = "crematorium tray"
	desc = "Apply body before burning."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "cremat"
	density = TRUE
	layer = 2.0
	var/obj/structure/crematorium/connected = null
	anchored = TRUE
	throwpass = TRUE

/obj/structure/c_tray/Destroy()
	if (connected && connected.connected == src)
		connected.connected = null
	connected = null
	return ..()

/obj/structure/c_tray/attack_hand(mob/user as mob)
	if (connected)
		for (var/atom/movable/A as mob|obj in loc)
			if (!( A.anchored ))
				A.forceMove(connected)
			//Foreach goto(26)
		connected.connected = null
		connected.update()
		add_fingerprint(user)
		//SN src = null
		qdel(src)
		return
	return

/obj/structure/c_tray/MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
	if ((!( istype(O, /atom/movable) ) || O.anchored || get_dist(user, src) > 1 || get_dist(user, O) > 1 || user.contents.Find(src) || user.contents.Find(O)))
		return
	if (!ismob(O) && !istype(O, /obj/structure/closet/body_bag))
		return
	if (!ismob(user) || user.stat || user.lying || user.stunned)
		return
	O.forceMove(loc)
	if (user != O)
		for (var/mob/B in viewers(user, 3))
			if ((B.client && !( B.blinded )))
				B << text("<span class='warning'>[] stuffs [] into []!</span>", user, O, src)
			//Foreach goto(99)
	return

/obj/machinery/button/crematorium
	name = "crematorium igniter"
	desc = "Burn baby burn!"
	icon = 'icons/obj/power.dmi'
	icon_state = "crema_switch"
	req_access = list(access_crematorium)
	id = TRUE

/obj/machinery/button/crematorium/update_icon()
	return

/obj/machinery/button/crematorium/attack_hand(mob/user as mob)
	if (..())
		return
	if (allowed(user))
		for (var/obj/structure/crematorium/C in world)
			if (C.id == id)
				if (!C.cremating)
					C.cremate(user)
	else
		usr << "<span class='warning'>Access denied.</span>"
*/