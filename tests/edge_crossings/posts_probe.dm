// Travel posts become signposts once edge travel is on
// (code/modules/persistence/region_posts_retire.dm): trail markers and plain
// trails turn into signposts with their wood refunded, launch pads stay, and
// trail markers can no longer be built.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	// The production native fill: an added underground level is unformed rock.
	turf = /turf/sky/building
	area = /area/caribbean
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/posts_probe
/obj/map_metadata/posts_probe/New()
	return

var/deep_failures = 0
var/deep_runtime_error = FALSE
/proc/deep_check(condition, label)
	if (!condition)
		deep_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	deep_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/deep_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
		T.ChangeTurf(/turf/floor/dirt)
	var/obj/structure/region_gate/trail_marker/M = new(locate(3, 20, 1))
	M.name = "trail to the hills"
	M.destination = "beyond"
	M.approved = TRUE
	var/obj/structure/region_gate/plain = new(locate(5, 20, 1))
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(7, 20, 1))
	shard_group.enabled = TRUE
	shard_group.region = "europe"
	shard_group.edge_travel_oceans = FALSE
	deep_check(region_posts_retire_all() == 0 && !QDELETED(M), "with edge travel off nothing changes")
	deep_check(isnull(region_trail_build_refusal(null, /obj/structure/region_gate/trail_marker/launch_pad)), "launch pads are not held to the edge rule")
	shard_group.edge_travel_oceans = TRUE
	deep_check(findtext(region_trail_build_refusal(null, /obj/structure/region_gate/trail_marker), "not marked any more"), "with edge travel on a trail marker cannot be built")
	var/n = region_posts_retire_all()
	deep_check(n == 2 && QDELETED(M) && QDELETED(plain) && !QDELETED(pad), "the marker and the plain trail retire; the launch pad stays ([n])")
	var/obj/structure/sign/signpost/S = locate() in locate(3, 20, 1)
	var/obj/item/stack/material/wood/W = locate() in locate(3, 20, 1)
	deep_check(S && S.name == "trail to the hills", "a signpost stands in its place with its name")
	deep_check(W && W.amount == 10, "and its 10 wood beside it")
	deep_check(region_posts_retire_all() == 0, "a second sweep finds nothing")
	deep_check(!deep_runtime_error, "no runtime errors")
/proc/deep_run()
	try
		deep_checks()
	catch(var/exception/e)
		deep_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = deep_failures, "runtime_error" = deep_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		shard_group = new
		world_z_budget = new /datum/world_z_budget/fixture_admission
		map = new /obj/map_metadata/posts_probe
		ticker = new /datum/controller/gameticker
		ticker.current_state = GAME_STATE_PLAYING
	catch(var/exception/e)
		deep_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		deep_run()

#include "../new_z_budget/fixture_admission.dm"
