// ============================================================
// Breaking a ship up for parts at a berth (docs/berths.md)
// ------------------------------------------------------------
// A built hull lying still at a berth (berth.dm: a boathouse slip, a slipway
// after a haul-out, a drydock) can be taken apart for what she is made of.
// The berth's menu offers "Break up the <name> for parts" and shows what
// comes back and roughly how long it takes before anyone starts; the work
// only begins once the player says yes.
//
// - Who may: a registered ship only by a member of the party she is
//   registered to, or her listed captain. A ship registered to nobody may be
//   broken up by any player with a Discord-verified account.
// - What comes back: everything her floors, fittings and gunwales cost to
//   build by hand (the ship's draught tables), less for damaged parts: each
//   part gives back its cost times its condition (breakup_part_condition),
//   and a patched plank counts as half worn. Totals are rounded down and
//   stacked by the berth, so a ship never gives back more than she cost.
// - Everything aboard that is not part of her (cargo, chests' contents,
//   engines, machines, cannons the draught does not know) is set down by the
//   berth whole: nothing is lost with her.
// - How long: half of what laying her floors and setting her fittings on a
//   slipway takes (three seconds a floor, five a fitting), shortened by a
//   yard office near (yard_office.dm). Several people can work on her at
//   once; the work done is kept on her tiller until the world restarts.
// - She is refused while anyone alive is aboard, while a vehicle is parked
//   on her, while she is under way, grappled or bound on a voyage.
// ============================================================

#define BREAKUP_FLOOR_TIME 15  // half of SLIPWAY_FLOOR_TIME, ticks per floor
#define BREAKUP_FIT_TIME 25    // half of SLIPWAY_FIT_TIME, ticks per fitting
#define BREAKUP_STEP 50        // ticks of work between progress checks
#define BREAKUP_PATCH_CONDITION 0.5 // a patched plank is worth half a sound one

/obj/structure/hull_tiller
	var/tmp/breakup_done = 0           // ticks of breaking-up work done on her
	var/tmp/list/breakup_hands = null  // who is at work on her now

// What part M of a hull costs to build by hand: material = amount. An empty
// list for a part that gives nothing back; null when M is not part of her
// (it is set down by the berth whole).
/proc/berth_breakup_part_cost(atom/movable/M)
	var/list/pieces = ship_draught_pieces()
	if (istype(M, /obj/covers))
		var/obj/covers/C = M
		if (C.wall)
			return pieces["W"]["cost"]
		if (istype(C, /obj/covers/steelplating) || istype(C, /obj/covers/metal))
			return ship_draught_floors()["s"]["cost"]
		return ship_draught_floors()["w"]["cost"]
	if (istype(M, /obj/roof))
		return list() // her deck above is paid for by the floor laid on it
	if (istype(M, /obj/structure/vehicleparts/movement/sail))
		var/obj/structure/vehicleparts/movement/sail/S = M
		if (S.crows_nest)
			return pieces["N"]["cost"]
	for (var/key in pieces)
		if (M.type == pieces[key]["path"])
			return pieces[key]["cost"]
	// Close kin of a piece, as a survey draws them (ship_draught_piece_on).
	if (hull_gun_port(M))
		return istype(M, /obj/structure/railing/built/gunwale/bulwark) ? list("steel" = 4) : list("wood" = 4)
	if (istype(M, /obj/structure/railing/built/gunwale))
		return istype(M, /obj/structure/railing/built/gunwale/bulwark) ? list("steel" = 2) : list("wood" = 2)
	if (istype(M, /obj/structure/hull_tiller))
		return pieces["T"]["cost"]
	if (istype(M, /obj/structure/multiz/ladder/up))
		return pieces["X"]["cost"]
	if (istype(M, /obj/structure/multiz/ladder))
		return list() // the head of a ladder standing on the deck below
	if (istype(M, /obj/structure/simple_door))
		return pieces["D"]["cost"]
	if (istype(M, /obj/structure/window_frame))
		return pieces["G"]["cost"]
	if (istype(M, /obj/structure/closet/crate))
		return pieces["C"]["cost"]
	return null

