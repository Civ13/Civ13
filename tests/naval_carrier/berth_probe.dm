// Berths (code/modules/naval/berth.dm): a built hull lying wholly in a
// boathouse slip can be caulked tight, scraped and sheathed over deep water,
// her patches planked over for good, and the boathouse surveys what she
// needs; the same hull outside the slip cannot. A small boat stored in the
// boathouse dries faster.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/berth_probe/New()
	return
/mob/living/human/berth_probe/New()
	return
var/berth_failures = 0
var/berth_runtime_error = FALSE
/proc/berth_check(condition, label)
	if (!condition)
		berth_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	berth_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Sand ashore (x 1-10), deep sea beyond.
/proc/berth_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(x <= 10 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)

// A wooden hull of planks laid the way a player lays them, commissioned.
/proc/berth_hull(x1, y1, x2, y2, hull_name)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			var/obj/covers/repairedfloor/ship/C = new(locate(x, y, 1))
			C.updateturf()
	var/obj/structure/hull_tiller/tiller = new(locate(x1, y1, 1))
	berth_check(isnull(tiller.commission(hull_name, NORTH)) && tiller.craft && tiller.craft.ledger, "the [hull_name] is commissioned")
	return tiller

/proc/berth_near(a, b, slack = 0.01)
	return abs(a - b) <= slack

