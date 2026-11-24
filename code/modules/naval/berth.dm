// ============================================================
// Berths (docs/berths.md): places that hold a boat for her upkeep
// ------------------------------------------------------------
// Any place that holds a boat is a berth: the boathouse slip now, the
// slipway and the drydock as they learn to hold a hull. A built hull lying
// still with every tile of her inside a berth can be worked on as if she
// lay in the shallows, wherever the water under her is deep:
//
// - her seams can be caulked right down to tight (hull_caulking.dm);
// - her bottom can be scraped and sheathed in copper (hull_fouling.dm);
// - her patches can be planked over for good: use one piece of wood (or one
//   steel sheet) on a patch, hammer in the other hand, standing on her deck
//   beside it. The patch becomes ordinary hull and stops weeping;
// - the berth's "Survey her condition" lists what she needs and what it
//   costs.
//
// A small boat stored in a boathouse dries out three times as fast as one
// left on the shore.
//
// Work at a berth costs what the same work costs by hand: a berth saves
// trouble, not materials. A berth keeps no record of the hulls in it: it is
// asked each time, from where she lies.
// ============================================================

// How far from a tile of her a berth structure may stand and still hold her.
#define BERTH_REACH 8
// Deciseconds to plank over one patch.
#define BERTH_PLANK_TIME 40
// How much faster a small boat dries stored in a boathouse.
#define BOATHOUSE_DRY_FACTOR 3

// ---- Which berth holds her ----

// TRUE when this structure is a berth holding every tile of C (the cells
// her body covers now).
/obj/structure/proc/berth_holds(datum/craft/C, list/cells)
	return FALSE

// TRUE when the berth holds C out of the water (hauled out or drained).
/obj/structure/proc/berth_dry(datum/craft/C)
	return FALSE

// The berth that holds every tile of C, or null.
/proc/craft_berth(datum/craft/C)
	if (!C || !C.body || !C.body.placed())
		return null
	var/list/cells = C.body.cells()
	if (!cells.len)
		return null
	var/turf/T = cells[1]
	// A dock basin, flooded or pumped dry (drydock.dm).
	var/obj/structure/canal_lock/dock_gate/G = dock_basin_turfs[T]
	if (G && !QDELETED(G) && G.berth_holds(C, cells))
		return G
	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded))
		for (var/obj/structure/boathouse/B in range(BERTH_REACH, T))
			if (B.berth_holds(C, cells))
				return B
		return null
	// On dry ground: a slipway next to one of her tiles (slipway_haul.dm).
	var/list/seen = list()
	for (var/turf/O in cells)
		for (var/obj/structure/slipway/S in range(1, O))
			if (seen[S])
				continue
			seen[S] = TRUE
			if (S.berth_holds(C, cells))
				return S
	return null

// TRUE when she lies at a berth out of the water.
/datum/hull_ledger/proc/lies_dry()
	var/obj/structure/S = craft_berth(craft)
	return S && S.berth_dry(craft)

// The boathouse holds a hull lying wholly in its slip.
/obj/structure/boathouse/berth_holds(datum/craft/C, list/cells)
	if (!C || !cells || !cells.len)
		return FALSE
	var/list/slip = slip()
	for (var/turf/T in cells)
		if (!(T in slip))
			return FALSE
	return TRUE

// The built hulls lying wholly in the slip.
/obj/structure/boathouse/proc/hulls_in_slip()
	. = list()
	var/list/seen = list()
	for (var/turf/T in slip())
		var/datum/craft/C = craft_at(T)
		if (!C || seen[C] || !C.ledger)
			continue
		seen[C] = TRUE
		if (berth_holds(C, C.body.cells()))
			. += C

// TRUE when her bottom and her seams can be got at where she lies: in the
// shallows, or at a berth.
/datum/hull_ledger/proc/bottom_reachable()
	return !over_deep() || craft_berth(craft)

// ---- Planking over a patch ----

// The floor a stack lays over a patch, or null.
/proc/berth_plank_path(obj/item/stack/W)
	if (istype(W, /obj/item/stack/material/steel))
		return /obj/covers/steelplating
	if (istype(W, /obj/item/stack/material/wood))
		return /obj/covers/repairedfloor/ship
	return null

// Why H cannot plank over the patch P with W, or null.
/proc/berth_plank_refusal(mob/living/human/H, obj/item/stack/W, obj/covers/repairedfloor/ship/patch/P)
	if (!istype(H) || !istype(W) || !istype(P))
		return "nothing to plank over"
	var/turf/T = get_turf(P)
	var/datum/craft/C = T ? craft_at(T) : null
	if (!C || !C.ledger)
		return "that is not a hull afloat"
	if (!berth_plank_path(W))
		return "a patch is planked over with wood or plated with steel"
	var/turf/at = get_turf(H)
	if (!at || get_dist(at, T) > 1 || !C.body.contains(at))
		return "stand on her deck beside the patch"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state for it"
	if (C.ledger.under_way())
		return "she must lie still"
	if (!craft_berth(C))
		return "a patch can only be cut out and planked over at a berth, such as a boathouse slip"
	if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
		return "you need a hammer in your other hand"
	if (W.amount < 1)
		return "you have nothing left to lay"
	return null

