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
/obj/map_metadata/eco_probe/New()
	return
/mob/living/human/eco_probe/New()
	return
/mob/living/human/eco_probe/update_icons()
	return
// The probe never needs AI or life ticks from spawned animals.
/mob/living/simple_animal/deer/eco_probe/New()
	deer_count |= src
	register_living_mob(src)
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/eco_probe
		eco_habitat_checks()
		eco_cycle_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/eco_grass(x1, y1, x2, y2)
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/eco_habitat_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	eco_grass(1, 1, 40, 40)
	var/turf/T = locate(20, 20, 1)
	var/list/deer_biomes = list("temperate")
	eco_check(isnull(ecology_habitat_error(T, deer_biomes)), "open temperate grass is deer habitat")
	eco_check(ecology_habitat_error(T, list("desert")) == "habitat", "wrong biome is refused")
	var/obj/roof/R = new(T)
	eco_check(!isnull(ecology_habitat_error(T, deer_biomes)), "a roofed tile is refused")
	qdel(R)
	A = get_area(T)
	A.location = AREA_OUTSIDE
	var/obj/structure/S = new /obj/structure(T)
	S.density = TRUE
	eco_check(ecology_habitat_error(T, deer_biomes) == "occupied", "an occupied tile is refused")
	qdel(S)
	A.location = AREA_INSIDE
	eco_check(ecology_habitat_error(T, deer_biomes) == "habitat", "an indoor area is refused")
	A.location = AREA_OUTSIDE
	var/turf/water = locate(2, 2, 1)
	water = water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	eco_check(ecology_habitat_error(water, deer_biomes) == "ground", "water is refused")
	water.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	var/list/row = ecology_cell_row(locate(17, 9, 1))
	eco_check(row[1] == 1 && row[2] == 3 && row[3] == 2, "cells are 8x8 tiles")
	eco_check(!ecology_visible_to_players(T), "no clients means nothing is watching")

/proc/eco_cycle_checks()
	var/datum/ecology_spawner/E = new
	var/datum/ecology_species/deer = new("deer", list(/mob/living/simple_animal/deer/eco_probe), 3, list("temperate"))
	E.species = list(deer)
	E.enabled = TRUE
	E.heatmap = new /datum/ecology_activity_heatmap(4096, 60, 1800, 0.25)
	E.started_at = world.time
	deer_count = list()
	eco_check(E.cycle() == 0 && !deer_count.len && findtext(E.last_report, "warming up"), "nothing spawns during warm-up")
	E.started_at = world.time - 11 MINUTES
	var/before = deer.population()
	eco_check(before == 0, "population counts living deer")
	var/spawned = E.cycle()
	eco_check(spawned >= 1 && deer.population() == spawned, "a herd spawns below target")
	var/mob/living/simple_animal/deer/D = deer_count[1]
	eco_check(D && istype(get_turf(D), /turf/floor/grass), "spawned deer stands on grass habitat")
	// Fill to target and confirm the spawner stops.
	E.cycle()
	E.cycle()
	eco_check(deer.population() == 3, "population reaches the target")
	eco_check(E.cycle() == 0 && deer.population() == 3, "no spawn at or above target")
	D = deer_count[1]
	D.stat = DEAD
	eco_check(deer.population() == 2, "dead animals do not count")
	D = deer_count[2]
	D.friends = list("tamer")
	eco_check(deer.population() == 1, "tamed animals do not count as wild")
	D.friends = list()
	// Pressure: mark every cell busy, so nothing is quiet.
	var/list/rows = list()
	for (var/x = 1, x <= 5, x++)
		for (var/y = 1, y <= 5, y++)
			rows += list(list(1, x, y))
	var/datum/ecology_activity_heatmap/H = E.heatmap
	for (var/i = 1, i <= 6, i++)
		H.last_bucket = -1
		H.sample(E.now_seconds(), rows, TRUE, H.epoch)
	eco_check(E.cycle() == 0 && deer.population() == 2, "busy player cells receive no spawns")
	H.coverage_valid = FALSE
	H.cells = list()
	eco_check(isnull(E.find_site(deer)), "unknown coverage is never treated as quiet")
	E.stop()
	eco_check(!E.enabled && !E.heatmap, "stop releases the heatmap")
	eco_check(E.cycle() == 0, "a stopped spawner does nothing")
	eco_check(!("heatmap" in E.get_saved_vars()) && !("enabled" in E.get_saved_vars()) && !("habitat_cells" in E.get_saved_vars()), "spawner state is runtime-only")
	eco_default_species_checks()
	eco_index_checks()
	eco_rest_checks()
	eco_elk_breeding_checks()

