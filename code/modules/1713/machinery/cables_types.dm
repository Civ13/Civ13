
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
	desc = "A cable connector, used to merge or split cables."
	w_class = ITEM_SIZE_TINY
	layer = 3.92
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "connector"
	var/list/connections = list()
	var/list/turflist = list()
	var/list/junction_pairs = list()
	var/tilepos = "over"
	flags = CONDUCT

/obj/item/connector/verb/hiding()
	set category = null
	set name = "Under/Over tiles"
	set src in range(1, usr)

	if (!anchored)
		to_chat(usr, "Place it first.")
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
	var/mob/living/human/H = user
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.item_is_in_hands(src) || anchored || !isturf(H.loc))
		return
	for (var/obj/item/connector/other in H.loc)
		if (other != src && other.anchored)
			to_chat(H, "There is already a secured connector here.")
			return
	user.drop_from_inventory(src)
	anchored = TRUE
	connect_cables()
	to_chat(user, "You connect the cables on this tile.")
	return

/obj/item/connector/proc/disconnect_cables()
	var/list/previous = turflist.Copy()
	for (var/list/pair in junction_pairs)
		var/obj/structure/cable/A = pair[1]
		var/obj/structure/cable/B = pair[2]
		if (A)
			A.connections -= B
		if (B)
			B.connections -= A
	for (var/obj/structure/cable/C in previous)
		C.connections -= src
	junction_pairs.Cut()
	turflist.Cut()
	connections.Cut()
	for (var/obj/structure/cable/C in previous)
		C.rebuild_supply()

/obj/item/connector/proc/forget_cable(obj/structure/cable/C)
	for (var/list/pair in junction_pairs.Copy())
		if (C in pair)
			junction_pairs -= list(pair)
	turflist -= C
	connections -= C

/obj/item/connector/proc/connect_cables()
	disconnect_cables()
	if (!anchored || !isturf(loc))
		return
	for (var/obj/structure/cable/C in loc)
		if (turflist.len >= 16)
			return
		turflist |= C
	for (var/i = 1, i <= turflist.len, i++)
		var/obj/structure/cable/A = turflist[i]
		A.connections |= src
		connections |= A
		for (var/j = i + 1, j <= turflist.len, j++)
			var/obj/structure/cable/B = turflist[j]
			A.connections |= B
			B.connections |= A
			junction_pairs += list(list(A,B))
	if (turflist.len)
		var/obj/structure/cable/root = turflist[1]
		root.rebuild_supply()

/obj/item/connector/after_load()
	..()
	// Older native saves have the junction edges but no ownership pairs.
	if (!anchored || !isturf(loc) || junction_pairs.len)
		return
	for (var/i = 1, i <= turflist.len, i++)
		var/obj/structure/cable/A = turflist[i]
		if (!A || A.loc != loc)
			continue
		for (var/j = i + 1, j <= turflist.len, j++)
			var/obj/structure/cable/B = turflist[j]
			if (B && B.loc == loc && (B in A.connections) && (A in B.connections))
				junction_pairs += list(list(A,B))

/obj/item/connector/Destroy()
	disconnect_cables()
	return ..()
/obj/item/connector/Del()
	disconnect_cables()
	..()
/obj/item/connector/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		disconnect_cables()
		anchored = FALSE
/obj/item/connector/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		disconnect_cables()
		anchored = FALSE
/obj/item/connector/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		var/mob/living/human/H = user
		if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.item_is_in_hands(W) || get_dist(H,src) > 1 || !isturf(loc))
			return
		if (!anchored)
			for (var/obj/item/connector/other in loc)
				if (other != src && other.anchored)
					return
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		to_chat(user, (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>"))
		anchored = !anchored
		if (anchored)
			connect_cables()
		else
			disconnect_cables()
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
	var/mob/living/human/H = user
	if(!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.item_is_in_hands(src) || !isturf(H.loc))
		return

	if(!isturf(T))
		to_chat(user, "<span class='warning'>You can't lay a cable here!")
		return

	if(amount < 1) // Out of cable
		to_chat(user, "<span class='warning'>There is no cable left!</span>")
		user.remove_from_mob(src)
		qdel(src)
		return

	if(get_dist(T,user) > 1) // Too far
		to_chat(user, "<span class='warning'>You can't lay cable at a place that far away!</span>")
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
			to_chat(user, "<span class='warning'>There's already a cable at that position with the same direction!</span>")
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
				NCOO.connections |= C
				C.connections |= NCOO
				to_chat(user, "You connect the two cables.")

		for(var/obj/structure/cable/NCOC in get_turf(get_step(C,opdir2)))
			if ((NCOC.tiledir == C.tiledir) && NCOC != C)
				NCOC.connections |= C
				C.connections |= NCOC
				to_chat(user, "You connect the two cables.")
	// Crossing directions join only through a secured connector.
	for (var/obj/item/connector/junction in T)
		if (junction.anchored)
			junction.connect_cables()
			break
	C.rebuild_supply()
	if (amount <= 0)
		user.remove_from_mob(src)
		qdel(src)
	else
		update_icon()
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
