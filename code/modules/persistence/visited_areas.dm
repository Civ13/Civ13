// Where players have been, by VISITED_CHUNK x VISITED_CHUNK chunk of each
// level, kept with every save (round.json "visited", checked by
// valid_visited_record in functions.dm). Every few seconds each player's
// character marks the chunk it stands in and the eight around it, which covers
// what it can see. The save leaves out wild animals in chunks no player has
// visited; the ecology and sea life spawners repopulate them (Val, 2026-11-13:
// wildlife only, terrain and builds are always saved).

// z -> one TRUE/null per chunk, row by row.
var/global/list/persistence_visited_levels = list()
// When the record began (world.realtime); 0 until the first visit.
var/global/persistence_visited_since = 0
var/global/persistence_visited_running = FALSE

/proc/visited_chunk_columns()
	return -round(-world.maxx / VISITED_CHUNK)

/proc/visited_chunk_rows()
	return -round(-world.maxy / VISITED_CHUNK)

/proc/visited_level(z)
	var/cells = visited_chunk_columns() * visited_chunk_rows()
	while(persistence_visited_levels.len < z)
		var/list/level = list()
		level.len = cells
		persistence_visited_levels[++persistence_visited_levels.len] = level
	return persistence_visited_levels[z]

/proc/mark_visited_around(turf/T)
	if(!T || T.z < 1) return
	if(!persistence_visited_since) persistence_visited_since = world.realtime
	var/list/level = visited_level(T.z)
	var/columns = visited_chunk_columns()
	var/rows = visited_chunk_rows()
	var/cx = round((T.x - 1) / VISITED_CHUNK)
	var/cy = round((T.y - 1) / VISITED_CHUNK)
	for(var/y = max(0, cy - 1), y <= min(rows - 1, cy + 1), y++)
		for(var/x = max(0, cx - 1), x <= min(columns - 1, cx + 1), x++)
			level[y * columns + x + 1] = TRUE

/proc/visited_chunk(x, y, z)
	if(z < 1 || z > persistence_visited_levels.len) return FALSE
	var/list/level = persistence_visited_levels[z]
	return !!level[round((y - 1) / VISITED_CHUNK) * visited_chunk_columns() + round((x - 1) / VISITED_CHUNK) + 1]

/proc/mark_visited_by_players()
	for(var/client/C in clients)
		var/mob/living/M = C.mob
		if(istype(M)) mark_visited_around(get_turf(M))

/proc/visited_tracking_loop()
	set waitfor = FALSE
	if(persistence_visited_running) return
	persistence_visited_running = TRUE
	while(TRUE)
		sleep(50)
		// A held world has not loaded its save; its record comes with the load.
		if(persistence_restart && persistence_restart.startup_hold) continue
		mark_visited_by_players()

/hook/startup/proc/start_visited_tracking()
	visited_tracking_loop()
	return TRUE

/map_storage/visited_capture()
	if(!persistence_visited_since) return null
	var/cells = visited_chunk_columns() * visited_chunk_rows()
	var/list/levels = list()
	var/list/counts = list()
	for(var/z = 1, z <= world.maxz, z++)
		var/list/level = visited_level(z)
		var/list/marks = list()
		var/visited = 0
		for(var/i = 1, i <= cells, i++)
			if(level[i])
				marks += "1"
				visited++
			else
				marks += "0"
		levels["[z]"] = jointext(marks, "")
		counts += "level [z] [visited] of [cells]"
	var/line = "World save: chunks players have visited: [jointext(counts, ", ")]."
	world.log << line
	persistence_game_log(line)
	return list("version" = 1, "chunk" = VISITED_CHUNK, "since" = persistence_visited_since, "levels" = levels)

// Adds the loaded save's record to anything marked since this world started.
/map_storage/visited_loaded(list/round_state)
	var/list/record = islist(round_state) ? round_state["visited"] : null
	if(!valid_visited_record(record, world.maxx, world.maxy, world.maxz)) return
	if(!persistence_visited_since || record["since"] < persistence_visited_since) persistence_visited_since = record["since"]
	var/list/levels = record["levels"]
	for(var/z = 1, z <= world.maxz, z++)
		var/marks = levels["[z]"]
		var/list/level = visited_level(z)
		for(var/i = 1, i <= length(marks), i++)
			if(text2ascii(marks, i) == 49) level[i] = TRUE

// A wild animal (ecology_wild_animal: no rider, friends, follower or player)
// of a species a spawner tops up, standing in a chunk no player has visited
// since the record began. Animals nobody repopulates are always kept.
/map_storage/save_skips_wildlife(atom/movable/A)
	if(!persistence_visited_since || !istype(A, /mob/living/simple_animal) || !isturf(A.loc)) return FALSE
	var/mob/living/simple_animal/animal = A
	if(!ecology_wild_animal(animal) || visited_chunk(animal.x, animal.y, animal.z)) return FALSE
	if(!wildlife_repopulated(animal.type)) return FALSE
	saving_skipped_wildlife["\ref[animal]"] = TRUE
	return TRUE

/proc/wildlife_repopulated(path)
	if(ispath(path, /mob/living/simple_animal/sea))
		if(!sea_life_table) sea_life_table = sea_life_species()
		for(var/datum/sea_species/S in sea_life_table)
			if(S.path == path) return TRUE
		return FALSE
	return ecology_spawner && ecology_spawner.species_for_type(path)
