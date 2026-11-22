// Ship's gun turrets (code/modules/naval/ship_turret.dm): a turret on a
// built hull hoists shells up its barbette from a rack in her hold right
// under it, found by position, through sailing and turning.
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


/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/probe_rack(turf/T, shells)
	var/obj/structure/shellrack/R = new(T)
	for (var/i = 1, i <= shells, i++)
		new /obj/item/cannon_ball/shell(R.storage)
	R.update_icon()
	return R

/proc/naval_checks()
	naval_fixture()
	naval_research_done = TRUE

	// ---- A hull with a hold, a turret amidships and its magazine below ----
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	for (var/x = 31, x <= 33, x++)
		hull_hold_lay(locate(x, 11, 1))
	var/obj/structure/cannon/modern/ship_turret/G = new(locate(32, 11, 2))
	G.face_dir(EAST)
	var/obj/structure/shellrack/R = probe_rack(locate(32, 11, 1), 2)
	var/obj/structure/cannon/modern/ship_turret/dry = new(locate(30, 10, 2))
	var/obj/structure/shellrack/rock_rack = probe_rack(locate(30, 10, 1), 1)
	var/obj/structure/hull_tiller/tiller = new(locate(30, 11, 2))
	naval_check(isnull(tiller.commission("Warspite", EAST)) && tiller.craft, "she is commissioned")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(B.lower_tile_count() == 3 && (G in B.aboard()) && (R in B.aboard()), "her hold, her turret and its rack are aboard ([B.lower_tile_count()])")
	naval_check(craft_holding(locate(32, 11, 1)) == C && craft_holding(locate(32, 11, 2)) == C && !craft_holding(locate(40, 11, 2)), "her hold tiles are hers and the sea beside her is nobody's")
	naval_check(G.magazine() == R && findtext(G.barbette_text(), "2 shells"), "the turret's barbette reaches the rack right under it ([G.barbette_text()])")
	naval_check(isnull(dry.magazine()) && findtext(dry.barbette_text(), "reaches no shell rack"), "a turret over the rock beside her hold reaches no rack, though one stands in the rock under it")

	// ---- Hoisting ----
	naval_check(G.take_from_magazine() && G.loaded.len == 1 && R.storage.contents.len == 1, "a shell rides up the barbette into the breech")
	naval_check(!G.take_from_magazine() && R.storage.contents.len == 1, "a loaded gun takes no second shell")
	var/obj/item/cannon_ball/fired = G.loaded[1]
	G.loaded -= fired
	qdel(fired)
	naval_check(G.take_from_magazine() && R.storage.contents.len == 0, "the second shell comes up once the breech is clear")
	G.loaded.Cut()
	naval_check(!G.take_from_magazine() && findtext(G.barbette_text(), "0 shells"), "an empty rack sends nothing up")
	new /obj/item/cannon_ball/shell(R.storage)
	new /obj/item/weapon/aircraft_bomb(R.storage)

	// ---- She sails and turns; the barbette still reaches the same rack ----
	var/turf/O = B.origin()
	naval_check(B.move_to(O.x + 1, O.y, EAST), "she steps one tile east ([B.last_refusal])")
	naval_check(G.x == 33 && R.x == 33 && R.z == 1 && G.magazine() == R, "turret and rack moved together and still line up ([G.x],[R.x])")
	naval_check(B.turn_to(NORTH), "she comes about to the north ([B.last_refusal])")
	naval_check(G.x == R.x && G.y == R.y && G.magazine() == R, "after the turn the rack is still right under the turret ([G.x],[G.y] over [R.x],[R.y])")
	naval_check(G.take_from_magazine() && G.loaded.len == 1, "she still hoists after sailing and turning")
	G.loaded.Cut()


	// ---- Belt armour ----
	var/obj/structure/hull_armour/plate = new(locate(G.x + 1, G.y, 2))
	var/turf/PT = get_turf(plate)
	var/list/belt = C.armour_belt()
	naval_check(belt[1] == 1 && belt[2] >= 8 && findtext(tiller.status_text(), "Belt armour covers 1 of her"), "the tiller counts her belt ([belt[1]] of [belt[2]])")
	naval_check(plate.hull_load() == 1, "a plate weighs like a tile of hull")
	var/obj/covers/plated_floor = null
	for (var/obj/covers/F in PT)
		plated_floor = F
	naval_check(plated_floor && hull_armour_soften(plated_floor, 3) == 4 && hull_armour_soften(plated_floor, 2) == 3 && !QDELETED(plate), "a blast on a plated tile reaches her floor a step lighter, and a light one leaves the plate")
	var/holes_before = C.ledger ? C.ledger.holes : 0
	plate.ex_act(1)
	naval_check(!QDELETED(plate), "the plate takes its blast through the floor it covers")
	plated_floor.ex_act(1)
	naval_check(!QDELETED(plated_floor) && (!C.ledger || C.ledger.holes == holes_before), "a direct hit on a plated tile leaves her floor and she is not holed")
	naval_check(QDELETED(plate) && !hull_armour_at(PT), "the direct hit spent the plate")
	var/turf/bare = locate(PT.x, PT.y, 2)
	var/obj/covers/bare_floor = null
	for (var/obj/covers/F in bare)
		bare_floor = F
	naval_check(bare_floor && hull_armour_soften(bare_floor, 1) == 1, "without the plate a blast hits her floor in full")
	// Her hold under a plated tile is covered too.
	var/obj/structure/hull_armour/plate2 = new(locate(R.x, R.y, 2))
	var/obj/covers/hold_floor = null
	for (var/obj/covers/F in get_turf(R))
		hold_floor = F
	naval_check(hold_floor && hull_armour_at(get_turf(R)) == plate2 && hull_armour_soften(hold_floor, 2) == 3, "the hold floor under a plated tile is covered by the belt")

	// ---- Off a ship ----
	var/obj/structure/cannon/modern/ship_turret/fort = new(locate(10, 10, 2))
	var/obj/structure/shellrack/fort_rack = probe_rack(locate(10, 10, 1), 1)
	naval_check(fort.magazine() == fort_rack, "ashore a turret reaches a magazine dug under it")
	naval_check(rock_rack && !QDELETED(rock_rack), "the rack in the rock stays where it was")
	naval_check(G.bound_width == 32 && G.bound_height == 32 && G.density, "the turret stands on one tile")

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
