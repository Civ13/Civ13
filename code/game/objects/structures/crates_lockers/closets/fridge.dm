
/obj/structure/closet/fridge
	name = "refrigerator"
	icon_state = "fridge1"
	icon_closed = "fridge"
	icon_opened = "fridgeopen"
	storage_capacity = MOB_MEDIUM
	powerneeded = 5
	not_movable = FALSE
	anchored = TRUE
	health = 3000

/obj/structure/closet/fridge/update_icon()
	if (!opened)
		icon_state = icon_closed
	else
		icon_state = icon_opened

/obj/structure/closet/fridge/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		if (powersource)
			user << "<span class='notice'>Remove the cables first.</span>"
			return
		visible_message("<span class='warning'>[user] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
		playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (do_after(user,50,src))
			visible_message("<span class='warning'>[user] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
			anchored = !anchored
			return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		if (!powersource)
			return
		powersource.connections += src
		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					user << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
		user << "You connect the cable to the [src]."
	else
		..()

/obj/structure/closet/fridge/icebox
	name = "ice box"
	powerneeded = 0

/obj/structure/closet/fridge/icecreamcooler
	name = "icecream cooler"
	icon_state = "icecream_cooler1"
	icon_closed = "icecream_cooler"
	icon_opened = "icecream_cooler_open"
	powerneeded = 0

/obj/structure/closet/fridge/icecreamcooler/open()
	if (opened)
		return FALSE

	if (!can_open())
		return FALSE

	dump_contents()

	icon_state = icon_opened
	opened = TRUE
	playsound(loc, open_sound, 100, TRUE, -3)
	return TRUE