// Ecology-driven wildlife spawning (roadmap plan item 4). Default off.
//
// Every cycle the owner samples where active players are into the activity
// heatmap, then tops up each wild species that is below its target by placing
// at most one animal per species in a habitat cell players have not used
// recently, out of every client's view range. Animals register in their own
// species lists in New(), so breeding caps and deaths keep working unchanged.
// Nothing here is saved; the heatmap and its epoch start fresh after a load.

#define ECOLOGY_CELL_SIZE 8
#define ECOLOGY_CYCLE (60 SECONDS)
#define ECOLOGY_WARMUP (10 MINUTES)
#define ECOLOGY_QUIET_PRESSURE 0.05
#define ECOLOGY_VIEW_MARGIN 15
#define ECOLOGY_ATTEMPTS 24

var/global/datum/ecology_spawner/ecology_spawner = null

// One wild species: what to spawn, which list counts it, its cap and habitat.
/datum/ecology_species
	var/name
	var/list/spawn_types = list()
	var/target = 0 // the spawner tops up to this many living animals
	var/list/biomes = list()

/datum/ecology_species/New(_name, list/_types, _target, list/_biomes)
	..()
	name = _name
	spawn_types = _types
	target = _target
	biomes = _biomes

/datum/ecology_species/proc/population()
	var/list/registry
	switch (name)
		if ("deer")
			registry = deer_count
		if ("wolf")
			registry = wolf_count
		if ("bear")
			registry = bear_count
	if (!islist(registry))
		return null
	var/total = 0
	for (var/mob/living/L in registry)
		if (L.stat != DEAD && !QDELETED(L))
			total++
	return total

// Targets stay below each species' breeding cap (deer 30, wolves 20, bears 12)
// so natural breeding still has room to work.
/proc/ecology_default_species()
	return list(
		new /datum/ecology_species("deer", list(/mob/living/simple_animal/deer/male, /mob/living/simple_animal/deer/female), 20, list("temperate", "taiga", "tundra", "sea")),
		new /datum/ecology_species("wolf", list(/mob/living/simple_animal/hostile/wolf, /mob/living/simple_animal/hostile/wolf/female), 8, list("temperate", "taiga", "tundra")),
		new /datum/ecology_species("bear", list(/mob/living/simple_animal/hostile/bear/boar, /mob/living/simple_animal/hostile/bear/sow), 4, list("temperate", "taiga")),
	)

/datum/ecology_spawner
	should_save = FALSE
	var/tmp/enabled = FALSE
	var/tmp/datum/ecology_activity_heatmap/heatmap
	var/tmp/list/species
	var/tmp/started_at = 0
	var/tmp/loop_generation = 0
	var/tmp/spawned_total = 0
	var/tmp/last_report = "not started"

/datum/ecology_spawner/New()
	..()
	species = ecology_default_species()

/datum/ecology_spawner/persistence_runtime_var(key)
	if (key in list("enabled", "heatmap", "species", "started_at", "loop_generation", "spawned_total", "last_report"))
		return TRUE
	return ..()

/datum/ecology_spawner/proc/now_seconds()
	return round(world.time / 10)

/datum/ecology_spawner/proc/start()
	if (enabled)
		return FALSE
	enabled = TRUE
	heatmap = new /datum/ecology_activity_heatmap(4096, ECOLOGY_CYCLE / 10, 1800, 0.25)
	started_at = world.time
	loop_generation++
	var/generation = loop_generation
	spawn (0)
		while (enabled && generation == loop_generation)
			cycle()
			sleep(ECOLOGY_CYCLE)
	return TRUE

/datum/ecology_spawner/proc/stop()
	if (!enabled)
		return FALSE
	enabled = FALSE
	loop_generation++
	if (heatmap)
		qdel(heatmap)
	heatmap = null
	return TRUE

/proc/ecology_cell_row(turf/T)
	if (!T)
		return null
	return list(T.z, round((T.x - 1) / ECOLOGY_CELL_SIZE) + 1, round((T.y - 1) / ECOLOGY_CELL_SIZE) + 1)

// Active, non-AFK players in the world. Ghosts and lobby players do not count as activity.
/datum/ecology_spawner/proc/activity_rows()
	var/list/rows = list()
	var/list/seen = list()
	for (var/client/C in clients)
		var/mob/living/L = C.mob
		if (!istype(L) || L.stat == DEAD || C.inactivity > 5 MINUTES)
			continue
		var/list/row = ecology_cell_row(get_turf(L))
		if (!row)
			continue
		var/key = "[row[1]]:[row[2]]:[row[3]]"
		if (seen[key])
			continue
		seen[key] = TRUE
		rows += list(row)
	return rows