// Every tile of her, upper decks first and her hold last.
/obj/structure/hull_tiller/proc/breakup_turfs()
	. = list()
	var/datum/craft_body/built/B = body()
	if (!istype(B) || !B.placed())
		return
	var/list/deck = B.cells()
	var/list/above = B.upper_cells(deck)
	for (var/turf/A in B.top_cells(above))
		. += A
	for (var/turf/U in above)
		. += U
	. += deck
	for (var/turf/L in B.lower_cells(deck))
		. += L

// What breaking her up takes and gives: list("parts" = atoms to take apart,
// "loose" = atoms set down whole, "cost" = what her parts cost to build,
// "time" = ticks of work, "refusal" = why not, or null).
/obj/structure/hull_tiller/proc/breakup_inventory()
	. = list("parts" = list(), "loose" = list(), "cost" = list(), "worth" = list(), "time" = 0, "refusal" = null)
	for (var/turf/T in breakup_turfs())
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || !M.simulated)
				continue
			if (isliving(M))
				var/mob/living/L = M
				if (L.stat != DEAD)
					.["refusal"] = "[L] is aboard her: everyone must be off her before she is broken up."
					return
			if (istype(M, /obj/structure/vehicle) || istype(M, /obj/structure/vehicleparts/axis))
				.["refusal"] = "\The [M] is aboard her: take it off before she is broken up."
				return
			if (istype(M, /obj/structure/region_gate) || istype(M, /obj/structure/berth_refit_mark) || !M.craft_cargo())
				continue
			var/list/cost = ismob(M) ? null : berth_breakup_part_cost(M)
			if (isnull(cost))
				.["loose"] += M
				continue
			.["parts"] += M
			ship_draught_add_cost(.["cost"], cost)
			var/condition = breakup_part_condition(M)
			for (var/key in cost)
				.["worth"][key] = (.["worth"][key] || 0) + cost[key] * condition
			.["time"] += istype(M, /obj/covers) ? BREAKUP_FLOOR_TIME : (istype(M, /obj/roof) ? 0 : BREAKUP_FIT_TIME)

// How sound part M is, from 0 (wrecked) to 1 (as built): its health
// against its most where it keeps them, half for a patched plank or a broken
// vehicle frame, else 1.
/proc/breakup_part_condition(atom/movable/M)
	if (istype(M, /obj/covers/repairedfloor/ship/patch))
		return BREAKUP_PATCH_CONDITION
	if (istype(M, /obj/structure/vehicleparts/frame))
		var/obj/structure/vehicleparts/frame/F = M
		if (F.broken)
			return BREAKUP_PATCH_CONDITION
	for (var/most in list("maxhealth", "max_health", "initial_health"))
		if ((most in M.vars) && ("health" in M.vars))
			var/top = M.vars[most]
			var/now = M.vars["health"]
			if (isnum(top) && top > 0 && isnum(now))
				return clamp(now / top, 0, 1)
	return 1

// What comes back for parts worth worth (material = amount, fractions
// allowed): each total rounded down.
/proc/berth_breakup_reclaim(list/worth)
	. = list()
	for (var/key in worth)
		var/n = round(worth[key])
		if (n > 0)
			.[key] = n

