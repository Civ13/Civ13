/* a fuel slot. It's an object. You put fuel tanks in it. */

/obj/plane_part/plane_fuelslot
	anchored = TRUE
	icon = null
	icon_state = null
	layer = MOB_LAYER - 0.01
	var/screwed = TRUE
	var/open = FALSE
	var/fuel = 750
	var/max_fuel = 750
	var/locked = TRUE
	var/datum/plane/master = null

/obj/plane_part/plane_fuelslot/New(_master)
	..()
	master = _master
	if (!master)
		qdel(src)
		return

/obj/plane_part/plane_fuelslot/attack_hand(var/mob/user as mob)

	if (!ishuman(user))
		return FALSE

	if (open)
		plane_message("<span class = 'danger'>[user] closes [my_name()]'s fuel slot.</span>")
		open = FALSE
		return TRUE
	else
		return ..()

/obj/plane_part/plane_fuelslot/attackby(var/obj/item/weapon/W, var/mob/user as mob)

	if (!istype(W))
		return FALSE
	else if (istype(W, /obj/item/weapon/vehicle_fueltank))
		if (open)
			refuel(W, user)
			return TRUE
		else
			user << "<span class = 'danger'>Open the fuel slot first.</span>"
			return FALSE
	else if (istype(W, /obj/item/weapon/flammenwerfer_fueltank))
		if (open)
			user << "<span class = 'danger'>Wrong kind of fuel.</span>"
		return FALSE
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		var/obj/item/weapon/storage/belt/keychain/kc = W
		//var/list/keylist = kc.keys

		for (var/obj/item/weapon/key/german/command_intermediate/key in kc.keys)
			if(istype(key))
				if (locked == TRUE)
					plane_message("<span class = 'notice'>[user] unlocks [my_name()].</span>")
					locked = FALSE
				else
					plane_message("<span class = 'notice'>[user] locks [my_name()].</span>")
					locked = TRUE
				return FALSE
		for (var/obj/item/weapon/key/soviet/command_intermediate/key in kc.keys)
			if(istype(key))
				if (locked == TRUE)
					plane_message("<span class = 'notice'>[user] unlocks [my_name()].</span>")
					locked = FALSE
				else
					plane_message("<span class = 'notice'>[user] locks [my_name()].</span>")
					locked = TRUE
				return FALSE
		user << "<span class = 'danger'>None of your keys seem to fit!</span>"
		return FALSE
	else if (istype(W, /obj/item/weapon/key/german/command_intermediate) || istype(W, /obj/item/weapon/key/soviet/command_intermediate))
		if (locked == TRUE)
			plane_message("<span class = 'notice'>[user] unlocks [my_name()].</span>")
			locked = FALSE
		else
			plane_message("<span class = 'notice'>[user] locks [my_name()].</span>")
			locked = TRUE
		return FALSE

	if (isplanevalidtool(W))
		if (istype(W, /obj/item/weapon/screwdriver))
			if (prob(50))
				playsound(get_turf(src), 'sound/items/Screwdriver.ogg', rand(75,100))
			else
				playsound(get_turf(src), 'sound/items/Screwdriver2.ogg', rand(75,100))
			screwed = !screwed
			plane_message("<span class = 'notice'>[user] [screwed ? "screws in" : "screws out"] the screw on [my_name()] fuel slot.</span>")
		else if (istype(W, /obj/item/weapon/crowbar))
			if (screwed)
				user << "<span class = 'danger'>Unscrew the fuel slot first.</span>"
			else if (open)
				user << "<span class = 'notice'>It's already open.</span>"
			else
				open = TRUE
				plane_message("<span class = 'notice'>[user] crowbars open [my_name()] fuel slot.</span>")
	else
		return FALSE
	return TRUE

/obj/plane_part/plane_fuelslot/proc/refuel(var/obj/item/weapon/vehicle_fueltank/ftank, var/mob/user as mob)
	plane_message("[user] refuels [my_name()] with [ftank].")
	qdel(ftank)
	fuel = max_fuel