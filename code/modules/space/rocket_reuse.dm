// ============================================================
// Rocket reuse and wear (docs/rocket-plans.md)
// ------------------------------------------------------------
// Reuse belongs to each part, never the whole rocket. Every rocket section
// (rocket_works.dm) carries its own condition, flights and whether it was
// inspected since its last flight; a launch stand will not mount a section
// below ROCKET_SECTION_MIN_CONDITION or one not inspected.
//
// - In 1969 engines, tanks, decouplers, boosters and bays are spent at launch.
// - A crew capsule comes home with its crew when it has a heat shield under
//   it and parachutes over it. Its record rides the flight ("capsule"
//   payload field) to the capsule in orbit and home again. Where it comes
//   down sets its wear: landing rockets put it on dry ground beside the
//   crew (ROCKET_WEAR_SOFT); parachutes alone splash it down off the nearest
//   shore, where it is towed in (ROCKET_WEAR_SPLASH), or land it hard where
//   there is no water near (ROCKET_WEAR_HARD). The heat shield burns away;
//   the parachutes come back to be repacked; landing rockets come back worn.
// - From 2013 (ROCKET_FLYBACK_AGE) landing legs on the first stage fly it
//   back beside the stand after staging, each of its sections worn
//   ROCKET_WEAR_FLYBACK, at the cost of the propellant it keeps to land.
//
// Every returned section must be inspected (a wrench, a short wait) before
// it mounts again. Steel sheets restore frames and capsules, an engine
// overhaul kit restores an engine, and cloth repacks parachutes. Nothing is
// random. Nothing here stores world.time or an object ref.
// ============================================================

#define ROCKET_WEAR_SOFT 10
#define ROCKET_WEAR_SPLASH 15
#define ROCKET_WEAR_HARD 40
#define ROCKET_WEAR_FLYBACK 20
#define ROCKET_WEAR_LANDING_ROCKETS 30
#define ROCKET_REPAIR_PER_SHEET 4
#define ROCKET_CHUTE_CLOTH 10
#define ROCKET_INSPECT_TIME 50
#define ROCKET_SPLASH_RANGE 15
#define ROCKET_LAND_RANGE 7

// ---------------------------------------------------------------- inspection and repair

/obj/item/engine_overhaul_kit
	name = "engine overhaul kit"
	desc = "Turbopump seals, injector plates and a fresh igniter for a rocket engine. Use it on a worn engine section to restore it."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "airfilter_canister"
	w_class = ITEM_SIZE_NORMAL

/obj/structure/rocket_section/proc/engine()
	return piece in list("E", "V", "M")

/obj/structure/rocket_section/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (!istype(H))
		return ..()
	if (is_tool(W, TOOL_WRENCH))
		inspect(H)
		return TRUE
	if (istype(W, /obj/item/engine_overhaul_kit))
		if (!engine())
			to_chat(H, SPAN_WARNING("Only an engine takes an overhaul kit."))
			return TRUE
		if (condition >= 100)
			to_chat(H, SPAN_NOTICE("\The [src] needs no overhaul."))
			return TRUE
		condition = 100
		inspected = FALSE
		qdel(W)
		to_chat(H, SPAN_NOTICE("You overhaul \the [src]. Inspect it before it flies."))
		return TRUE
	if (piece == "R" && is_cloth_sheet(W))
		var/obj/item/stack/S = W
		if (condition >= 100)
			to_chat(H, SPAN_NOTICE("The parachutes are packed."))
			return TRUE
		if (!S.use(ROCKET_CHUTE_CLOTH))
			to_chat(H, SPAN_WARNING("Repacking the parachutes takes [ROCKET_CHUTE_CLOTH] cloth."))
			return TRUE
		condition = 100
		inspected = FALSE
		to_chat(H, SPAN_NOTICE("You repair and repack the parachutes. Inspect them before they fly."))
		return TRUE
	if (istype(W, /obj/item/stack/material/steel) && !engine() && piece != "R")
		var/obj/item/stack/material/steel/S = W
		var/sheets = min(S.amount, ceil((100 - condition) / ROCKET_REPAIR_PER_SHEET))
		if (sheets <= 0)
			to_chat(H, SPAN_NOTICE("\The [src] needs no repair."))
			return TRUE
		S.use(sheets)
		condition = min(100, condition + sheets * ROCKET_REPAIR_PER_SHEET)
		inspected = FALSE
		to_chat(H, SPAN_NOTICE("You repair \the [src] with [sheets] steel sheet\s ([round(condition)]%). Inspect it before it flies."))
		return TRUE
	return ..()

