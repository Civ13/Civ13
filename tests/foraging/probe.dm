// Run with the existing ecology constructor fixture, after maintainer approval.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/foraging_probe/New()
	return
var/foraging_failures = 0
var/foraging_runtime_error = FALSE
/proc/foraging_check(condition, label)
	if (!condition)
		foraging_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	foraging_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/foraging_probe
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		var/turf/T = locate(3, 3, 1)
		foraging_check(!foraging_commit(T, persistence_admission_identity), "disabled by default")
		map.foraging_enabled = TRUE
		foraging_check(foraging_anchor(T) == locate(1, 1, 1), "stable cell anchor")
		foraging_check(foraging_available(T) == 4, "initial stock")
		for (var/i in 1 to 4)
			foraging_check(foraging_commit(T, persistence_admission_identity), "finite award [i]")
		foraging_check(!foraging_commit(T, persistence_admission_identity), "exhaustion")
		foraging_check(!foraging_commit(locate(8, 8, 1), persistence_admission_identity), "neighbor shares exhaustion")
		foraging_check(foraging_available(locate(9, 8, 1)) == 4, "next cell independent")
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		foraging_check(foraging_available(T) == 0, "terraforming does not replenish")
		var/obj/foraging_cell/C = foraging_record(foraging_anchor(T))
		var/turf/anchor = foraging_anchor(T)
		foraging_check(!C.forceMove(locate(9, 9, 1)), "forced relocation refused")
		foraging_check(!C.persistence_set_loc(locate(9, 9, 1)), "raw relocation refused")
		foraging_check(!C.Move(locate(9, 9, 1)), "movement refused")
		foraging_check(C.loc == anchor, "record retains coordinate")
		foraging_check("remaining" in C.get_saved_vars(), "depletion field exported")
		persistence_admission_identity = new /datum
		var/epoch = persistence_admission_identity
		persistence_save_in_progress = TRUE
		foraging_check(!foraging_persistence_ready(epoch), "active save fenced")
		persistence_save_in_progress = FALSE
		foraging_check(!foraging_persistence_ready(null), "stale epoch fenced")
		C.remaining = -1
		foraging_check(foraging_available(T) == 0, "invalid ledger fails closed")
	catch(var/exception/e)
		foraging_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = foraging_failures, "runtime_error" = foraging_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
