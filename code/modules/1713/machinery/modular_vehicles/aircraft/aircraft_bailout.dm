// ============================================================
// Bailing out of an aircraft (docs/vessel-entries.md, phase 6)
// ------------------------------------------------------------
// Aboard an airborne aircraft anyone can "Bail out". A plane with a door goes
// out through it, and the door is left open. A plane with none, such as a
// single-seater, jettisons its canopy first: it is gone until two sheets of
// glass refit it on the ground, and examine says so.
//
// The jumper drops to the ground straight below (the nearest open tile, if
// that one is solid). With a parachute pack on their back they float down and
// land on their feet. Without one, a jump just off the ground is a hard
// landing; any higher breaks both legs, and from above the hills worse.
// ============================================================

#define AIRCRAFT_BAILOUT_TIME (2 SECONDS)
#define AIRCRAFT_CANOPY_GLASS 2

/obj/structure/vehicleparts/frame/car/aircraft
	// TRUE once the canopy over this cockpit has been jettisoned.
	var/canopy_gone = FALSE

// The aircraft this frame belongs to, or null.
/obj/structure/vehicleparts/frame/car/aircraft/proc/aircraft()
	return istype(axis, /obj/structure/vehicleparts/axis/aircraft) ? axis : null

// A frame of hers with a working door, or null.
/obj/structure/vehicleparts/axis/aircraft/proc/door_frame()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		if (F.opening_walls().len)
			return F
	return null

// Her cockpit, or the first of her frames when none is called one.
/obj/structure/vehicleparts/axis/aircraft/proc/canopy_frame()
	var/list/F = frames()
	for (var/obj/structure/vehicleparts/frame/car/aircraft/cockpit/C in F)
		return C
	for (var/obj/structure/vehicleparts/frame/car/aircraft/A in F)
		return A
	return null

// Why H cannot bail out of the aircraft this frame belongs to, or null.
/obj/structure/vehicleparts/frame/car/aircraft/proc/bailout_refusal(mob/living/human/H)
	var/obj/structure/vehicleparts/axis/aircraft/A = aircraft()
	if (!A)
		return "This is no aircraft."
	if (get_turf(H) != get_turf(src))
		return "You must be aboard her to bail out."
	if (H.travel_held())
		return "You cannot do that now."
	if (!A.airborne())
		return "She is on the ground: just climb out."
	if (!A.ground_z() || !bailout_landing(H))
		return "There is nothing below to land on."
	return null

// Where H comes down: the ground straight below, or the nearest open tile.
/obj/structure/vehicleparts/frame/car/aircraft/proc/bailout_landing(mob/living/human/H)
	var/obj/structure/vehicleparts/axis/aircraft/A = aircraft()
	var/gz = A ? A.ground_z() : 0
	if (!gz)
		return null
	var/turf/below = locate(H.x, H.y, gz)
	if (!below)
		return null
	if (!below.density)
		return below
	var/turf/best = null
	var/best_dist = 1000
	for (var/turf/T in range(2, below))
		if (T.density)
			continue
		var/d = get_dist(below, T)
		if (d < best_dist)
			best = T
			best_dist = d
	return best

// Opens her way out: a door, or the canopy jettisoned. Returns what was opened.
/obj/structure/vehicleparts/axis/aircraft/proc/open_for_bailout(mob/living/human/H)
	var/obj/structure/vehicleparts/frame/D = door_frame()
	if (D)
		if (!D.doors_open())
			D.door_unlocked = TRUE
			D.set_doors_open(TRUE)
		return "door"
	var/obj/structure/vehicleparts/frame/car/aircraft/C = canopy_frame()
	if (C && !C.canopy_gone)
		C.canopy_gone = TRUE
		playsound(get_turf(C), 'sound/effects/clang.ogg', 60)
		if (H)
			H.visible_message(SPAN_WARNING("[H] pulls the release and the canopy of \the [C] tears away in the slipstream!"))
	return "canopy"

