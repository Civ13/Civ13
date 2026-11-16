// Old-save seed for tests/underground_level/migration.py. Compiled into the
// build from BEFORE the unformed compiled levels: it leaves a body, a loose
// item and a crate with an item inside on the old cave level (z 1), puts a
// ladder on the surface above a fourth cell, saves, writes result.json and
// ends. Test-only; never part of civ13.dme.
var/global/datum/underground_migration_seed/underground_migration_seed = new

/datum/underground_migration_seed
	var/list/result = list()

/datum/underground_migration_seed/New()
	spawn(10)
		drive()

/datum/underground_migration_seed/proc/open_cell(skip)
	for(var/turf/T in block(locate(40, 40, 1), locate(world.maxx - 40, world.maxy - 40, 1)))
		if(!istype(T, /turf/floor) || T.density || (T in skip)) continue
		var/turf/up = locate(T.x, T.y, 2)
		if(!istype(up, /turf/floor) || up.density || istype(up, /turf/floor/beach/water)) continue
		var/clear = TRUE
		for(var/atom/movable/AM in T)
			if(AM.density) clear = FALSE
		if(clear) return T
	return null

/datum/underground_migration_seed/proc/drive()
	var/failure
	try
		while(!(ticker && processScheduler && processes && config && ticker.current_state >= GAME_STATE_PREGAME))
			sleep(10)
		config.webhook_can_fire = FALSE
		world.visibility = 0
		if(ticker.current_state < GAME_STATE_PLAYING)
			ticker.admin_started = TRUE
			if(ticker.pregame_timeleft > 1) ticker.pregame_timeleft = 1
		while(ticker.current_state != GAME_STATE_PLAYING)
			sleep(10)
		result["map"] = map.ID
		var/list/used = list()
		var/list/cells = list()
		for(var/i = 1 to 4)
			var/turf/T = open_cell(used)
			if(!T) throw EXCEPTION("No open cave cell [i]")
			used += T
			cells += "[T.x],[T.y]"
		result["cells"] = cells
		new /mob/living/human(used[1])
		var/obj/item/weapon/material/shovel/S = new(used[2])
		S.name = "migration seed shovel"
		var/obj/structure/closet/crate/C = new(used[3])
		C.name = "migration seed crate"
		var/obj/item/weapon/material/shovel/inside = new(C)
		inside.name = "migration seed crate shovel"
		var/turf/L = used[4]
		new /obj/structure/multiz/ladder/ww2/tunneltop(locate(L.x, L.y, 2))
		new /obj/structure/multiz/ladder/ww2/tunnelbottom(L)
		var/list/dups = list()
		for(var/name in list("start", "join", "paradrop", "supply"))
			var/list/reg = name == "start" ? newplayer_start : name == "join" ? latejoin : name == "paradrop" ? paradrop_landmarks : supplydrop_turfs
			var/list/seen = list()
			for(var/turf/T in reg)
				if(seen["[T.x],[T.y],[T.z]"]) dups += "[name] [T.x],[T.y],[T.z] [T.type]"
				seen["[T.x],[T.y],[T.z]"] = TRUE
		for(var/group in latejoin_turfs)
			var/list/seen = list()
			for(var/turf/T in latejoin_turfs[group])
				if(seen["[T.x],[T.y],[T.z]"]) dups += "latejoin [group] [T.x],[T.y],[T.z] [T.type]"
				seen["[T.x],[T.y],[T.z]"] = TRUE
			// Old Desert builds listed one landmark tile twice and could not save; one each.
			var/list/unique = list()
			for(var/T in latejoin_turfs[group])
				if(!(T in unique)) unique += T
			latejoin_turfs[group] = unique
		result["duplicate_spawns"] = dups
		var/saved = FALSE
		for(var/attempt = 1 to 60)
			saved = ticker.savemap()
			if(saved || !findtext("[map_storage.last_error]", "transitioning")) break
			sleep(20)
		if(!saved) throw EXCEPTION("Seed save failed: [map_storage.last_error]")
	catch(var/exception/e)
		failure = "[e] at [e.file]:[e.line]"
	result["passed"] = !failure
	result["failure"] = failure
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	sleep(5)
	del(world)
