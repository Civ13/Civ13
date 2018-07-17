#define MAXCOIL 30
#define CABLE_COIL_COLORS list("Yellow" = COLOR_YELLOW, "Green" = COLOR_LIME, "Pink" = COLOR_PINK, "Blue" = COLOR_BLUE, "Orange" = COLOR_ORANGE, "Cyan" = COLOR_CYAN, "Red" = COLOR_RED)

/obj/item/stack/cable_coil
	name = "cable coil"
	icon = 'icons/obj/power.dmi'
	icon_state = "coil"
	amount = MAXCOIL
	max_amount = MAXCOIL
	color = COLOR_RED
	desc = "A coil of power cable."
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = 1.0
	throw_speed = 2
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 50, "glass" = 20)
	flags = CONDUCT
	slot_flags = SLOT_BELT
	item_state = "coil"
	attack_verb = list("whipped", "lashed", "disciplined", "flogged")
	stacktype = /obj/item/stack/cable_coil

/obj/item/stack/cable_coil/New(loc, length = MAXCOIL, var/param_color = null)
	..()
	amount = length
	if (param_color) // It should be red by default, so only recolor it if parameter was specified.
		color = param_color
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()
	update_wclass()

///////////////////////////////////
// General procedures
///////////////////////////////////

//you can use wires to heal robotics
/obj/item/stack/cable_coil/afterattack(var/mob/M, var/mob/user)

	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		var/obj/item/organ/external/S = H.organs_by_name[user.targeted_organ]

		if (!S) return
		if (!(S.status & ORGAN_ROBOT) || user.a_intent != I_HELP)
			return ..()

		if (S.burn_dam)
			if (S.burn_dam < ROBOLIMB_SELF_REPAIR_CAP)
				S.heal_damage(0,15,0,1)
				user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				user.visible_message("<span class='danger'>\The [user] patches some damaged wiring on \the [M]'s [S.name] with \the [src].</span>")
			else if (S.open != 2)
				user << "<span class='danger'>The damage is far too severe to patch over externally.</span>"
			return TRUE
		else if (S.open != 2)
			user << "<span class='notice'>Nothing to fix!</span>"

	else
		return ..()

/obj/item/stack/cable_coil/update_icon()
	if (!color)
		color = pick(COLOR_RED, COLOR_BLUE, COLOR_LIME, COLOR_ORANGE, COLOR_WHITE, COLOR_PINK, COLOR_YELLOW, COLOR_CYAN)
	if (amount == TRUE)
		icon_state = "coil1"
		name = "cable piece"
	else if (amount == 2)
		icon_state = "coil2"
		name = "cable piece"
	else
		icon_state = "coil"
		name = "cable coil"

/obj/item/stack/cable_coil/proc/set_cable_color(var/selected_color, var/user)
	if (!selected_color)
		return

	var/final_color = CABLE_COIL_COLORS[selected_color]
	if (!final_color)
		final_color = CABLE_COIL_COLORS["Red"]
		selected_color = "red"
	color = final_color
	user << "<span class='notice'>You change \the [src]'s color to [lowertext(selected_color)].</span>"

/obj/item/stack/cable_coil/proc/update_wclass()
	if (amount == TRUE)
		w_class = 1.0
	else
		w_class = 2.0

/obj/item/stack/cable_coil/examine(mob/user)
	if (get_dist(src, user) > 1)
		return

	if (get_amount() == TRUE)
		user << "A short piece of power cable."
	else if (get_amount() == 2)
		user << "A piece of power cable."
	else
		user << "A coil of power cable. There are [get_amount()] lengths of cable in the coil."


/obj/item/stack/cable_coil/verb/make_restraint()
	set name = "Make Cable Restraints"
	set category = null
	var/mob/M = usr

	if (ishuman(M) && !M.restrained() && !M.stat && !M.paralysis && ! M.stunned)
		if (!istype(usr.loc,/turf)) return
		if (amount <= 14)
			usr << "<span class = 'red'>You need at least 15 lengths to make restraints!</span>"
			return
		var/obj/item/weapon/handcuffs/cable/B = new /obj/item/weapon/handcuffs/cable(usr.loc)
		B.color = color
		usr << "<span class='notice'>You wind some cable together to make some restraints.</span>"
		use(15)
	else
		usr << "<span class = 'notice'>You cannot do that.</span>"
	..()

