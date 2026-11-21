// Sites at sea in the ocean regions (code/modules/naval/ocean_sites.dm,
// docs/ocean-regions.md): the list rolled from the ocean's id, islets, reefs,
// wrecks and sea marks raised when a ship comes near and gone again after
// everyone has left, the same islet rising the same, and what keeps a site:
// someone aboard near it, a harbour, a bunk kept as home, a world save.
/world
	hub = ""
	hub_password = ""
	maxx = 600
	maxy = 300
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
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

// An ocean with no metadata start-up: the probe rolls and ticks by hand.
/obj/map_metadata/nomads/ocean/probe
	ocean = "probe"
/obj/map_metadata/nomads/ocean/probe/New()
	return
/obj/map_metadata/nomads/ocean/probe/is_node_done(faction, node_id)
	return naval_research_done

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/W = locate(x, y, 1)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 1)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// A 5 by 3 hull with a rigged mast, bow east, its corner at (x, y).
/proc/sea_ship(x, y, ship_name)
	for (var/dx = 0, dx < 5, dx++)
		for (var/dy = 0, dy < 3, dy++)
			hull_lay(x + dx, y + dy)
	var/obj/structure/hull_tiller/tiller = new(locate(x + 1, y + 1, 1))
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(x + 3, y + 1, 1))
	mast.sails = new /obj/item/sail(mast)
	naval_check(isnull(tiller.commission(ship_name, EAST)), "the [ship_name] is commissioned")
	return tiller

// Tiles of a site's square that are not open sea, and the things on them.
/proc/site_count(datum/ocean_site/S)
	. = 0
	var/list/B = S.box()
	for (var/turf/T in block(locate(B[1], B[2], 1), locate(B[3], B[4], 1)))
		if (T.type != /turf/floor/beach/water/deep/saltwater)
			.++
		for (var/obj/O in T)
			.++

