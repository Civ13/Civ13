// ============================================================
// Vehicle papers (docs/craft-core.md): modular vehicles on the craft core
// ------------------------------------------------------------
// A modular vehicle (a car, a truck, a tank, a boat or an aircraft built
// from frames around an axis) is a craft with an axis body. It keeps the
// same papers a ship has, read in a vehicle's words: a commander keeps them,
// a commander or driver may take the controls, and a stranger can only force
// them while one of the owners is in the world. Its turret guns follow the
// rule a ship's levers do: locked to strangers while no owner is about.
//
// The papers are opened from the driver's seat. They sit beside the vehicle
// key: a keyed vehicle still needs its key, and a registered one also needs
// its crew. A vehicle nobody registered drives for anyone, as before.
//
// Vehicle crafts are kept out of the global crafts list, so the sea chart,
// hails, grapples and radar never see them. The axis saves the register.
// ============================================================

var/global/list/vehicle_crafts = list()

/datum/craft/vehicle
	papers_title = "Vehicle papers"
	kind_word = "vehicle"
	helm_word = "controls"
	helm_stance = "sits at"
	sail_word = "drive"
	pro_she = "it"
	pro_her = "it"
	pro_hers = "its"
	var/tmp/forced_by = null     // The character who forced the controls and still holds them.
	var/tmp/forcing = FALSE

/datum/craft/vehicle/New(datum/craft_body/new_body)
	..()
	crafts -= src
	vehicle_crafts += src

/datum/craft/vehicle/Destroy()
	vehicle_crafts -= src
	return ..()

/datum/craft/vehicle/role_title(role)
	switch (role)
		if (CRAFT_ROLE_CAPTAIN) return "commander"
		if (CRAFT_ROLE_HELMSMAN) return "driver"
		if (CRAFT_ROLE_ENGINEER) return "mechanic"
		if (CRAFT_ROLE_HAND) return "crewman"
	return role

/datum/craft/vehicle/proc/vehicle_axis()
	var/datum/craft_body/axis/B = body
	return istype(B) ? B.axis : null

// ---- The body ----

/datum/craft_body/axis
	var/obj/structure/vehicleparts/axis/axis

/datum/craft_body/axis/New(obj/structure/vehicleparts/axis/A)
	..()
	axis = A

/datum/craft_body/axis/Destroy()
	axis = null
	return ..()

/datum/craft_body/axis/craft_name()
	if (!axis)
		return null
	// A bare axis is called an axis; the vehicle is better named by its kind.
	return findtext(axis.name, "axis") ? axis.vehicle_type : axis.name

/datum/craft_body/axis/placed()
	return axis && !QDELETED(axis) && !isnull(get_turf(axis))

/datum/craft_body/axis/cells()
	. = list()
	if (!placed())
		return
	. |= get_turf(axis)
	for (var/obj/O in axis.components)
		var/turf/T = get_turf(O)
		if (T)
			. |= T

/datum/craft_body/axis/origin()
	var/turf/low = null
	for (var/turf/T in cells())
		if (!low)
			low = T
		else
			low = locate(min(low.x, T.x), min(low.y, T.y), low.z)
	return low

/datum/craft_body/axis/heading()
	return (axis && (axis.dir in cardinal)) ? axis.dir : NORTH

// ---- The axis ----

/obj/structure/vehicleparts/axis
	var/tmp/datum/craft/vehicle/craft
	// The crew register's register_state() text, saved with the vehicle.
	var/register_state = ""

// The craft around a vehicle, made the first time it is asked for.
/proc/craft_of_axis(obj/structure/vehicleparts/axis/A, make = TRUE)
	if (!istype(A) || QDELETED(A))
		return null
	if (A.craft && !QDELETED(A.craft))
		return A.craft
	if (!make)
		return null
	A.craft = new /datum/craft/vehicle(new /datum/craft_body/axis(A))
	return A.craft