// Items usable on a cable coil :
//   - Wirecutters : cut them duh !
//   - Cable coil : merge cables
/obj/item/stack/cable_coil/proc/can_merge(var/obj/item/stack/cable_coil/C)
	return color == C.color

/obj/item/stack/cable_coil/transfer_to(obj/item/stack/cable_coil/S)
	if (!istype(S))
		return
	if (!can_merge(S))
		return

	..()

/obj/item/stack/cable_coil/use()
	. = ..()
	update_icon()
	return

/obj/item/stack/cable_coil/add()
	. = ..()
	update_icon()
	return

///////////////////////////////////////////////
// Cable laying procedures
//////////////////////////////////////////////

// called when cable_coil is clicked on a turf/floor
/*
/obj/item/stack/cable_coil/proc/turf_place(turf/F, mob/user)
	if (!isturf(user.loc))
		return

	if (get_amount() < 1) // Out of cable
		user << "There is no cable left."
		return

	if (get_dist(F,user) > 1) // Too far
		user << "You can't lay cable at a place that far away."
		return

	if (!F.is_plating())		// Ff floor is intact, complain
		user << "You can't lay cable there unless the floor tiles are removed."
		return

	else
		var/dirn

		if (user.loc == F)
			dirn = user.dir			// if laying on the tile we're on, lay in the direction we're facing
		else
			dirn = get_dir(F, user)

		for (var/obj/structure/cable/LC in F)
			if ((LC.d1 == dirn && LC.d2 == FALSE ) || ( LC.d2 == dirn && LC.d1 == FALSE))
				user << "<span class='warning'>There's already a cable at that position.</span>"
				return
///// Z-Level Stuff
		// check if the target is open space
		if (istype(F, /turf/open))
			for (var/obj/structure/cable/LC in F)
				if ((LC.d1 == dirn && LC.d2 == 11 ) || ( LC.d2 == dirn && LC.d1 == 11))
					user << "<span class='warning'>There's already a cable at that position.</span>"
					return

			var/obj/structure/cable/C = new(F)
			var/obj/structure/cable/D = new(GetBelow(F))

			C.cableColor(color)

			C.d1 = 11
			C.d2 = dirn
			C.add_fingerprint(user)
			C.updateicon()
/*
			var/datum/powernet/PN = new()
			PN.add_cable(C)
*/
			C.mergeConnectedNetworks(C.d2)
			C.mergeConnectedNetworksOnTurf()

			D.cableColor(color)

			D.d1 = 12
			D.d2 = FALSE
			D.add_fingerprint(user)
			D.updateicon()
/*
			PN.add_cable(D)
*/
			D.mergeConnectedNetworksOnTurf()

		// do the normal stuff
		else
///// Z-Level Stuff
			for (var/obj/structure/cable/LC in F)
				if ((LC.d1 == dirn && LC.d2 == FALSE ) || ( LC.d2 == dirn && LC.d1 == FALSE))
					user << "There's already a cable at that position."
					return

			var/obj/structure/cable/C = new(F)

			C.cableColor(color)

			//set up the new cable
			C.d1 = FALSE //it's a O-X node cable
			C.d2 = dirn
			C.add_fingerprint(user)
			C.updateicon()
