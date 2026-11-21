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
/proc/berth_hull(x1, y1, x2, y2, hull_name, heading = NORTH)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			var/obj/covers/repairedfloor/ship/C = new(locate(x, y, 1))
			C.updateturf()
	var/obj/structure/hull_tiller/tiller = new(locate(x1, y1, 1))
	berth_check(isnull(tiller.commission(hull_name, heading)) && tiller.craft && tiller.craft.ledger, "the [hull_name] is commissioned")
	return tiller

/obj/structure/boathouse_probe_block
	name = "probe block"
	anchored = TRUE
	density = TRUE

/proc/near_zero_change(a, b)
	return abs(a - b) <= 0.001

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
	var/obj/structure/vehicle/raft/dugout/canoe = new(locate(5, 28, 1))
	berth_check(canoe.dry_factor() == 1, "a dugout on the shore dries at the plain rate")
	var/obj/structure/boathouse_stored_tile/shelf = new(house)
	canoe.loc = shelf
	berth_check(canoe.dry_factor() == 3, "stored in the boathouse she dries three times as fast")
	berth_check(findtext(canoe.berth_condition_text(), "dries out 3 times"), "and the survey says so")

/proc/berth_haul_checks()
	// A slipway at 3,20 facing east: its berth is the sand from x 4 to 10.
	var/obj/structure/slipway/post = new(locate(3, 20, 1))
	post.dir = EAST
	var/obj/structure/hull_tiller/tern_tiller = berth_hull(15, 19, 19, 21, "Tern", EAST)
	var/datum/craft/tern = tern_tiller.craft
	var/datum/hull_ledger/L = tern.ledger
	berth_check(post.hull_off_ways() == tern && post.haul_distance(tern) == 11, "the Tern lies off the ways, eleven tiles from the berth ([post.haul_distance(tern)])")
	berth_check(isnull(craft_berth(tern)) && !L.lies_dry(), "afloat, nothing holds her")
	berth_check(findtext(post.haul_refusal(tern), "pair"), "with nobody at the post she cannot be hauled ([post.haul_refusal(tern)])")
	var/mob/living/human/berth_probe/hauler = new(locate(3, 21, 1))
	berth_check(slipway_hands_needed(tern) == 1 && post.haul_hands(tern) == 1 && isnull(post.haul_refusal(tern)), "one pair of hands hauls her fifteen tiles ([post.haul_refusal(tern)])")
	tern.set_anchor(FALSE)
	tern.set_speed(VESSEL_SPEED_SLOW)
	berth_check(findtext(post.haul_refusal(tern), "stop"), "under way she must stop first")
	tern.set_speed(VESSEL_SPEED_STOP)
	var/obj/structure/probe_block = new /obj/structure/boathouse_probe_block(locate(10, 22, 1))
	berth_check(isnull(post.haul_refusal(tern)), "something off to the side is not in her way")
	qdel(probe_block)
	probe_block = new /obj/structure/boathouse_probe_block(locate(9, 20, 1))
	berth_check(findtext(post.haul_refusal(tern), "in the way"), "something solid on the berth stops her ([post.haul_refusal(tern)])")
	qdel(probe_block)
	var/list/options = list()
	post.haul_options(options)
	berth_check(options["Haul the Tern out"] == "haul", "the post offers to haul her out")
	L.water = 12
	L.fouling = 0.5
	berth_check(isnull(post.haul_out(tern)), "she is hauled up the ways ([post.haul_out(tern)])")
	var/turf/stern = locate(4, 20, 1)
	berth_check(craft_at(stern) == tern && craft_at(locate(8, 21, 1)) == tern && !craft_at(locate(15, 20, 1)), "her stern lies in front of the post and the sea is clear behind her")
	berth_check(post.hauled_hull() == tern && craft_berth(tern) == post && L.lies_dry(), "the slipway holds her dry")
	berth_check(L.water == 0 && tern.anchored, "the water ran out of her and she is held")
	L.water = 5
	L.crewed = TRUE
	var/seams_was = L.seams
	L.step_ledger(600)
	berth_check(L.water == 0 && L.seams == seams_was && near_zero_change(L.fouling, 0.5), "hauled out she gathers no water, wears nothing and grows nothing")
	L.crewed = FALSE
	var/mob/living/human/berth_probe/H = new(locate(6, 20, 1))
	var/obj/covers/plank = locate(/obj/covers) in locate(6, 21, 1)
	berth_check(isnull(hull_bottom_refusal(H, plank)) && L.caulk_floor() == 0, "her bottom and seams can be worked ([hull_bottom_refusal(H, plank)])")
	options = list()
	berth_check(post.haul_options(options) && options["Launch the Tern again"] == "relaunch" && options["Survey her condition"] == "survey", "the post offers to launch her again and to survey her")
	berth_check(findtext(L.berth_condition_text(), "Bottom to scrape"), "the survey lists her bottom")
	qdel(H)
	qdel(hauler)
	berth_check(isnull(post.relaunch(tern)), "she slides back down the ways ([post.relaunch(tern)])")
	berth_check(!craft_at(stern) && isnull(craft_berth(tern)) && !L.lies_dry() && istype(get_turf(tern_tiller), /turf/floor/beach/water), "afloat again, the berth is empty")
	berth_check(findtext(post.relaunch(tern), "No ship"), "nothing is left to launch")