/datum/ecology_spawner/proc/sample_activity()
	var/list/rows = activity_rows()
	// More distinct occupied cells than one complete sample allows: hold
	// coverage unknown for this epoch rather than truncating it.
	if (rows.len > 256)
		heatmap.reset_epoch(now_seconds())
		started_at = world.time
		return FALSE
	return heatmap.sample(now_seconds(), rows, TRUE, heatmap.epoch)

// No client's eye or body may be close enough to see the spawn happen.
/proc/ecology_visible_to_players(turf/T, margin = ECOLOGY_VIEW_MARGIN)
	for (var/client/C in clients)
		var/turf/eye = get_turf(C.eye)
		var/turf/body = get_turf(C.mob)
		if (eye && eye.z == T.z && get_dist(eye, T) <= margin)
			return TRUE
		if (body && body.z == T.z && get_dist(body, T) <= margin)
			return TRUE
	return FALSE

/proc/ecology_habitat_error(turf/T, list/biomes)
	if (!T || T.density || !(istype(T, /turf/floor/grass) || T.type == /turf/floor/dirt))
		return "ground"
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || A.is_void_area || !(A.climate in biomes))
		return "habitat"
	if (locate(/obj/roof) in T)
		return "roofed"
	for (var/atom/movable/AM in T)
		if (AM.density || istype(AM, /mob/living))
			return "occupied"
	return null

// Returns the turf used, or null. Picks random candidates; never scans the world.
/datum/ecology_spawner/proc/find_site(datum/ecology_species/S)
	var/now = now_seconds()
	for (var/i = 1, i <= ECOLOGY_ATTEMPTS, i++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), rand(1, world.maxz))
		if (ecology_habitat_error(T, S.biomes))
			continue
		var/pressure = heatmap.pressure(now, ecology_cell_row(T), heatmap.epoch)
		// Unknown coverage (null) never counts as quiet.
		if (isnull(pressure) || pressure > ECOLOGY_QUIET_PRESSURE)
			continue
		if (ecology_visible_to_players(T))
			continue
		return T
	return null

/datum/ecology_spawner/proc/cycle()
	if (!enabled || !heatmap)
		return 0
	if (persistence_active_operation || persistence_save_in_progress)
		last_report = "paused for a world save"
		return 0
	sample_activity()
	if (world.time - started_at < ECOLOGY_WARMUP)
		last_report = "warming up activity history"
		return 0
	var/spawned = 0
	var/list/notes = list()
	for (var/datum/ecology_species/S in species)
		var/count = S.population()
		if (isnull(count) || count >= S.target)
			notes += "[S.name] [count]/[S.target]"
			continue
		var/turf/T = find_site(S)
		if (!T)
			notes += "[S.name] [count]/[S.target] (no quiet habitat found)"
			continue
		var/path = pick(S.spawn_types)
		new path(T)
		spawned++
		notes += "[S.name] [count + 1]/[S.target] (+1)"
	spawned_total += spawned
	last_report = jointext(notes, ", ")
	return spawned

/client/proc/toggle_ecology_spawning()
	set category = "Debug"
	set name = "Toggle Ecology Spawning"
	if (!check_rights(R_DEBUG))
		return
	if (!ecology_spawner)
		ecology_spawner = new
	if (ecology_spawner.enabled)
		ecology_spawner.stop()
	else
		ecology_spawner.start()
	var/state = ecology_spawner.enabled ? "enabled" : "disabled"
	to_chat(src, SPAN_NOTICE("Ecology spawning [state]. It needs ten minutes of activity history before the first spawn."))
	message_admins("[key_name(src)] [state] ecology spawning.", key_name(src))
	log_admin("[key_name(src)] [state] ecology spawning.")

/client/proc/ecology_spawning_status()
	set category = "Debug"
	set name = "Ecology Spawning Status"
	if (!check_rights(R_DEBUG))
		return
	if (!ecology_spawner || !ecology_spawner.enabled)
		to_chat(src, SPAN_NOTICE("Ecology spawning is off."))
		return
	to_chat(src, SPAN_NOTICE("Ecology spawning is on. Spawned so far: [ecology_spawner.spawned_total]. Last cycle: [ecology_spawner.last_report]."))

#undef ECOLOGY_CELL_SIZE
#undef ECOLOGY_CYCLE
#undef ECOLOGY_WARMUP
#undef ECOLOGY_QUIET_PRESSURE
#undef ECOLOGY_VIEW_MARGIN
#undef ECOLOGY_ATTEMPTS
