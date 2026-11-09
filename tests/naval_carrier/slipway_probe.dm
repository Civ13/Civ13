// Turf-built vessels, the slipway: players build a ship piece by piece on a
// berth beside the water and launch her. The post is gated on Wagons & Ships,
// refuses a berth with no deep water ahead, lays a keel, takes materials a
// piece at a time and shows the hull growing from stern to bow; a finished
// schooner slides down the ways with her crew aboard and sails without fuel;
// a freighter gets her hold, engine room and ladders below; a dry dock must
// be flooded first; the frames are rebuilt after a load, never saved.
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

/proc/slipway_frames_named(obj/structure/slipway/S, text)
	. = 0
	for (var/obj/structure/slipway_frame/F in S.frames)
		if (!QDELETED(F) && findtext(F.name, text))
			.++

/proc/slipway_frame_count(obj/structure/slipway/S)
	. = 0
	for (var/obj/structure/slipway_frame/F in S.frames)
		if (!QDELETED(F))
			.++

// Pays for every remaining piece with fresh stacks; returns the pieces fitted.
/proc/slipway_finish(obj/structure/slipway/S)
	var/list/paths = list("wood" = /obj/item/stack/material/wood, "steel" = /obj/item/stack/material/steel, "glass" = /obj/item/stack/material/glass, "cloth" = /obj/item/stack/material/cloth, "rope" = /obj/item/stack/material/rope, "cable" = /obj/item/stack/cable_coil)
	var/before = S.pieces_done
	var/guard = 0
	while (S.next_piece() && guard++ < 200)
		var/list/needed = S.still_needed()
		for (var/key in needed)
			var/path = paths[key]
			var/obj/item/stack/stack = new path(S.loc)
			stack.amount = 60
			S.pay(stack)
			qdel(stack)
	return S.pieces_done - before