/proc/berth_dock_checks()
	// A basin of trench from x 4 to 9 and y 24 to 28, with three dock gates
	// across its mouth at x 10, y 25 to 27, opening on the sea at x 11.
	for (var/x = 4, x <= 9, x++)
		for (var/y = 24, y <= 28, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/trench/flooded/salty)
	var/list/gates = list()
	for (var/y = 25, y <= 27, y++)
		var/turf/T = locate(10, y, 1)
		T.ChangeTurf(/turf/floor/trench/flooded/salty)
		gates += new /obj/structure/canal_lock/dock_gate(T)
	var/obj/structure/canal_lock/dock_gate/gate = gates[2]
	gate.refresh_basin()
	var/list/basin = gate.basin()
	berth_check(islist(basin) && basin.len == 30, "the basin is thirty tiles of trench behind the gates ([islist(basin) ? basin.len : gate.survey_basin()])")
	var/list/all = gate.all_gates()
	berth_check(all.len == 3, "the three gates work together ([all.len])")
	if (!research_nodes.len)
		build_research_tree()
	berth_check(get_recipe_node_req("/obj/structure/canal_lock/dock_gate") == "wagons_ships", "Wagons & Ships gates the dock gate ([get_recipe_node_req("/obj/structure/canal_lock/dock_gate")])")
	berth_check(dock_floats(locate(6, 26, 1)) && dock_floats(locate(10, 26, 1)) && !dock_floats(locate(3, 26, 1)), "a hull floats in the flooded basin and through an open gate")

	// The Petrel sails in from the sea.
	var/obj/structure/hull_tiller/petrel_tiller = berth_hull(13, 25, 17, 27, "Petrel", WEST)
	var/datum/craft/petrel = petrel_tiller.craft
	var/datum/craft_body/built/B = petrel.body
	var/datum/hull_ledger/L = petrel.ledger
	berth_check(B.move_to(5, 25, WEST), "she sails into the basin ([B.last_refusal])")
	berth_check(craft_at(locate(9, 26, 1)) == petrel && craft_at(locate(5, 25, 1)) == petrel && !craft_at(locate(13, 26, 1)), "she lies wholly in the basin")
	var/obj/structure/S = craft_berth(petrel)
	berth_check(istype(S, /obj/structure/canal_lock/dock_gate) && !S.berth_dry(petrel) && L.bottom_reachable(), "the flooded dock holds her like a slip")
	berth_check(findtext(gate.pump_refusal(), "Shut the gate"), "the dock cannot be pumped with the gates open ([gate.pump_refusal()])")
	for (var/obj/structure/canal_lock/dock_gate/G in all)
		G.set_shut(TRUE)
	berth_check(gate.density && gate.chamber_level < -100 && isnull(gate.pump_refusal()), "shut, the gates hold the water and the dock can be pumped ([gate.pump_refusal()])")
	berth_check(!dock_floats(locate(10, 26, 1)), "no hull passes a shut gate")
	berth_check(gate.pump_rate() == 1, "by hand one go pumps one tile")
	var/obj/structure/cellar_pump/lever/hand_pump = new(locate(10, 23, 1))
	berth_check(gate.pump_rate() == 2, "a hand pump by the gate doubles it ([gate.pump_rate()])")
	qdel(hand_pump)
	L.water = 20
	L.fouling = 0.5
	berth_check(gate.drain(), "the dock is pumped dry")
	sleep(10)
	var/dry = TRUE
	for (var/turf/T in basin)
		if (!istype(T, /turf/floor/trench) || istype(T, /turf/floor/trench/flooded))
			dry = FALSE
	berth_check(dry, "every tile of the basin is dry and stays dry behind the gates")
	berth_check(istype(locate(10, 26, 1), /turf/floor/trench/flooded) && istype(locate(11, 26, 1), /turf/floor/beach/water), "the sea stands outside the gates")
	berth_check(gate.drained && craft_berth(petrel) && L.lies_dry() && L.water == 0 && petrel.anchored, "she lies dry on the dock floor, held, her bilge empty")
	var/floors = 0
	for (var/turf/T in B.cells())
		if (locate(/obj/covers) in T)
			floors++
	berth_check(floors == 15, "all fifteen of her floors are still under her ([floors])")
	berth_check(!B.can_move_to(4, 25, WEST), "she cannot sail on the dock floor")
	L.crewed = TRUE
	L.water = 3
	L.step_ledger(600)
	berth_check(L.water == 0 && near_zero_change(L.fouling, 0.5), "dry in the dock nothing changes")
	L.crewed = FALSE
	var/mob/living/human/berth_probe/H = new(locate(6, 26, 1))
	var/obj/covers/plank = locate(/obj/covers) in locate(7, 26, 1)
	berth_check(isnull(hull_bottom_refusal(H, plank)), "her bottom can be scraped ([hull_bottom_refusal(H, plank)])")
	qdel(H)
	berth_check(findtext(gate.pump_refusal(), "already dry"), "a dry dock is not pumped again")
	// Flooded and opened, she sails out.
	berth_check(gate.flood(), "the sluices flood the dock")
	berth_check(istype(locate(6, 27, 1), /turf/floor/trench/flooded/salty) && !gate.drained && !L.lies_dry(), "the basin is salt water again and she floats")
	for (var/obj/structure/canal_lock/dock_gate/G in all)
		G.set_shut(FALSE)
	berth_check(B.move_to(13, 25, WEST), "with the gates open she sails out ([B.last_refusal])")
	berth_check(isnull(craft_berth(petrel)), "out at sea no berth holds her")
	berth_dock_build_checks(gate)
	// A basin open to the sea elsewhere is no dock.
	var/turf/leak = locate(10, 29, 1)
	leak.ChangeTurf(/turf/floor/trench/flooded/salty)
	berth_check(findtext(gate.survey_basin(), "open to the water"), "a basin that touches the sea past its gates is refused ([gate.survey_basin()])")

