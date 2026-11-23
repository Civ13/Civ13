// A second deck above on player-built hulls (code/modules/craft/built_body.dm):
// a roof built on her upper deck has its floor two levels above her hull, and
// that deck sails, turns and is stopped by what is in its way like her upper
// deck; her lines draw it, and the slipway builds it from a draught.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 4
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			for (var/z = 3, z <= 4, z++)
				var/turf/S = locate(x, y, z)
				S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// A roof built the way a player builds one, with its floor on the level above.
/proc/deck_roof(x, y, z)
	return building_construct_roof(locate(x, y, z), /obj/roof/wood, null)

/proc/deck_floors(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// Roofs on level z over her hull that still have their floor above.
/proc/deck_paired(datum/craft_body/built/B, z)
	. = 0
	for (var/turf/T in B.cells())
		for (var/obj/roof/R in locate(T.x, T.y, z))
			if (R.building_floor())
				.++

/proc/naval_checks()
	naval_fixture()
	naval_research_done = TRUE
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	naval_check(building_upper_z(2) == 3 && building_upper_z(3) == 4, "two building levels stand over the sea")

	// ---- A hull with two decks above ----
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	new /obj/structure/roof_support(locate(32, 11, 2))
	var/roofs = 0
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			if (deck_roof(x, y, 2))
				roofs++
	new /obj/structure/roof_support(locate(32, 11, 3))
	var/upper_roofs = 0
	for (var/x = 31, x <= 33, x++)
		for (var/y = 10, y <= 12, y++)
			if (deck_roof(x, y, 3))
				upper_roofs++
	naval_check(roofs == 15 && upper_roofs == 9 && deck_floors(locate(32, 11, 4)) == 1, "her deck is roofed over and nine tiles of the deck above are roofed again ([roofs], [upper_roofs])")
	var/obj/structure/multiz/ladder/up/foot = new(locate(31, 11, 3))
	var/obj/structure/multiz/ladder/head = new(locate(31, 11, 4))
	foot.find_target()
	head.find_target()
	var/obj/structure/hull_tiller/tiller = new(locate(30, 11, 2))
	naval_check(isnull(tiller.commission("Osprey", EAST)) && tiller.craft, "she is commissioned")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(B.top_z() == 4 && B.upper_tile_count() == 15 && B.top_tile_count() == 9, "her second deck above is nine tiles ([B.top_tile_count()])")
	naval_check(findtext(tiller.status_text(), "15 of upper deck with 9 of second deck above"), "the tiller reads out her second deck ([tiller.status_text()])")
	var/mob/living/human/naval_probe/kit = new(locate(33, 11, 4))
	kit.real_name = "Kit"
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(locate(32, 12, 4))
	naval_check(kit in B.aboard(), "a sailor on her second deck is aboard")
	naval_check(B.carries(locate(33, 11, 4)) && !B.carries(locate(34, 11, 4)), "she carries her second deck and not the air beside it")

	// ---- One step east ----
	var/turf/O = B.origin()
	naval_check(B.move_to(O.x + 1, O.y, EAST), "she steps one tile east ([B.last_refusal])")
	naval_check(kit.x == 34 && kit.z == 4 && pail.x == 33 && pail.z == 4, "the sailor and the pail on her second deck ride along ([kit.x],[kit.y],[kit.z])")
	naval_check(deck_floors(locate(31, 11, 4)) == 0 && deck_floors(locate(34, 11, 4)) == 1 && deck_floors(locate(32, 11, 4)) == 1, "the floors of her second deck moved with her and none is left behind or doubled")
	naval_check(B.top_tile_count() == 9 && deck_paired(B, 3) == 9 && deck_paired(B, 2) == 15, "every roof on both decks still has its floor above")
	naval_check(foot.x == 32 && head.x == 32 && head.z == 4 && foot.target == head, "the ladder up to her second deck still joins it")

	// ---- Something in the way of her second deck ----
	var/obj/covers/repairedfloor/bridge = new(locate(35, 11, 4))
	O = B.origin()
	naval_check(!B.move_to(O.x + 1, O.y, EAST) && findtext(B.last_refusal, "upper deck at 35,11") && tiller.x == 31, "a floor two levels up stops her, with the reason ([B.last_refusal])")
	qdel(bridge)
	var/obj/structure/probe_rock/kite = new(locate(35, 12, 4))
	naval_check(!B.move_to(O.x + 1, O.y, EAST) && findtext(B.last_refusal, "probe rock") && tiller.x == 31, "so does something solid up there ([B.last_refusal])")
	qdel(kite)
	var/obj/structure/probe_rock/beside = new(locate(36, 11, 4))
	naval_check(B.move_to(O.x + 1, O.y, EAST) && tiller.x == 32, "with the air clear over her second deck she steps on; a rock over her upper deck's open tiles at that height is no matter ([B.last_refusal])")
	qdel(beside)

	// ---- Coming about ----
	naval_check(B.turn_to(NORTH) && B.dir == NORTH, "she comes about to the north")
	naval_check(B.top_tile_count() == 9 && deck_paired(B, 3) == 9, "her second deck swung with her, every roof under its floor")
	naval_check(kit.z == 4 && deck_floors(get_turf(kit)) == 1 && B.contains(locate(kit.x, kit.y, 2)), "the sailor still stands on her second deck, over her hull")

	// ---- Her lines ----
	var/datum/ship_draught/lines = ship_draught_survey(tiller)
	naval_check(istype(lines) && lines.deck_tiles(1) == 15 && lines.deck_tiles(2) == 9, "her lines draw her second deck ([istype(lines) ? lines.deck_tiles(2) : lines])")
	if (istype(lines))
		var/list/errors = lines.problems()
		naval_check(!errors.len, "her own lines pass the design checks ([jointext(errors, " ")])")
		qdel(lines)

	// ---- Sinking ----
	qdel(kit)
	var/turf/pail_was = get_turf(pail)
	var/foundered = C.ledger.sink()
	// Foundering disables her; she keeps her decks and what stands on them.
	naval_check(foundered && get_turf(pail) == pail_was, "when she founders the pail stays on her second deck ([pail.x],[pail.y],[pail.z])")
	naval_check(deck_floors(pail_was), "her second deck stays with her")
	qdel(tiller)

	// ---- The slipway builds a second deck ----
	var/datum/ship_draught/D = new
	D.name = "Skua"
	for (var/x = 0, x < 3, x++)
		for (var/y = 0, y < 4, y++)
			D.set_floor(x, y, "w")
	D.set_piece(1, 0, "T")
	for (var/x = 0, x < 3, x++)
		for (var/y = 1, y < 4, y++)
			D.set_deck(1, x, y, TRUE)
	D.set_piece(1, 2, "S")
	D.set_piece(0, 1, "X")
	D.set_deck(2, 1, 2, TRUE)
	D.set_deck(2, 1, 3, TRUE)
	D.set_deck_piece(1, 1, 2, "S")
	D.set_deck_piece(1, 1, 3, "X")
	naval_check(D.buildable(), "a draught with a second deck above can be built ([jointext(D.problems(), " ")])")
	var/datum/design_report/DR = design_report("ship", D)
	naval_check(!findtext(jointext(DR.texts(DESIGN_NOTE), " "), "drawn for later"), "her second deck is no longer noted as drawn for later ([jointext(DR.texts(DESIGN_NOTE), " ")])")
	qdel(DR)
	var/datum/slipway_design/draught/plan = slipway_draught_plan(D)
	var/list/stages = list()
	for (var/list/stage in plan.stages)
		stages += stage["name"]
	naval_check(findtext(jointext(stages, "|"), "Deck above|Second deck above|Deck pillars below and above|Ladders"), "the slipway builds her deck above, then her second deck, what stands on them and her ladders ([jointext(stages, "|")])")
	plan.draught = null
	qdel(plan)
	var/obj/structure/slipway/ways = new(locate(5, 40, 2))
	ways.dir = EAST
	var/obj/covers/repairedfloor/overhead = new(locate(9, 40, 4))
	var/refusal = ways.draught_refusal(D)
	naval_check(refusal && findtext(refusal, "second deck above needs open air"), "a floor over the berth two levels up refuses her second deck ([refusal])")
	qdel(overhead)
	naval_check(!ways.draught_refusal(D), "the berth takes her ([ways.draught_refusal(D)])")
	ways.lay_draught(D)
	var/list/pay_paths = list("wood" = /obj/item/stack/material/wood, "steel" = /obj/item/stack/material/steel, "iron" = /obj/item/stack/material/iron, "planks" = /obj/item/stack/material/woodplank)
	var/guard = 0
	while (ways.next_piece() && guard++ < 80)
		var/list/needed = ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(ways.loc)
			stack.amount = needed[key]
			ways.pay(stack)
	naval_check(ways.finished(), "every piece is built ([ways.status_text()])")
	var/obj/structure/multiz/ladder/up/placed/top_foot = null
	var/obj/structure/multiz/ladder/placed/top_head = null
	for (var/z = 3, z <= 4, z++)
		for (var/turf/T in block(locate(6, 39, z), locate(9, 41, z)))
			if (z == 3 && !top_foot)
				top_foot = locate(/obj/structure/multiz/ladder/up/placed) in T
			if (z == 4 && !top_head)
				top_head = locate(/obj/structure/multiz/ladder/placed) in T
	naval_check(top_foot && top_head && top_foot.target == top_head, "a ladder joins her deck above to her second deck")
	var/obj/structure/hull_tiller/skua_tiller = null
	for (var/turf/T in block(locate(6, 39, 2), locate(9, 41, 2)))
		if (!skua_tiller)
			skua_tiller = locate(/obj/structure/hull_tiller) in T
	var/launched = ways.launch()
	var/datum/craft_body/built/SB = istype(launched, /obj/structure/hull_tiller) && skua_tiller && skua_tiller.craft ? skua_tiller.craft.body : null
	naval_check(SB && SB.tile_count() == 12 && SB.upper_tile_count() == 9 && SB.top_tile_count() == 2, "she launches with both decks above ([istext(launched) ? launched : "launched"]; [SB ? "[SB.upper_tile_count()] above, [SB.top_tile_count()] second" : "no body"])")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