/proc/naval_checks()
	naval_fixture()
	build_research_tree()

	naval_check(get_recipe_node_req("/obj/structure/slipway") == "wagons_ships", "the slipway recipe is gated on Wagons & Ships")
	var/list/designs = slipway_design_list()
	var/datum/slipway_design/schooner = designs["sailing schooner"]
	var/datum/slipway_design/freighter = designs["motor freighter"]
	naval_check(schooner && schooner.node == "wagons_ships" && freighter && freighter.node == "combustion", "the schooner needs Wagons & Ships and the freighter Combustion")
	naval_check(schooner.total_pieces() == 16 && freighter.total_pieces() == 20, "a schooner takes 16 pieces and a freighter 20")

	// A post on the shore at (5, 30) facing the sea to the east.
	var/obj/structure/slipway/post = new(locate(5, 30, 2))
	post.dir = EAST
	var/mob/living/human/naval_probe/wright = new(locate(5, 29, 2))
	var/refusal = post.keel_refusal(schooner, wright)
	naval_check(refusal && findtext(refusal, "Wagons & Ships"), "without research the keel is refused ([refusal])")
	naval_research_done = TRUE
	naval_check(!post.keel_refusal(schooner, wright) && !post.keel_refusal(freighter, wright), "with research both keels may be laid facing the sea")
	post.dir = NORTH
	refusal = post.keel_refusal(schooner, wright)
	naval_check(refusal && findtext(refusal, "no open deep water"), "facing along the shore there is no water to launch into ([refusal])")
	post.dir = EAST
	var/obj/structure/vessel_mast/stump = new(locate(10, 31, 2))
	refusal = post.keel_refusal(schooner, wright)
	naval_check(refusal && findtext(refusal, "in the way on the berth"), "a solid object on the berth refuses the keel ([refusal])")
	qdel(stump)
	naval_check(!naval_vessels.len, "fit checks put no ship on the sea")

	// Laying the keel marks out the berth with the cradle.
	post.lay_keel(schooner)
	naval_check(post.design == "sailing schooner" && slipway_frame_count(post) == 62 && slipway_frames_named(post, "cradle") == 62, "the keel marks out 62 berth tiles with the cradle")
	var/obj/structure/slipway_frame/stern = locate() in locate(6, 30, 2)
	var/obj/structure/slipway_frame/bow = locate() in locate(19, 30, 2)
	naval_check(stern && bow && !(locate(/obj/structure/slipway_frame) in locate(20, 30, 2)) && !stern.density && stern.should_save == FALSE, "the berth runs from the post (stern) to the water's edge (bow); frames are walkable and never saved")
	var/obj/structure/slipway/across = new(locate(12, 25, 2))
	across.dir = NORTH
	refusal = across.keel_refusal(schooner, wright)
	naval_check(refusal && findtext(refusal, "Another ship"), "a second berth across the first is refused ([refusal])")
	qdel(across)

	// Pieces are paid for a stack at a time.
	var/obj/item/stack/material/steel/wrong = new(post.loc)
	wrong.amount = 20
	naval_check(!post.pay(wrong) && wrong.amount == 20 && !post.paid.len, "the keel takes no steel")
	var/obj/item/stack/material/wood/planks = new(post.loc)
	planks.amount = 4
	naval_check(post.pay(planks) == 4 && post.pieces_done == 0 && post.paid["wood"] == 4 && findtext(post.status_text(), "needs 6 wood"), "four planks go towards the first keel timber ([post.status_text()])")
	planks = new(post.loc)
	planks.amount = 30
	naval_check(post.pay(planks) == 6 && planks.amount == 24 && post.pieces_done == 1 && !post.paid.len, "six more fit it and the rest of the stack is kept")
	naval_check(slipway_frames_named(post, "keel of") == 7, "half the keel is laid, stern first (7 tiles)")
	naval_check(post.pay(planks) == 10 && post.pieces_done == 2 && slipway_frames_named(post, "keel of") == 14, "the second timber finishes the keel")
	post.pay(planks)
	naval_check(post.pieces_done == 3 && slipway_frames_named(post, "frames of") == 4 * 5 - 2, "the first set of ribs stands on the four sternmost rows")
	var/fitted = slipway_finish(post)
	naval_check(fitted == 13 && post.finished() && findtext(post.status_text(), "ready to launch"), "the rest of the pieces finish her ([post.status_text()])")
	naval_check(slipway_frames_named(post, "sailing schooner") == 62, "every tile shows the finished hull and deck")
	var/overlays = 0
	for (var/obj/structure/slipway_frame/F in post.frames)
		overlays += length(F.overlays)
	naval_check(overlays == 3, "the masts and wheel show on the hull (3)")

	// After a load the frames come back from the saved project.
	naval_check(post.persistence_runtime_var("frames") && post.persistence_runtime_var("busy") && !post.persistence_runtime_var("pieces_done"), "the project is saved, the frames are not")
	post.clear_frames()
	post.after_load()
	naval_check(slipway_frame_count(post) == 62 && slipway_frames_named(post, "sailing schooner") == 62, "after a load the frames are rebuilt as they were")

	// The ways must be clear.
	var/obj/structure/vessel_mast/wreck = new(locate(21, 30, 2))
	var/list/place = list()
	refusal = post.launch_problem(place)
	naval_check(refusal && findtext(refusal, "down the ways"), "a wreck in the shallows blocks the launch ([refusal])")
	for (var/datum/vessel/V in place)
		qdel(V)
	qdel(wreck)

	// Launch: she slides 15 tiles to float clear of the shore, crew aboard.
	var/mob/living/human/naval_probe/sailor = new(locate(10, 30, 2))
	var/obj/structure/closet/crate/cargo = new(locate(12, 31, 2))
	var/datum/vessel/schooner/S = post.launch()
	naval_check(istype(S) && S.placed && S.ox == 21 && S.oy == 28 && S.dir == EAST && S.anchored && S.fuel == 0, "the schooner floats at (21, 28) bow east, anchored")
	if (!istype(S))
		return
	naval_check(sailor.loc == locate(25, 30, 2) && cargo.loc == locate(27, 31, 2) && vessel_at(sailor.loc) == S, "the sailor and the crate went down the ways with her")
	naval_check(!post.design && !slipway_frame_count(post) && istype(locate(10, 30, 2), /turf/floor/beach/sand), "the berth is clear sand again and ready for another keel")
	var/obj/structure/vessel_helm/wheel = locate() in locate(22, 30, 2)
	var/masts = 0
	for (var/turf/T in S.cells())
		for (var/obj/structure/vessel_mast/M in T)
			masts++
	naval_check(wheel && wheel.vessel == S && masts == 2, "her wheel is connected and both masts stand")
	S.set_anchor(FALSE)
	S.set_speed(VESSEL_SPEED_FULL)
	S.stop_sailing()
	naval_check(S.speed == VESSEL_SPEED_HALF, "under sail she makes half ahead at best")
	naval_check(S.sail_tick() && S.ox == 25 && S.fuel == 0 && sailor.loc == locate(29, 30, 2), "she sails four tiles with no fuel, the sailor aboard")
	naval_check(findtext(S.chart_text(), "Under sail"), "the chart says she is under sail")

	// The freighter: a second berth further up the shore.
	var/obj/structure/slipway/yard = new(locate(5, 45, 2))
	yard.dir = EAST
	naval_check(!yard.keel_refusal(freighter, wright), "a freighter berth fits running into the water")
	yard.lay_keel(freighter)
	naval_check(slipway_frame_count(yard) == 132, "the freighter's berth is 132 tiles, part of it in the water")
	slipway_finish(yard)
	var/datum/vessel/freighter/F = yard.launch()
	naval_check(istype(F) && F.ox == 21 && F.oy == 42 && F.base_z == 2, "the freighter floats at (21, 42)")
	if (!istype(F))
		return
	var/obj/structure/vessel_bunker/valve
	var/obj/structure/multiz/ladder/up/up
	var/obj/structure/multiz/ladder/down
	var/hold_tiles = 0
	for (var/turf/T in F.cells())
		if (T.z == 1)
			if (istype(T, /turf/floor/sub_deck/freighter))
				hold_tiles++
			if (!valve)
				valve = locate() in T
			if (!up)
				up = locate() in T
		else if (!down)
			for (var/obj/structure/multiz/ladder/L in T)
				if (L.type == /obj/structure/multiz/ladder)
					down = L
	naval_check(hold_tiles == 82 && F.compartments().len == 2, "below the waterline she has 82 tiles of hold and engine room in two compartments")
	naval_check(valve && valve.ship() == F && istype(valve.loc, /turf/floor/sub_deck/freighter/engine_room), "the bunker filling point is in the engine room")
	naval_check(up && down && down.target == up && up.target == down, "the deck ladder pairs with the hold ladder")
	F.set_anchor(FALSE)
	F.set_speed(VESSEL_SPEED_SLOW)
	F.stop_sailing()
	naval_check(!F.sail_tick() && F.ox == 21 && findtext(F.last_refusal, "dry"), "with dry bunkers the freighter does not move")
	F.bunker(100)
	F.set_speed(VESSEL_SPEED_SLOW)
	F.stop_sailing()
	naval_check(F.sail_tick() && F.ox == 23 && F.fuel == 100 - VESSEL_FUEL_PER_STEP, "with fuel she makes two tiles at slow ahead")

	// A dry dock: a trench berth must be flooded before the launch.
	var/obj/structure/slipway/dock = new(locate(5, 10, 2))
	dock.dir = EAST
	for (var/x = 6, x <= 20, x++)
		for (var/y = 8, y <= 12, y++)
			var/turf/T = locate(x, y, 2)
			T.ChangeTurf(/turf/floor/trench)
	naval_check(!dock.keel_refusal(schooner, wright), "a schooner keel may be laid in a dug trench")
	dock.lay_keel(schooner)
	slipway_finish(dock)
	place = list()
	refusal = dock.launch_problem(place)
	naval_check(refusal && findtext(refusal, "not flooded") && !place.len, "a dry dock refuses the launch ([refusal])")
	for (var/x = 6, x <= 20, x++)
		for (var/y = 8, y <= 12, y++)
			var/turf/T = locate(x, y, 2)
			T.ChangeTurf(/turf/floor/trench/flooded/salty)
	var/datum/vessel/schooner/docked = dock.launch()
	naval_check(istype(docked) && docked.ox == 21 && docked.oy == 8, "flooded, the dock floats her out to the sea at (21, 8)")

	// Abandoning a project clears the berth.
	dock.lay_keel(freighter)
	dock.pieces_done = 5
	dock.update_frames()
	dock.abandon()
	naval_check(!dock.design && !dock.pieces_done && !slipway_frame_count(dock), "abandoning a project clears the berth")
	naval_check(naval_vessels.len == 3, "three ships afloat and no stray prototypes ([naval_vessels.len])")

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