// Lays wooden floors from x1,y1 to x2,y2 the way a player lays them.
/proc/berth_floors(x1, y1, x2, y2)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			var/obj/covers/repairedfloor/ship/C = new(locate(x, y, 1))
			C.updateturf()

/proc/berth_build_checks()
	// A slipway at 3,15 facing east: a hull is laid down on its dry berth.
	var/obj/structure/slipway/post = new(locate(3, 15, 1))
	post.dir = EAST
	berth_floors(4, 14, 8, 16)
	var/obj/structure/hull_tiller/tiller = new(locate(4, 15, 1))
	berth_check(berth_ground_at(locate(6, 15, 1)) == post && !berth_ground_at(locate(3, 16, 1)), "the slipway's berth is the ground in front of the post")
	berth_check(islist(built_hull_survey(get_turf(tiller))), "floors on the berth survey as a hull ([built_hull_survey(get_turf(tiller))])")
	berth_check(findtext(tiller.commission("Gull", NORTH), "bow must point"), "on the slipway her bow must point to the water ([tiller.commission("Gull", NORTH)])")
	var/obj/covers/repairedfloor/ship/stray = new(locate(3, 16, 1))
	stray.updateturf()
	berth_check(findtext(built_hull_survey(get_turf(tiller)), "joined to the shore"), "a floor off the berth joins her to the shore")
	qdel(stray)
	berth_check(isnull(tiller.commission("Gull", EAST)) && tiller.craft, "she is commissioned on the berth")
	var/datum/craft/gull = tiller.craft
	berth_check(gull.ledger.tiles == 15 && post.hauled_hull() == gull && craft_berth(gull) == post && gull.ledger.lies_dry(), "she lies hauled out on the slipway")
	// A floor more, and the refit takes it in.
	berth_floors(9, 15, 9, 15)
	berth_check(isnull(tiller.commission()) && gull.ledger.tiles == 16 && post.hauled_hull() == gull, "a refit on the berth takes in a new floor ([gull.ledger.tiles])")
	berth_check(isnull(post.relaunch(gull)) && istype(get_turf(tiller), /turf/floor/beach/water) && !gull.ledger.lies_dry(), "she is launched from the berth she was built on ([post.relaunch(gull)])")
	// Floors on plain ground are no hull.
	berth_floors(1, 14, 2, 15)
	var/obj/structure/hull_tiller/shore_tiller = new(locate(1, 14, 1))
	berth_check(findtext(shore_tiller.commission("Mud", NORTH), "at a berth"), "floors on plain ground are no hull ([shore_tiller.commission("Mud", NORTH)])")
	qdel(shore_tiller)

