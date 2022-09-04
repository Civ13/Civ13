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
	desc = "Used to keep bodies in until someone fetches them."
	icon = 'icons/obj/morgue.dmi'
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
	icon = 'icons/obj/morgue.dmi'
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

//////////////
// Cremator //
//////////////

/obj/structure/cremator
	name = "cremator"
	desc = "An incinerator designed for cremating human corpses."
	icon = 'icons/obj/morgue.dmi'
	icon_state = "crema1"
	density = TRUE
	var/obj/structure/c_tray/connected = null
	anchored = TRUE
	var/cremating = FALSE
	var/id = TRUE
	var/locked = FALSE

/obj/structure/cremator/Destroy()
	if (connected)
		qdel(connected)
		connected = null
	return ..()

/obj/structure/cremator/proc/update()
	if (cremating)
		icon_state = "crema_active"
	else if (src.connected)
		src.icon_state = "crema0"
	else if (contents.len)
		src.icon_state = "crema2"
	else
		icon_state = "crema1"

/obj/structure/cremator/ex_act(severity)
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

/obj/structure/cremator/attack_hand(mob/user as mob)
	if (cremating)
		usr << "<span class='warning'>It's locked.</span>"
		return
	if ((src.connected) && (src.locked == FALSE))
		for (var/atom/movable/A as mob|obj in src.connected.loc)
			if (!( A.anchored ))
				A.forceMove(src)
		playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		src.connected = null
		qdel(connected)
	else if (src.locked == FALSE)
		playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, TRUE)
		src.connected = new /obj/structure/c_tray(src.loc)
		step(src.connected, dir)
		connected.layer = OBJ_LAYER
		var/turf/T = get_step(src, dir)
		if (T.contents.Find(src.connected))
			src.connected.connected = src
			src.icon_state = "crema0"
			for (var/atom/movable/A as mob|obj in src)
				A.forceMove(connected.loc)
			src.connected.icon_state = "cremat"
		else
			qdel(connected)
			src.connected = null
	add_fingerprint(user)
	update()

/obj/structure/cremator/attackby(P as obj, mob/user as mob)
	if (istype(P, /obj/item/weapon/pen))
		var/t = WWinput(user, "What would you like the label to be?", text("[]", name), null, "text")
		if (user.get_active_hand() != P)
			return
		if ((!in_range(src, usr) > 1 && loc != user))
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if (t)
			name = text("cremator - '[]'", t)
		else
			name = "cremator"
	add_fingerprint(user)
	return

/obj/structure/cremator/relaymove(mob/user as mob)
	if (user.stat || locked)
		return
	src.connected = new /obj/structure/c_tray( loc )
	step(src.connected, SOUTH)
	connected.layer = OBJ_LAYER
	var/turf/T = get_step(src, SOUTH)
	if (T.contents.Find(connected))
		src.connected.connected = src
		src.icon_state = "crema0"
		for (var/atom/movable/A as mob|obj in src)
			A.forceMove(connected.loc)
	else
		qdel(src.connected)
		src.connected = null
	return

/obj/structure/cremator/proc/cremate(atom/A, mob/user as mob)
	if (cremating)
		return //Doesn't let you cremate something twice.
	if (contents.len <= 0)
		for (var/mob/M in viewers(src))
			M.show_message("<span class='warning'>You hear a hollow crackle.</span>", TRUE)
			return
	else
		for (var/mob/M in viewers(src))
			M.show_message("<span class='warning'>You hear a roar as the cremator activates.</span>", TRUE)
		cremating = TRUE
		locked = TRUE
		update()
		for (var/mob/living/M in contents)
			admin_attack_log(A, M, "Began cremating their victim.", "Has begun being cremated.", "began cremating")
			if (isliving(M))
				var/mob/living/L = M
				for(var/I, I < 60, I++)
					L.bodytemperature += 50
					L.adjustFireLoss(20)
					L.adjustBrainLoss(5)
					if(L.stat == DEAD || !(L in contents)) //In case we die or are removed at any point.
						cremating = 0
						update()
						break
					sleep(30)
					L.emote("scream")
			if(M.stat == DEAD)
				admin_attack_log(A, M, "Cremated their victim.", "Was cremated.", "cremated alive")
				M.audible_message("[M]'s screams cease, as does any movement within the [src]. All that remains is a dull, empty silence.")
				qdel(M)
		for (var/obj/O in contents) //obj instead of obj/item so that bodybags and ashes get destroyed. We dont want tons and tons of ash piling up
			qdel(O)
		new /obj/effect/decal/cleanable/ash(src)
		sleep(30)
		cremating = FALSE
		locked = FALSE
		update()
		playsound(loc, 'sound/machines/crema.ogg', 70, TRUE)
	return

/*
 * Cremator tray
 */

/obj/structure/c_tray
	name = "cremator tray"
	desc = "Apply body before burning."
	icon = 'icons/obj/morgue.dmi'
	icon_state = "cremat"
	density = TRUE
	layer = 2.0
	var/obj/structure/cremator/connected = null
	anchored = TRUE
	throwpass = TRUE

/obj/structure/c_tray/Destroy()
	if (connected && connected.connected == src)
		connected.connected = null
	connected = null
	return ..()

/obj/structure/c_tray/attack_hand(mob/user as mob)
	if (src.connected)
		for (var/atom/movable/A as mob|obj in src.loc)
			if (!( A.anchored ))
				A.forceMove(src.connected)
		src.connected.connected = null
		src.connected.update()
		add_fingerprint(user)
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
	return

//Cremator button//

/obj/structure/button/cremator
	name = "cremator igniter"
	desc = "Burn baby burn!"
	icon = 'icons/obj/morgue.dmi'
	icon_state = "crema_switch"
	anchored = TRUE

/obj/structure/button/cremator/update_icon()
	return
/obj/structure/button/cremator/attack_hand(mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	add_fingerprint(user)
	for (var/obj/structure/cremator/C in range(8,src))
		if (!C.cremating)
			C.cremate(user)
	..()

/obj/structure/autopsy_table
	name = "autopsy table"
	desc = "A stationary table designed to hold cadavers during autopsy procedures."
	icon = 'icons/obj/morgue.dmi'
	icon_state = "autopsy_table"
	anchored = TRUE
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = TRUE
	not_movable = FALSE
	density = FALSE
	opacity = FALSE
	not_disassemblable = TRUE