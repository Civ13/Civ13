// Long passages for a fitted warship (code/modules/naval/ship_crossing.dm):
// a light cruiser off the slipway and a fully laden 200-tile battleship with
// a hold pack into one crossing record, well inside its budget, and come out
// the other side with turrets loaded and fed, shell racks full and the belt
// armour on her sides. Packing and building time are logged.
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
/proc/probe_rack(turf/T, shells)
	var/obj/structure/shellrack/R = new(T)
	for (var/i = 1, i <= shells, i++)
		new /obj/item/cannon_ball/shell(R.storage)
	R.update_icon()
	return R

/proc/probe_ms(t)
	return (world.tick_usage - t) * world.tick_lag

// What stands in the box from (x1, y1) to (x2, y2): turrets, the shells in
// their breeches, turrets fed from below, racks, the shells in them, plates.
/proc/probe_fittings(x1, y1, x2, y2)
	var/list/L = list("turrets" = 0, "loaded" = 0, "fed" = 0, "racks" = 0, "shells" = 0, "plates" = 0)
	for (var/obj/structure/cannon/modern/ship_turret/G in world)
		if (G.x >= x1 && G.x <= x2 && G.y >= y1 && G.y <= y2)
			L["turrets"]++
			L["loaded"] += G.loaded.len
			if (G.magazine())
				L["fed"]++
	for (var/obj/structure/shellrack/R in world)
		if (R.x >= x1 && R.x <= x2 && R.y >= y1 && R.y <= y2)
			L["racks"]++
			for (var/obj/item/cannon_ball/S in R.storage.contents)
				L["shells"]++
	for (var/obj/structure/hull_armour/A in world)
		if (A.x >= x1 && A.x <= x2 && A.y >= y1 && A.y <= y2)
			L["plates"]++
	return L

/proc/probe_said(list/L)
	var/list/out = list()
	for (var/key in L)
		out += "[key] [L[key]]"
	return jointext(out, ", ")