/proc/berth_dock_build_checks(obj/structure/canal_lock/dock_gate/gate)
	for (var/obj/structure/canal_lock/dock_gate/G in gate.all_gates())
		G.set_shut(TRUE)
	berth_check(gate.drain(), "the empty dock is pumped dry")
	sleep(10)
	berth_floors(5, 25, 7, 27)
	var/obj/structure/hull_tiller/tiller = new(locate(5, 26, 1))
	berth_check(isnull(tiller.commission("Skua", EAST)) && tiller.craft, "a hull is laid down on the dry dock floor")
	var/datum/craft/skua = tiller.craft
	berth_check(istype(craft_berth(skua), /obj/structure/canal_lock/dock_gate) && skua.ledger.lies_dry(), "the dock holds her dry ([craft_berth(skua)])")
	berth_check(gate.flood() && !skua.ledger.lies_dry() && craft_at(locate(6, 26, 1)) == skua, "flooded, she floats in the basin")
	berth_check(isnull(tiller.commission()) && skua.ledger.tiles == 9, "afloat in the basin she can be refitted")
	tiller.decommission()
	for (var/turf/T in block(locate(5, 25, 1), locate(7, 27, 1)))
		for (var/obj/covers/C in T)
			qdel(C)
	qdel(tiller)
	for (var/obj/structure/canal_lock/dock_gate/G in gate.all_gates())
		G.set_shut(FALSE)

/proc/berth_run()
	try
		berth_checks()
		berth_haul_checks()
		berth_dock_checks()
		berth_build_checks()
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
