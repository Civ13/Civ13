// Holds for hulls already afloat and boarding from a level up
// (code/modules/naval/berth_refit_hold.dm, hull_gangway.dm): a hull refitted
// at a berth to a draught with a hold gets that hold dug out under her from the
// tiller, floors first and then the ladders; a gangway on her upper deck runs
// its gangplank over open air to a quay a level up.
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

/proc/hold_floors_at(x, y)
	return hull_hold_cover(locate(x, y, 1))

/proc/naval_checks()
	naval_fixture()
	naval_research_done = TRUE
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)

	// ---- A hull hauled out on a slipway gets a hold in a refit ----
	var/obj/structure/slipway/post = new(locate(3, 15, 2))
	post.dir = EAST
	for (var/x = 4, x <= 8, x++)
		for (var/y = 14, y <= 16, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(4, 15, 2))
	naval_check(isnull(tiller.commission("Gull", EAST)) && tiller.craft && craft_berth(tiller.craft) == post, "the Gull is commissioned on the slipway")
	var/datum/craft_body/built/B = tiller.craft.body
	naval_check(B.lower_tile_count() == 0, "she has no hold yet")
	var/datum/ship_draught/D = ship_draught_survey(tiller)
	naval_check(istype(D), "her lines can be drawn ([D])")
	// World x,y lies at sheet (16 - y, x - 4) with her bow to the east.
	D.set_deck(-1, 1, 2, TRUE)
	D.set_deck(-1, 1, 3, TRUE)
	var/list/rung = D.decks["-1"]["1,2"]
	rung[1] = "X"
	tiller.refit_code = D.to_code()
	qdel(D)
	var/list/diff = tiller.mark_refit()
	naval_check(islist(diff) && !diff.len && tiller.refit_code && tiller.refit_hold_left == 3, "her deck matches but the refit keeps her hold to dig: two floors and a ladder ([islist(diff) ? diff.len : diff], [tiller.refit_hold_left])")
	var/mob/living/human/naval_probe/wright = new(locate(5, 16, 2))
	var/list/options = tiller.refit_options(wright)
	naval_check(("Dig out the hold" in options) && ("Check the refit" in options), "the tiller offers to dig out the hold")
	D = ship_draught_from_code(tiller.refit_code)
	var/list/work = tiller.refit_hold_work(D)
	naval_check(islist(work) && work.len == 3 && work[1][1] == "floor" && work[3][1] == "ladder", "floors come before the ladder down to them")
	var/list/ladder = work[3]
	naval_check(ladder[2] == locate(6, 15, 2) && ladder[3] == locate(6, 15, 1), "the ladder stands where the draught has it, under her deck at 6,15")
	naval_check(findtext(tiller.refit_hold_refusal(ladder), "before the ladder"), "the ladder waits for the hold floor under it ([tiller.refit_hold_refusal(ladder)])")
	var/list/cost = refit_hold_cost(work[1])
	naval_check(cost["steel"] == 1 && refit_hold_cost(ladder)["wood"] == 4, "a hold floor costs 1 steel and a ladder 4 wood, as on the slipway")
	for (var/list/W in work)
		if (W[1] == "floor")
			naval_check(isnull(tiller.refit_hold_refusal(W)) && tiller.refit_hold_place(W), "a hold floor is dug under [W[2]:x],[W[2]:y]")
	naval_check(hold_floors_at(6, 15) && hold_floors_at(7, 15) && istype(locate(6, 15, 1), /turf/floor/plating/ship_hold), "the rock under her is hollowed into her hold")
	naval_check(B.lower_tile_count() == 2 && B.carries(locate(7, 15, 1)) && !B.carries(locate(8, 15, 1)), "she carries her new hold and not the rock beside it")
	naval_check(isnull(tiller.refit_hold_refusal(ladder)) && tiller.refit_hold_place(ladder), "the ladder is fitted once the floor is down")
	var/obj/structure/multiz/ladder/up/foot = locate() in locate(6, 15, 1)
	var/obj/structure/multiz/ladder/head = null
	for (var/obj/structure/multiz/ladder/L in locate(6, 15, 2))
		head = L
	naval_check(foot && head && foot.target == head, "the ladder joins her deck to her hold")
	work = tiller.refit_hold_work(D)
	naval_check(islist(work) && !work.len, "nothing is left to dig")
	qdel(D)
	diff = tiller.mark_refit()
	naval_check(islist(diff) && !diff.len && !tiller.refit_code && !tiller.refit_hold_left, "she matches her draught and the refit is done")
	// A hold under a tile that is not hers is refused.
	D = new /datum/ship_draught
	var/list/bad = list("floor", locate(12, 15, 2), locate(12, 15, 1))
	naval_check(findtext(tiller.refit_hold_refusal(bad), "deck must be laid"), "no hold is dug under a tile that is not her deck ([tiller.refit_hold_refusal(bad)])")
	qdel(D)
	var/obj/item/stack/material/steel/plate = new(locate(5, 16, 2))
	plate.amount = 5
	var/crate = new /obj/structure/closet/crate(locate(7, 15, 1))
	naval_check(crate in B.aboard(), "a crate in her new hold is aboard her, weighed with her load")
	qdel(plate)

	// ---- Boarding from a level up ----
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	new /obj/structure/roof_support(locate(32, 11, 2))
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			building_construct_roof(locate(x, y, 2), /obj/roof/wood, null)
	var/obj/structure/hull_tiller/osprey_tiller = new(locate(30, 11, 2))
	naval_check(isnull(osprey_tiller.commission("Osprey", EAST)) && osprey_tiller.craft, "the Osprey is commissioned with a deck above")
	var/datum/craft/C = osprey_tiller.craft
	var/obj/structure/railing/built/gunwale/gangway/way = new(locate(34, 11, 3))
	way.set_dir(EAST)
	naval_check(craft_holding(get_turf(way)) == C, "a gangway on her upper deck is hers")
	naval_check(findtext(hull_gangplank_plan(way), "no pier"), "with open air off her upper deck there is nothing to run the plank to ([hull_gangplank_plan(way)])")
	var/obj/covers/repairedfloor/quay = new(locate(37, 11, 3))
	quay.updateturf()
	var/list/plan = hull_gangplank_plan(way)
	naval_check(islist(plan) && plan.len == 2 && plan[1] == locate(35, 11, 3), "a quay a level up three tiles off takes a two-tile gangplank over the air")
	naval_check(isnull(hull_run_out_gangplank(way)) && way.planks.len == 2 && (locate(/obj/covers/repairedfloor/rope/boarding/gangplank) in locate(36, 11, 3)), "the gangplank runs out over the air to the quay")
	var/held = C.gangplank_refusal()
	naval_check(held && findtext(held, "Take it in"), "she is held while the plank to the quay is out ([held])")
	naval_check(hull_take_in_gangplank(way) && !way.planks.len && !C.gangplank_refusal(), "taken in, she may sail")
	// A gangway on her main deck still wants water under the plank.
	var/obj/structure/railing/built/gunwale/gangway/low = new(locate(34, 10, 2))
	low.set_dir(EAST)
	var/obj/covers/repairedfloor/pier = new(locate(37, 10, 2))
	pier.updateturf()
	plan = hull_gangplank_plan(low)
	naval_check(islist(plan) && plan.len == 2 && plan[1] == locate(35, 10, 2), "a gangway on her main deck still runs over water to a pier")

