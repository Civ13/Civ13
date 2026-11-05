/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wild_probe/New()
	return
// Probe animals skip AI start-up but join the real living mob list.
/mob/living/simple_animal/hostile/gorilla/wild_probe/New()
	living_mob_list |= src
// The probe drives spawner cycles directly instead of the timer loop.
/obj/effect/spawner/mobspawner/gorilla/wild_probe
	create_path = /mob/living/simple_animal/hostile/gorilla/wild_probe
	max_number = 2
	max_range = 5
/obj/effect/spawner/mobspawner/gorilla/wild_probe/New()
	if (persistence_saved_atom_construction)
		cull_restored_excess = TRUE
var/wild_failures = 0
var/wild_runtime_error = FALSE
/proc/wild_check(condition, label)
	if (!condition)
		wild_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wild_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wild_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(60, 60, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		wild_runtime_checks()
		wild_restore_checks()
		wild_density_checks()
	catch(var/exception/e)
		wild_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wild_failures, "runtime_error" = wild_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wild_clear()
	for (var/mob/living/simple_animal/hostile/gorilla/wild_probe/A in living_mob_list)
		living_mob_list -= A
		A.origin = null
		A.loc = null

/proc/wild_restored_animal(obj/effect/spawner/mobspawner/S, x, y)
	var/mob/living/simple_animal/hostile/gorilla/wild_probe/A = new(locate(x, y, 1))
	A.origin = S
	A.after_load()
	return A

/proc/wild_runtime_checks()
	var/obj/effect/spawner/mobspawner/gorilla/wild_probe/S = new(locate(10, 10, 1))
	S.spawnTarget()
	S.spawnTarget()
	wild_check(S.living_spawned_count() == 2 && S.current_number == 2, "spawned animals register with their spawner")
	S.spawnerproc()
	wild_check(S.living_spawned_count() == 2, "a full spawner spawns nothing more")
	var/mob/living/simple_animal/A = S.spawned_mobs[1]
	A.stat = DEAD
	A.unregisterSpawner()
	wild_check(S.living_spawned_count() == 1 && isnull(A.origin), "a death frees one slot")
	wild_check(S.persistence_runtime_var("spawned_mobs") && S.persistence_runtime_var("cull_restored_excess"), "spawner head count is runtime-only")
	wild_check(!S.cull_restored_excess, "a mapped spawner never culls")
	wild_clear()
	qdel(S)

/proc/wild_restore_checks()
	persistence_saved_atom_construction++
	var/obj/effect/spawner/mobspawner/gorilla/wild_probe/S = new(locate(30, 30, 1))
	persistence_saved_atom_construction--
	wild_check(S.cull_restored_excess && !S.spawned_mobs, "a restored spawner starts empty and marked for a cull")
	var/list/animals = list()
	for (var/i = 1, i <= 6, i++)
		animals += wild_restored_animal(S, 30 + i, 30)
	var/mob/living/simple_animal/tame = wild_restored_animal(S, 40, 40)
	tame.friends += tame
	wild_check(S.living_spawned_count() == 7, "restored animals rebuild the spawner head count")
	var/removed = S.cull_excess()
	wild_check(removed == 5 && S.living_spawned_count() == 2, "the cull removes restored animals above the quota, the tamed one counting toward it")
	wild_check(!QDELETED(tame) && (tame in S.spawned_mobs), "a tamed animal is never culled")
	wild_check((animals[1] in S.spawned_mobs) && !(animals[2] in S.spawned_mobs), "the animal closest to the spawner stays")
	wild_check(!S.cull_restored_excess && S.cull_excess() == 0, "the cull runs once per load")
	wild_clear()
	qdel(S)

/proc/wild_density_checks()
	var/obj/effect/spawner/mobspawner/gorilla/wild_probe/S = new(locate(15, 45, 1))
	// Unowned animals of the same kind nearby, as left by older builds.
	var/mob/living/simple_animal/hostile/gorilla/wild_probe/A = new(locate(20, 45, 1))
	var/mob/living/simple_animal/hostile/gorilla/wild_probe/B = new(locate(15, 52, 1))
	wild_check(S.nearby_population() == 2, "unowned animals near the spawner count toward density")
	S.spawnerproc()
	wild_check(S.living_spawned_count() == 0, "a spawner with a full neighbourhood stays quiet")
	B.loc = locate(50, 50, 1)
	wild_check(S.nearby_population() == 1, "animals that wandered far stop counting")
	S.spawnerproc()
	wild_check(S.living_spawned_count() == 1, "a spawner refills once its area thins out")
	A.stat = DEAD
	wild_check(S.nearby_population() == 1, "dead animals do not count")
	wild_clear()
	qdel(S)
