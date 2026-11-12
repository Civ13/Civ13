// Headless admin spectating probe (developer evidence, not CI). Run with
// tests/ecology_spawning/run_linux.py . tests/admin_spectate/probe.dm
// No client can connect here, so it checks the hidden ghost, the follow-list
// filter, the camera mirror's list sync and the view's failure paths only.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
	fps = 20
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/spectate_probe/New()
	return
var/spectate_failures = 0
var/spectate_runtime_error = FALSE
/proc/spectate_check(condition, label)
	if (!condition)
		spectate_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	spectate_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	spawn(1)
		try
			GLOB.all_observable_events = list()
			GLOB.moved_event = new
			GLOB.dir_set_event = new
			GLOB.destroyed_event = new
			map = new /obj/map_metadata/spectate_probe
			for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
				T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
			spectate_checks()
		catch(var/exception/e)
			spectate_check(FALSE, "exception [e] [e.file]:[e.line]")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = spectate_failures, "runtime_error" = spectate_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
		del(world)

/proc/spectate_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/observer/ghost/G = new(T)
	G.real_name = "Hidden Admin"
	var/mob/observer/ghost/P = new(T)
	P.real_name = "Plain Ghost"
	spectate_check(G.invisibility == INVISIBILITY_OBSERVER, "a new ghost starts at observer invisibility")
	spectate_check((G.ghost_image in ghost_darkness_images), "a new ghost's image is in the darkness list")

	G.set_admin_hidden(TRUE)
	spectate_check(G.admin_hidden, "hiding sets admin_hidden")
	spectate_check(G.invisibility == INVISIBILITY_MAXIMUM, "a hidden ghost is at maximum invisibility")
	spectate_check(G.invisibility > SEE_INVISIBLE_OBSERVER && G.invisibility > SEE_INVISIBLE_OBSERVER_NOLIGHTING, "no ghost sight level reaches a hidden ghost")
	spectate_check(!(G.ghost_image in ghost_darkness_images) && !(G.ghost_image in ghost_sightless_images), "a hidden ghost's image leaves the ghost image lists")
	spectate_check(G.sight & SEE_SELF, "the hidden admin still sees themselves")

	usr = null
	var/list/fit = ghost_follow_targets()
	var/found_hidden = FALSE
	var/found_plain = FALSE
	for (var/k in fit)
		if (fit[k] == G)
			found_hidden = TRUE
		if (fit[k] == P)
			found_plain = TRUE
	spectate_check(!found_hidden, "players' follow/jump list leaves out a hidden admin ghost")
	spectate_check(found_plain, "players' follow/jump list still has ordinary ghosts")
	spectate_check(G.admin_hidden_from(G), "a hidden ghost is hidden from a non-staff user")

	G.set_admin_hidden(FALSE)
	spectate_check(!G.admin_hidden && G.invisibility == INVISIBILITY_OBSERVER, "unhiding restores observer invisibility")
	spectate_check((G.ghost_image in ghost_darkness_images), "unhiding puts the ghost image back")
	spectate_check(!G.admin_hidden_from(null), "a visible ghost is never filtered")

	// The camera mirror: current ends up holding exactly want's keys.
	var/datum/admin_player_view/V = new(null, G, P)
	var/list/current = list("a", "b", "c")
	var/list/want = list("b" = TRUE, "d" = TRUE)
	V.mirror(current, want)
	spectate_check(current.len == 2 && ("b" in current) && ("d" in current), "mirror removes stale entries and adds new ones")
	current = list("b", "d")
	V.mirror(current, want)
	spectate_check(current.len == 2, "mirror of an already synced list changes nothing")

	// Without a client the view cannot start and cleans itself up.
	spectate_check(!V.sync(), "an inactive view does not sync")
	spectate_check(!V.start(), "a view without a client does not start")
	sleep(2)
	spectate_check(QDELETED(V), "a view that failed to start is deleted")
	spectate_check(!(V in admin_player_views), "a failed view is not registered")
	spectate_check(!admin_spectate_allowed(null), "nobody without a client may spectate")
