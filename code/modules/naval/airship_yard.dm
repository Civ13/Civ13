// ============================================================
// The airship yard (docs/airship-sheets.md)
// ------------------------------------------------------------
// A press like the automobile workshop, gated on Lighter-than-Air Flight. It
// keeps no models of its own: use an airship sheet (air_draught.dm) on it and
// it lays her deck on the clear, level ground to the northeast, bow to the
// north, hangs her gas cells empty, sets up her helm, engines with their fuel
// tanks and bomb hatches, and commissions her under the sheet's name, held in
// place. Fill her cells with gas and her tanks with fuel before casting off.
//
// It refuses a sheet whose air_sheet checks report an error, one it lacks
// the research for, a bay that is not clear and stock it lacks. Its stock
// takes plastic or rubber sheets for rubberised cells and sausage casings for
// goldbeater's skin as well as the press's own materials.
// ============================================================

#define AIRSHIP_YARD_BAY 4 // the least clear ground the yard is placed beside

/obj/structure/car_workshop/airship_yard
	name = "airship yard"
	desc = "A rigging shed and slipway for crewed airships. Feed it wood, aluminium, steel, cloth, plastic and sausage casings, then use an airship sheet on it: it lays her deck on the clear, level ground to the northeast and commissions her."
	icon_state = "workbench"
	piece_projects = FALSE

/obj/structure/car_workshop/airship_yard/models()
	return list()

/obj/structure/car_workshop/airship_yard/required_nodes()
	return list("lighter_than_air_flight")

/obj/structure/car_workshop/airship_yard/sheet_axes()
	return list()

/obj/structure/car_workshop/airship_yard/largest_model_size()
	return AIRSHIP_YARD_BAY

// Her deck is laid on the ground she can lift off from (air_hull.dm).
/obj/structure/car_workshop/airship_yard/bay_floor(turf/T)
	return air_ground_open(T)

/obj/structure/car_workshop/airship_yard/stock_key(obj/item/I)
	if (istype(I, /obj/item/stack/material/plastic) || istype(I, /obj/item/stack/material/rubber))
		return "plastic"
	if (istype(I, /obj/item/stack/sausagecasing))
		return "casings"
	return ..()

/obj/structure/car_workshop/airship_yard/stock_cap(key)
	switch (key)
		if ("cloth")
			return 1200
		if ("wood", "aluminium", "steel")
			return 1000
		if ("plastic", "casings")
			return 400
	return ..()

/obj/structure/car_workshop/airship_yard/menu_text()
	return "Stored: [stock["wood"] || 0] wood, [stock["aluminium"] || 0] aluminium, [stock["steel"] || 0] steel, [stock["cloth"] || 0] cloth, [stock["plastic"] || 0] plastic, [stock["casings"] || 0] sausage casings. Use an airship sheet on the yard to build her: it lays her deck on the clear, level ground northeast of the yard, bow to the north. Draw one on a ship's draught with \"Draw an airship on the sheet\"."

/obj/structure/car_workshop/airship_yard/extra_options()
	return list()

/obj/structure/car_workshop/airship_yard/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/ship_draught/S = I
	if (istype(S) && S.air_draught_kind() && !busy && allowed(H) && Adjacent(H))
		build_from_air_sheet(H, S)
		return
	return ..()

/obj/structure/car_workshop/airship_yard/unload()
	var/list/extra = list("plastic" = /obj/item/stack/material/plastic, "casings" = /obj/item/stack/sausagecasing)
	for (var/key in extra)
		var/path = extra[key]
		while ((stock[key] || 0) > 0)
			var/obj/item/stack/P = new path(get_turf(src))
			P.amount = min(stock[key], P.max_amount)
			stock[key] -= P.amount
			P.update_icon()
	return ..()

/obj/structure/car_workshop/airship_yard/proc/air_missing_research(mob/living/human/H, datum/air_draught/D)
	. = list()
	if ((istype(src, /obj/structure/car_workshop/airship_yard/practice)) && tutorial_workshop_access(H, src))
		return
	for (var/node_id in D.nodes())
		if (node_id in required_nodes())
			continue
		if (!H || !map || !research_node_known(H, node_id))
			var/datum/research_node/N = get_research_node(node_id)
			. += N ? N.name : node_id

// The bay tile under the sheet's tile (col, row): her bow row along the
// north edge of a length-deep box, her port column at its west.
/obj/structure/car_workshop/airship_yard/proc/air_bay_turf(datum/air_draught/D, col, row)
	return locate(x + col, y + D.length - row + 1, z)

// TRUE when every tile her deck will cover is clear, level ground.
/obj/structure/car_workshop/airship_yard/proc/air_bay_clear(datum/air_draught/D)
	if (!isturf(loc))
		return FALSE
	for (var/key in D.deck_cells())
		var/list/at = splittext(key, ",")
		var/turf/T = air_bay_turf(D, text2num(at[1]), text2num(at[2]))
		if (!T || !bay_floor(T))
			return FALSE
		for (var/atom/movable/M in T)
			if (M.simulated)
				return FALSE
	return TRUE