/obj/structure/vehicleparts/axis/Destroy()
	if (craft)
		var/datum/craft/vehicle/C = craft
		craft = null
		if (!QDELETED(C))
			var/datum/craft_body/B = C.body
			qdel(C)
			if (B && !QDELETED(B))
				qdel(B)
	return ..()

/obj/structure/vehicleparts/axis/before_save()
	..()
	var/datum/craft_register/R = craft ? craft.register : null
	register_state = (R && R.party) ? R.register_state() : ""

/obj/structure/vehicleparts/axis/after_load()
	..()
	if (!register_state)
		return
	var/datum/craft_register/R = craft_register_restore(register_state)
	if (!R)
		return
	var/datum/craft/vehicle/C = craft_of_axis(src)
	C.register = R
	if (length(R.name))
		C.name = R.name

// Whether this mob may start or speed up the vehicle. A stranger is asked
// whether to force the controls, which takes a while and warns the crew.
/obj/structure/vehicleparts/axis/proc/papers_allow(mob/living/human/H, atom/at)
	var/datum/craft/vehicle/C = craft
	if (!C || QDELETED(C))
		return TRUE
	switch (C.helm_access(H))
		if (CRAFT_HELM_FREE)
			// Its crew have it back.
			if (C.forced_by != H.real_name)
				C.forced_by = null
			return TRUE
		if (CRAFT_HELM_CHAINED)
			to_chat(H, SPAN_WARNING("The controls are locked. The [C.name] belongs to [party_train_party_name(C.register.party)] and none of them are about."))
			return FALSE
	if (C.forced_by == H.real_name)
		return TRUE
	if (C.forcing)
		return FALSE
	C.forcing = TRUE
	var/forced = FALSE
	try
		forced = C.force_helm(H, at)
	catch (var/exception/e)
		C.forcing = FALSE
		throw e
	C.forcing = FALSE
	if (!forced || QDELETED(src) || craft != C)
		return FALSE
	C.forced_by = H.real_name
	return TRUE

// Whether this mob may steer a vehicle that is already rolling: its crew, or
// whoever forced the controls.
/obj/structure/vehicleparts/axis/proc/papers_steer(mob/user)
	var/datum/craft/vehicle/C = craft
	if (!C || QDELETED(C) || !user)
		return TRUE
	return C.helm_access(user) == CRAFT_HELM_FREE || C.forced_by == user.real_name

// ---- The controls ----

/obj/item/vehicleparts/wheel/modular/attack_self(mob/living/human/H)
	if (control && control.axis && control.axis.craft && istype(H))
		if (!control.axis.papers_allow(H, drivingchair || control))
			return
		if (QDELETED(src) || !control || !control.axis || loc != H)
			return
	return ..()

/obj/item/vehicleparts/wheel/modular/turndir(var/mob/living/mob = null, var/newdir = "left")
	if (control && control.axis && control.axis.craft && !control.axis.papers_steer(mob))
		return FALSE
	return ..()

// ---- The guns ----

// The vehicle whose frame stands on this tile, or null.
/proc/vehicle_axis_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (F.axis && !QDELETED(F.axis))
			return F.axis
	return null

// Why this mob may not work a fitting of the vehicle standing here (its
// guns), or null: the rule a ship's levers follow. Crew always may; a
// stranger may only while one of the owners is in the world.
/proc/vehicle_fitting_refusal(atom/at, mob/user)
	var/obj/structure/vehicleparts/axis/A = vehicle_axis_at(get_turf(at))
	var/datum/craft/vehicle/C = A ? A.craft : null
	return (C && !QDELETED(C)) ? C.fitting_refusal(user) : null

/obj/item/turret_controls/attack_self(mob/living/human/user)
	if (turret)
		var/locked = vehicle_fitting_refusal(turret, user)
		if (locked)
			to_chat(user, SPAN_WARNING(locked))
			return
	return ..()

// ---- The driver's seat ----

/obj/structure/bed/chair/drivers/proc/seat_axis()
	if (axis && !QDELETED(axis))
		return axis
	if (wheel && wheel.control && wheel.control.axis && !QDELETED(wheel.control.axis))
		return wheel.control.axis
	return null

