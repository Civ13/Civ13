// Native faction banner load probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. A restored faction banner builds its look while its
// level loads, before map metadata (custom_civs) is restored. It must wait for
// the load instead of reading custom_civs[faction][6] from a null row.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/banner_probe/New()
	map = src
var/banner_p_failures = 0
var/banner_p_runtime_error = FALSE
/proc/banner_p_check(condition, label)
	if (!condition)
		banner_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	banner_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		new /obj/map_metadata/banner_probe
		banner_p_checks()
	catch(var/exception/e)
		banner_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = banner_p_failures, "runtime_error" = banner_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/banner_p_new(faction, x)
	var/obj/structure/banner/faction/banner_a/B = new(locate(x, 5, 1))
	B.faction = faction
	return B

/proc/banner_p_checks()
	var/turf/T = locate(1, 1, 1)
	banner_p_check(istype(T), "probe turf exists")
	map.custom_civs = list()
	// A world load is running and has not restored custom_civs yet.
	persistence_active_operation = new /datum/persistence_world_operation
	var/obj/structure/banner/faction/loading = banner_p_new("Swan", 2)
	sleep(40)
	banner_p_check(!banner_p_runtime_error, "no runtime while the load is still running")
	banner_p_check(loading.invisibility == 101, "banner waits for the load before showing")
	// The load restores the faction's row, then finishes.
	map.custom_civs["Swan"] = list(0, 0, 0, null, 0, "star", "#112233", "#445566")
	persistence_active_operation = null
	sleep(80)
	banner_p_check(!banner_p_runtime_error, "no runtime after the load finishes")
	banner_p_check(loading.invisibility == 0, "banner shows after the load")
	banner_p_check(loading.overlays.len == 3, "banner has cloth, trim and symbol after the load ([loading.overlays.len])")
	banner_p_check(loading.name == "Swan's banner", "banner is named for its faction")
	// A banner of a faction that no longer exists keeps its cloth and trim.
	var/obj/structure/banner/faction/gone = banner_p_new("Gone", 4)
	sleep(30)
	banner_p_check(!banner_p_runtime_error, "no runtime for a dissolved faction's banner")
	banner_p_check(gone.invisibility == 0 && gone.overlays.len == 2, "dissolved faction's banner keeps cloth and trim ([gone.overlays.len])")