// A genuine hold requires three linked levels: it cannot fit in a two-level
// column or drill through the rock below a diveable shelf.
/proc/hold_depth_checks()
	for (var/x = 48 to 53)
		for (var/y = 43 to 47)
			var/turf/bottom = locate(x, y, 1)
			bottom.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
			var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/middle = locate(x, y, 2)
			middle.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
			middle.depth_zone = SEA_ZONE_OPEN
			var/turf/surface = locate(x, y, 3)
			surface.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/obj/covers/repairedfloor/ship/deck = new(surface)
			deck.updateturf()

	var/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/bottom_hold = locate(50, 44, 1)
	bottom_hold.depth_zone = SEA_ZONE_DEEP
	var/obj/covers/hold_cover = hull_hold_lay(locate(50, 44, 2))
	var/obj/structure/hull_tiller/T = new(locate(48, 43, 3))
	var/obj/structure/cargo_hatch/hatch = new(locate(50, 44, 3))
	naval_check(hold_cover && isnull(T.commission("Sounder Hold", EAST)) && T.craft, "depth fixture has a commissioned hull on three linked levels")
	if (!T.craft)
		return
	var/datum/craft_body/built/body = T.craft.body
	var/obj/structure/closet/crate/chest = new(locate(50, 44, 2))
	var/obj/item/stack/material/wood/manifest = new(chest)
	var/mob/living/human/naval_probe/inside = new(locate(50, 44, 2))
	bottom_hold.ChangeTurf(/turf/wall/rockwall)
	naval_check(!body.shift_foundering_level(2, FALSE) && body.z == 3 && chest.z == 2 && hull_hold_cover(locate(50, 44, 2)) == hold_cover, "rock under the destination hold refuses descent without modifying cargo or deck")
	bottom_hold.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
	bottom_hold.depth_zone = SEA_ZONE_DEEP
	naval_check(body.shift_foundering_level(2, FALSE) && body.z == 2 && T.z == 2 && chest.z == 1 && inside.z == 1 && manifest.loc == chest, "main deck, hold floor, occupants and nested cargo descend as one assembly")
	naval_check(hull_hold_cover(locate(50, 44, 1)) == hold_cover && hold_cover.hold_sea_zone == SEA_ZONE_DEEP && hull_depth_underwater(get_turf(chest)), "original hold floor retains the destination seabed type and depth")
	naval_check(sea_layer_cell(locate(50, 44, 2)) && sea_zone_of(locate(50, 44, 2)) == SEA_ZONE_OPEN, "descent restores the old hold seabed under the new main deck")
	naval_check(!hatch.up_destination(inside), "battened hatch is not an upward escape")
	hatch.open = TRUE
	naval_check(hatch.up_destination(inside) == get_turf(hatch), "open hatch carries its upward route to the matching submerged hull")
	var/obj/covers/overhead_wall = new(get_turf(hatch))
	overhead_wall.wall = TRUE
	naval_check(!hatch.up_destination(inside), "a wall covering the hatch blocks upward travel")
	qdel(overhead_wall)
	naval_check(!body.shift_foundering_level(1, FALSE) && body.z == 2 && chest.z == 1, "no linked level under a hold stops descent without discarding it")
	naval_check(body.shift_foundering_level(3, TRUE) && body.z == 3 && T.z == 3 && chest.z == 2 && inside.z == 2 && manifest.loc == chest, "refloat returns the original hull and lower-deck crew and cargo")
	naval_check(hull_hold_cover(locate(50, 44, 2)) == hold_cover && hold_cover.hold_sea_zone == SEA_ZONE_OPEN && sea_zone_of(locate(50, 44, 1)) == SEA_ZONE_DEEP, "refloat restores the vacated seabed and its original depth")

/proc/naval_run()
	try
		naval_checks()
		hold_depth_checks()
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
