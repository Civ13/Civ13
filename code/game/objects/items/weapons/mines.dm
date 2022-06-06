
//*****************************
//MINES
//*****************************
/obj/item/mine
	name = "proximity mine"
	desc = "An anti-personnel mine. Useful for setting traps or for area denial. "
	icon = 'icons/obj/grenade.dmi'
	icon_state = "mine"
	force = 5.0
	w_class = 2.0
	layer = OBJ_LAYER + 0.01 //because they go in crates
	throwforce = 5.0
	throw_range = 6
	throw_speed = 3
	anchored = FALSE
	flags = CONDUCT
	var/triggered = FALSE
	var/triggertype = "explosive" //Calls that proc
	/*
		"explosive"
		//"incendiary" //New bay//
	*/

	// failsafe to stop a horrible mine bug - kachnov
	var/nextCanExplode = -1

//Arming
/obj/item/mine/attack_self(mob/living/user as mob)
	if (locate(/obj/item/mine) in get_turf(src))
		src << "There's already a mine at this position!"
		return

	if (!anchored)
		user.visible_message("<span class = 'notice'>\The [user] starts to deploy the \the [src].</span>")
		if (!do_after(user,rand(30,40)))
			user.visible_message("<span class = 'notice'>\The [user] decides not to deploy the \the [src].</span>")
			return
		nextCanExplode = world.time + 5
		user.visible_message("<span class = 'notice'>\The [user] finishes deploying the \the [src].</span>")
		anchored = TRUE
		layer = TURF_LAYER + 0.01
		icon_state = "mine_armed"
		user.drop_item()
		return

//Disarming
/obj/item/mine/attackby(obj/item/W as obj, mob/user as mob)
	if (anchored)
		if (ishuman(user))
			var/mob/living/human/H = user
			if (istype(W, /obj/item/weapon/wirecutters))
				user.visible_message("<span class = 'notice'>\The [user] starts to disarm the \the [src] with the [W].</span>")
				if (!do_after(user,60))
					user.visible_message("<span class = 'notice'>\The [user] decides not to disarm the \the [src].</span>")
					return
				if (prob(min(95*H.getStatCoeff("dexterity"),100)))
					user.visible_message("<span class = 'notice'>\The [user] finishes disarming the \the [src]!</span>")
					anchored = FALSE
					icon_state = "mine"
					layer = initial(layer)
					return
				else
					Bumped(user)
			else if (istype(W, /obj/item/weapon/material/knife))
				user.visible_message("<span class = 'notice'>\The [user] starts to disarm the \the [src] with the [W].</span>")
				if (!do_after(user,80))
					user.visible_message("<span class = 'notice'>\The [user] decides not to disarm the \the [src].</span>")
					return
				if (prob(min(50*H.getStatCoeff("dexterity"),75)))
					user.visible_message("<span class = 'notice'>\The [user] finishes disarming the \the [src]!</span>")
					anchored = FALSE
					icon_state = "mine"
					layer = initial(layer)
					return
				else
					Bumped(user)
			else
				Bumped(user)
		else
			Bumped(user)

/obj/item/mine/attack_hand(mob/user as mob)
	if (anchored)
		if (ishuman(user))
			var/mob/living/human/H = user
			user.visible_message("<span class = 'notice'>\The [user] starts to dig around the \the [src] with their bare hands!</span>")
			if (!do_after(user,100))
				user.visible_message("<span class = 'notice'>\The [user] decides not to dig up the \the [src].</span>")
				return
			if (prob(min(15*H.getStatCoeff("dexterity"),35)))
				user.visible_message("<span class = 'notice'>\The [user] finishes digging up the \the [src], disarming it!</span>")
				anchored = FALSE
				icon_state = "mine"
				layer = initial(layer)
				return
			else
				Bumped(user)
		else
			Bumped(user)
	else
		..()

//Triggering
/obj/item/mine/Crossed(AM as mob|obj)
	if (isobserver(AM)) return
	if (istype(AM, /obj/item/projectile)) return
	if (istype(AM, /mob/living))
		var/mob/living/AMM = AM
		if (AMM.mob_size <= MOB_SMALL) return
	Bumped(AM)


/obj/item/mine/Bumped(AM as mob|obj)
	if (isobserver(AM)) return
	if (!anchored) return //If armed
	if (triggered) return
	if (istype(AM, /mob/living))
		var/mob/living/AMM = AM
		if (AMM.mob_size <= MOB_SMALL) return
	trigger(AM)

/obj/item/mine/proc/trigger(atom/movable/AM)
	if (world.time < nextCanExplode)
		return
	if (istype(AM, /mob/living))
		for (var/mob/O in viewers(7, loc))
			O << "<font color='red'>[AM] triggered the [src]!</font>"
		triggered = TRUE
		visible_message("<span class = 'red'><b>Click!</b></span>")
		explosion(get_turf(src),2,2,6)
		spawn(9)
			if (src)
				qdel(src)

//TYPES//
//Explosive
/obj/item/mine/proc/explosive(obj)
	explosion(loc,2,2,4)
	spawn(0)
		qdel(src)

/obj/item/mine/ap
	name = "anti-personnel mine"
	desc = "Useful for setting traps or for area denial."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "mine"
	force = 10.0
	w_class = 2.0
	throwforce = 5.0
	throw_range = 6
	throw_speed = 3
	anchored = FALSE