/proc/naval_checks()
	naval_fixture()
	persistence_player_restore_ready = TRUE

	// ---- the list
	var/list/first = list()
	for (var/datum/ocean_site/S in ocean_sites_roll())
		first += "[S.id] [S.kind] [S.x],[S.y]"
	var/list/again = list()
	for (var/datum/ocean_site/S in ocean_sites_roll())
		again += "[S.id] [S.kind] [S.x],[S.y]"
	naval_check(first.len >= 4 && first.len == again.len && jointext(first, ";") == jointext(again, ";"), "the same sites in the same places on every start ([jointext(first, "; ")])")
	var/inside = TRUE
	for (var/datum/ocean_site/S in ocean_sites)
		var/list/B = S.box()
		if (B[1] < 60 || B[2] < 60 || B[3] > world.maxx - 60 || B[4] > world.maxy - 60 || S.raised())
			inside = FALSE
	naval_check(inside, "every site lies clear of the map's edge, and none stands until a ship comes")

	// ---- one of each kind, by hand
	for (var/datum/ocean_site/S in ocean_sites.Copy())
		qdel(S)
	var/datum/ocean_site/islet/isle = new
	isle.id = "probe-isle"
	isle.seed = 77
	isle.x = 120
	isle.y = 150
	var/datum/ocean_site/reef/reef = new
	reef.id = "probe-reef"
	reef.seed = 5
	reef.x = 480
	reef.y = 80
	var/datum/ocean_site/wreck/wreck = new
	wreck.id = "probe-wreck"
	wreck.seed = 9
	wreck.x = 480
	wreck.y = 220
	var/datum/ocean_site/mark/mark = new
	mark.id = "probe-mark"
	mark.seed = 3
	mark.x = 300
	mark.y = 250
	mark.name = "Gull Rock"
	ocean_sites = list(isle, reef, wreck, mark)

	var/obj/structure/hull_tiller/tiller = sea_ship(300, 20, "Wren")
	var/datum/craft/C = tiller.craft
	ocean_sites_tick()
	naval_check(!isle.raised() && !reef.raised() && !wreck.raised() && !mark.raised(), "with the ship far off, nothing rises")

	// The islet rises when she comes within 40 tiles of it.
	naval_check(C.body.move_to(isle.x + isle.half + 30, isle.y, EAST), "she sails up to the islet ([C.body.last_refusal])")
	ocean_sites_tick()
	var/made = site_count(isle)
	var/trees = 0
	var/list/B = isle.box()
	for (var/turf/T in block(locate(B[1], B[2], 1), locate(B[3], B[4], 1)))
		for (var/obj/structure/wild/tree/live_tree/W in T)
			trees++
	naval_check(isle.raised() && made > 200 && istype(locate(isle.x, isle.y, 1), /turf/floor/grass) && !reef.raised(), "the islet rises out of the sea, with grass at its middle ([made] tiles and things)")
	naval_check(trees > 0, "and trees on it ([trees])")
	naval_check(findtext(isle.lower_refusal(), "Wren"), "while she lies off it the sea does not close over it ([isle.lower_refusal()])")

	// She sails away: after everyone has gone the islet goes under.
	naval_check(C.body.move_to(300, 20, EAST), "she sails away ([C.body.last_refusal])")
	ocean_sites_tick()
	naval_check(isle.linger_timer && isle.raised(), "with everyone gone it lingers a while")
	deltimer(isle.linger_timer)
	isle.linger_timer = 0
	isle.linger_done()
	naval_check(!isle.raised() && site_count(isle) == 0, "then the sea closes over it, leaving open water")

	// The same islet rises the same.
	naval_check(isle.raise() && site_count(isle) == made, "it rises the same again ([site_count(isle)] against [made])")

	// What keeps it.
	var/obj/structure/bed/bunk = new(locate(isle.x, isle.y, 1))
	bunk.persistence_bed_owner_ckey = "probeplayer"
	naval_check(findtext(isle.lower_refusal(), "home") && !isle.lower(), "a bunk kept as home keeps it")
	qdel(bunk)
	var/obj/structure/berth/quay/post = new(locate(isle.x + 3, isle.y, 1))
	naval_check(isle.held() && findtext(isle.lower_refusal(), "harbour") && !isle.lower(), "a mooring post makes a harbour of it, and it stays")
	post.takes_ships = FALSE
	naval_check(!isle.held(), "a board that takes no ships keeps nothing")
	qdel(post)
	naval_check(C.body.move_to(reef.x - reef.half - 20, reef.y, EAST), "she sails on towards the reef ([C.body.last_refusal])")
	persistence_save_in_progress = TRUE
	naval_check(findtext(isle.lower_refusal(), "saved") && !isle.lower(), "nothing goes under during a world save")
	ocean_sites_tick()
	naval_check(!reef.raised(), "and nothing rises during one")
	persistence_save_in_progress = FALSE
	naval_check(isle.lower() && !isle.raised(), "afterwards it goes under")

	// The reef: shallows, the best fishing at sea, with coral heads awash.
	ocean_sites_tick()
	var/shallow = 0
	B = reef.box()
	for (var/turf/floor/beach/water/shallowsaltwater/T in block(locate(B[1], B[2], 1), locate(B[3], B[4], 1)))
		shallow++
	naval_check(reef.raised() && shallow > 20 && fish_water_capacity(locate(reef.x, reef.y, 1), fish_water_kind(locate(reef.x, reef.y, 1))) > fish_water_capacity(locate(300, 150, 1), fish_water_kind(locate(300, 150, 1))), "the reef rises as shallows, richer fishing than open sea ([shallow] tiles)")

	// The wreck: her planks lie on open water, with salvage aboard.
	C.body.move_to(wreck.x - wreck.half - 20, wreck.y, EAST)
	ocean_sites_tick()
	var/salvage = 0
	B = wreck.box()
	for (var/turf/T in block(locate(B[1], B[2], 1), locate(B[3], B[4], 1)))
		for (var/obj/structure/closet/crate/K in T)
			if (K.salvage_of == wreck.id)
				salvage++
	naval_check(wreck.raised() && salvage > 0, "the wreck is there, with [salvage] crate\s of salvage")
	C.body.move_to(300, 20, EAST)
	naval_check(wreck.lower() && !wreck.raised() && site_count(wreck) == 0, "and she goes under again")

	// The sea mark: a named rock.
	C.body.move_to(mark.x - mark.half - 20, mark.y, EAST)
	ocean_sites_tick()
	var/obj/structure/wild/rock/R = locate() in locate(mark.x, mark.y, 1)
	naval_check(mark.raised() && R && R.name == "Gull Rock", "the sea mark stands, named Gull Rock")
	naval_check(!naval_runtime_error, "no runtime errors")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	chart_hazards_off = TRUE
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/nomads/ocean/probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
