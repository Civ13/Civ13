// Builds every simple animal, kills it and then refreshes its sprite the way
// the game does afterwards (update_canmove() and update_icons()). Each animal
// must then show icon_dead, and icon_dead must exist in its icon file.
// Young (lamb, calf, piglet, babydeer) and sheared variants are swept too.
// run.py compares the gaps with known_missing.txt.
/obj/map_metadata/animal_dead_states_fixture/New()
	return
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	fps = 20
	turf = /turf
var/animal_dead_states_errors = 0
var/animal_dead_states_checked = 0
var/list/animal_dead_states_error_lines = list()
/world/Topic(T, addr, master, key)
	return "no"
/world/Error(exception/e, datum/e_src)
	animal_dead_states_errors++
	var/line = "[e] on [e.file]:[e.line]"
	if(!animal_dead_states_error_lines[line])
		animal_dead_states_error_lines[line] = TRUE
		text2file("[line] ([e_src ? e_src.type : "no source"])", "animal_dead_errors.txt")
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new /decl/observ/destroyed
	GLOB.nanomanager = new /datum/nanomanager
	map = new /obj/map_metadata/animal_dead_states_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	spawn(10) animal_dead_states_sweep()

/proc/animal_dead_states_throw(T, step, exception/e)
	text2file("THROW\t[T]\t[step]\t[e] on [e.file]:[e.line]", "animal_dead_throws.txt")

/proc/animal_dead_states_check(mob/living/simple_animal/A, variant)
	// icon_dead "" or a blank state is an animal that is deleted on death.
	if(!A.icon || !A.icon_dead)
		return
	var/line = "[A.type]\t[variant]"
	if(!(A.icon_dead in icon_states(A.icon)))
		text2file("MISSING\t[line]\t[A.icon_dead]\t[A.icon]", "animal_dead_missing.txt")
	else if(A.icon_state != A.icon_dead)
		text2file("STANDING\t[line]\t[A.icon_state]\t[A.icon_dead]", "animal_dead_missing.txt")

// Spawns T, applies variant, waits for the spawn(1) setup in New(), then kills it.
/proc/animal_dead_states_one(T, variant, turf/loc)
	var/mob/living/simple_animal/A
	try
		A = new T(loc)
	catch(var/exception/e)
		animal_dead_states_throw(T, "new", e)
		return FALSE
	if(QDELETED(A))
		return FALSE
	if(variant != "adult")
		if(!(variant in A.vars))
			qdel(A)
			return FALSE
		A.vars[variant] = TRUE
	sleep(2)
	if(QDELETED(A))
		return FALSE
	if(variant == "sheared")
		try
			A.update_icons()
		catch(var/exception/e2)
			animal_dead_states_throw(T, "sheared", e2)
	try
		A.death()
	catch(var/exception/e3)
		animal_dead_states_throw(T, "death", e3)
	if(QDELETED(A) || A.stat != DEAD)
		return FALSE
	try
		A.update_canmove()
		A.update_icons()
	catch(var/exception/e4)
		animal_dead_states_throw(T, "refresh", e4)
	animal_dead_states_check(A, variant)
	qdel(A)
	return TRUE

/proc/animal_dead_states_sweep()
	var/n = 0
	for(var/T in typesof(/mob/living/simple_animal))
		for(var/variant in list("adult", "lamb", "calf", "piglet", "babydeer", "sheared"))
			var/turf/loc = locate((n % 38) + 2, (round(n / 38) % 38) + 2, 1)
			n++
			spawn(0)
				if(animal_dead_states_one(T, variant, loc))
					animal_dead_states_checked++
		if(n % 60 == 0)
			sleep(1)
	sleep(50)
	text2file("PASS: checked [animal_dead_states_checked] animal variants; [animal_dead_states_errors] async runtime errors", "animal_dead_result.txt")
	del(world)
