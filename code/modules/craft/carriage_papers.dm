// ============================================================
// Carriage papers (docs/craft-core.md): carriages on the craft core
// ------------------------------------------------------------
// A carriage is a vehicle craft with a body of its own (its footprint). It
// keeps the papers every vehicle keeps, read in a carriage's words, and its
// reins follow the rule of a vehicle's controls: crew urge the team freely,
// a stranger must force the reins while an owner is in the world and cannot
// otherwise. Reining in is never locked. The carriage saves the register.
// ============================================================

/datum/craft/vehicle/carriage
	papers_title = "Carriage papers"
	kind_word = "carriage"
	helm_word = "reins"
	helm_stance = "holds"

/datum/craft/vehicle/carriage/role_title(role)
	switch (role)
		if (CRAFT_ROLE_CAPTAIN) return "master"
		if (CRAFT_ROLE_HELMSMAN) return "coachman"
		if (CRAFT_ROLE_ENGINEER) return "wheelwright"
		if (CRAFT_ROLE_HAND) return "groom"
	return role

/datum/craft/vehicle/carriage/proc/carriage()
	var/datum/craft_body/carriage/B = body
	return istype(B) ? B.carriage : null

/datum/craft/vehicle/carriage/rename(new_name)
	..()
	var/obj/structure/vehicle/carriage/W = carriage()
	if (W)
		W.name = new_name

/datum/craft/vehicle/carriage/where_text(turf/from)
	var/obj/structure/vehicle/carriage/W = carriage()
	var/turf/T = W ? get_turf(W) : null
	if (!T)
		return "[name]: lost"
	var/state = W.moving ? "on the move" : "standing"
	if (W.driver && W.driver.stat != DEAD)
		state += ", [W.driver.real_name] at the reins"
	if (!from || from.z != T.z)
		return "[name]: on another level ([state])"
	var/far = get_dist(from, T)
	if (far <= 1)
		return "[name]: here ([state])"
	return "[name]: [far] tiles to the [dir2text(get_dir(from, T))] ([state])"

// ---- The body ----

/datum/craft_body/carriage
	var/obj/structure/vehicle/carriage/carriage

/datum/craft_body/carriage/New(obj/structure/vehicle/carriage/W)
	..()
	carriage = W

/datum/craft_body/carriage/Destroy()
	carriage = null
	return ..()

/datum/craft_body/carriage/craft_name()
	return carriage ? carriage.name : null

/datum/craft_body/carriage/placed()
	return carriage && !QDELETED(carriage) && isturf(carriage.loc)

/datum/craft_body/carriage/cells()
	if (!placed())
		return list()
	var/list/L = carriage.cells_at(carriage.loc, carriage.facing, 0)
	return L ? L : list(carriage.loc)

/datum/craft_body/carriage/origin()
	return placed() ? carriage.loc : null

/datum/craft_body/carriage/heading()
	return (carriage && (carriage.facing in cardinal)) ? carriage.facing : NORTH

/datum/craft_body/carriage/length_tiles()
	return 3

/datum/craft_body/carriage/beam_tiles()
	return 2

// ---- The carriage ----

// The craft around a carriage, made the first time it is asked for.
/obj/structure/vehicle/carriage/proc/carriage_craft(make = TRUE)
	if (craft && !QDELETED(craft))
		return craft
	if (!make)
		return null
	craft = new /datum/craft/vehicle/carriage(new /datum/craft_body/carriage(src))
	craft.name = name
	return craft

/obj/structure/vehicle/carriage/before_save()
	..()
	var/datum/craft_register/R = craft ? craft.register : null
	register_state = (R && R.party) ? R.register_state() : ""

/obj/structure/vehicle/carriage/after_load()
	..()
	if (!register_state)
		return
	var/datum/craft_register/R = craft_register_restore(register_state)
	if (!R)
		return
	var/datum/craft/vehicle/carriage/C = carriage_craft()
	C.register = R
	if (length(R.name))
		C.name = R.name

// Whether this mob may urge the team on. A stranger is asked whether to force
// the reins, which takes a while and warns the crew.
/obj/structure/vehicle/carriage/proc/carriage_papers_allow(mob/living/human/H)
	var/datum/craft/vehicle/carriage/C = craft
	if (!C || QDELETED(C))
		return TRUE
	switch (C.helm_access(H))
		if (CRAFT_HELM_FREE)
			if (C.forced_by != H.real_name)
				C.forced_by = null
			return TRUE
		if (CRAFT_HELM_CHAINED)
			to_chat(H, SPAN_WARNING("The team will not go for you. The [C.name] belongs to [party_train_party_name(C.register.party)] and none of them are about."))
			return FALSE
	if (C.forced_by == H.real_name)
		return TRUE
	if (C.forcing)
		return FALSE
	C.forcing = TRUE
	var/forced = FALSE
	try
		forced = C.force_helm(H, src)
	catch (var/exception/e)
		C.forcing = FALSE
		throw e
	C.forcing = FALSE
	if (!forced || QDELETED(src) || craft != C)
		return FALSE
	C.forced_by = H.real_name
	return TRUE

/obj/structure/vehicle/carriage/verb/carriage_papers()
	set name = "Vehicle Papers"
	set category = null
	set src in view(3)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || !Adjacent(H))
		return
	var/datum/craft/vehicle/carriage/C = carriage_craft()
	if (C)
		// The papers ask that the reader stays within a tile of where they
		// were opened: the part of the carriage nearest the reader.
		C.papers(H, nearest_cell(H))

/obj/structure/vehicle/carriage/proc/nearest_cell(atom/A)
	var/turf/best = get_turf(src)
	var/best_dist = get_dist(A, best)
	for (var/turf/T in locs)
		var/d = get_dist(A, T)
		if (d < best_dist)
			best = T
			best_dist = d
	return best
