// ============================================================
// Digging out a hold in a refit at a berth (docs/berths.md)
// ------------------------------------------------------------
// A hull refitted to a draught (berth_refit.dm) that has a hold on its draught
// gets that hold dug out under her, as the slipway digs one under a new ship
// (slipway_draught.dm). Nobody can reach the rock under her deck, so the work
// is done from the tiller: "Dig out the hold" lays one hold floor at a time
// under a tile of her hull, then fits the draught's ladders down to it, paid
// from the stack in hand at the slipway's prices (ship_draught_decks and the
// ladder piece). Her hold is only ever added to: hold floors the draught does
// not have stay where they are.
// ============================================================

#define REFIT_HOLD_FLOOR_TIME 30 // ticks to dig and floor one tile of hold
#define REFIT_HOLD_LADDER_TIME 50 // ticks to fit one ladder down to it

/obj/structure/hull_tiller
	var/tmp/refit_digging = FALSE

// What her refit to draught D still wants in her hold, in the order it is
// done: list(kind, deck turf, hold turf) with kind "floor" or "ladder".
// Text when the draught cannot be laid over her.
/obj/structure/hull_tiller/proc/refit_hold_work(datum/ship_draught/D)
	var/list/hold = D.decks["-1"]
	if (!hold || !hold.len)
		return list()
	var/list/at = refit_turfs(D)
	if (istext(at))
		return at
	var/list/floors = list()
	var/list/ladders = list()
	for (var/key in hold)
		var/turf/T = at[key]
		var/turf/L = draught_level_turf(T, -1)
		if (!L)
			return "There is no level below her to dig a hold in."
		if (!hull_hold_cover(L))
			floors += list(list("floor", T, L))
		var/list/C = hold[key]
		if (C && C[1] == "X" && !(locate(/obj/structure/multiz/ladder) in L))
			ladders += list(list("ladder", T, L))
	return floors + ladders

// What one piece of hold work costs: material key -> amount.
/proc/refit_hold_cost(list/W)
	if (W[1] == "ladder")
		var/list/X = ship_draught_pieces()["X"]
		return X["cost"]
	var/list/deck = ship_draught_decks["-1"]
	return deck["cost"]

// Why piece W of her hold cannot be done now, or null.
/obj/structure/hull_tiller/proc/refit_hold_refusal(list/W)
	var/datum/craft_body/built/B = body()
	if (!istype(B))
		return "She is not commissioned."
	var/turf/T = W[2]
	var/turf/L = W[3]
	if (!(T in B.cells()))
		return "Her deck must be laid at [T.x],[T.y] before her hold is dug under it."
	if (W[1] == "ladder")
		if (!hull_hold_cover(L))
			return "Dig out her hold at [T.x],[T.y] before the ladder down to it is fitted."
		if (locate(/obj/structure/multiz) in T)
			return "Something already climbs from her deck at [T.x],[T.y]."
		return null
	if (!hull_hold_ground(L) || (locate(/obj/covers) in L))
		return "Her hold cannot be dug in [L.name] under her at [T.x],[T.y]: it wants rock or deep water."
	if (B.offsets.len + B.upper_tile_count() + B.top_tile_count() + B.lower_tile_count() + 1 > BUILT_HULL_MAX_DECK_TILES)
		return "Her decks and hold would be more than [BUILT_HULL_MAX_DECK_TILES] tiles in all: she could not sail."
	return null

// Does the work: floors first, then ladders.
/obj/structure/hull_tiller/proc/refit_hold_place(list/W)
	var/turf/T = W[2]
	var/turf/L = W[3]
	if (W[1] == "floor")
		return hull_hold_lay(L)
	var/obj/structure/multiz/ladder/up/placed/up = new(L)
	var/obj/structure/multiz/ladder/placed/down = new(T)
	up.find_target()
	down.find_target()
	return up

// "1 steel", "4 wood".
/proc/refit_hold_cost_text(list/cost)
	var/list/parts = list()
	for (var/key in cost)
		parts += "[cost[key]] [key]"
	return english_list(parts)

// The shipwright at her tiller digs out her hold with the stack in hand, piece
// after piece while it pays.
/obj/structure/hull_tiller/proc/dig_out_hold(mob/living/human/H)
	if (refit_digging)
		to_chat(H, SPAN_WARNING("Her hold is already being dug out."))
		return
	var/why = refit_refusal()
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	var/code = refit_code
	var/datum/ship_draught/D = ship_draught_from_code(code)
	if (!D)
		to_chat(H, SPAN_WARNING("The draught cannot be read."))
		return
	var/obj/item/stack/S = H.get_active_hand()
	var/dug = 0
	refit_digging = TRUE
	while (TRUE)
		var/list/work = refit_hold_work(D)
		if (istext(work))
			to_chat(H, SPAN_WARNING(work))
			break
		if (!work.len)
			to_chat(H, SPAN_NOTICE("Her hold is dug out to her draught."))
			break
		var/key = (istype(S) && !QDELETED(S)) ? piece_material(S) : null
		var/list/W = null
		for (var/list/E in work)
			var/list/cost = refit_hold_cost(E)
			if (key && cost[key] && S.amount >= cost[key])
				W = E
				break
		if (!W)
			if (!dug)
				to_chat(H, SPAN_WARNING("Hold the materials in your hand: the next piece of her hold needs [refit_hold_cost_text(refit_hold_cost(work[1]))]."))
			break
		var/refusal = refit_hold_refusal(W)
		if (refusal)
			to_chat(H, SPAN_WARNING(refusal))
			break
		if (!dug)
			to_chat(H, SPAN_NOTICE("You set the crew to work on her hold..."))
		var/time = W[1] == "ladder" ? REFIT_HOLD_LADDER_TIME : REFIT_HOLD_FLOOR_TIME
		if (!do_after(H, yard_time(src, time), src) || QDELETED(src) || QDELETED(S) || S.loc != H || refit_code != code || refit_refusal() || refit_hold_refusal(W))
			break
		var/list/cost = refit_hold_cost(W)
		if (S.amount < cost[key] || !refit_hold_place(W))
			break
		S.use(cost[key])
		dug++
	refit_digging = FALSE
	qdel(D)
	if (!dug)
		return
	if (craft && craft.ledger)
		craft.ledger.bays_dirty = TRUE
	log_game("[key_name(H)] dug out [dug] piece\s of the hold of the [craft ? craft.name : "hull"] at [x],[y],[z].")
	var/result = mark_refit()
	H.visible_message(SPAN_NOTICE("[H]'s crew works on the hold of the [craft ? craft.name : "hull"]."), SPAN_NOTICE("[dug] piece\s of her hold [dug == 1 ? "is" : "are"] done.[refit_hold_left ? " [refit_hold_left] still to dig out." : ""]"))
	if (islist(result) && !refit_hold_left)
		report_refit(H, result, FALSE)

#undef REFIT_HOLD_FLOOR_TIME
#undef REFIT_HOLD_LADDER_TIME
