// ============================================================
// Reusable launch (orbital stations, stage D, 2026)
// ------------------------------------------------------------
// From 2026 a party can build a reusable rocket: a crew ship with eight
// seats on a booster that flies back. It flies to orbit like the two-stage
// rocket, but after a launch the booster lands beside the pad again with
// its tank empty and some wear. Only the crew ship and its hold travel.
//
// - Condition runs from 0 to 100, a plain saved number. Each flight costs
//   ORBIT_BOOSTER_WEAR. A booster below that will not fly until it is
//   refurbished: each steel sheet restores ORBIT_BOOSTER_REFIT_PER_SHEET.
// - The crew ship arrives in orbit as a capsule with eight seats home, so
//   the whole crew can deorbit together (the "seats" flight field).
// ============================================================

#define ORBIT_REUSABLE_AGE 9
#define ORBIT_CREW_SHIP_SEATS 8
#define ORBIT_BOOSTER_WEAR 20
#define ORBIT_BOOSTER_REFIT_PER_SHEET 4

// TRUE when n is a valid seat count for a flight's capsule.
/proc/space_flight_seats_ok(n)
	return isnum(n) && n >= 1 && n <= ORBIT_CREW_SHIP_SEATS && n == round(n)

/obj/structure/crewed_lander/orbital_rocket/reusable
	name = "reusable rocket"
	desc = "A crew ship with eight seats on a booster that lands itself again. Fill it with rocket propellant beside a launch pad pointed at orbit, strap in on its tile and launch; the booster comes back to the pad."
	seats = ORBIT_CREW_SHIP_SEATS
	// 0 to 100; never a world.time stamp.
	var/condition = 100

/obj/structure/crewed_lander/orbital_rocket/reusable/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Booster condition: [round(condition)]%. Each flight wears it by [ORBIT_BOOSTER_WEAR]; steel sheets refurbish it."))

/obj/structure/crewed_lander/orbital_rocket/reusable/vehicle_refusal(destination)
	. = ..()
	if (.)
		return
	if (!map || map.ordinal_age < ORBIT_REUSABLE_AGE)
		return "Reusable rockets only fly from 2026."
	if (condition < ORBIT_BOOSTER_WEAR)
		return "The booster is too worn to fly. Refurbish it with steel sheets."
	return null

/obj/structure/crewed_lander/orbital_rocket/reusable/flight_extras(list/flight)
	flight["seats"] = seats

/obj/structure/crewed_lander/orbital_rocket/reusable/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/steel))
		var/obj/item/stack/material/steel/S = W
		var/sheets = min(S.amount, ceil((100 - condition) / ORBIT_BOOSTER_REFIT_PER_SHEET))
		if (sheets <= 0)
			to_chat(user, SPAN_NOTICE("\The [src]'s booster needs no refurbishing."))
			return
		S.use(sheets)
		condition = min(100, condition + sheets * ORBIT_BOOSTER_REFIT_PER_SHEET)
		to_chat(user, SPAN_NOTICE("You refurbish the booster with [sheets] steel sheet\s ([round(condition)]%)."))
		return
	return ..()

// The booster lands back at T after a flight. Returns the landed booster.
/proc/orbit_booster_return(turf/T, condition)
	if (!T)
		return null
	var/obj/structure/crewed_lander/orbital_rocket/reusable/B = new(T)
	B.condition = clamp(condition, 0, 100)
	B.propellant = 0
	B.visible_message(SPAN_NOTICE("\The [B]'s booster drops back onto its legs beside the pad."))
	return B

/obj/structure/crewed_lander/orbital_rocket/reusable/launch(obj/structure/region_gate/trail_marker/launch_pad/pad, lx = null, ly = null, mob/living/human/notify = null)
	var/turf/T = get_turf(src)
	var/left = condition - ORBIT_BOOSTER_WEAR
	. = ..()
	if (isnull(.))
		orbit_booster_return(T, left)
		log_game("Reusable launch: booster back at [T.x],[T.y],[T.z] at [left]%.")
