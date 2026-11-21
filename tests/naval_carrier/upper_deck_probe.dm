// Upper decks on player-built hulls (code/modules/craft/built_body.dm): a
// roof built over her deck has its walkable floor on the building level above,
// and that upper deck sails and turns with her, ladders paired, riders
// standing, and the indoor areas under her roofs carried along.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
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
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0


// A roof built the way a player builds one, with its upper floor above.
/proc/deck_roof(x, y)
	return building_construct_roof(locate(x, y, 2), /obj/roof/wood, null)

/proc/deck_floors(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

/proc/deck_paired(datum/craft_body/built/B)
	. = 0
	for (var/turf/T in B.cells())
		for (var/obj/roof/R in T)
			if (R.building_floor())
				.++

/proc/deck_ms(t)
	return (world.tick_usage - t) * world.tick_lag

/proc/naval_checks()
	naval_fixture()
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	naval_check(building_upper_z(2) == 3, "the building level stands over the sea")

	// ---- A small hull, roofed over ----
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	new /obj/structure/roof_support(locate(32, 11, 2))
	var/roofs = 0
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			if (deck_roof(x, y))
				roofs++
	naval_check(roofs == 15 && deck_floors(locate(32, 11, 3)) == 1, "a pillar holds a roof over all fifteen planks, each with a floor above ([roofs])")
	var/obj/structure/multiz/ladder/up/foot = new(locate(31, 12, 2))
	var/obj/structure/multiz/ladder/head = new(locate(31, 12, 3))
	foot.find_target()
	head.find_target()
	naval_check(foot.target == head && head.target == foot, "a ladder joins her deck to the deck above")
	var/obj/structure/hull_tiller/tiller = new(locate(30, 11, 2))
	naval_check(isnull(tiller.commission("Heron", EAST)) && tiller.craft, "she is commissioned")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(B.upper_z() == 3 && B.upper_tile_count() == 15, "her upper deck is fifteen tiles ([B.upper_tile_count()])")
	naval_check(findtext(tiller.status_text(), "15 tiles of hull and 15 of upper deck"), "the tiller reads out both decks ([tiller.status_text()])")
	naval_check(istype(get_area(locate(33, 11, 2)), /area/caribbean/roofed) && !istype(get_area(locate(35, 11, 2)), /area/caribbean/roofed), "under her roofs is indoors and the sea beside her is not")

	// A floor that belongs to nobody aboard is not her deck.
	var/obj/covers/repairedfloor/stray = new(locate(36, 11, 3))
	naval_check(isnull(B.upper_deck_cell(locate(36, 11, 2), 3)), "a stray floor above the water is not part of her")

	var/mob/living/human/naval_probe/bea = new(locate(33, 11, 3))
	bea.real_name = "Bea"
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(locate(34, 12, 3))
	var/bea_health = bea.health
	naval_check(bea in B.aboard(), "a sailor on the upper deck is aboard")
	qdel(stray)

	// ---- One step east ----
	var/turf/O = B.origin()
	naval_check(B.move_to(O.x + 1, O.y, EAST), "she steps one tile east ([B.last_refusal])")
	naval_check(bea.x == 34 && bea.y == 11 && bea.z == 3 && bea.health == bea_health, "the sailor on the upper deck rides along on her feet ([bea.x],[bea.y],[bea.z])")
	naval_check(pail.x == 35 && pail.z == 3, "a pail on the upper deck rides along")
	naval_check(deck_floors(locate(30, 11, 3)) == 0 && deck_floors(locate(35, 11, 3)) == 1 && deck_floors(locate(33, 11, 3)) == 1, "the upper floors moved with her and none is left behind or doubled")
	naval_check(B.upper_tile_count() == 15 && deck_paired(B) == 15, "every roof still has its floor above ([deck_paired(B)])")
	naval_check(foot.x == 32 && head.x == 32 && head.z == 3 && foot.target == head && head.target == foot, "the ladder still joins the decks")
	naval_check(istype(get_area(locate(35, 11, 2)), /area/caribbean/roofed) && !istype(get_area(locate(30, 11, 2)), /area/caribbean/roofed), "the indoors moved with her roofs and the sea behind her is open sky again")

	// ---- Something in the way of the upper deck ----
	var/obj/covers/repairedfloor/bridge = new(locate(36, 10, 3))
	O = B.origin()
	naval_check(!B.move_to(O.x + 1, O.y, EAST) && findtext(B.last_refusal, "upper deck") && tiller.x == 31, "a floor on the level above stops her, with the reason ([B.last_refusal])")
	qdel(bridge)
	var/obj/structure/probe_rock/kite = new(locate(36, 12, 3))
	naval_check(!B.move_to(O.x + 1, O.y, EAST) && findtext(B.last_refusal, "probe rock") && tiller.x == 31, "so does something solid up there ([B.last_refusal])")
	qdel(kite)
	naval_check(B.move_to(O.x + 1, O.y, EAST) && tiller.x == 32, "with the air clear she steps on")

	// ---- Coming about ----
	naval_check(B.turn_to(NORTH) && B.dir == NORTH, "she comes about to the north")
	naval_check(B.upper_tile_count() == 15 && deck_paired(B) == 15, "her upper deck swung with her, every roof under its floor")
	var/turf/bea_at = get_turf(bea)
	naval_check(bea.z == 3 && deck_floors(bea_at) == 1 && B.contains(locate(bea.x, bea.y, 2)), "the sailor still stands on the upper deck, over her hull")
	naval_check(foot.target == head && head.x == foot.x && head.y == foot.y, "the ladder swung whole")

	// ---- Crossing the sea ----
	naval_check(findtext(tiller.crossing_refusal(null), "upper deck"), "she may not cross the sea with an upper deck yet")

	tiller.decommission()
	qdel(tiller)
	qdel(bea)

	// ---- A mast under a bridge ----
	for (var/x = 50, x <= 52, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(51, 11, 2))
	var/obj/structure/hull_tiller/sloop_tiller = new(locate(50, 11, 2))
	naval_check(isnull(sloop_tiller.commission("Wren", EAST)) && sloop_tiller.craft, "a sloop with a mast and no deck above is commissioned")
	var/datum/craft_body/built/SB = sloop_tiller.craft.body
	var/turf/SO = SB.origin()
	var/obj/covers/repairedfloor/low_bridge = new(locate(52, 11, 3))
	naval_check(!SB.move_to(SO.x + 1, SO.y, EAST) && findtext(SB.last_refusal, "over her mast") && mast.x == 51, "a floor on the level above stops her mast, with the reason ([SB.last_refusal])")
	var/obj/covers/repairedfloor/beside = new(locate(53, 12, 3))
	qdel(low_bridge)
	naval_check(SB.move_to(SO.x + 1, SO.y, EAST) && mast.x == 52, "a floor over her plain deck lets her pass; only her mast needs the air clear ([SB.last_refusal])")
	qdel(beside)
	sloop_tiller.decommission()
	qdel(sloop_tiller)

	// ---- The cap on her decks, and the timing at it ----
	for (var/x = 40, x <= 49, x++)
		for (var/y = 20, y <= 39, y++)
			hull_lay(x, y)
	for (var/x = 41, x <= 49, x += 3)
		for (var/y = 21, y <= 39, y += 3)
			new /obj/structure/roof_support(locate(x, y, 2))
	roofs = 0
	for (var/x = 40, x <= 49, x++)
		for (var/y = 20, y <= 39, y++)
			if (deck_roof(x, y))
				roofs++
	var/obj/structure/hull_tiller/big = new(locate(40, 20, 2))
	naval_check(roofs == 200 && isnull(big.commission("Leviathan", NORTH)), "a 200-tile hull is roofed over and commissioned ([roofs])")
	var/datum/craft_body/built/BB = big.craft.body
	var/turf/BO = BB.origin()
	naval_check(!BB.move_to(BO.x, BO.y + 1, NORTH) && findtext(BB.last_refusal, "more than [BUILT_HULL_MAX_DECK_TILES] in all"), "with 200 tiles of upper deck as well her decks are too large to sail ([BB.last_refusal])")
	for (var/x = 45, x <= 49, x++)
		for (var/y = 20, y <= 39, y++)
			for (var/obj/roof/R in locate(x, y, 2))
				qdel(R)
	naval_check(BB.upper_tile_count() == 100 && deck_floors(locate(47, 30, 3)) == 0, "taking down half her roofs takes their floors too ([BB.upper_tile_count()])")
	for (var/i = 1, i <= 10, i++)
		new /obj/item/weapon/reagent_containers/glass/bucket(locate(40 + (i % 5), 30, 3))
		new /mob/living/human/naval_probe(locate(40 + (i % 5), 25, 3))
	var/worst = 0
	var/total = 0
	for (var/i = 1, i <= 4, i++)
		sleep(1)
		BO = BB.origin()
		var/t = world.tick_usage
		var/ok = BB.move_to(BO.x, BO.y + 1, NORTH)
		var/ms = deck_ms(t)
		naval_check(ok, "step [i] at the cap of 300 deck tiles ([BB.last_refusal])")
		worst = max(worst, ms)
		total += ms
	world.log << "TIMING: a step of 200 tiles of hull with 100 of upper deck: worst [worst] ms, mean [total / 4] ms"
	naval_check(worst < 100, "a step at the cap stays well inside a tick ([worst] ms)")
	naval_check(deck_paired(BB) == 100 && BB.upper_tile_count() == 100, "after four steps every roof still has its floor")

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
