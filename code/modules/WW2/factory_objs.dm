//conveyor2 is pretty much like the original, except it supports corners, but not diverters.
//note that corner pieces transfer stuff clockwise when running forward, and anti-clockwise backwards.

/obj/structure/conveyor
	icon = 'icons/obj/recycling.dmi'
	icon_state = "conveyor0"
	name = "conveyor belt"
	desc = "A conveyor belt."
	layer = 2			// so they appear under stuff
	anchored = TRUE
	var/operating = FALSE	// TRUE if running forward, -1 if backwards, FALSE if off
	var/operable = TRUE	// true if can operate (no broken segments in this belt run)
	var/forwards		// this is the default (forward) direction, set by the map dir
	var/backwards		// hopefully self-explanatory
	var/movedir			// the actual direction to move stuff in

	var/list/affecting	// the list of all items that will be moved this ptick
	var/id = ""			// the control ID	- must match controller ID
	var/stat = 0

/obj/structure/conveyor/centcom_auto
	id = "round_end_belt"

	// create a conveyor
/obj/structure/conveyor/New(loc, newdir, on = FALSE)
	..(loc)
	if (newdir)
		set_dir(newdir)

	if (dir & (dir-1)) // Diagonal. Forwards is *away* from dir, curving to the right.
		forwards = turn(dir, 135)
		backwards = turn(dir, 45)
	else
		forwards = dir
		backwards = turn(dir, 180)

	if (on)
		operating = TRUE
		setmove()



/obj/structure/conveyor/proc/setmove()
	if (operating == TRUE)
		movedir = forwards
	else if (operating == -1)
		movedir = backwards
	else operating = FALSE
	update()

/obj/structure/conveyor/proc/update()
	if (stat & BROKEN)
		icon_state = "conveyor-broken"
		operating = FALSE
		return
	if (!operable)
		operating = FALSE
	if (stat & NOPOWER)
		operating = FALSE
	icon_state = "conveyor[operating]"

	// machine process
	// move items to the target location
/obj/structure/conveyor/process()
	if (stat & (BROKEN | NOPOWER))
		return
	if (!operating)
		return
//	use_power(100)

	affecting = loc.contents - src		// moved items will be all in loc
	spawn(1)	// slight delay to prevent infinite propagation due to map order	//TODO: please no spawn() in process(). It's a very bad idea
		var/items_moved = FALSE
		for (var/atom/movable/A in affecting)
			if (!A.anchored)
				if (A.loc == loc) // prevents the object from being affected if it's not currently here.
					step(A,movedir)
					items_moved++
			if (items_moved >= 10)
				break

// attack with item, place item on conveyor
/obj/structure/conveyor/attackby(var/obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/crowbar))
		if (!(stat & BROKEN))
			var/obj/item/conveyor_construct/C = new/obj/item/conveyor_construct(loc)
			C.id = id
			transfer_fingerprints_to(C)
		user << "<span class='notice'>You remove the conveyor belt.</span>"
		qdel(src)
		return
	if (I.loc != user)	return // This should stop mounted modules ending up outside the module.

	user.drop_item(get_turf(src))
	return

// attack with hand, move pulled object onto conveyor
/obj/structure/conveyor/attack_hand(mob/user as mob)
	if ((!( user.canmove ) || user.restrained() || !( user.pulling )))
		return
	if (user.pulling.anchored)
		return
	if ((user.pulling.loc != user.loc && get_dist(user, user.pulling) > 1))
		return
	if (ismob(user.pulling))
		var/mob/M = user.pulling
		M.stop_pulling()
		step(user.pulling, get_dir(user.pulling.loc, src))
		user.stop_pulling()
	else
		step(user.pulling, get_dir(user.pulling.loc, src))
		user.stop_pulling()
	return


// make the conveyor broken
// also propagate inoperability to any connected conveyor with the same ID
/obj/structure/conveyor/proc/broken()
	stat |= BROKEN
	update()

	var/obj/structure/conveyor/C = locate() in get_step(src, dir)
	if (C)
		C.set_operable(dir, id, FALSE)

	C = locate() in get_step(src, turn(dir,180))
	if (C)
		C.set_operable(turn(dir,180), id, FALSE)


//set the operable var if ID matches, propagating in the given direction

/obj/structure/conveyor/proc/set_operable(stepdir, match_id, op)

	if (id != match_id)
		return
	operable = op

	update()
	var/obj/structure/conveyor/C = locate() in get_step(src, stepdir)
	if (C)
		C.set_operable(stepdir, id, op)

// the conveyor control switch
//
//

/obj/structure/conveyor_switch

	name = "conveyor switch"
	desc = "A conveyor control switch."
	icon = 'icons/obj/recycling.dmi'
	icon_state = "switch-off"
	var/position = FALSE			// FALSE off, -1 reverse, TRUE forward
	var/last_pos = -1			// last direction setting
	var/operated = TRUE			// true if just operated

	var/id = "" 				// must match conveyor IDs to control them

	var/list/conveyors		// the list of converyors that are controlled by this switch
	anchored = TRUE



/obj/structure/conveyor_switch/New(loc, newid)
	..(loc)
	if (!id)
		id = newid
	update()
/*
	spawn(5)		// allow map load
		conveyors = list()
		for (var/obj/structure/conveyor/C in world)
			if (C.id == id)
				conveyors += C*/

// update the icon depending on the position

/obj/structure/conveyor_switch/proc/update()

	if (position<0)
		icon_state = "switch-rev"
	else if (position>0)
		icon_state = "switch-fwd"
	else
		icon_state = "switch-off"


