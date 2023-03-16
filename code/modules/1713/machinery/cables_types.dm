
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
	w_class = ITEM_SIZE_SMALL
	throw_speed = 3
	throw_range = 5
	slot_flags = SLOT_BELT
	attack_verb = list("whipped", "lashed", "disciplined", "flogged")
	singular_name = "cable piece"
	w_class = ITEM_SIZE_SMALL
	var/usesound = 'sound/items/deconstruct.ogg'
	value = 0.25
	flags = CONDUCT
/obj/item/stack/cable_coil/New()
	..()
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()

/obj/item/connector
	name = "cable connector"
	desc = "a cable connector, used to merge or split cables."
	w_class = ITEM_SIZE_TINY
	layer = 3.92
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "connector"
	var/list/connections = list()
	var/list/turflist = list()
	var/tilepos = "over"
	flags = CONDUCT

/obj/item/connector/verb/hiding()
	set category = null
	set name = "Under/Over tiles"
	set src in range(1, usr)

	if (!anchored)
		usr << "Place it first."
		return

	if (tilepos == "over")
		tilepos = "under"
		layer = 1.95
		return

	else if (tilepos == "under")
		tilepos = "over"
		layer = 3.92
		return

/obj/item/connector/attack_self(mob/user)
	for(var/obj/structure/cable/CL in get_turf(user))
		turflist += CL
		CL.connections += src
	for(var/obj/structure/cable/CLC in turflist)
		for(var/obj/structure/cable/CLD in turflist)
			if (!(CLD in CLC.connections) && CLC != CLD)
				CLC.connections += CLD
	user.drop_from_inventory(src)
	anchored = TRUE
	user << "You connect the cables on this tile."
	return
/obj/item/connector/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
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

	if(amount < 1) // Out of cable
		user << "<span class='warning'>There is no cable left!</span>"
		qdel(src)
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
	var/currdir = "horizontal"
	if (dirn == 8 || dirn == 4)
		currdir = "horizontal"
	else if (dirn == 1 || dirn == 2)
		currdir = "vertical"
	for(var/obj/structure/cable/LC in T)
		if(LC.tiledir == currdir)
			user << "<span class='warning'>There's already a cable at that position with the same direction!</span>"
			return

	var/obj/structure/cable/C = new /obj/structure/cable(T)
	C.color = color
	C.cable_color = cable_color
	amount -= 1
	C.d1 = 0 //it's a O-X node cable
	C.d2 = dirn
	C.tiledir = currdir
	C.add_fingerprint(user)
	var/opdir1 = 0
	var/opdir2 = 0
	if (C.tiledir == "horizontal")
		opdir1 = 4
		opdir2 = 8
	else if  (C.tiledir == "vertical")
		opdir1 = 1
		opdir2 = 2
	C.update_icon()

	if (opdir1 != 0 && opdir2 != 0)
		for(var/obj/structure/cable/NCOO in get_turf(get_step(C,opdir1)))
			if ((NCOO.tiledir == C.tiledir) && NCOO != C)
				if (!(C in NCOO.connections) && !list_cmp(C.connections, NCOO.connections))
					NCOO.connections += C
				if (!(NCOO in C.connections) && !list_cmp(C.connections, NCOO.connections))
					C.connections += NCOO
				user << "You connect the two cables."

		for(var/obj/structure/cable/NCOC in get_turf(get_step(C,opdir2)))
			if ((NCOC.tiledir == C.tiledir) && NCOC != C)
				if (!(C in NCOC.connections) && !list_cmp(C.connections, NCOC.connections))
					NCOC.connections += C
				if (!(NCOC in C.connections) && !list_cmp(C.connections, NCOC.connections))
					C.connections += NCOC
				user << "You connect the two cables."
	var/list/turflist = list()
	for(var/obj/structure/cable/CL in get_turf(user))
		turflist += CL
		if (CL != C)
			CL.connections += C
	for(var/obj/structure/cable/CLC in turflist)
		for(var/obj/structure/cable/CLD in turflist)
			if (!(CLD in CLC.connections) && CLC != CLD)
				CLC.connections += CLD
	if (turflist.len > 1)
		user << "You connect the cables on this tile."
	return C

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