// Lays the new floor where the patch was and pays for it. Returns the floor.
/proc/berth_plank_lay(datum/craft/C, obj/item/stack/W, obj/covers/repairedfloor/ship/patch/P)
	var/turf/T = get_turf(P)
	var/path = berth_plank_path(W)
	if (!T || !path || !W.use(1))
		return null
	var/obj/covers/N = new path(T)
	N.afloat = TRUE
	N.updateturf()
	qdel(P)
	var/datum/hull_ledger/L = C.ledger
	L.survey()
	C.crew_message(SPAN_NOTICE("The patch at [T.x], [T.y] is cut out and [istype(N, /obj/covers/steelplating) ? "plated" : "planked"] over. [L.patches ? "[L.patches] patch[L.patches == 1 ? "" : "es"] still weep[L.patches == 1 ? "s" : ""]." : "No patch is left in her."]"))
	return N

// H planks over the patch P.
/proc/berth_plank(mob/living/human/H, obj/item/stack/W, obj/covers/repairedfloor/ship/patch/P)
	var/why = berth_plank_refusal(H, W, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot plank over that patch: [why]."))
		return null
	var/datum/craft/C = craft_at(get_turf(P))
	H.visible_message(SPAN_NOTICE("[H] starts cutting out a patch in the [C.name]."), SPAN_NOTICE("You start cutting out the patch and laying sound hull in its place."))
	playsound(get_turf(P), 'sound/items/Screwdriver.ogg', 50, TRUE)
	if (!do_after(H, yard_time(P, BERTH_PLANK_TIME), P) || QDELETED(W) || QDELETED(P) || H.get_active_hand() != W)
		return null
	if (berth_plank_refusal(H, W, P))
		return null
	var/obj/covers/deck = berth_plank_lay(C, W, P)
	if (deck && !QDELETED(deck) && deck.type == /obj/covers/repairedfloor/ship)
		H.note_craftsman_work("plank-hull", /obj/covers/repairedfloor/ship, 1)
	return deck

/obj/covers/repairedfloor/ship/patch/attackby(obj/item/W as obj, mob/user as mob)
	if (ishuman(user) && user.a_intent != I_HARM && berth_plank_path(W))
		var/turf/T = get_turf(src)
		var/datum/craft/C = T ? craft_at(T) : null
		if (C && C.ledger)
			berth_plank(user, W, src)
			return TRUE
	return ..()

// ---- Survey her condition ----

// What she needs done and what it costs, as a list of lines.
/datum/hull_ledger/proc/berth_work()
	. = list()
	if (holes > 0)
		. += "[holes] hole\s to patch: [holes * HULL_PATCH_PLANKS] wood, hammer in the other hand."
	if (patches > 0)
		. += "[patches] patch[patches == 1 ? "" : "es"] to plank over: [patches] wood or steel sheet\s, hammer in the other hand."
	if (water >= 1)
		. += "[round(water)] bucketful\s of water to bail."
	var/twists = caulk_wanted()
	if (twists > 0)
		. += "Seams to caulk tight: [twists] twist\s of tarred oakum, chisel or hammer in the other hand."
	var/goes = scrape_wanted()
	if (goes > 0)
		. += "Bottom to scrape: [goes] go[goes == 1 ? "" : "es"] with a shovel or a knife."
	if (takes_copper() && copper_wanted() > 0)
		. += "Copper sheathing to finish (optional): [copper_wanted()] copper sheet\s, hammer in the other hand."

/datum/hull_ledger/proc/berth_condition_text()
	. = "<b>The [craft ? craft.name : "hull"].</b> [status_text()]"
	var/list/work = berth_work()
	if (!work.len)
		. += "<br>Nothing needs doing: she is as sound as she can be made."
		return
	. += "<br><b>Work wanted:</b>"
	for (var/line in work)
		. += "<br>- [line]"

/obj/structure/vehicle/proc/berth_condition_text()
	return "<b>[capitalize(name)].</b>[small_craft_text()]"

/obj/structure/vehicle/raft/berth_condition_text()
	. = ..()
	var/upkeep = upkeep_text()
	. += upkeep ? upkeep : " She wants no upkeep."
	if (istype(loc, /obj/structure/boathouse_stored_tile))
		. += " Stored here, she dries out [BOATHOUSE_DRY_FACTOR] times as fast as on the shore."

// The condition of every hull and small boat in the slip or stored.
/obj/structure/boathouse/proc/condition_report()
	. = list()
	for (var/datum/craft/C in hulls_in_slip())
		. += C.ledger.berth_condition_text()
	for (var/atom/movable/M in boats_in_slip())
		var/obj/structure/vehicle/V = M
		if (istype(V))
			. += V.berth_condition_text()
	for (var/obj/structure/boathouse_stored/B in stored_boats())
		var/obj/structure/vehicle/V = B.boat()
		if (istype(V))
			. += V.berth_condition_text()

/obj/structure/boathouse/proc/show_condition(mob/living/human/H)
	var/list/report = condition_report()
	if (!report.len)
		to_chat(H, SPAN_NOTICE("There is nothing in the slip or the boathouse to survey. A built hull of up to 7x7 tiles lying wholly in the slip can be worked on here as if she lay in the shallows."))
		return
	for (var/text in report)
		to_chat(H, SPAN_NOTICE(text))

// ---- Small boats dry faster indoors ----

/obj/structure/vehicle/raft/proc/dry_factor()
	return istype(loc, /obj/structure/boathouse_stored_tile) ? BOATHOUSE_DRY_FACTOR : 1

#undef BERTH_REACH
#undef BERTH_PLANK_TIME
#undef BOATHOUSE_DRY_FACTOR
