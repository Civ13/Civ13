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
	eco_check(spawned == 1 && deer.population() == 1, "one deer per species per cycle below target")
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
	eco_check(!("heatmap" in E.get_saved_vars()) && !("enabled" in E.get_saved_vars()), "spawner state is runtime-only")
	var/list/defaults = ecology_default_species()
	var/ok = defaults.len == 3
	for (var/datum/ecology_species/S in defaults)
		ok = ok && S.target > 0 && S.spawn_types.len && !isnull(S.population())
	eco_check(ok, "default species resolve their registries")