/*
			//create a new powernet with the cable, if needed it will be merged later
			var/datum/powernet/PN = new()
			PN.add_cable(C)
*/
			C.mergeConnectedNetworks(C.d2) //merge the powernet with adjacents powernets
			C.mergeConnectedNetworksOnTurf() //merge the powernet with on turf powernets

			if (C.d2 & (C.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
				C.mergeDiagonalsNetworks(C.d2)


			use(1)
			if (C.shock(user, 50))
				if (prob(50)) //fail
					new/obj/item/stack/cable_coil(C.loc, TRUE, C.color)
					qdel(C)
					*/
/*
// called when cable_coil is click on an installed obj/cable
// or click on a turf that already contains a "node" cable
/obj/item/stack/cable_coil/proc/cable_join(obj/structure/cable/C, mob/user)
	var/turf/U = user.loc
	if (!isturf(U))
		return

	var/turf/T = C.loc

	if (!isturf(T) || !T.is_plating())		// sanity checks, also stop use interacting with T-scanner revealed cable
		return

	if (get_dist(C, user) > 1)		// make sure it's close enough
		user << "You can't lay cable at a place that far away."
		return

	if (U == T) //if clicked on the turf we're standing on, try to put a cable in the direction we're facing
		turf_place(T,user)
		return

	var/dirn = get_dir(C, user)

	// one end of the clicked cable is pointing towards us
	if (C.d1 == dirn || C.d2 == dirn)
		if (!U.is_plating())						// can't place a cable if the floor is complete
			user << "You can't lay cable there unless the floor tiles are removed."
			return
		else
			// cable is pointing at us, we're standing on an open tile
			// so create a stub pointing at the clicked cable on our tile

			var/fdirn = turn(dirn, 180)		// the opposite direction

			for (var/obj/structure/cable/LC in U)		// check to make sure there's not a cable there already
				if (LC.d1 == fdirn || LC.d2 == fdirn)
					user << "There's already a cable at that position."
					return

			var/obj/structure/cable/NC = new(U)
			NC.cableColor(color)

			NC.d1 = FALSE
			NC.d2 = fdirn
			NC.add_fingerprint()
			NC.updateicon()
/*
			//create a new powernet with the cable, if needed it will be merged later
			var/datum/powernet/newPN = new()
			newPN.add_cable(NC)
*/
			NC.mergeConnectedNetworks(NC.d2) //merge the powernet with adjacents powernets
			NC.mergeConnectedNetworksOnTurf() //merge the powernet with on turf powernets

			if (NC.d2 & (NC.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
				NC.mergeDiagonalsNetworks(NC.d2)

			use(1)

			if (NC.shock(user, 50))
				if (prob(50)) //fail
					new/obj/item/stack/cable_coil(NC.loc, TRUE, NC.color)
					qdel(NC)

			return

	// exisiting cable doesn't point at our position, so see if it's a stub
	else if (C.d1 == FALSE)
							// if so, make it a full cable pointing from it's old direction to our dirn
		var/nd1 = C.d2	// these will be the new directions
		var/nd2 = dirn


		if (nd1 > nd2)		// swap directions to match icons/states
			nd1 = dirn
			nd2 = C.d2


		for (var/obj/structure/cable/LC in T)		// check to make sure there's no matching cable
			if (LC == C)			// skip the cable we're interacting with
				continue
			if ((LC.d1 == nd1 && LC.d2 == nd2) || (LC.d1 == nd2 && LC.d2 == nd1) )	// make sure no cable matches either direction
				user << "There's already a cable at that position."
				return


		C.cableColor(color)

		C.d1 = nd1
		C.d2 = nd2

		C.add_fingerprint()
		C.updateicon()


		C.mergeConnectedNetworks(C.d1) //merge the powernets...
		C.mergeConnectedNetworks(C.d2) //...in the two new cable directions
		C.mergeConnectedNetworksOnTurf()

		if (C.d1 & (C.d1 - 1))// if the cable is layed diagonally, check the others 2 possible directions
			C.mergeDiagonalsNetworks(C.d1)

		if (C.d2 & (C.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
			C.mergeDiagonalsNetworks(C.d2)

		use(1)

		if (C.shock(user, 50))
			if (prob(50)) //fail
				new/obj/item/stack/cable_coil(C.loc, 2, C.color)
				qdel(C)
				return

		C.denode()// this call may have disconnected some cables that terminated on the centre of the turf, if so split the powernets.
		return
*/
//////////////////////////////
// Misc.
/////////////////////////////

/obj/item/stack/cable_coil/cut
	item_state = "coil2"

/obj/item/stack/cable_coil/cut/New(loc)
	..()
	amount = rand(1,2)
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()
	update_wclass()

/obj/item/stack/cable_coil/yellow
	color = COLOR_YELLOW

/obj/item/stack/cable_coil/blue
	color = COLOR_BLUE

/obj/item/stack/cable_coil/green
	color = COLOR_LIME

/obj/item/stack/cable_coil/pink
	color = COLOR_PINK

/obj/item/stack/cable_coil/orange
	color = COLOR_ORANGE

/obj/item/stack/cable_coil/cyan
	color = COLOR_CYAN

/obj/item/stack/cable_coil/white
	color = COLOR_WHITE

/obj/item/stack/cable_coil/random/New()
	color = pick(COLOR_RED, COLOR_BLUE, COLOR_LIME, COLOR_WHITE, COLOR_PINK, COLOR_YELLOW, COLOR_CYAN)
	..()