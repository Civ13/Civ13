// ============================================================
// The yard office (docs/berths.md)
// ------------------------------------------------------------
// A shipwright's yard office turns the berths around it into a shipyard.
// Build it within YARD_OFFICE_REACH tiles of a slipway, a boathouse or a
// dock gate (30 wood, construction, Workshops). Every berth in its reach:
//
// - works faster: fitting pieces on a slipway, hauling a hull up the ways,
//   planking over patches, pumping out and flooding a dock all take two
//   thirds of the time (yard_time());
// - shares the yard's stock: hit the office with wood, steel, iron, planks,
//   rope, cloth, glass or cable to store it. "Fit from the yard stock" at a
//   slipway post fits piece after piece from what the office holds;
// - keeps its draughts on the office shelf: hit the office with a ship's
//   draught to file it, and take any one back from its menu.
//
// "Survey the yard" lists the berths in reach and the hulls they hold.
// The stock and the shelf are the office's contents and save with it.
// Not to be confused with the shipyard office that lays down an aircraft
// carrier (shipyard.dm).
// ============================================================

#define YARD_OFFICE_REACH 15 // tiles from the office a berth works faster
#define YARD_SPEED 1.5       // how much faster work goes in the yard
#define YARD_FIT_TIME 40     // deciseconds to fit one piece from the stock
#define YARD_SHELF_MAX 20    // draughts on the shelf

// Not initialised here: world's global initialiser is at its size limit.
var/global/list/yard_offices

/obj/structure/yard_office
	name = "yard office"
	desc = "A shipwright's office with a drawing shelf and a stock shed. The slipways, boathouses and docks around it work faster, draw on its stock and keep their draughts on its shelf."
	icon = 'icons/obj/berths.dmi'
	icon_state = "yard_office"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = TRUE
	var/tmp/busy = FALSE

/obj/structure/yard_office/New()
	..()
	LAZYINITLIST(yard_offices)
	yard_offices |= src

/obj/structure/yard_office/after_load()
	..()
	busy = FALSE
	LAZYINITLIST(yard_offices)
	yard_offices |= src

/obj/structure/yard_office/Destroy()
	if (yard_offices)
		yard_offices -= src
	var/turf/T = get_turf(src)
	for (var/obj/item/I in contents)
		I.forceMove(T)
	return ..()

// The yard office whose reach A lies in, or null.
/proc/yard_office_near(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	for (var/obj/structure/yard_office/O in yard_offices)
		if (QDELETED(O) || O.z != T.z || !isturf(O.loc))
			continue
		if (get_dist(O, T) <= YARD_OFFICE_REACH)
			return O
	return null

// How long work taking time takes at A: faster within a yard office's reach.
/proc/yard_time(atom/A, time)
	return yard_office_near(A) ? max(1, round(time / YARD_SPEED)) : time

// ---- The stock ----

// material key -> amount the office holds.
/obj/structure/yard_office/proc/stock()
	. = list()
	for (var/obj/item/stack/S in contents)
		var/key = piece_material(S)
		if (key)
			.[key] = (.[key] || 0) + S.amount

// A stack of the stock that pays one of the materials in needed, or null.
/obj/structure/yard_office/proc/stock_for(list/needed)
	for (var/obj/item/stack/S in contents)
		var/key = piece_material(S)
		if (key && needed[key] && S.amount > 0)
			return S
	return null

/obj/structure/yard_office/proc/stock_text()
	var/list/S = stock()
	return S.len ? "The yard holds [piece_cost_text(S)]." : "The yard's stock is empty."

/obj/structure/yard_office/proc/draughts()
	. = list()
	for (var/obj/item/ship_draught/D in contents)
		. += D

/obj/structure/yard_office/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/ship_draught))
		if (length(draughts()) >= YARD_SHELF_MAX)
			to_chat(user, SPAN_WARNING("The shelf is full: take a draught down first."))
			return
		if (user.drop_from_inventory(W, src))
			W.forceMove(src)
			to_chat(user, SPAN_NOTICE("You file \the [W] on the office shelf."))
		return
	if (istype(W, /obj/item/stack) && piece_material(W))
		if (user.drop_from_inventory(W, src))
			W.forceMove(src)
			to_chat(user, SPAN_NOTICE("You store \the [W] in the yard. [stock_text()]"))
		return
	return ..()

/obj/structure/yard_office/examine(mob/user, distance)
	..()
	to_chat(user, "[stock_text()] [length(draughts())] draught\s on the shelf.")

// ---- The yard ----