/obj/item/mine/ap/armed
	anchored = TRUE
	layer = TURF_LAYER + 0.01
	icon_state = "mine_armed"

/obj/item/mine/ap/armed/New()
	if (map.ID == MAP_HUNGERGAMES && processes.ticker.playtime_elapsed > 1800)
		qdel(src)

/obj/item/mine/at
	name = "anti-tank mine"
	desc = "Useful for setting traps or for area denial."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "mine"
	force = 12.0
	w_class = 4.0
	throwforce = 2.0
	throw_range = 3
	throw_speed = 3
	anchored = FALSE
/obj/item/mine/at/armed
	anchored = TRUE
	layer = TURF_LAYER + 0.01
	icon_state = "mine_armed"
	var/origin = null

/obj/item/mine/at/Crossed(AM as mob|obj)
	if (isobserver(AM)) return
	if (istype(AM, /obj/item/projectile)) return
	if (istype(AM, /obj/structure/vehicleparts/frame))
		trigger(AM)


/obj/item/mine/at/Bumped(AM as obj)
	if (isobserver(AM)) return
	if (!anchored) return //If armed
	if (triggered) return
	if (istype(AM, /obj/structure/vehicleparts/frame))
		trigger(AM)

/obj/item/mine/at/trigger(atom/movable/AM)
	for (var/mob/O in viewers(7, loc))
		O << "<font color='red'>[AM] triggered the [src]!</font>"
	triggered = TRUE
	visible_message("<span class = 'red'><b>Click!</b></span>")
	for(var/obj/structure/vehicleparts/frame/F in range(1,src))
		for (var/mob/M in F.axis.transporting)
			shake_camera(M, 4, 4)

		F.w_left[5] -= 25
		F.w_right[5] -= 25
		F.w_front[5] -= 25
		F.w_back[5] -= 25
		F.try_destroy()

		for(var/obj/structure/vehicleparts/movement/MV in F)
			MV.broken = TRUE
			MV.update_icon()
		F.update_icon()
	explosion(get_turf(src),0,0,1,3) // its light since damage is processed separately
	spawn(3)
		if (src)
			qdel(src)
			return TRUE
/obj/item/mine/boobytrap
	name = "booby trap"
	desc = "Useful for setting traps or for area denial."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "boobytrap_armed"
	force = 10.0
	w_class = 2.0
	throwforce = 5.0
	throw_range = 6
	throw_speed = 3
	anchored = TRUE
	var/origin = null

//Disarming
/obj/item/mine/boobytrap/attackby(obj/item/W as obj, mob/user as mob)
	if (anchored)
		if (ishuman(user))
			var/mob/living/human/H = user
			if (istype(W, /obj/item/weapon/wirecutters))
				user.visible_message("<span class = 'notice'>\The [user] starts to disarm the \the [src] with the [W].</span>")
				if (!do_after(user,60))
					user.visible_message("<span class = 'notice'>\The [user] decides not to disarm the \the [src].</span>")
					return
				if (prob(min(95*H.getStatCoeff("dexterity"),100)))
					user.visible_message("<span class = 'notice'>\The [user] finishes disarming the \the [src]!</span>")
					if (origin)
						new origin(get_turf(user))
					qdel(src)
					return
				else
					Bumped(user)
			else if (istype(W, /obj/item/weapon/material/knife))
				user.visible_message("<span class = 'notice'>\The [user] starts to disarm the \the [src] with the [W].</span>")
				if (!do_after(user,80))
					user.visible_message("<span class = 'notice'>\The [user] decides not to disarm the \the [src].</span>")
					return
				if (prob(min(85*H.getStatCoeff("dexterity"),90)))
					user.visible_message("<span class = 'notice'>\The [user] finishes disarming the \the [src]!</span>")
					if (origin)
						new origin(get_turf(user))
					qdel(src)
					return
				else
					Bumped(user)
			else
				Bumped(user)
		else
			Bumped(user)

/obj/item/mine/boobytrap/attack_hand(mob/user as mob)
	if (anchored)
		if (ishuman(user))
			var/mob/living/human/H = user
			user.visible_message("<span class = 'notice'>\The [user] starts to dig around the \the [src] with their bare hands!</span>")
			if (!do_after(user,100))
				user.visible_message("<span class = 'notice'>\The [user] decides not to dig up the \the [src].</span>")
				return
			if (prob(min(60*H.getStatCoeff("dexterity"),85)))
				user.visible_message("<span class = 'notice'>\The [user] finishes digging up the \the [src], disarming it!</span>")
				if (origin)
					new origin(get_turf(user))
				qdel(src)
				return
			else
				Bumped(user)
		else
			Bumped(user)
	else
		..()

/obj/item/mine/boobytrap/trigger(atom/movable/AM)
	if (world.time < nextCanExplode)
		return
	if (istype(AM, /mob/living))
		for (var/mob/O in viewers(7, loc))
			O << "<font color='red'>[AM] triggered the [src]!</font>"
		triggered = TRUE
		visible_message("<span class = 'red'><b>Click!</b></span>")
		explosion(get_turf(src),2,2,4)
		spawn(9)
			if (src)
				qdel(src)