/obj/structure/rocket_section/proc/inspect(mob/living/human/H)
	if (H && !do_after(H, ROCKET_INSPECT_TIME, src))
		return FALSE
	if (QDELETED(src))
		return FALSE
	inspected = TRUE
	var/advice = ""
	if (condition < ROCKET_SECTION_MIN_CONDITION)
		advice = engine() ? " It needs an engine overhaul kit before it flies." : (piece == "R" ? " Repack them with cloth." : " Repair it with steel sheets.")
	if (H)
		to_chat(H, SPAN_NOTICE("You inspect \the [src]: [round(condition)]% after [flights] flight\s.[advice]"))
	return TRUE

// A section coming back from a flight, worn, needing inspection.
/proc/rocket_section_returned(turf/T, piece, frame, condition, flights, wear)
	if (!T)
		return null
	var/obj/structure/rocket_section/S = new(T, piece, frame)
	S.condition = clamp(condition - wear, 0, 100)
	S.flights = flights + 1
	S.inspected = FALSE
	return S

// ---------------------------------------------------------------- the capsule's record

// What a launching rocket's capsule carries through the flight, or null.
/obj/structure/crewed_lander/modular_rocket/proc/capsule_record()
	var/datum/rocket_plan/D = plan()
	if (!D)
		return null
	var/list/have = sections()
	. = null
	for (var/i = 1, i <= have.len, i++)
		var/obj/structure/rocket_section/C = have[i]
		if (C.piece != "C")
			continue
		var/obj/structure/rocket_section/below = i > 1 ? have[i - 1] : null
		var/obj/structure/rocket_section/above = i < have.len ? have[i + 1] : null
		var/obj/structure/rocket_section/under = i > 2 ? have[i - 2] : null
		var/shield = below && (below.piece in list("X", "Y")) ? below.piece : ""
		var/chutes = above && above.piece == "R" ? 1 : 0
		var/landing = shield && under && under.piece == "L" ? 1 : 0
		. = list("c" = round(C.condition), "f" = C.flights, "x" = shield, "r" = chutes, "rc" = chutes ? round(above.condition) : 0, "rf" = chutes ? above.flights : 0, "l" = landing, "lc" = landing ? round(under.condition) : 0, "lf" = landing ? under.flights : 0)
		break
	qdel(D)

// TRUE when a payload's capsule record is absent or well formed.
/proc/rocket_capsule_record_ok(list/R)
	if (isnull(R))
		return TRUE
	if (!islist(R) || R.len != 9)
		return FALSE
	for (var/key in list("c", "f", "r", "rc", "rf", "l", "lc", "lf"))
		var/n = R[key]
		if (!isnum(n) || n < 0 || n > 10000 || n != round(n))
			return FALSE
	if (R["r"] > 1 || R["l"] > 1 || R["c"] > 100 || R["rc"] > 100 || R["lc"] > 100)
		return FALSE
	return R["x"] in list("", "X", "Y")

// TRUE when the record brings its crew home: a heat shield and parachutes.
/proc/rocket_capsule_can_return(list/R)
	return islist(R) && R["x"] && R["r"]

// The capsule in orbit keeps the record (orbital_flight.dm) and refuses to
// deorbit without a heat shield and parachutes.
/obj/structure/landed_lander/capsule/deorbit_refusal(mob/living/human/H)
	if (recovery && !rocket_capsule_can_return(recovery))
		return "\The [src] has no [recovery["x"] ? "parachutes" : "heat shield"] to come home on. Leave orbit from a station."
	return ..()

/obj/structure/landed_lander/capsule/flight_home_extras(list/flight)
	if (rocket_capsule_can_return(recovery))
		flight["capsule"] = recovery

// ---------------------------------------------------------------- coming down

// Where a returning capsule comes down near T, and the wear it takes:
// list(turf, wear, how).
/proc/rocket_capsule_landing(turf/T, list/R)
	if (!T)
		return null
	if (R["l"])
		var/turf/ground = rocket_landing_ground(T, ROCKET_LAND_RANGE, FALSE)
		if (ground)
			return list(ground, ROCKET_WEAR_SOFT, "settles onto its landing rockets")
	var/turf/shore = rocket_landing_ground(T, ROCKET_SPLASH_RANGE, TRUE)
	if (shore)
		return list(shore, ROCKET_WEAR_SPLASH, "splashes down offshore and is towed in")
	var/turf/hard = rocket_landing_ground(T, ROCKET_LAND_RANGE, FALSE)
	if (hard)
		return list(hard, ROCKET_WEAR_HARD, "comes down hard under its parachutes")
	return list(T, ROCKET_WEAR_HARD, "comes down hard under its parachutes")

