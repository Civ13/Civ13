// ============================================================
// Refitting a hull to a draught at a berth (docs/berths.md)
// ------------------------------------------------------------
// A built hull lying still at a berth (berth.dm) can be refitted to a ship's
// draught. Hold the draught and choose "Mark out a refit" at her tiller: the
// draught is laid over her with its helm on her tiller and its bow the way
// her bow points, and every tile that differs is marked on her:
//
// - green: a floor (and whatever stands on it) to add;
// - red: a tile of her to lift;
// - amber: a floor or fitting to change for another;
// - amber, faint: a fitting to turn to face another way.
//
// Only her main deck is compared. The work is done by hand, as any work on a
// hull, at what it costs by hand: lay floors and fittings, dismantle what is
// marked red, turn what is marked to turn. "Check the refit" at the tiller
// marks her again as she stands and lists what is left; "Refit the hull"
// surveys her new lines once her floors are done. When nothing differs the
// marks are gone and she is the ship on her draught.
//
// The draught is held by the tiller only until the world restarts: the marks
// are not saved, and the draught can be marked out again.
// ============================================================

/obj/structure/hull_tiller
	var/tmp/refit_code = ""          // the draught she is being refitted to
	var/tmp/list/refit_marks = list()

// A mark on a hull being refitted.
/obj/structure/berth_refit_mark
	name = "refit mark"
	desc = "Chalk on a hull being refitted at her berth."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "grid"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	mouse_opacity = FALSE
	layer = TURF_LAYER + 0.2
	should_save = FALSE
	alpha = 120
	var/kind = "add"

/obj/structure/berth_refit_mark/proc/set_kind(new_kind, what)
	kind = new_kind
	switch (kind)
		if ("add")
			color = "#40c040"
			name = "refit mark: add"
			desc = "The refit adds [what] here."
		if ("remove")
			color = "#d04040"
			name = "refit mark: lift"
			desc = "The refit lifts [what] here."
		if ("change")
			color = "#e0a020"
			name = "refit mark: change"
			desc = "The refit changes [what] here."
		else
			color = "#e0a020"
			alpha = 70
			name = "refit mark: turn"
			desc = "The refit turns [what] here."

// What tile T of her has: list(floor key, piece key or null, piece dir).
/obj/structure/hull_tiller/proc/refit_tile(turf/T)
	var/floor = (locate(/obj/covers/steelplating) in T) ? "s" : "w"
	var/list/piece = ship_draught_piece_on(T, src)
	return list(floor, piece ? piece[1] : null, piece ? piece[2] : NORTH)

// The draught D laid over her: turf = list(floor, piece, dir as it stands).
// Text when it cannot be laid over her.
/obj/structure/hull_tiller/proc/refit_target(datum/ship_draught/D)
	var/datum/craft_body/built/B = body()
	if (!istype(B) || !B.placed())
		return "She is not commissioned."
	var/hx = null
	var/hy = null
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (C[2] == "T" || C[2] == "O")
			var/list/xy = splittext(key, ",")
			hx = text2num(xy[1])
			hy = text2num(xy[2])
			break
	if (isnull(hx))
		return "The [D.name] on the draught has no tiller or steering oar to lay on hers."
	var/turf/helm = get_turf(src)
	var/angle = craft_turn_angle(NORTH, B.dir)
	. = list()
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		var/list/xy = splittext(key, ",")
		var/list/R = slipway_draught_turn(text2num(xy[1]) - hx, text2num(xy[2]) - hy, B.dir)
		var/turf/T = locate(helm.x + R[1], helm.y + R[2], helm.z)
		if (!T)
			return "The [D.name] would run off the edge of the world."
		.[T] = list(C[1], C[2], (C[3] in cardinal) ? turn(C[3], angle) : NORTH)

// Every tile where she and the draught differ: turf = list(kind, what).
/obj/structure/hull_tiller/proc/refit_diff(list/target)
	. = list()
	var/datum/craft_body/built/B = body()
	var/list/mine = list()
	for (var/turf/T in B.cells())
		mine[T] = TRUE
	for (var/turf/T in target)
		var/list/want = target[T]
		var/floor_name = ship_draught_floors[want[1]]["name"]
		var/list/piece = want[2] ? ship_draught_pieces[want[2]] : null
		if (!mine[T])
			.[T] = list("add", piece ? "a [floor_name] with a [piece["name"]]" : "a [floor_name]")
			continue
		var/list/have = refit_tile(T)
		if (have[1] != want[1])
			.[T] = list("change", "the floor for a [floor_name]")
		else if (have[2] != want[2])
			var/list/old = have[2] ? ship_draught_pieces[have[2]] : null
			if (!piece)
				.[T] = list("remove", "the [old["name"]]")
			else
				.[T] = list("change", old ? "the [old["name"]] for a [piece["name"]]" : "nothing for a [piece["name"]]")
		else if (piece && piece["turns"] && have[3] != want[3])
			.[T] = list("turn", "the [piece["name"]] to face [dir2text(want[3])]")
	for (var/turf/T in mine)
		if (!target[T])
			var/list/have = refit_tile(T)
			var/list/old = have[2] ? ship_draught_pieces[have[2]] : null
			.[T] = list("remove", old ? "the floor and the [old["name"]]" : "the floor")

