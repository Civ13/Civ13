//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/obj/structure/closet/crate
	name = "crate"
	desc = "A rectangular steel crate."
	icon = 'icons/obj/storage.dmi'
	icon_state = "crate"
	icon_opened = "crateopen"
	icon_closed = "crate"
	climbable = TRUE
//	mouse_drag_pointer = MOUSE_ACTIVE_POINTER	//???
	var/rigged = FALSE

// climbing crates - Kachnov
/obj/structure/closet/crate/MouseDrop_T(mob/target, mob/user)
	if (!opened)
		var/mob/living/H = user
		if (istype(H) && can_climb(H) && target == user)
			do_climb(target)
		else
			return ..(target, user)
	else
		return ..(target, user)

/obj/structure/closet/crate/can_open()
	return TRUE

/obj/structure/closet/crate/can_close()
	return TRUE

/obj/structure/closet/crate/open()
	if (opened)
		return FALSE
	if (!can_open())
		return FALSE

	playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
	for (var/obj/O in src)
		O.forceMove(get_turf(src))
	icon_state = icon_opened
	opened = TRUE

	if (climbable)
		structure_shaken()
	return TRUE

/obj/structure/closet/crate/close()
	if (!opened)
		return FALSE
	if (!can_close())
		return FALSE

	playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
	var/itemcount = FALSE
	for (var/obj/O in get_turf(src))
		if (itemcount >= storage_capacity)
			break
		if (O.density || O.anchored)
			continue
		if (istype(O, /obj/structure))
			continue
		O.forceMove(src)
		itemcount++

	icon_state = icon_closed
	opened = FALSE
	return TRUE

/obj/structure/closet/crate/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		return TRUE
	return !density