// timed process
// if the switch changed, update the linked conveyors

/obj/structure/conveyor_switch/process()
	if (!operated)
		return
	operated = FALSE

	for (var/obj/structure/conveyor/C in conveyors)
		C.operating = position
		C.setmove()

// attack with hand, switch position
/obj/structure/conveyor_switch/attack_hand(mob/user)

	playsound(user,'sound/machines/Conveyor_switch.wav',100,1)
	if (position == FALSE)
		if (last_pos < 0)
			position = TRUE
			last_pos = FALSE
		else
			position = -1
			last_pos = FALSE
	else
		last_pos = position
		position = FALSE


	operated = TRUE
	update()

/*
	// find any switches with same id as this one, and set their positions to match us
	for (var/obj/structure/conveyor_switch/S in world)
		if (S.id == id)
			S.position = position
			S.update()*/


/obj/structure/conveyor_switch/attackby(obj/item/I, mob/user, params)
	if (istype(I, /obj/item/weapon/crowbar))
		var/obj/item/conveyor_switch_construct/C = new/obj/item/conveyor_switch_construct(loc)
		C.id = id
		transfer_fingerprints_to(C)
		user << "<span class='notice'>You deattach the conveyor switch.</span>"
		qdel(src)

/obj/structure/conveyor_switch/oneway
	var/convdir = TRUE //Set to TRUE or -1 depending on which way you want the convayor to go. (In other words keep at TRUE and set the proper dir on the belts.)
	desc = "A conveyor control switch. It appears to only go in one direction."

// attack with hand, switch position
/obj/structure/conveyor_switch/oneway/attack_hand(mob/user)
	playsound(user,'sound/machines/Conveyor_switch.wav',100,1)
	if (position == FALSE)
		position = convdir
	else
		position = FALSE

	operated = TRUE
	update()

	// find any switches with same id as this one, and set their positions to match us
	for (var/obj/structure/conveyor_switch/S in world)
		if (S.id == id)
			S.position = position
			S.update()



//
// CONVEYOR CONSTRUCTION STARTS HERE
//

/obj/item/conveyor_construct
	icon = 'icons/obj/recycling.dmi'
	icon_state = "conveyor0"
	name = "conveyor belt assembly"
	desc = "A conveyor belt assembly."
	w_class = 4
	var/id = "" //inherited by the belt

/obj/item/conveyor_construct/attackby(obj/item/I, mob/user, params)
	..()
	if (istype(I, /obj/item/conveyor_switch_construct))
		user << "<span class='notice'>You link the switch to the conveyor belt assembly.</span>"
		var/obj/item/conveyor_switch_construct/C = I
		id = C.id

/obj/item/conveyor_construct/afterattack(atom/A, mob/user, proximity)
	if (!proximity || !istype(A, /turf/floor) || user.incapacitated())
		return
	var/cdir = get_dir(A, user)
	if (!(cdir in cardinal) || A == user.loc)
		return
	for (var/obj/structure/conveyor/CB in A)
		if (CB.dir == cdir || CB.dir == turn(cdir,180))
			return
		cdir |= CB.dir
		qdel(CB)
	var/obj/structure/conveyor/C = new/obj/structure/conveyor(A,cdir)
	C.id = id
	transfer_fingerprints_to(C)
	qdel(src)

/obj/item/conveyor_switch_construct
	name = "conveyor switch assembly"
	desc = "A conveyor control switch assembly."
	icon = 'icons/obj/recycling.dmi'
	icon_state = "switch-off"
	w_class = 4
	var/id = "" //inherited by the switch

/obj/item/conveyor_switch_construct/New()
	..()
	id = rand() //this couldn't possibly go wrong

/obj/item/conveyor_switch_construct/afterattack(atom/A, mob/user, proximity)
	if (!proximity || !istype(A, /turf/floor) || user.incapacitated())
		return
	var/found = FALSE
	for (var/obj/structure/conveyor/C in view())
		if (C.id == id)
			found = TRUE
			break
	if (!found)
		user << "\icon[src]<span class=notice>The conveyor switch did not detect any linked conveyor belts in range.</span>"
		return
	var/obj/structure/conveyor_switch/NC = new/obj/structure/conveyor_switch(A, id)
	transfer_fingerprints_to(NC)
	qdel(src)


/obj/structure/plasticflaps //HOW DO YOU CALL THOSE THINGS ANYWAY
	name = "\improper plastic flaps"
	desc = "Completely impassable - or are they?"
	icon = 'icons/obj/stationobjs.dmi' //Change this.
	icon_state = "plasticflaps"
	density = FALSE
	anchored = TRUE
	layer = 4
	explosion_resistance = 5
	var/list/mobs_can_pass = list(
		/mob/living/simple_animal/mouse
		)

/obj/structure/plasticflaps/CanPass(atom/A, turf/T)
	if (istype(A) && A.checkpass(PASSGLASS))
		return prob(60)

	var/obj/structure/bed/B = A
	if (istype(A, /obj/structure/bed) && B.buckled_mob)//if it's a bed/chair and someone is buckled, it will not pass
		return FALSE

	if (istype(A, /obj/vehicle))	//no vehicles
		return FALSE

	var/mob/living/M = A
	if (istype(M))
		if (M.lying)
			return ..()
		for (var/mob_type in mobs_can_pass)
			if (istype(A, mob_type))
				return ..()
		return issmall(M)

	return ..()

/obj/structure/plasticflaps/ex_act(severity)
	switch(severity)
		if (1)
			qdel(src)
		if (2)
			if (prob(50))
				qdel(src)
		if (3)
			if (prob(5))
				qdel(src)