// Why H may not break her up, or null.
/obj/structure/hull_tiller/proc/breakup_refusal(mob/living/human/H)
	if (!craft || !craft.ledger)
		return "Only a commissioned hull can be broken up."
	if (craft.ledger.under_way())
		return "Bring the [craft.name] to a stop first."
	if (craft.grapple)
		return "The [craft.name] is grappled to another ship: she must lie free before she is broken up."
	if (voyage || crossing_hold_current())
		return "The [craft.name] is bound on a voyage."
	if (!craft_berth(craft))
		return "A ship is broken up at a berth: a boathouse slip, a slipway or a drydock."
	if (!istype(H))
		return null
	var/datum/craft_register/R = craft.register
	if (R && R.party)
		if (!R.is_owner(H) && R.role_of(H) != CRAFT_ROLE_CAPTAIN)
			return "The [craft.name] is registered to [party_train_party_name(R.party)]: only they or her captain may break her up."
	else if (!H.client || !verified_discord_id(H.client.ckey))
		return "The [craft.name] is registered to nobody: only a Discord-verified player may break her up. Use OOC > Verify Discord first."
	return null

// Takes her apart: her parts are deleted, what comes back is stacked at
// drop, and what was aboard that is not hers is set down there whole.
// Returns what came back (material = amount), or the reason she stayed.
/obj/structure/hull_tiller/proc/break_up(turf/drop)
	var/why = breakup_refusal(null)
	if (why)
		return why
	var/list/I = breakup_inventory()
	if (I["refusal"])
		return I["refusal"]
	var/datum/craft_body/built/B = body()
	// The ground her hold was hollowed from closes again (hull_hold.dm).
	var/list/origin = list()
	for (var/turf/L in B.lower_cells(B.cells()))
		var/obj/covers/HC = hull_hold_cover(L)
		origin[L] = HC ? HC.hold_origin : "[/turf/wall/rockwall]"
	var/hull_name = craft.name
	decommission()
	for (var/atom/movable/M in I["loose"])
		if (!QDELETED(M))
			M.forceMove(drop)
	// What stands on her first, then her floors and roofs, so nothing falls
	// through a deck already gone.
	for (var/pass = 1, pass <= 2, pass++)
		for (var/atom/movable/M in I["parts"])
			if (QDELETED(M) || M == src || (pass == 2) != (istype(M, /obj/covers) || istype(M, /obj/roof)))
				continue
			// A chest's contents are cargo, not parts.
			if (istype(M, /obj/structure/closet))
				for (var/atom/movable/inside in M)
					inside.forceMove(drop)
			qdel(M)
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/L in origin)
		L.ChangeTurf(hull_hold_origin_path(origin[L]))
	wall_bulk_placement = old_bulk
	. = piece_refund(berth_breakup_reclaim(I["worth"]), drop)
	log_game("Berth breakup: the [hull_name] at [x],[y],[z] was broken up ([length(I["parts"])] parts, [length(I["loose"])] things set down); back: [piece_cost_text(.)].")
	qdel(src)

// "about 4 minutes", "under a minute".
/proc/berth_breakup_time_text(ticks)
	if (ticks < 600)
		return "under a minute"
	var/minutes = round(ticks / 600 + 0.5)
	return "about [minutes] minute\s"

// The tiller that commissioned built hull C, or null.
/proc/berth_breakup_tiller(datum/craft/C)
	var/datum/craft_body/built/B = C ? C.body : null
	if (!istype(B) || !B.placed())
		return null
	for (var/obj/structure/hull_tiller/T in locate(B.px, B.py, B.z))
		if (T.craft == C)
			return T
	return null

// The berth's menu entries for breaking up the hulls it holds.
/obj/structure/proc/breakup_options(list/options, list/hulls)
	for (var/datum/craft/C in hulls)
		if (berth_breakup_tiller(C))
			options["Break up the [C.name] for parts"] = C