/proc/eco_default_species_checks()
	var/list/defaults = ecology_default_species()
	var/ok = defaults.len >= 30
	var/list/names = list()
	for (var/datum/ecology_species/S in defaults)
		ok = ok && S.spawn_types.len && S.biomes.len && S.grounds && S.density > 0 && S.max_target > 0
		names += S.name
		for (var/path in S.spawn_types)
			ok = ok && ispath(path, /mob/living/simple_animal)
	eco_check(ok, "default species are complete")
	eco_check(("sheep" in names) && ("deer" in names) && ("penguin" in names) && ("camel" in names), "default species cover the map spawner animals")
	ecology_spawner = null
	ecology_species_table = defaults
	var/datum/ecology_species/S = ecology_species_for_type(/mob/living/simple_animal/deer/elk/male)
	eco_check(S && S.name == "elk", "subtypes resolve to the most specific species")
	S = ecology_species_for_type(/mob/living/simple_animal/deer/female)
	eco_check(S && S.name == "deer", "deer resolve to deer")
	eco_check(isnull(ecology_species_for_type(/mob/living/simple_animal/hostile/human/skeleton)), "non-wildlife is not covered")
	S = ecology_species_for_type(/mob/living/simple_animal/hostile/gorilla)
	eco_check(S && S.name == "gorilla", "ordinary gorillas are gorillas")
	S = ecology_species_for_type(/mob/living/simple_animal/crab/small)
	eco_check(S && S.name == "crab", "ordinary crabs are crabs")
	var/ok_special = TRUE
	for (var/special in list(/mob/living/simple_animal/hostile/gorilla/gigantopithecus, /mob/living/simple_animal/hostile/gorilla/gigantopithecus/bigfoot, /mob/living/simple_animal/hostile/gorilla/gigantopithecus/yeti, /mob/living/simple_animal/crab/small/trilobite))
		ok_special = ok_special && isnull(ecology_species_for_type(special))
	eco_check(ok_special, "gigantopithecus, bigfoot, yeti and trilobites are not ordinary species")

