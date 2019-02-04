
///////////////////////////////////////////////
// The cable coil object, used for laying cable
///////////////////////////////////////////////

////////////////////////////////
// Definitions
////////////////////////////////

/obj/item/stack/cable_coil
	name = "cable coil"
	gender = NEUTER //That's a cable coil sounds better than that's some cable coils
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "coil"
	item_state = "coil"
	max_amount = 50
	amount = 10
	var/cable_color = "red"
	desc = "A coil of insulated power cable."
	throwforce = 0
	w_class = 2
	throw_speed = 3
	throw_range = 5
	slot_flags = SLOT_BELT
	attack_verb = list("whipped", "lashed", "disciplined", "flogged")
	singular_name = "cable piece"
	w_class = 2
	var/usesound = 'sound/items/deconstruct.ogg'

/obj/item/stack/cable_coil/New()
	..()
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()

/obj/item/connector
	name = "cable connector"
	desc = "a cable connector, used to merge or split cables."
	w_class = 1
	layer = 3.92
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "connector"
	var/list/connections = list()
	var/list/turflist = list()
/obj/item/connector/attack_self(mob/user)
	for(var/obj/structure/cable/CL in get_turf(user))
		turflist += CL
	for(var/obj/structure/cable/CLC in turflist)
		for(var/obj/structure/cable/CLD in turflist)
			if (!(CLD in CLC.connections) && CLC != CLD)
				CLC.connections += CLD
	user.drop_from_inventory(src)
	anchored = TRUE
	user << "You connect the cables on this tile."
	return
///////////////////////////////////
// General procedures
///////////////////////////////////


/obj/item/stack/cable_coil/update_icon()
	icon_state = "[initial(item_state)][amount < 3 ? amount : ""]"
	name = "cable [amount < 3 ? "piece" : "coil"]"

/obj/item/stack/cable_coil/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	var/obj/item/stack/cable_coil/new_cable = ..()
	if(istype(new_cable))
		new_cable.cable_color = cable_color
		new_cable.update_icon()

/obj/item/stack/cable_coil/attack_self(mob/user)
	place_turf(get_turf(user),user,get_dir(get_turf(user), user))

///////////////////////////////////////////////
// Cable laying procedures
//////////////////////////////////////////////

// called when cable_coil is placed on a turf
/obj/item/stack/cable_coil/proc/place_turf(turf/T, mob/user, dirnew)
	if(!isturf(user.loc))
		return

	if(!isturf(T))
		user << "<span class='warning'>You can't lay a cable here!"
		return

	if(get_amount() < 1) // Out of cable
		user << "<span class='warning'>There is no cable left!</span>"
		return

	if(get_dist(T,user) > 1) // Too far
		user << "<span class='warning'>You can't lay cable at a place that far away!</span>"
		return

	var/dirn
	if(!dirnew) //If we weren't given a direction, come up with one!
		if(user.loc == T)
			dirn = user.dir //If laying on the tile we're on, lay in the direction we're facing
		else
			dirn = get_dir(T, user)
	else
		dirn = dirnew

	for(var/obj/structure/cable/LC in T)
		if(LC.d2 == dirn && LC.d1 == 0)
			user << "<span class='warning'>There's already a cable at that position!</span>"
			return

	var/obj/structure/cable/C = new /obj/structure/cable(T)
	C.color = color
	C.cable_color = cable_color
	amount -= 1
	C.d1 = 0 //it's a O-X node cable
	C.d2 = dirn
	C.add_fingerprint(user)
	var/opdir = 1
	if (dirn == 1)
		opdir = 2
	else if (dirn == 2)
		opdir = 1
	else if (dirn == 4)
		opdir = 8
	else if (dirn == 5)
		opdir = 10
	else if (dirn == 6)
		opdir = 9
	else if (dirn == 8)
		opdir = 4
	else if (dirn == 9)
		opdir = 6
	else if (dirn == 10)
		opdir = 5
	C.update_icon()
	for(var/obj/structure/cable/NCO in get_turf(C))
		if (NCO.d2 == dirn || NCO.d2 == opdir && NCO != C)
			NCO.connections += C
			C.connections += NCO
//			user << "You connect the two cables."
	for(var/obj/structure/cable/NCOO in get_turf(get_dir(C,dirn)))
		if (NCOO.d2 == opdir && NCOO != C)
			NCOO.connections += C
			C.connections += NCOO
			user << "You connect the two cables."
	for(var/obj/structure/cable/NCOC in get_turf(get_dir(C,opdir)))
		if (NCOC.d2 == dirn && NCOC != C)
			NCOC.connections += C
			C.connections += NCOC
			user << "You connect the two cables."
	return C

