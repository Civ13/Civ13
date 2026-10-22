// Prepared only: no native acceptance until reviewed containment is available.
var/wolfcave_ticking = FALSE // Historical-source control only.
var/fixture_failed = FALSE
var/fixture_roll_wanderer = FALSE
var/fixture_wolves = 0
var/fixture_services = 0

/datum
	var/gcDestroyed = 0
	var/gc_destroyed = 0
/datum/proc/Destroy()
	return
/datum/proc/persistence_runtime_var(key)
	return key == "fixture_parent_runtime"

/area
	var/climate = "sea"
/area/caribbean/void/caves/special

/mob/living/simple_animal/hostile/wolf
	var/stat = CONSCIOUS
	var/cub = FALSE
/mob/living/simple_animal/hostile/wolf/New()
	fixture_wolves++
	..()
/mob/living/simple_animal/hostile/wolf/female
/mob/living/simple_animal/hostile/wolf/white
/mob/living/simple_animal/hostile/wolf/white/female

/obj/structure/animalspawner/wolfcave
	var/fixture_calls = 0
/obj/structure/animalspawner/wolfcave/fixture
	procreate_holder = 6
	wanderer_holder = 6
/obj/structure/animalspawner/wolfcave/full/fixture
	procreate_holder = 6
	wanderer_holder = 6

/proc/get_area(atom/A)
	return A.loc.loc
/proc/fixture_prob(chance)
	return chance == 18 && fixture_roll_wanderer
/proc/fixture_assert(condition, label)
	if(!condition)
		fixture_failed = TRUE
		world.log << "FAIL wolf cave: [label]"
/proc/fixture_retire(obj/structure/animalspawner/wolfcave/C)
	C.gcDestroyed = world.time + 1
	C.gc_destroyed = C.gcDestroyed
	C.Destroy()
	C.loc = null

/world
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 10
	visibility = FALSE
	view = 0
/world/OpenPort(port)
	if(port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
/world/Error(exception/E)
	fixture_failed = TRUE
	world.log << "FAIL wolf cave runtime: [E]"
/world/New()
	OpenPort("none")
	fixture_assert(port == 0, "closed port")
	OpenPort(0)
	fixture_assert(port == 0, "refused reopen")
	spawn(150)
		world.log << "FAIL wolf cave: watchdog"
		del(world)
		return
	spawn(1)
		fixture_main()
	return

/proc/fixture_batch(count, full)
	var/list/caves = list()
	var/cave_type = full ? /obj/structure/animalspawner/wolfcave/full/fixture : /obj/structure/animalspawner/wolfcave/fixture
	for(var/i = 1, i <= count, i++)
		caves += new cave_type(locate(i, 1, 1))
	sleep(1)
	for(var/obj/structure/animalspawner/wolfcave/C in caves)
		fixture_assert(C.fixture_calls == 1, "one initial service count=[count] full=[full]")
		C.Tick()
		C.Tick()
		C.Tick()
	sleep(4)
	for(var/obj/structure/animalspawner/wolfcave/C in caves)
		fixture_assert(C.fixture_calls == 3, "one chain count=[count] full=[full]")
	var/obj/structure/animalspawner/wolfcave/first = caves[1]
	var/old_calls = first.fixture_calls
	fixture_retire(first)
	first.Tick() // A retired object cannot restart its chain.
	var/obj/structure/animalspawner/wolfcave/replacement = new cave_type(locate(1, 1, 1))
	sleep(1)
	fixture_assert(replacement.fixture_calls == 1, "replacement starts independently")
	sleep(2)
	fixture_assert(first.fixture_calls == old_calls, "retired sleeper stops")
	fixture_assert(replacement.fixture_calls == 2, "replacement serviced once")
	for(var/obj/structure/animalspawner/wolfcave/C in caves)
		if(C != first)
			fixture_assert(C.fixture_calls == 5, "survivor after first-owner removal")
	var/obj/structure/animalspawner/wolfcave/late = new cave_type(locate(11, 1, 1))
	sleep(1)
	fixture_assert(late.fixture_calls == 1, "late creation starts independently")
	var/late_calls = late.fixture_calls
	late.Destroy() // Check direct cleanup independently of qdel flags.
	var/replacement_calls = replacement.fixture_calls
	for(var/obj/structure/animalspawner/wolfcave/C in caves)
		fixture_retire(C)
	fixture_retire(replacement)
	sleep(3)
	fixture_assert(late.fixture_calls == late_calls, "Destroy stops sleeper")
	fixture_assert(replacement.fixture_calls == replacement_calls, "all removed")
	for(var/obj/structure/animalspawner/wolfcave/C in caves)
		del(C)
	del(replacement)
	del(late)
	world.log << "CHECK wolf cave batch count=[count] full=[full]"

/proc/fixture_population()
	var/obj/structure/animalspawner/wolfcave/hard = new /obj/structure/animalspawner/wolfcave/fixture(locate(1, 1, 1))
	sleep(1)
	del(hard)
	var/services = fixture_services
	sleep(3)
	fixture_assert(fixture_services == services, "native deletion stops sleeper")
	var/obj/structure/animalspawner/wolfcave/C = new /obj/structure/animalspawner/wolfcave/fixture(locate(1, 1, 1))
	sleep(1)
	fixture_assert(C.males >= 1 && C.males <= 3 && C.females >= 1 && C.females <= 3, "existing constructor bounds")
	fixture_assert(C.cubs == 1 && C.procreate_cooldown && C.cub_growing, "one pregnancy and growth wait")
	fixture_assert(C.persistence_runtime_var("ticking"), "timer excluded from custom save")
	fixture_assert(C.persistence_runtime_var("fixture_parent_runtime"), "parent exclusion forwarded")
	fixture_assert(!C.persistence_runtime_var("males") && !C.persistence_runtime_var("procreate_cooldown"), "durable accounting policy preserved")
	// Legacy false must not overwrite an active constructor timer on import.
	if(!C.persistence_runtime_var("ticking"))
		C.ticking = FALSE
	var/calls = C.fixture_calls
	C.males = 7
	C.females = 0
	C.cubs = 0
	sleep(2)
	fixture_assert(C.fixture_calls == calls + 1 && C.total_population == 7, "recount and legacy flag admission")
	fixture_retire(C)
	del(C)

	// A single eligible wanderer debits the existing population path and then
	// blocks subsequent attempts for the holder duration (six adapted ticks).
	fixture_roll_wanderer = TRUE
	var/start_wolves = fixture_wolves
	C = new /obj/structure/animalspawner/wolfcave/fixture(locate(1, 1, 1))
	sleep(1)
	fixture_assert(fixture_wolves == start_wolves + 1 && C.wanderer_cooldown, "one wanderer and cooldown")
	var/adults = C.males + C.females
	fixture_assert(adults >= 1 && adults <= 5, "wanderer debits one adult")
	sleep(2)
	fixture_assert(fixture_wolves == start_wolves + 1 && C.wanderer_cooldown, "cooldown suppresses next roll")
	fixture_roll_wanderer = FALSE
	fixture_retire(C)
	del(C)
	for(var/mob/living/simple_animal/hostile/wolf/W in world)
		del(W)

/proc/fixture_main()
	for(var/count in list(1, 3, 10))
		fixture_batch(count, FALSE)
		fixture_batch(count, TRUE)
	fixture_population()
	if(fixture_failed)
		world.log << "FAIL wolf cave ownership"
	else
		world.log << "PASS wolf cave ownership"
	del(world)
	return