// The berths in reach: slipways, boathouses and dock gates.
/obj/structure/yard_office/proc/yard_berths()
	. = list()
	for (var/obj/structure/S in range(YARD_OFFICE_REACH, src))
		if (istype(S, /obj/structure/slipway) || istype(S, /obj/structure/boathouse) || istype(S, /obj/structure/canal_lock/dock_gate))
			. += S

/obj/structure/yard_office/proc/survey_lines()
	. = list()
	var/list/seen = list()
	for (var/obj/structure/S in yard_berths())
		var/line = "[capitalize(S.name)] at [S.x],[S.y]"
		var/list/hulls = list()
		if (istype(S, /obj/structure/slipway))
			var/obj/structure/slipway/W = S
			var/datum/craft/C = W.hauled_hull()
			if (C)
				hulls += C
			else if (W.design)
				line += ": building a [W.design]. [W.status_text()]"
		else if (istype(S, /obj/structure/boathouse))
			var/obj/structure/boathouse/B = S
			hulls = B.hulls_in_slip()
		else
			var/obj/structure/canal_lock/dock_gate/G = S
			hulls = G.hulls_in_basin()
		var/list/names = list()
		for (var/datum/craft/C in hulls)
			if (seen[C])
				continue
			seen[C] = TRUE
			names += C.name
		if (names.len)
			line += ": the [english_list(names)]"
		. += line + "."

/obj/structure/yard_office/attack_hand(mob/living/human/H)
	if (!istype(H) || busy || !Adjacent(H))
		return
	var/list/options = list("Survey the yard" = "survey")
	var/list/shelf = draughts()
	for (var/obj/item/ship_draught/D in shelf)
		options["Take down the [D.name]"] = D
	var/list/S = stock()
	for (var/key in S)
		options["Take out the [key] ([S[key]])"] = key
	var/choice = WWinput(H, "[stock_text()] [shelf.len] draught\s on the shelf. Berths within [YARD_OFFICE_REACH] tiles work faster and can draw on the stock.", name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	var/action = options[choice]
	if (action == "survey")
		var/list/lines = survey_lines()
		if (!lines.len)
			to_chat(H, SPAN_NOTICE("No slipway, boathouse or dock gate stands within [YARD_OFFICE_REACH] tiles of the office."))
		for (var/line in lines)
			to_chat(H, SPAN_NOTICE(line))
		return
	if (istype(action, /obj/item/ship_draught))
		var/obj/item/ship_draught/D = action
		if (D.loc == src)
			D.forceMove(get_turf(src))
			H.put_in_hands(D)
		return
	for (var/obj/item/stack/T in contents)
		if (piece_material(T) == action)
			T.forceMove(get_turf(src))
	to_chat(H, SPAN_NOTICE("You set the [action] out by the office."))

// ---- The slipway draws on the stock ----

// Adds "Fit from the yard stock" to the post's menu while a ship is building.
/obj/structure/slipway/proc/yard_options(list/options)
	if (!design || finished())
		return
	var/obj/structure/yard_office/O = yard_office_near(src)
	if (O && O.stock_for(still_needed()))
		options["Fit from the yard stock"] = "yard"

// TRUE when the action was the yard's.
/obj/structure/slipway/proc/yard_action(mob/living/human/H, action)
	if (action != "yard")
		return FALSE
	var/fitted = fit_from_stock(H)
	if (fitted)
		log_game("[key_name(H)] fitted [fitted] piece\s from the yard stock at [src] at [x],[y],[z].")
		H.visible_message(SPAN_NOTICE("[H] works on the ship from the yard's stock."), SPAN_NOTICE("You fit [fitted] piece\s from the yard's stock. [status_text()]"))
	return TRUE

// Fits pieces from the yard's stock until it runs short. Returns the number fitted.
/obj/structure/slipway/proc/fit_from_stock(mob/living/human/H, wait = TRUE)
	. = 0
	if (busy || !design)
		return
	busy = TRUE
	var/code = draught_code
	var/name_was = design
	while (TRUE)
		var/obj/structure/yard_office/O = yard_office_near(src)
		var/list/needed = still_needed()
		if (!O || !needed.len || finished())
			break
		var/obj/item/stack/S = O.stock_for(needed)
		if (!S)
			if (H)
				to_chat(H, SPAN_NOTICE("The yard has no [english_list(needed)] left for the next piece."))
			break
		if (wait && (!H || !do_after(H, yard_time(src, YARD_FIT_TIME), src)))
			break
		if (QDELETED(src) || QDELETED(S) || S.loc != O || design != name_was || draught_code != code)
			break
		var/before = pieces_done
		if (!pay(S))
			break
		. += pieces_done - before
	busy = FALSE

#undef YARD_OFFICE_REACH
#undef YARD_SPEED
#undef YARD_FIT_TIME
#undef YARD_SHELF_MAX