/proc/naval_checks()
	naval_fixture()

	// ---- A light cruiser off the slipway ----
	var/datum/vessel/freighter/cruiser/warship = new
	naval_check(warship.place(45, 48, 2, EAST), "a light cruiser is laid down ([warship.last_refusal])")
	var/obj/structure/hull_tiller/CT = vessel_to_built_hull(warship)
	var/datum/craft_body/built/CB = CT ? CT.craft.body : null
	naval_check(CB && CB.lower_tile_count() == 82, "she becomes a built hull with her hold")
	if (!CB)
		return
	for (var/obj/structure/shellrack/R in CB.aboard())
		for (var/i = 1, i <= 6, i++)
			new /obj/item/cannon_ball/shell(R.storage)
	for (var/obj/structure/cannon/modern/ship_turret/G in CB.aboard())
		G.take_from_magazine()
	var/load = sea_crossing_load(CT)
	naval_check(isnum(load) && load < 15, "her turrets, racks and belt pass for a crossing, at [load]% of the record budget")
	var/list/packed = sea_crossing_pack(CT)
	var/list/R = islist(packed) ? packed["record"] : null
	naval_check(R && sea_crossing_record_ok(R), "her record is one a far shore accepts")
	var/plates_packed = 0
	for (var/list/tile in (R ? R["tiles"] : list()))
		for (var/list/E in tile[3])
			if (E[1] == "a")
				plates_packed++
	naval_check(plates_packed == 34, "her 34 belt plates go as part of her hull, not as cargo ([plates_packed])")
	var/obj/structure/hull_tiller/NT = R ? sea_crossing_build(R, locate(45, 10, 2)) : null
	var/list/got = probe_fittings(30, 1, 70, 20)
	naval_check(NT && got["turrets"] == 2 && got["loaded"] == 2 && got["fed"] == 2, "she arrives with both turrets loaded over their magazines ([probe_said(got)])")
	naval_check(got["racks"] == 2 && got["shells"] == 10 && got["plates"] == 34, "her racks keep their shells and her sides their belt")
	naval_check(NT && NT.craft && NT.craft.armour_belt()[1] == 34, "the tiller counts her belt again")

	// ---- A fully laden 200-tile battleship ----
	// Eight turrets over full racks, her sides belted, and as much stowed in
	// crates as a crossing takes.
	for (var/x = 3, x <= 12, x++)
		for (var/y = 30, y <= 49, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	for (var/x = 3, x <= 12, x++)
		for (var/y = 30, y <= 49, y++)
			var/obj/covers/steelplating/SP = new(locate(x, y, 2))
			SP.updateturf()
			if (x >= 4 && x <= 11 && y >= 34 && y <= 45)
				hull_hold_lay(locate(x, y, 1))
	var/list/turrets = list()
	for (var/y in list(34, 38, 42, 45))
		for (var/x in list(4, 11))
			var/obj/structure/cannon/modern/ship_turret/T = new(locate(x, y, 2))
			T.face_dir(x == 4 ? WEST : EAST)
			probe_rack(locate(x, y, 1), 12)
			turrets += T
	for (var/y = 30, y <= 49, y++)
		new /obj/structure/hull_armour(locate(3, y, 2))
		new /obj/structure/hull_armour(locate(12, y, 2))
	for (var/i = 0, i < 13, i++)
		var/obj/structure/closet/crate/K = new(locate(5 + i % 6, 36 + round(i / 6) * 3, 1))
		for (var/obj/item/old in K)
			qdel(old)
		for (var/j = 1, j <= 30, j++)
			new /obj/item/stack/material/steel(K, 50)
	var/obj/structure/hull_tiller/bb = new(locate(8, 30, 2))
	naval_check(isnull(bb.commission("Dreadnought", NORTH)) && bb.craft, "a 200-tile battleship is commissioned")
	var/datum/craft_body/built/BB = bb.craft.body
	naval_check(BB.tile_count() == 200 && BB.lower_tile_count() == 96, "she has 200 tiles of hull and 96 of hold")
	for (var/obj/structure/cannon/modern/ship_turret/T in turrets)
		T.take_from_magazine()
	var/t = world.tick_usage
	var/list/big = sea_crossing_pack(bb)
	var/pack_ms = probe_ms(t)
	if (istext(big))
		world.log << "battleship refused: [big]"
	var/list/BR = islist(big) ? big["record"] : null
	var/size = BR ? length(json_encode(BR)) : 0
	naval_check(BR && sea_crossing_record_ok(BR), "laden to the crossing limits, her record is accepted")
	naval_check(size && size * 2 < 196608, "she fills under half of the record budget ([size] of 196608 bytes)")
	var/obj/structure/hull_tiller/BT = null
	var/build_ms = 0
	if (BR)
		t = world.tick_usage
		BT = sea_crossing_build(BR, locate(60, 22, 2))
		build_ms = probe_ms(t)
	got = probe_fittings(50, 20, 70, 42)
	naval_check(BT && got["turrets"] == 8 && got["loaded"] == 8 && got["fed"] == 8, "she arrives with eight turrets loaded and fed ([probe_said(got)])")
	naval_check(got["racks"] == 8 && got["shells"] == 88 && got["plates"] == 40, "her magazines and belt arrive whole")
	var/crates = 0
	var/steel = 0
	for (var/obj/structure/closet/crate/K in world)
		if (K.x >= 50 && K.y >= 20 && K.y <= 42)
			crates++
			for (var/obj/item/stack/material/steel/S in K)
				steel += S.amount
	naval_check(crates == 13 && steel == 13 * 30 * 50, "her crates arrive full ([crates], [steel] steel)")
	world.log << "PASSAGE: a laden 200-tile battleship with 96 tiles of hold packs to [size] bytes in [pack_ms] ms and is built in [build_ms] ms"
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
