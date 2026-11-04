// Native arrival-timing probe for wildlife sub-tile walking (#3509).
// Test-only: run.py appends it to a temporary copy of civ13.dme. It walks a
// probe mosquito 8 tiles towards a still or once-moved target with the legacy
// native walk_towards() and with the opted-in sub-tile walker, then records
// each turf entry and the arrival time. run.py compares the two.
var/global/datum/wildlife_arrival_probe/wildlife_arrival_probe = new

/mob/living/simple_animal/mosquito/arrival_probe
	Life()
		return

/mob/living/simple_animal/cow/arrival_target
	Life()
		return

/datum/wildlife_arrival_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		drive()

/datum/wildlife_arrival_probe/proc/clear_row(z, length)
	for(var/y in 20 to world.maxy - 20)
		for(var/x in 20 to world.maxx - length - 20)
			var/ok = TRUE
			for(var/i in 0 to length)
				var/turf/T = locate(x + i, y, z)
				if(!T || T.density || istype(T, /turf/floor/beach/water) || istype(T, /turf/wall))
					ok = FALSE
					break
				for(var/atom/movable/A in T)
					if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers))
						ok = FALSE
				if(!ok)
					break
			if(ok)
				return locate(x, y, z)
	return null

/datum/wildlife_arrival_probe/proc/trial(subtile, distance, lag, move_target_at = -1)
	var/turf/start = clear_row(1, distance + 2)
	if(!start)
		for(var/z in 2 to world.maxz)
			start = clear_row(z, distance + 2)
			if(start)
				break
	var/mob/living/simple_animal/mosquito/arrival_probe/M = new(start)
	var/mob/living/simple_animal/cow/arrival_target/C = new(locate(start.x + distance, start.y, start.z))
	C.density = FALSE
	if(subtile)
		M.npc_subtile_species_enabled = TRUE
		M.set_npc_subtile(TRUE)
	var/list/entries = list()
	var/turf/last = get_turf(M)
	var/t0 = world.time
	M.npc_subtile_species_walk("towards", C, lag)
	var/arrived = -1
	var/moved = FALSE
	while(world.time - t0 < 200)
		sleep(world.tick_lag)
		if(!moved && move_target_at >= 0 && world.time - t0 >= move_target_at)
			C.loc = locate(C.x + 2, C.y, C.z)
			moved = TRUE
		var/turf/now = get_turf(M)
		if(now != last)
			entries += world.time - t0
			last = now
		if(now == get_turf(C) && (!subtile || !(M.step_x || M.step_y)) && (move_target_at < 0 || moved))
			arrived = world.time - t0
			break
	var/list/out = list("subtile" = subtile, "distance" = distance, "lag" = lag, "move_target_at" = move_target_at, "arrived" = arrived, "entries" = entries, "tick_lag" = world.tick_lag)
	walk(M, 0)
	M.npc_subtile_stop_wild_walk()
	qdel(M)
	qdel(C)
	return out

/datum/wildlife_arrival_probe/proc/drive()
	var/list/results = list()
	try
		while(!ticker || !processes)
			sleep(10)
		sleep(50)
		for(var/lag in list(1, 2, 3, 3.5, 4, 5))
			for(var/sub in list(FALSE, TRUE))
				results += list(trial(sub, 8, lag))
				results += list(trial(sub, 8, lag, 10))
	catch(var/exception/e)
		results = list(list("error" = "[e.name] [e.file]:[e.line]"))
	text2file(json_encode(results), "result.json")
	sleep(5)
	del(world)
