// Voyages on the world chart (code/modules/naval/ship_voyage.dm,
// docs/ship-voyage.md): the chart a crew sees, setting out, and landfall
// waiting on the world directory's answer to her course.
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

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/probe_chart()
	// 8 x 4 chart. The owner has seen (1,2) and (5,0): bits 17 and 5.
	world_chart = list("key" = "probe:1", "width" = 8, "height" = 4, "rows" = list("........", "........", "........", "........"),
		"pins" = list("gaia" = list(4, 2)),
		"seen" = list("faction:romeempire" = "00020020"),
		"tiles" = list(
			"1,2" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "DESERT", "land_type" = "COASTAL_PLAIN", "size" = "TINY", "coast" = list("S"))),
			"5,0" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "SWAMP", "land_type" = "MARSH", "size" = "SMALL", "coast" = list())),
			"6,3" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "TUNDRA", "land_type" = "FJORD_COAST", "size" = "SMALL", "coast" = list("N")))),
		"courses" = list())

/proc/naval_checks()
	naval_fixture()
	// ---- The chart a crew sees ----
	var/mob/living/human/naval_probe/H = new(locate(10, 10, 2))
	H.civilization = "Rome Empire"
	naval_check(voyage_owner(H) == "faction:romeempire", "a crew sails for their faction ([voyage_owner(H)])")
	probe_chart()
	naval_check(voyage_seen("faction:romeempire", 1, 2) && voyage_seen("faction:romeempire", 5, 0), "the seen mask shows the tiles the owner saw")
	naval_check(!voyage_seen("faction:romeempire", 6, 3) && !voyage_seen("faction:romeempire", 0, 0) && !voyage_seen("faction:gaul", 1, 2), "and no others, nor to another owner")
	shard_group.region = "gaia"
	shard_group.mainland = "gaia"
	var/list/origin = voyage_origin()
	naval_check(islist(origin) && origin[1] == 4 && origin[2] == 2, "this world sits on its pinned tile")
	var/list/lands = voyage_destinations("faction:romeempire", origin)
	naval_check(lands.len == 1, "only a seen land with a coast can be sailed for ([lands.len])")
	var/label = lands.len ? lands[1] : ""
	var/list/land = lands.len ? lands[label] : null
	naval_check(islist(land) && land[1] == 1 && land[2] == 2 && land[3] == 3, "it lies 3 tiles away ([label])")
	naval_check(findtext(label, "Tiny desert, coastal plain at 1,2: 3 tiles, about 3 minutes"), "the crew read its size, biome and voyage time")
	var/list/north = voyage_scout_target(origin, NORTH)
	var/list/west = voyage_scout_target(origin, WEST)
	naval_check(north[1] == 4 && north[2] == 3 && west[1] == 0 && west[2] == 2, "scouting turns round within the chart")

	// ---- Setting out ----
	for (var/x = 62, x <= 65, x++)
		for (var/y = 30, y <= 32, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(63, 31, 2))
	naval_check(isnull(tiller.commission("Tern", EAST)) && tiller.craft, "the Tern is commissioned off the east edge")
	shard_group.enabled = FALSE
	naval_check(findtext(tiller.voyage_refusal(H), "No world chart"), "a world outside a region group has no voyages")
	shard_group.enabled = TRUE
	shard_group.kind = "EXPEDITION"
	naval_check(findtext(tiller.voyage_refusal(H), "No world chart"), "nor does a land across the sea (its ships sail home)")
	shard_group.kind = "SURFACE"
	tiller.craft.set_anchor(FALSE)
	naval_check(tiller.set_out(H, "scout", 4, 3, "faction:romeempire", 8, "the unknown water to the north"), "she sets out to scout")
	naval_check(tiller.voyage && tiller.voyage["kind"] == "scout" && tiller.craft.anchored && !tiller.craft.speed, "she lies at anchor under way on the chart")
	naval_check(findtext(tiller.voyage_status_text(), "about 8 minutes to go"), "the tiller tells how long ([tiller.voyage_status_text()])")
	tiller.end_voyage(null)
	naval_check(isnull(tiller.voyage), "a voyage ends at the tiller")

	// ---- Landfall waits on the world directory ----
	tiller.voyage = list("id" = "gaia-1-2", "kind" = "course", "x" = 1, "y" = 2, "owner" = "faction:romeempire", "label" = "a desert", "by" = "probe", "ends" = world.time - 10, "said" = null)
	var/list/mine = tiller.voyage
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine && mine["said"] == "The coast is not yet in sight.", "with no answer yet she waits off the coast")
	world_chart["courses"] = list("gaia-1-2" = list("state" = "ASSIGNED", "region" = "far1"))
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine, "and while the land is being opened")
	world_chart["courses"] = list("gaia-1-2" = list("state" = "READY", "region" = "far1"))
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine, "and while its world does not answer")
	mine["ends"] = world.time - 18010
	naval_check(tiller.voyage_landfall(mine) && isnull(tiller.voyage), "she turns back after waiting too long")
	tiller.voyage = mine = list("id" = "gaia-3-4", "kind" = "course", "x" = 1, "y" = 2, "owner" = "faction:romeempire", "label" = "a desert", "by" = "probe", "ends" = world.time - 10, "said" = null)
	world_chart["courses"] = list("gaia-3-4" = list("state" = "REFUSED", "reason" = "every harbour master is busy"))
	naval_check(tiller.voyage_landfall(mine) && isnull(tiller.voyage), "a refused course turns her back at once")
	naval_check(tiller.craft && !QDELETED(tiller), "she is still here, off the coast where she set out")

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
