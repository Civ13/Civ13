// Walking over a land edge underground (code/modules/persistence/region_edge_deep.dm):
// a tunnel out to a linked edge is a crossing at its depth, the crossing record
// carries that depth, and the walker comes out at the same depth on the far
// side, with the level added and the tunnel dug in from the border, or on the
// surface when that depth cannot be reached.
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

/obj/map_metadata/deep_edge_probe
	dig_down_underground = TRUE
	edge_crossings = list("east" = list("beyond" = list(0, 1)), "west" = list("beyond" = list(0, 1)))
/obj/map_metadata/deep_edge_probe/New()
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
	deep_check(region_edge_side(locate(40, 20, 1)) == "east", "the surface edge still leads on")
	deep_check(underground_create(1) && underground_z_at(1), "the cave is dug")
	var/cave = underground_z_at(1)
	var/turf/rock = locate(39, 20, cave)
	deep_check(isnull(region_edge_side(rock)), "unformed rock at the edge leads nowhere")
	var/turf/tunnel = rock.ChangeTurf(/turf/floor/dirt)
	deep_check(istype(locate(40, 20, cave), /turf/wall/rockwall/bedrock), "the border itself is the bedrock rim")
	deep_check(region_edge_deep_depth(tunnel) == 1 && region_edge_side(tunnel) == "east", "a tunnel dug out to the rim at a linked edge leads on ([region_edge_side(tunnel)])")
	var/turf/inner = locate(30, 20, cave)
	inner = dug_underground_form(inner)
	inner = inner.ChangeTurf(/turf/floor/dirt)
	deep_check(!region_edge_deep_on_rim(inner) && isnull(region_edge_side(inner)), "a tunnel short of the rim does not")
	deep_check(region_edge_deep_destination("east", 20) == "beyond" && abs(region_edge_deep_fraction("east", "beyond", 20) - 19 / 39) < 0.002, "underground the place along is counted over the whole stretch")
	deep_check(region_edge_payload_ok(list("edge" = list("east", 0.5, "beyond", 1))) && region_edge_payload_ok(list("edge" = list("east", 0.5, "beyond"))), "a crossing with or without a depth is well formed")
	deep_check(!region_edge_payload_ok(list("edge" = list("east", 0.5, "beyond", 9))) && !region_edge_payload_ok(list("edge" = list("east", 0.5, "beyond", 1.5))), "a depth past the deepest level is refused")

	// Arriving at depth 1: out of the west border into the tunnel, dug in from it.
	var/turf/out = region_edge_arrival_turf(list("edge" = list("east", 0.5, "beyond", 1), "from" = "beyond"), TRUE)
	deep_check(out && out.z == cave && out.x == 5 && out.y == 20 && istype(out, /turf/floor/dirt), "she comes out underground, three tiles in from the rim ([out ? "[out.x],[out.y],[out.z]" : "none"])")
	deep_check(istype(locate(1, 20, cave), /turf/wall/rockwall/bedrock), "the rim stays bedrock")
	var/open = TRUE
	for (var/x = 2 to 5)
		var/turf/T = locate(x, 20, cave)
		open = open && istype(T, /turf/floor/dirt)
	deep_check(open, "and the tunnel back to the rim is dug")

	// Arriving at depth 2 adds that level.
	var/before = world.maxz
	out = region_edge_arrival_turf(list("edge" = list("east", 0.25, "beyond", 2), "from" = "beyond"), TRUE)
	deep_check(out && underground_z_at(2) && out.z == underground_z_at(2) && world.maxz == before + 1, "a depth nobody has dug to here is added for her ([out ? "[out.x],[out.y],[out.z]" : "none"])")

	// Too deep to reach: she comes out on the surface.
	out = region_edge_arrival_turf(list("edge" = list("east", 0.5, "beyond", 4), "from" = "beyond"), TRUE)
	deep_check(out && out.z == 1, "a depth below the next to be dug brings her out on the surface ([out ? "[out.x],[out.y],[out.z]" : "none"])")

	// Hot rock is never dug into: she comes out beside it.
	for (var/d = 1 to 4)
		var/turf/T = dug_underground_form(locate(1 + d, 30, cave))
		T.ChangeTurf(/turf/floor/dirt/underground/hot)
	out = region_edge_arrival_turf(list("edge" = list("east", 29 / 39, "beyond", 1), "from" = "beyond"), TRUE)
	deep_check(out && out.z == cave && out.y != 30 && abs(out.y - 30) <= 3, "hot rock is passed by ([out ? "[out.x],[out.y],[out.z]" : "none"])")
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
		world_z_budget = new /datum/world_z_budget/fixture_admission
		map = new /obj/map_metadata/deep_edge_probe
		ticker = new /datum/controller/gameticker
		ticker.current_state = GAME_STATE_PLAYING
	catch(var/exception/e)
		deep_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		deep_run()

#include "../new_z_budget/fixture_admission.dm"