/obj/structure/bed/chair/drivers/verb/vehicle_papers()
	set name = "Vehicle Papers"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
		return
	var/obj/structure/vehicleparts/axis/A = seat_axis()
	if (!A)
		to_chat(H, SPAN_WARNING("This seat is not fitted to a vehicle."))
		return
	var/datum/craft/vehicle/C = craft_of_axis(A)
	if (C)
		C.papers(H, src)

/obj/structure/bed/chair/drivers/examine(mob/user, distance = -1)
	. = ..()
	var/obj/structure/vehicleparts/axis/A = seat_axis()
	var/datum/craft/vehicle/C = A ? A.craft : null
	if (C && C.register && C.register.party)
		to_chat(user, SPAN_NOTICE("The [C.name] is registered to [party_train_party_name(C.register.party)]. Right-click the seat and choose Vehicle Papers to read its papers."))
	else if (A)
		to_chat(user, SPAN_NOTICE("Right-click the seat and choose Vehicle Papers to register this vehicle."))

// ---- Naming, and the list of a party's vehicles ----

/datum/craft/vehicle/papers_extra(mob/living/human/H, datum/craft_register/R)
	. = list()
	if (R.party && (R.is_owner(H) || R.role_of(H) == CRAFT_ROLE_CAPTAIN))
		. += "Name the vehicle"
	if (party_train_party_of(H))
		. += "Our vehicles"

/datum/craft/vehicle/papers_extra_action(mob/living/human/H, datum/craft_register/R, choice, atom/at)
	switch (choice)
		if ("Our vehicles")
			to_chat(H, fleet_text(H, get_turf(at)))
			return TRUE
		if ("Name the vehicle")
			if (!papers_still_valid(H, R, at))
				return TRUE
			var/new_name = player_input(H, "What is it called? Its crew and your vehicle list use the name.", papers_title, name, "text", null, TRUE)
			if (isnull(new_name) || !papers_still_valid(H, R, at))
				return TRUE
			new_name = sanitize(copytext(new_name, 1, 40))
			if (!length(new_name))
				return TRUE
			rename(new_name)
			crew_message(SPAN_NOTICE("[H] names the vehicle the [name]."))
			return TRUE
	return FALSE

/datum/craft/vehicle/proc/rename(new_name)
	name = new_name
	if (register)
		register.name = new_name

// Every registered vehicle of a party that still stands on the map.
/proc/party_vehicles(party)
	. = list()
	if (!party)
		return
	for (var/datum/craft/vehicle/C in vehicle_crafts)
		if (C.register && C.register.party == party && C.body && C.body.placed())
			. += C

// One line on where this vehicle is, as seen from a turf.
/datum/craft/vehicle/proc/where_text(turf/from)
	var/obj/structure/vehicleparts/axis/A = vehicle_axis()
	var/turf/T = A ? get_turf(A) : null
	if (!T)
		return "[name]: lost"
	var/state = A.moving ? "rolling" : "standing"
	if (A.driver && A.driver.stat != DEAD)
		state += ", [A.driver.real_name] at the controls"
	if (!from || from.z != T.z)
		return "[name]: on another level ([state])"
	var/far = get_dist(from, T)
	if (far <= 1)
		return "[name]: here ([state])"
	return "[name]: [far] tiles to the [dir2text(get_dir(from, T))] ([state])"

// The vehicle list a member reads in any vehicle's papers.
/datum/craft/vehicle/proc/fleet_text(mob/living/human/H, turf/from)
	var/party = party_train_party_of(H)
	var/list/mine = party_vehicles(party)
	if (!mine.len)
		return SPAN_NOTICE("[party_train_party_name(party)] has no registered vehicles in this land.")
	var/list/lines = list("<b>Vehicles of [party_train_party_name(party)]:</b>")
	for (var/datum/craft/vehicle/C in mine)
		lines += C.where_text(from)
	return SPAN_NOTICE(jointext(lines, "<br>"))