/obj/structure/closet/crate/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (opened)
		return ..()
	else if (istype(W, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/C = W
		if (rigged)
			user << "<span class='notice'>[src] is already rigged!</span>"
			return
		if (C.use(1))
			user  << "<span class='notice'>You rig [src].</span>"
			rigged = TRUE
			return
	else if (istype(W, /obj/item/weapon/wirecutters))
		if (rigged)
			user  << "<span class='notice'>You cut away the wiring.</span>"
			playsound(loc, 'sound/items/Wirecutter.ogg', 100, TRUE)
			rigged = FALSE
			return
	else return attack_hand(user)

/obj/structure/closet/crate/ex_act(severity)
	switch(severity)
		if (1.0)
			for (var/obj/O in contents)
				qdel(O)
			qdel(src)
			return
		if (2.0)
			for (var/obj/O in contents)
				if (prob(50))
					qdel(O)
			qdel(src)
			return
		if (3.0)
			if (prob(50))
				qdel(src)
			return
		else
	return
/*
/obj/structure/closet/crate/secure
	desc = "A secure crate."
	name = "Secure crate"
	icon_state = "securecrate"
	icon_opened = "securecrateopen"
	icon_closed = "securecrate"
	var/redlight = "securecrater"
	var/greenlight = "securecrateg"
	var/sparks = "securecratesparks"
	var/emag = "securecrateemag"
	var/broken = FALSE
	var/locked = TRUE

/obj/structure/closet/crate/secure/New()
	..()
	if (locked)
		overlays.Cut()
		overlays += redlight
	else
		overlays.Cut()
		overlays += greenlight

/obj/structure/closet/crate/secure/can_open()
	return !locked

/obj/structure/closet/crate/secure/proc/togglelock(mob/user as mob)
	if (opened)
		user << "<span class='notice'>Close the crate first.</span>"
		return
	if (broken)
		user << "<span class='warning'>The crate appears to be broken.</span>"
		return
	if (allowed(user))
		set_locked(!locked, user)
	else
		user << "<span class='notice'>Access Denied</span>"

/obj/structure/closet/crate/secure/proc/set_locked(var/newlocked, mob/user = null)
	if (locked == newlocked) return

	locked = newlocked
	if (user)
		for (var/mob/O in viewers(user, 3))
			O.show_message( "<span class='notice'>The crate has been [locked ? null : "un"]locked by [user].</span>", TRUE)
	overlays.Cut()
	overlays += locked ? redlight : greenlight

/obj/structure/closet/crate/secure/verb/verb_togglelock()
	set src in oview(1) // One square distance
	set category = null
	set name = "Toggle Lock"

	if (!usr.canmove || usr.stat || usr.restrained()) // Don't use it if you're not able to! Checks for stuns, ghost and restrain
		return

	if (ishuman(usr))
		add_fingerprint(usr)
		togglelock(usr)
	else
		usr << "<span class='warning'>This mob type can't use this verb.</span>"

/obj/structure/closet/crate/secure/attack_hand(mob/user as mob)
	add_fingerprint(user)
	if (locked)
		togglelock(user)
	else
		toggle(user)

/obj/structure/closet/crate/secure/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (is_type_in_list(W, list(/obj/item/stack/cable_coil, /obj/item/weapon/wirecutters)))
		return ..()
	if (!opened)
		togglelock(user)
		return
	return ..()

/obj/structure/closet/crate/secure/emp_act(severity)
	for (var/obj/O in src)
		O.emp_act(severity)
	if (!broken && !opened  && prob(50/severity))
		if (!locked)
			locked = TRUE
			overlays.Cut()
			overlays += redlight
		else
			overlays.Cut()
			overlays += emag
			overlays += sparks
			spawn(6) overlays -= sparks //Tried lots of stuff but nothing works right. so i have to use this *sadface*
			playsound(loc, 'sound/effects/sparks4.ogg', 75, TRUE)
			locked = FALSE
	if (!opened && prob(20/severity))
		if (!locked)
			open()
		else
			req_access = list()
			req_access += pick(get_all_station_access())
	..()
*/
/obj/structure/closet/crate/plastic
	name = "plastic crate"
	desc = "A rectangular plastic crate."
	icon_state = "plasticcrate"
	icon_opened = "plasticcrateopen"
	icon_closed = "plasticcrate"

/obj/structure/closet/crate/internals
	name = "internals crate"
	desc = "A internals crate."
	icon_state = "o2crate"
	icon_opened = "o2crateopen"
	icon_closed = "o2crate"

/obj/structure/closet/crate/trashcart
	name = "trash cart"
	desc = "A heavy, metal trashcart with wheels."
	icon_state = "trashcart"
	icon_opened = "trashcartopen"
	icon_closed = "trashcart"

/*these aren't needed anymore
/obj/structure/closet/crate/hat
	desc = "A crate filled with Valuable Collector's Hats!."
	name = "Hat Crate"
	icon_state = "crate"
	icon_opened = "crateopen"
	icon_closed = "crate"

/obj/structure/closet/crate/contraband
	name = "Poster crate"
	desc = "A random assortment of posters manufactured by providers NOT listed under Nanotrasen's whitelist."
	icon_state = "crate"
	icon_opened = "crateopen"
	icon_closed = "crate"
*/

/obj/structure/closet/crate/medical
	name = "medical crate"
	desc = "A medical crate."
	icon_state = "medicalcrate"
	icon_opened = "medicalcrateopen"
	icon_closed = "medicalcrate"

/obj/structure/closet/crate/rcd
	name = "\improper RCD crate"
	desc = "A crate with rapid construction device."
	icon_state = "crate"
	icon_opened = "crateopen"
	icon_closed = "crate"

/obj/structure/closet/crate/rcd/New()
	..()
//	new /obj/item/weapon/rcd_ammo(src)
//	new /obj/item/weapon/rcd_ammo(src)
//	new /obj/item/weapon/rcd_ammo(src)
//	new /obj/item/weapon/rcd(src)

/obj/structure/closet/crate/freezer
	name = "freezer"
	desc = "A freezer."
	icon_state = "freezer"
	icon_opened = "freezeropen"
	icon_closed = "freezer"
	var/target_temp = T0C - 40
	var/cooling_power = 40

	return_air()
		var/datum/gas_mixture/gas = (..())
		if (!gas)	return null
		var/datum/gas_mixture/newgas = new/datum/gas_mixture()
		newgas.copy_from(gas)
		if (newgas.temperature <= target_temp)	return

		if ((newgas.temperature - cooling_power) > target_temp)
			newgas.temperature -= cooling_power
		else
			newgas.temperature = target_temp
		return newgas

/obj/structure/closet/crate/freezer/rations //Fpr use in the escape shuttle
	name = "emergency rations"
	desc = "A crate of emergency rations."


/obj/structure/closet/crate/freezer/rations/New()
	..()
	new /obj/item/weapon/reagent_containers/food/snacks/liquidfood(src)
	new /obj/item/weapon/reagent_containers/food/snacks/liquidfood(src)
	new /obj/item/weapon/reagent_containers/food/snacks/liquidfood(src)
	new /obj/item/weapon/reagent_containers/food/snacks/liquidfood(src)

/obj/structure/closet/crate/bin
	name = "large bin"
	desc = "A large bin."
	icon_state = "largebin"
	icon_opened = "largebinopen"
	icon_closed = "largebin"

/obj/structure/closet/crate/radiation
	name = "radioactive gear crate"
	desc = "A crate with a radiation sign on it."
	icon_state = "radiation"
	icon_opened = "radiationopen"
	icon_closed = "radiation"

/obj/structure/closet/crate/radiation/New()
	..()
	new /obj/item/clothing/suit/radiation(src)
	new /obj/item/clothing/head/radiation(src)
	new /obj/item/clothing/suit/radiation(src)
	new /obj/item/clothing/head/radiation(src)
	new /obj/item/clothing/suit/radiation(src)
	new /obj/item/clothing/head/radiation(src)
	new /obj/item/clothing/suit/radiation(src)
	new /obj/item/clothing/head/radiation(src)
/*
/obj/structure/closet/crate/secure/weapon
	name = "weapons crate"
	desc = "A secure weapons crate."
	icon_state = "weaponcrate"
	icon_opened = "weaponcrateopen"
	icon_closed = "weaponcrate"

/obj/structure/closet/crate/secure/plasma
	name = "plasma crate"
	desc = "A secure plasma crate."
	icon_state = "plasmacrate"
	icon_opened = "plasmacrateopen"
	icon_closed = "plasmacrate"

/obj/structure/closet/crate/secure/gear
	name = "gear crate"
	desc = "A secure gear crate."
	icon_state = "secgearcrate"
	icon_opened = "secgearcrateopen"
	icon_closed = "secgearcrate"

/obj/structure/closet/crate/secure/hydrosec
	name = "secure hydroponics crate"
	desc = "A crate with a lock on it, painted in the scheme of the station's botanists."
	icon_state = "hydrosecurecrate"
	icon_opened = "hydrosecurecrateopen"
	icon_closed = "hydrosecurecrate"

/obj/structure/closet/crate/secure/bin
	name = "secure bin"
	desc = "A secure bin."
	icon_state = "largebins"
	icon_opened = "largebinsopen"
	icon_closed = "largebins"
	redlight = "largebinr"
	greenlight = "largebing"
	sparks = "largebinsparks"
	emag = "largebinemag"
*/
/obj/structure/closet/crate/large
	name = "large crate"
	desc = "A hefty metal crate."
	icon = 'icons/obj/storage.dmi'
	icon_state = "largemetal"
	icon_opened = "largemetalopen"
	icon_closed = "largemetal"

/obj/structure/closet/crate/large/close()
	. = ..()
	if (.)//we can hold up to one large item
		for (var/obj/structure/S in loc)
			if (S == src)
				continue
			if (!S.anchored)
				S.forceMove(src)
				break
	return
/*
/obj/structure/closet/crate/secure/large
	name = "large crate"
	desc = "A hefty metal crate with an electronic locking system."
	icon = 'icons/obj/storage.dmi'
	icon_state = "largemetal"
	icon_opened = "largemetalopen"
	icon_closed = "largemetal"
	redlight = "largemetalr"
	greenlight = "largemetalg"

/obj/structure/closet/crate/secure/large/close()
	. = ..()
	if (.)//we can hold up to one large item
		var/found = FALSE
		for (var/obj/structure/S in loc)
			if (S == src)
				continue
			if (!S.anchored)
				found = TRUE
				S.forceMove(src)
				break
		if (!found)
			for (var/obj/machinery/M in loc)
				if (!M.anchored)
					M.forceMove(src)
					break
	return

//fluff variant
/obj/structure/closet/crate/secure/large/reinforced
	desc = "A hefty, reinforced metal crate with an electronic locking system."
	icon_state = "largermetal"
	icon_opened = "largermetalopen"
	icon_closed = "largermetal"
*/
/obj/structure/closet/crate/hydroponics
	name = "hydroponics crate"
	desc = "All you need to destroy those pesky weeds and pests."
	icon_state = "hydrocrate"
	icon_opened = "hydrocrateopen"
	icon_closed = "hydrocrate"

/obj/structure/closet/crate/hydroponics/prespawned
	//This exists so the prespawned hydro crates spawn with their contents.

	New()
		..()
		new /obj/item/weapon/reagent_containers/spray/plantbgone(src)
		new /obj/item/weapon/reagent_containers/spray/plantbgone(src)
		new /obj/item/weapon/material/minihoe(src)
//		new /obj/item/weapon/weedspray(src)
//		new /obj/item/weapon/weedspray(src)
//		new /obj/item/weapon/pestspray(src)
//		new /obj/item/weapon/pestspray(src)
//		new /obj/item/weapon/pestspray(src)