/obj/structure/car_workshop/airship_yard/proc/air_refusal(mob/living/human/H, datum/air_draught/D)
	if (!D)
		return "The sheet cannot be read."
	var/list/errors = D.problems()
	if (errors.len)
		var/list/first = list()
		for (var/i = 1, i <= min(errors.len, 3), i++)
			var/t = errors[i]
			if (copytext(t, -1) == ".")
				t = copytext(t, 1, -1)
			first += t
		return "The sheet's checks fail, so the yard will not build her: [jointext(first, "; ")][errors.len > 3 ? "; and [errors.len - 3] more" : ""]. Fix the drawing first."
	var/list/research = air_missing_research(H, D)
	if (research.len)
		return "[english_list(research)] research [research.len == 1 ? "is" : "are"] required to build the [D.name]."
	if (!air_bay_clear(D))
		return "The [D.name] needs the ground she covers northeast of the yard clear: dry, level, open ground with nothing on it, [D.width] tiles east and [D.length] north."
	var/list/costs = D.costs()
	var/list/short = list()
	for (var/key in costs)
		if ((stock[key] || 0) < costs[key])
			short += "[costs[key] - (stock[key] || 0)] more [key == "casings" ? "sausage casings" : key]"
	if (short.len)
		return "The [D.name] costs [D.costs_text()]. The yard needs [english_list(short)]."
	return null

/obj/structure/car_workshop/airship_yard/proc/build_from_air_sheet(mob/living/human/H, obj/item/ship_draught/S)
	var/datum/air_draught/D = S.air_draught()
	var/refusal = air_refusal(H, D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		qdel(D)
		return null
	var/list/deck = D.deck_cells()
	var/choice = WWinput(H, "Build the [D.name], [deck.len] tiles of deck in a [D.width] by [D.length] rectangle, for [D.costs_text()]? She will be laid facing north on the ground northeast of the yard and commissioned under her name, held in place with her gas cells and tanks empty.", name, "Cancel", list("Build her", "Cancel"))
	if (choice != "Build her" || busy || !Adjacent(H) || !allowed(H) || S.loc != H)
		qdel(D)
		return null
	busy = TRUE
	powerneeded = 20
	if (!draw_cable_power())
		finish_work()
		to_chat(H, SPAN_WARNING("Connect an active cable supply with 20 available power."))
		qdel(D)
		return null
	var/completed = wait_for_assembly(H)
	if (QDELETED(src))
		qdel(D)
		return null
	var/obj/structure/airship_helm/helm = null
	if (completed && Adjacent(H) && allowed(H) && draw_cable_power())
		refusal = air_refusal(H, D)
		if (refusal)
			to_chat(H, SPAN_WARNING(refusal))
		else
			var/result = build_airship(D)
			if (istext(result))
				to_chat(H, SPAN_WARNING("The yard could not build the [D.name]: [result]."))
			else
				helm = result
				log_game("[key_name(H)] built the airship [D.name] ([deck.len] tiles) at the airship yard at [x],[y],[z].")
				to_chat(H, SPAN_NOTICE("The [D.name] is laid and commissioned, holding her position. Fill her gas cells with hydrogen or helium[D.count_parts("E") ? " and her tanks with fuel" : ""], then cast off and lift off at her helm."))
	finish_work()
	qdel(D)
	return helm

// Lays D in the bay and commissions her: her helm, or why it could not be done.
// Spends the stock only on success.
/obj/structure/car_workshop/airship_yard/proc/build_airship(datum/air_draught/D)
	if (!air_bay_clear(D))
		return "the ground is not clear"
	var/list/made = list()
	var/obj/structure/airship_helm/helm = null
	var/list/engines = list()
	var/list/tanks = list()
	for (var/row = 1, row <= D.length, row++)
		for (var/col = 1, col <= D.width, col++)
			var/list/C = D.cell(col, row)
			if (!C || !C[1])
				continue
			var/turf/T = air_bay_turf(D, col, row)
			var/deck_path = air_draught_decks()[C[1]]["path"]
			made += new deck_path(T)
			if (C[2])
				var/cell_path = air_draught_cells()[C[2]]["path"]
				var/obj/structure/airship_gas_cell/G = new cell_path(T)
				G.gas = null
				G.gas_amount = 0
				G.update_icon()
				made += G
			if (!C[3])
				continue
			var/path = D.part_path(C[3])
			if (C[3] == "W" && helm)
				continue
			var/atom/movable/P = new path(T)
			made += P
			P.dir = NORTH
			if (C[3] == "W")
				helm = P
			else if (C[3] == "E")
				var/obj/structure/engine/internal/E = P
				E.enginesize = D.cc
				E.maxpower = initial(E.maxpower) * D.cc / 1000
				E.fuelefficiency = initial(E.fuelefficiency) * D.cc / 1000
				E.weight = 20 * D.cc / 1000
				E.name = "[D.cc]cc [initial(E.name)]"
				engines += E
			else if (istype(P, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
				var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/F = P
				if (F.reagents)
					F.reagents.clear_reagents()
				F.anchored = TRUE
				tanks += F
	if (!helm)
		for (var/atom/movable/M in made)
			qdel(M)
		return "she has no helm"
	// Each engine draws from the nearest tank not yet taken.
	for (var/obj/structure/engine/internal/E in engines)
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/best = null
		for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/F in tanks)
			if (!best || get_dist(E, F) < get_dist(E, best))
				best = F
		if (best)
			E.fueltank = best
			tanks -= best
	var/problem = helm.commission(D.name, NORTH)
	if (problem)
		for (var/atom/movable/M in made)
			if (!QDELETED(M))
				qdel(M)
		return problem
	if (helm.craft)
		helm.craft.set_anchor(TRUE)
	var/list/costs = D.costs()
	for (var/key in costs)
		stock[key] -= costs[key]
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	return helm

#undef AIRSHIP_YARD_BAY
