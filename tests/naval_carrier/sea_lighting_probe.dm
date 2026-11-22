// The sea a turf-built ship leaves keeps its lighting (2026-11-18 live report:
// a black strip of deck width behind a slipway schooner). A tile's lighting
// overlay is carried onto each turf ChangeTurf makes, and deep water sank it
// six seconds later like any dropped object (check_sinking).
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

/obj/item/probe_anchor
	name = "probe anchor"

/proc/naval_checks()
	naval_fixture()
	var/list/sea = list()
	for (var/x = 30, x <= 50, x++)
		for (var/y = 10, y <= 40, y++)
			var/turf/T = locate(x, y, 2)
			if (!T.lighting_overlay)
				new /atom/movable/lighting_overlay(T, TRUE)
			sea += T
	var/datum/vessel/V = new /datum/vessel/schooner
	naval_check(V.place(38, 15, 2, NORTH), "a schooner lies on the deep sea bow north ([V.last_refusal])")
	var/list/before = V.cells()
	for (var/i = 1 to 3)
		naval_check(V.relocate(V.ox, V.oy + 1, NORTH), "hop [i] ([V.last_refusal])")
	var/list/now = V.cells()
	var/list/left = list()
	for (var/turf/T in before)
		if (!(T in now))
			left += T
	naval_check(left.len >= 10, "she has left sea behind her ([left.len] tiles)")
	var/turf/drop = locate(45, 35, 2)
	var/obj/item/probe_anchor/A = new(drop)
	drop.Entered(A)
	// Deep water takes what sinks after six seconds.
	sleep(75)
	var/list/dark = list()
	for (var/turf/T in left)
		if (!istype(T, /turf/floor/beach/water/deep) || !T.lighting_overlay || QDELETED(T.lighting_overlay) || T.lighting_overlay.loc != T)
			dark += "[T.x],[T.y]"
	naval_check(!dark.len, "every tile of sea she left keeps its lighting overlay ([jointext(dark, " ")])")
	var/lost = 0
	for (var/turf/T in sea)
		if (!T.lighting_overlay || QDELETED(T.lighting_overlay))
			lost++
	naval_check(!lost, "no sea tile lost its overlay ([lost])")
	naval_check(QDELETED(A), "a dropped anchor still sinks")
	qdel(V)

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