// called when cable_coil is click on an installed obj/cable
// or click on a turf that already contains a "node" cable
/obj/item/stack/cable_coil/proc/cable_join(obj/structure/cable/C, mob/user, var/showerror = TRUE)
	var/turf/U = user.loc
	if(!isturf(U))
		return

	var/turf/T = C.loc

	if(!isturf(T))		// sanity checks
		return

	if(get_dist(C, user) > 1)		// make sure it's close enough
		user << "<span class='warning'>You can't lay cable at a place that far away!</span>"
		return


	if(U == T) //if clicked on the turf we're standing on, try to put a cable in the direction we're facing
		place_turf(T,user)
		return

	var/dirn = get_dir(C, user)

	// one end of the clicked cable is pointing towards us
	if(C.d1 == dirn || C.d2 == dirn)
		if(!isturf(U))
			user << "<span class='warning'>You can't lay a cable here!"
			return
		else
			// cable is pointing at us, we're standing on an open tile
			// so create a stub pointing at the clicked cable on our tile

			var/fdirn = turn(dirn, 180)		// the opposite direction

			for(var/obj/structure/cable/LC in U)		// check to make sure there's not a cable there already
				if(LC.d1 == fdirn || LC.d2 == fdirn)
					if (showerror)
						user << "<span class='warning'>There's already a cable at that position!</span>"
					return

			var/obj/structure/cable/NC = new /obj/structure/cable(U)
			amount -= 1
			NC.color = C.color
			NC.cable_color = C.cable_color
			NC.d1 = 0
			NC.d2 = fdirn
			NC.add_fingerprint(user)
			NC.connections += C
			C.connections += NC
			NC.update_icon()
			C.update_icon()
			return

	// exisiting cable doesn't point at our position, so see if it's a stub
	else if(C.d1 == 0)
							// if so, make it a full cable pointing from it's old direction to our dirn
		var/nd1 = C.d2	// these will be the new directions
		var/nd2 = dirn


		if(nd1 > nd2)		// swap directions to match icons/states
			nd1 = dirn
			nd2 = C.d2


		for(var/obj/structure/cable/LC in T)		// check to make sure there's no matching cable
			if(LC == C)			// skip the cable we're interacting with
				continue
			if((LC.d1 == nd1 && LC.d2 == nd2) || (LC.d1 == nd2 && LC.d2 == nd1) )	// make sure no cable matches either direction
				if (showerror)
					user <<"<span class='warning'>There's already a cable at that position!</span>"

				return


		C.update_icon()

		C.d1 = nd1
		C.d2 = nd2

		//updates the stored cable coil
		C.update_stored(2, cable_color)

		C.add_fingerprint(user)
		C.update_icon()
		return

//////////////////////////////
// Misc.
/////////////////////////////

/obj/item/stack/cable_coil/red
	cable_color = "red"
	color = "#ff0000"

/obj/item/stack/cable_coil/yellow
	cable_color = "yellow"
	color = "#ffff00"

/obj/item/stack/cable_coil/blue
	cable_color = "blue"
	color = "#1919c8"

/obj/item/stack/cable_coil/green
	cable_color = "green"
	color = "#00aa00"

/obj/item/stack/cable_coil/pink
	cable_color = "pink"
	color = "#ff3ccd"

/obj/item/stack/cable_coil/orange
	cable_color = "orange"
	color = "#ff8000"

/obj/item/stack/cable_coil/cyan
	cable_color = "cyan"
	color = "#00ffff"

/obj/item/stack/cable_coil/white
	cable_color = "white"

/obj/item/stack/cable_coil/random
	cable_color = null
	color = "#ffffff"
/obj/item/stack/cable_coil/random/New()
	..()
	cable_color = pick(cable_colors)
	for(var/i in cable_colors)
		if (i == cable_color)
			color = cable_colors[2]

/obj/item/stack/cable_coil/random/five
	amount = 5

/obj/item/stack/cable_coil/cut
	amount = null
	icon_state = "coil2"

/obj/item/stack/cable_coil/cut/New()
	..()
	if(!amount)
		amount = rand(1,2)
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()

/obj/item/stack/cable_coil/cut/red
	cable_color = "red"
	color = "#ff0000"

/obj/item/stack/cable_coil/cut/yellow
	cable_color = "yellow"
	color = "#ffff00"

/obj/item/stack/cable_coil/cut/blue
	cable_color = "blue"
	color = "#1919c8"

/obj/item/stack/cable_coil/cut/green
	cable_color = "green"
	color = "#00aa00"

/obj/item/stack/cable_coil/cut/pink
	cable_color = "pink"
	color = "#ff3ccd"

/obj/item/stack/cable_coil/cut/orange
	cable_color = "orange"
	color = "#ff8000"

/obj/item/stack/cable_coil/cut/cyan
	cable_color = "cyan"
	color = "#00ffff"

/obj/item/stack/cable_coil/cut/white
	cable_color = "white"

/obj/item/stack/cable_coil/cut/random
	cable_color = null
	color = "#ffffff"

/obj/item/stack/cable_coil/cut/random/New()
	..()
	cable_color = pick(cable_colors)
	for(var/i in cable_colors)
		if (i == cable_color)
			color = cable_colors[2]