/proc/berth_checks()
	berth_fixture()
	var/obj/structure/boathouse/house = new(locate(10, 5, 1))
	berth_check(house.slip_dir == NORTHEAST, "the boathouse slip lies north-east (x 11-17, y 6-12)")

	// ---- The Wren lies wholly in the slip, the Lark out at sea ----
	var/obj/structure/hull_tiller/wren_tiller = berth_hull(12, 7, 14, 11, "Wren")
	var/obj/structure/hull_tiller/lark_tiller = berth_hull(25, 7, 27, 11, "Lark")
	var/datum/craft/wren = wren_tiller.craft
	var/datum/craft/lark = lark_tiller.craft
	var/datum/hull_ledger/W = wren.ledger
	var/datum/hull_ledger/L = lark.ledger
	berth_check(W.tiles == 15 && W.hull_class() == HULL_CLASS_BOAT && W.seep_tiles == 15, "the Wren is a wooden boat of fifteen tiles ([W.tiles])")
	berth_check(craft_berth(wren) == house, "the boathouse holds the Wren")
	berth_check(isnull(craft_berth(lark)), "nothing holds the Lark")
	berth_check((wren in house.hulls_in_slip()) && !(lark in house.hulls_in_slip()), "the slip lists the Wren and not the Lark")

	// Deep water under both, but the Wren's bottom is in reach.
	berth_check(W.over_deep() && W.bottom_reachable() && W.caulk_floor() == 0, "over deep water in the slip she can be caulked tight")
	berth_check(L.over_deep() && !L.bottom_reachable() && berth_near(L.caulk_floor(), HULL_SEAMS_FAIR), "out at sea only back to sound")

	var/mob/living/human/berth_probe/H = new(locate(13, 9, 1))
	var/obj/covers/wren_plank = locate(/obj/covers) in locate(13, 10, 1)
	berth_check(isnull(hull_bottom_refusal(H, wren_plank)), "her bottom can be worked in the slip ([hull_bottom_refusal(H, wren_plank)])")
	var/mob/living/human/berth_probe/H2 = new(locate(26, 9, 1))
	var/obj/covers/lark_plank = locate(/obj/covers) in locate(26, 10, 1)
	berth_check(findtext(hull_bottom_refusal(H2, lark_plank), "berth") && findtext(hull_bottom_refusal(H2, lark_plank), "shallows"), "the Lark's crew are told of the shallows and berths ([hull_bottom_refusal(H2, lark_plank)])")

	// What the work comes to.
	W.seams = 1
	L.seams = 1
	berth_check(W.caulk_wanted() == 5, "open seams on fifteen tiles take five twists to tight ([W.caulk_wanted()])")
	berth_check(L.caulk_wanted() == 4, "out at sea four twists bring the Lark back to sound ([L.caulk_wanted()])")
	W.seams = 0
	berth_check(W.caulk_wanted() == 0, "tight seams want nothing")
	W.seams = 1
	W.fouling = 1
	berth_check(W.scrape_wanted() == 5 && W.copper_wanted() == 7, "a foul bottom takes five goes and seven copper sheets ([W.scrape_wanted()], [W.copper_wanted()])")
	W.caulk_twist()
	berth_check(berth_near(W.seams, 0.8), "a twist in the slip tightens her ([W.seams])")
	for (var/i = 1, i <= 4, i++)
		W.caulk_twist()
	berth_check(berth_near(W.seams, 0), "and five drive her right down to tight")

	// ---- A patch planked over for good ----
	var/turf/hole = locate(14, 9, 1)
	var/obj/covers/old = locate(/obj/covers) in hole
	qdel(old)
	berth_check(W.holes == 1, "a plank lost is a hole")
	var/obj/item/stack/material/wood/timber = new(locate(13, 9, 1))
	timber.amount = 5
	var/obj/covers/repairedfloor/ship/patch/P = hull_patch_lay(wren, timber, hole)
	berth_check(istype(P) && W.patches == 1 && W.holes == 0 && timber.amount == 3, "the hole is patched with two wood")
	berth_check(findtext(berth_plank_refusal(H, timber, P), "hammer"), "planking over wants a hammer and nothing else ([berth_plank_refusal(H, timber, P)])")
	var/list/report = house.condition_report()
	berth_check(report.len == 1 && findtext(report[1], "Wren") && findtext(report[1], "Work wanted") && findtext(report[1], "1 patch to plank over") && findtext(report[1], "Bottom to scrape: 5 goes"), "the boathouse surveys the Wren and lists her work ([report.len ? report[1] : "none"])")
	var/obj/covers/N = berth_plank_lay(wren, timber, P)
	berth_check(istype(N, /obj/covers/repairedfloor/ship) && !istype(N, /obj/covers/repairedfloor/ship/patch) && N.afloat && timber.amount == 2, "the patch becomes sound planking for one wood")
	berth_check(QDELETED(P) && W.patches == 0 && W.holes == 0 && W.seep_tiles == 15, "her ledger finds no patch and no hole ([W.patches], [W.holes], [W.seep_tiles])")
	var/obj/item/stack/material/steel/plate = new(locate(13, 9, 1))
	plate.amount = 3
	qdel(N)
	P = hull_patch_lay(wren, timber, hole)
	N = berth_plank_lay(wren, plate, P)
	berth_check(istype(N, /obj/covers/steelplating) && plate.amount == 2 && W.seep_tiles == 14 && W.patches == 0, "a steel sheet plates a patch over and that tile seeps no more ([W.seep_tiles])")

	// The Lark's patch must wait for a berth.
	var/turf/lark_hole = locate(27, 9, 1)
	qdel(locate(/obj/covers) in lark_hole)
	timber.amount = 5
	var/obj/covers/repairedfloor/ship/patch/LP = hull_patch_lay(lark, timber, lark_hole)
	berth_check(findtext(berth_plank_refusal(H2, timber, LP), "berth"), "out at sea a patch cannot be planked over ([berth_plank_refusal(H2, timber, LP)])")

	// Under way she is not worked on, even in the slip.
	wren.set_anchor(FALSE)
	wren.set_speed(VESSEL_SPEED_SLOW)
	berth_check(findtext(hull_bottom_refusal(H, wren_plank), "lie still"), "under way she must lie still first")
	wren.set_speed(VESSEL_SPEED_STOP)
	wren.set_anchor(TRUE)

	// ---- Small boats dry faster stored ----
	var/obj/structure/vehicle/raft/dugout/canoe = new(locate(5, 20, 1))
	berth_check(canoe.dry_factor() == 1, "a dugout on the shore dries at the plain rate")
	var/obj/structure/boathouse_stored_tile/shelf = new(house)
	canoe.loc = shelf
	berth_check(canoe.dry_factor() == 3, "stored in the boathouse she dries three times as fast")
	berth_check(findtext(canoe.berth_condition_text(), "dries out 3 times"), "and the survey says so")

/proc/berth_run()
	try
		berth_checks()
	catch(var/exception/e)
		berth_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = berth_failures, "runtime_error" = berth_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/berth_probe
		berth_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		berth_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		berth_run()