/obj/structure/hull_tiller/proc/clear_refit_marks()
	for (var/obj/structure/berth_refit_mark/M in refit_marks)
		qdel(M)
	refit_marks = list()

// Why she cannot be refitted to a draught here now, or null.
/obj/structure/hull_tiller/proc/refit_refusal()
	if (!craft || !craft.ledger)
		return "Only a commissioned hull can be refitted."
	if (craft.ledger.under_way())
		return "Bring her to a stop first."
	if (!craft_berth(craft))
		return "A hull is refitted to a draught at a berth: a boathouse slip, a slipway or a drydock."
	return null

// Marks her for the refit to the draught she holds, as she stands now.
// Returns the differences (turf = list(kind, what)), or text.
/obj/structure/hull_tiller/proc/mark_refit()
	clear_refit_marks()
	if (!refit_code)
		return "No refit is marked out."
	var/why = refit_refusal()
	if (why)
		return why
	var/datum/ship_draught/D = ship_draught_from_code(refit_code)
	if (!D)
		refit_code = ""
		return "The draught cannot be read."
	var/target = refit_target(D)
	qdel(D)
	if (istext(target))
		return target
	var/list/diff = refit_diff(target)
	for (var/turf/T in diff)
		var/list/E = diff[T]
		var/obj/structure/berth_refit_mark/M = new(T)
		M.set_kind(E[1], E[2])
		refit_marks += M
	if (!diff.len)
		refit_code = ""
	return diff

// "Add 3, lift 2, change 1, turn 1."
/proc/berth_refit_summary(list/diff)
	var/list/count = list("add" = 0, "remove" = 0, "change" = 0, "turn" = 0)
	for (var/turf/T in diff)
		var/list/E = diff[T]
		count[E[1]]++
	var/list/parts = list()
	if (count["add"])
		parts += "[count["add"]] tile\s to add (green)"
	if (count["remove"])
		parts += "[count["remove"]] to lift (red)"
	if (count["change"])
		parts += "[count["change"]] to change (amber)"
	if (count["turn"])
		parts += "[count["turn"]] fitting\s to turn (faint amber)"
	return english_list(parts)

// The tiller's menu entries for a refit at a berth.
/obj/structure/hull_tiller/proc/refit_options(mob/living/human/H)
	. = list()
	if (!craft || !craft_berth(craft))
		return
	if (istype(H.get_active_hand(), /obj/item/ship_draught))
		. += "Mark out a refit"
	if (refit_code)
		. += list("Check the refit", "Clear the refit marks")

// TRUE when choice was a refit action.
/obj/structure/hull_tiller/proc/refit_action(mob/living/human/H, choice)
	switch (choice)
		if ("Mark out a refit")
			var/obj/item/ship_draught/S = H.get_active_hand()
			if (!istype(S))
				return TRUE
			var/datum/ship_draught/D = S.draught()
			if (!D)
				to_chat(H, SPAN_WARNING("The draught is blank."))
				return TRUE
			refit_code = S.draught_code
			qdel(D)
			report_refit(H, mark_refit(), TRUE)
			return TRUE
		if ("Check the refit")
			report_refit(H, mark_refit(), FALSE)
			return TRUE
		if ("Clear the refit marks")
			refit_code = ""
			clear_refit_marks()
			to_chat(H, SPAN_NOTICE("The refit marks are rubbed out."))
			return TRUE
	return FALSE

/obj/structure/hull_tiller/proc/report_refit(mob/living/human/H, result, first)
	if (istext(result))
		refit_code = ""
		to_chat(H, SPAN_WARNING(result))
		return
	var/list/diff = result
	if (!diff.len)
		to_chat(H, SPAN_NOTICE("She matches her draught: there is nothing to refit."))
		return
	if (first)
		log_game("[key_name(H)] marked out a refit of the [craft.name] at [x],[y],[z] ([diff.len] tiles).")
	to_chat(H, SPAN_NOTICE("[first ? "The refit is chalked on her" : "The refit still wants"]: [berth_refit_summary(diff)]. Do the work by hand, then use Refit the hull here once her floors are done."))