// The clear dry floor nearest T within range; with by_water, only one beside water.
/proc/rocket_landing_ground(turf/T, range, by_water)
	var/turf/best = null
	var/best_d = 0
	for (var/turf/floor/F in range(range, T))
		if (istype(F, /turf/floor/beach/water) || !ledge_landing_clear(F))
			continue
		if (by_water)
			var/wet = FALSE
			for (var/d in cardinal)
				if (istype(get_step(F, d), /turf/floor/beach/water))
					wet = TRUE
					break
			if (!wet)
				continue
		var/d = get_dist(F, T)
		if (!best || d < best_d)
			best = F
			best_d = d
	return best

// The capsule, its parachutes and landing rockets come down once per flight.
/proc/rocket_capsules_recovered()
	var/static/list/seen
	if (!seen)
		seen = list()
	return seen

/proc/rocket_capsule_recover(list/P, turf/T)
	var/list/R = P["capsule"]
	if (!rocket_capsule_can_return(R) || !istext(P["lander"]))
		return null
	var/list/seen = rocket_capsules_recovered()
	if (seen[P["lander"]])
		return null
	seen[P["lander"]] = TRUE
	var/list/where = rocket_capsule_landing(T, R)
	var/turf/at = where[1]
	var/wear = where[2]
	var/obj/structure/rocket_section/C = rocket_section_returned(at, "C", null, R["c"], R["f"], wear)
	// The parachutes come back to be repacked; the heat shield is burnt away.
	rocket_section_returned(at, "R", null, R["rc"], R["rf"], 100)
	if (R["l"])
		rocket_section_returned(at, "L", null, R["lc"], R["lf"], ROCKET_WEAR_LANDING_ROCKETS)
	C.visible_message(SPAN_NOTICE("The capsule [where[3]]."))
	log_game("Rocket reuse: capsule of flight [P["lander"]] came down at [at.x],[at.y],[at.z], [round(C.condition)]%.")
	return C

// ---------------------------------------------------------------- flying back

// The first stage's sections, as records, when it flies back.
/obj/structure/crewed_lander/modular_rocket/proc/flyback_records()
	. = list()
	var/datum/rocket_plan/D = plan()
	if (!D || !D.first_stage_recovers())
		qdel(D)
		return
	var/list/first = D.segments()[1]
	var/list/have = sections()
	for (var/i in first)
		if (i > have.len)
			continue
		var/obj/structure/rocket_section/S = have[i]
		. += list(list(S.piece, S.frame, S.condition, S.flights))
	qdel(D)

// Lands flyback_records() taken before launch beside T.
/proc/rocket_flyback_land(turf/T, list/back)
	if (!T || !length(back))
		return
	var/turf/landing = rocket_landing_ground(T, ROCKET_LAND_RANGE, FALSE) || T
	for (var/list/rec in back)
		rocket_section_returned(landing, rec[1], rec[2], rec[3], rec[4], ROCKET_WEAR_FLYBACK)
	landing.visible_message(SPAN_NOTICE("The first stage flies back and drops onto its landing legs beside the stand."))
	log_game("Rocket reuse: first stage of [back.len] sections back at [landing.x],[landing.y],[landing.z].")

/obj/structure/crewed_lander/modular_rocket/launch(obj/structure/region_gate/trail_marker/launch_pad/pad, lx = null, ly = null, mob/living/human/notify = null)
	var/turf/T = get_turf(src)
	var/list/back = flyback_records()
	. = ..()
	if (isnull(.))
		rocket_flyback_land(T, back)

#undef ROCKET_WEAR_SOFT
#undef ROCKET_WEAR_SPLASH
#undef ROCKET_WEAR_HARD
#undef ROCKET_WEAR_FLYBACK
#undef ROCKET_WEAR_LANDING_ROCKETS
#undef ROCKET_REPAIR_PER_SHEET
#undef ROCKET_CHUTE_CLOTH
#undef ROCKET_INSPECT_TIME
#undef ROCKET_SPLASH_RANGE
#undef ROCKET_LAND_RANGE