// Bails H out. Returns the turf they land on, or null.
/obj/structure/vehicleparts/frame/car/aircraft/proc/bail_out(mob/living/human/H, instant = FALSE)
	var/why = bailout_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return null
	var/obj/structure/vehicleparts/axis/aircraft/A = aircraft()
	var/way = A.open_for_bailout(H)
	if (!instant)
		H.visible_message(SPAN_WARNING("[H] makes for the [way == "door" ? "open door" : "open cockpit"] to bail out..."))
		if (!do_after(H, AIRCRAFT_BAILOUT_TIME, src))
			return null
		why = bailout_refusal(H)
		if (why)
			to_chat(H, SPAN_WARNING(why))
			return null
	var/height = A.altitude
	var/turf/T = bailout_landing(H)
	H.forceMove(T)
	aircraft_bailout_landing(H, height)
	log_game("[key_name(H)] bailed out of [A] at altitude [height], landing at [T.x],[T.y],[T.z].")
	return T

// How a jumper comes down from altitude height.
/proc/aircraft_bailout_landing(mob/living/human/H, height)
	if (istype(H.back, /obj/item/weapon/storage/backpack/paratrooper))
		to_chat(H, SPAN_NOTICE("Your parachute cracks open above you and you drift down, landing on your feet."))
		playsound(get_turf(H), 'sound/effects/thud.ogg', 40)
		H.Weaken(1)
		return "parachute"
	if (height <= AIRCRAFT_LANDING_CLEARANCE)
		to_chat(H, SPAN_DANGER("You drop from her and land hard!"))
		H.adjustBruteLossByPart(20, "l_leg")
		H.adjustBruteLossByPart(20, "r_leg")
		H.Weaken(3)
		H.updatehealth()
		return "hard"
	to_chat(H, SPAN_DANGER("You fall from her with no parachute and hit the ground!"))
	H.adjustBruteLossByPart(300, "l_leg")
	H.adjustBruteLossByPart(300, "r_leg")
	if (height > AIRCRAFT_SURFACE_CEILING)
		H.adjustBruteLossByPart(150, "chest")
	if (hasorgans(H))
		for (var/zone in list("l_leg", "r_leg"))
			var/obj/item/organ/external/affecting = H.get_organ(zone)
			if (affecting)
				affecting.fracture()
	playsound(get_turf(H), 'sound/effects/thud.ogg', 80)
	H.Weaken(10)
	H.updatehealth()
	return "fall"

/obj/structure/vehicleparts/frame/car/aircraft/verb/bail_out_verb()
	set name = "Bail out"
	set category = null
	set src in view(0)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated())
		return
	bail_out(H)

/obj/structure/vehicleparts/frame/car/aircraft/examine(mob/user)
	. = ..()
	if (canopy_gone)
		to_chat(user, SPAN_WARNING("Her canopy has been jettisoned: two sheets of glass refit it on the ground."))

// On the ground, two sheets of glass refit a jettisoned canopy (called from
// breach_attackby, vehicle_breaches.dm).
/obj/structure/vehicleparts/frame/proc/canopy_refit(obj/item/I, mob/living/human/H)
	return FALSE

/obj/structure/vehicleparts/frame/car/aircraft/canopy_refit(obj/item/I, mob/living/human/H)
	if (!canopy_gone || !istype(I, /obj/item/stack/material/glass))
		return FALSE
	var/obj/structure/vehicleparts/axis/aircraft/A = aircraft()
	if (A && A.airborne())
		to_chat(H, SPAN_WARNING("She must be on the ground to refit her canopy."))
		return TRUE
	var/obj/item/stack/material/glass/G = I
	if (G.amount < AIRCRAFT_CANOPY_GLASS)
		to_chat(H, SPAN_WARNING("You need [AIRCRAFT_CANOPY_GLASS] sheets of glass to refit the canopy."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] starts fitting a new canopy to \the [src]."))
	if (!do_after(H, 8 SECONDS, src) || !canopy_gone || !G.use(AIRCRAFT_CANOPY_GLASS))
		return TRUE
	canopy_gone = FALSE
	H.visible_message(SPAN_NOTICE("[H] fits a new canopy to \the [src]."))
	return TRUE

#undef AIRCRAFT_BAILOUT_TIME
#undef AIRCRAFT_CANOPY_GLASS