// The berth's "Break up" choice for craft C, after asking H to confirm.
/obj/structure/proc/breakup_action(mob/living/human/H, datum/craft/C)
	var/obj/structure/hull_tiller/T = berth_breakup_tiller(C)
	if (!T)
		return
	var/why = T.breakup_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	var/list/I = T.breakup_inventory()
	if (I["refusal"])
		to_chat(H, SPAN_WARNING(I["refusal"]))
		return
	var/list/back = berth_breakup_reclaim(I["worth"])
	var/left = max(0, yard_time(src, I["time"] - T.breakup_done))
	var/list/lines = list("Break up the [C.name] for parts? She is taken apart for good and cannot be put back together.")
	if (back.len)
		lines += "You get back [piece_cost_text(back)], stacked by \the [src]: everything her parts cost to build, less for any that are damaged or patched."
	else
		lines += "You get nothing back for her parts."
	lines += "Her cargo and everything else aboard that is not part of her is set down whole by \the [src]; none of it is lost."
	lines += "[T.breakup_done ? "The work left takes" : "It takes"] [berth_breakup_time_text(left)] for one pair of hands; more hands make it quicker."
	if (WWinput(H, jointext(lines, " "), name, "No", list("Yes", "No")) != "Yes")
		return
	// Things may have changed while the question was open.
	if (QDELETED(src) || QDELETED(T) || !T.craft || !Adjacent(H))
		return
	why = T.breakup_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	work_breakup(H, T)

// H works at breaking T's hull up until she is gone, they stop, or something
// stops them.
/obj/structure/proc/work_breakup(mob/living/human/H, obj/structure/hull_tiller/T)
	if (!T.breakup_hands)
		T.breakup_hands = list()
	if (H in T.breakup_hands)
		to_chat(H, SPAN_WARNING("You are already at work on her."))
		return
	var/hull_name = T.craft.name
	T.breakup_hands += H
	H.visible_message(SPAN_NOTICE("[H] starts breaking up the [hull_name] for parts."), SPAN_NOTICE("You start breaking up the [hull_name]. Stay by \the [src] and keep still to keep working."))
	log_game("[key_name(H)] started breaking up the [hull_name] at [T.x],[T.y],[T.z] (berth [src] at [x],[y],[z]).")
	while (TRUE)
		if (!do_after(H, yard_time(src, BREAKUP_STEP), src) || QDELETED(src) || QDELETED(T) || !Adjacent(H))
			break
		var/why = T.breakup_refusal(H)
		var/list/I = why ? null : T.breakup_inventory()
		if (!why && I["refusal"])
			why = I["refusal"]
		if (why)
			to_chat(H, SPAN_WARNING(why))
			break
		T.breakup_done += BREAKUP_STEP
		if (T.breakup_done < I["time"])
			continue
		var/result = T.break_up(get_turf(src))
		if (istext(result))
			to_chat(H, SPAN_WARNING(result))
			break
		var/list/back = result
		H.visible_message(SPAN_NOTICE("The [hull_name] is broken up for parts."), SPAN_NOTICE("The [hull_name] is broken up.[back.len ? " [capitalize(piece_cost_text(back))] [back.len == 1 && back[back[1]] == 1 ? "is" : "are"] stacked by \the [src]." : ""]"))
		log_game("[key_name(H)] finished breaking up the [hull_name] at [src] at [x],[y],[z].")
		return
	if (!QDELETED(T) && T.breakup_hands)
		T.breakup_hands -= H
		var/list/state = T.breakup_inventory()
		if (!state["refusal"] && state["time"] > 0)
			to_chat(H, SPAN_NOTICE("You stop. The [hull_name] is [min(99, round(100 * T.breakup_done / state["time"]))]% broken up; the work done on her is kept, and she stays whole until it is finished."))

// ---- The berths ----

/obj/structure/slipway/proc/breakup_hulls()
	var/datum/craft/C = hauled_hull()
	return C ? list(C) : list()

/obj/structure/boathouse/proc/breakup_hulls()
	return hulls_in_slip()

/obj/structure/canal_lock/dock_gate/proc/breakup_hulls()
	return hulls_in_basin()

#undef BREAKUP_FLOOR_TIME
#undef BREAKUP_FIT_TIME
#undef BREAKUP_STEP
#undef BREAKUP_PATCH_CONDITION