/proc/eco_index_checks()
	// Whole 40x40 level is temperate grass: deer habitat, nothing for camels.
	var/datum/ecology_spawner/E = new
	E.build_index()
	var/datum/ecology_species/deer
	var/datum/ecology_species/camel
	var/datum/ecology_species/sheep
	for (var/datum/ecology_species/S in E.species)
		if (S.name == "deer")
			deer = S
		if (S.name == "camel")
			camel = S
		if (S.name == "sheep")
			sheep = S
	eco_check(deer.habitat_tiles >= 1400 && deer.target == 4, "deer habitat and target come from the map ([deer.habitat_tiles], [deer.target])")
	eco_check(camel.habitat_tiles == 0 && camel.target == 0, "no desert means no camels")
	eco_check(sheep.target >= 1, "sheep get a target on temperate grass")
	// The total stays under the map cap.
	map.ecology_wildlife_cap = 3
	E.size_targets()
	eco_check(E.total_target <= 3 + E.species.len && deer.target >= 1, "the map cap scales targets down")
	map.ecology_wildlife_cap = 700
	// A spawner of an indexed species is replaced only while ecology runs.
	map.ecology_wildlife = TRUE
	E.size_targets()
	ecology_spawner = E
	eco_check(!ecology_replaces_spawner(/mob/living/simple_animal/sheep), "spawners keep working until ecology starts")
	E.enabled = TRUE
	eco_check(ecology_replaces_spawner(/mob/living/simple_animal/sheep), "ecology retires the sheep spawner")
	eco_check(!ecology_replaces_spawner(/mob/living/simple_animal/camel), "species with no habitat keep their spawner")
	eco_check(!ecology_replaces_spawner(/mob/living/simple_animal/hostile/human/skeleton), "skeleton spawners are not wildlife")
	map.ecology_wildlife = FALSE
	eco_check(!ecology_replaces_spawner(/mob/living/simple_animal/sheep), "maps without ecology keep their spawners")
	E.enabled = FALSE
	ecology_spawner = null
	// Ground classes.
	var/turf/T = locate(30, 30, 1)
	T = T.ChangeTurf(/turf/floor/dirt/ploughed, FALSE, FALSE)
	eco_check(!ecology_ground(T), "farmland is not wildlife ground")
	T = T.ChangeTurf(/turf/floor/winter, FALSE, FALSE)
	eco_check(ecology_ground(T) == ECO_SNOW, "snow is snow ground")
	T = T.ChangeTurf(/turf/floor/beach/water/swamp, FALSE, FALSE)
	eco_check(ecology_ground(T) == ECO_WATER, "swamp water is shallow water ground")
	T = T.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
	eco_check(!ecology_ground(T), "deep water is not ground")
	T = T.ChangeTurf(/turf/floor/beach/sand/desert, FALSE, FALSE)
	eco_check(ecology_ground(T) == ECO_SAND, "desert sand is sand ground")
	T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/eco_rest_checks()
	var/mob/living/simple_animal/deer/eco_probe/D = new(locate(5, 5, 1))
	ecology_observer_turfs = list()
	var/rests = 0
	for (var/i = 1, i <= 8, i++)
		ecology_rest_phase = i % 4
		if (ecology_animal_resting(D))
			rests++
	eco_check(rests == 6, "an unobserved animal runs one Life in four")
	ecology_observer_turfs = list(locate(30, 30, 1))
	eco_check(!ecology_animal_resting(D), "an animal near a player runs every second")
	ecology_observer_turfs = list()
	D.stance = HOSTILE_STANCE_ATTACK
	eco_check(!ecology_animal_resting(D), "a fighting animal never rests")
	D.stance = HOSTILE_STANCE_IDLE
	var/mob/living/simple_animal/hostile/human/skeleton/K = new(locate(6, 6, 1))
	eco_check(!ecology_animal_resting(K), "human NPCs never rest")
	ecology_world_unwatched = TRUE
	eco_check(ecology_animal_frozen(D), "an animal waits while nobody is connected")
	eco_check(ecology_animal_frozen(K), "human NPCs wait while nobody is connected")
	D.stance = HOSTILE_STANCE_ATTACK
	eco_check(ecology_animal_frozen(D), "a fighting animal stops attacking while nobody is connected")
	D.stance = HOSTILE_STANCE_IDLE
	D.stat = DEAD
	eco_check(!ecology_animal_frozen(D), "a dead animal keeps rotting while nobody is connected")
	D.stat = CONSCIOUS
	ecology_world_unwatched = FALSE
	eco_check(!ecology_animal_frozen(D), "animals run again once someone connects")
	qdel(K)
	qdel(D)

/proc/eco_elk_breeding_checks()
	deer_count = list()
	var/mob/living/simple_animal/deer/elk/female/F = new(locate(20, 30, 1))
	var/mob/living/simple_animal/deer/elk/male/M = new(locate(21, 30, 1))
	F.Life()
	eco_check(F.pregnant, "an elk doe conceives with an elk stag")
	F.birthCountdown = 1
	F.Life()
	var/born = 0
	var/wrong = 0
	for (var/mob/living/simple_animal/deer/C in get_turf(F))
		if (C == F)
			continue
		if (istype(C, /mob/living/simple_animal/deer/elk))
			born++
		else
			wrong++
	eco_check(born == 1 && !wrong, "an elk doe gives birth to an elk")
	for (var/mob/living/simple_animal/deer/C in range(2, F))
		qdel(C)
	qdel(M)
