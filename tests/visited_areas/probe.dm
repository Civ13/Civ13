// Native probe for code/modules/persistence/visited_areas.dm; run.py adds the real
// file and valid_visited_record (functions.dm) beside these stubs.
/world
	maxx = 40
	maxy = 20
	maxz = 2

/datum/restart_stub
	var/startup_hold = FALSE
var/global/datum/restart_stub/persistence_restart = new
var/global/list/clients = list()
var/global/list/game_lines = list()
var/global/map_storage/map_storage = new

/map_storage
	var/list/saving_skipped_wildlife = list()
/map_storage/proc/visited_capture()
	return null
/map_storage/proc/visited_loaded(list/round_state)
	return
/map_storage/proc/save_skips_wildlife(atom/movable/A)
	return FALSE

// Wildlife: the real ecology_wild_animal is extracted beside these stubs.
#define DEAD 2
#define QDELETED(X) (!X)
/mob/living
	var/stat = 0
/mob/living/simple_animal
	var/list/friends = list()
	var/rider = null
	var/following_mob = null
/mob/living/simple_animal/deer
/mob/living/simple_animal/unique_boss
/mob/living/simple_animal/sea
/mob/living/simple_animal/sea/shoal
/mob/living/simple_animal/sea/mystery
/datum/sea_species
	var/path
/datum/sea_species/New(_path)
	path = _path
var/global/list/sea_life_table = null
/proc/sea_life_species()
	return list(new /datum/sea_species(/mob/living/simple_animal/sea/shoal))
/datum/ecology_spawner/proc/species_for_type(path)
	return path == /mob/living/simple_animal/deer
var/global/datum/ecology_spawner/ecology_spawner = new

/proc/persistence_game_log(text)
	game_lines += text

/hook/startup

var/global/list/failures = list()
/proc/check(ok, message)
	if(!ok) failures += message

/proc/run_probe()
	check(!map_storage.visited_capture(), "no record before anyone visits")
	// 40x20 is 3 x 2 chunks of 16; (20,5,1) is chunk (1,0), so the whole level is marked
	// except nothing: its neighbours cover columns 0-2 and rows 0-1.
	mark_visited_around(locate(20, 5, 1))
	check(persistence_visited_since > 0, "the record starts at the first visit")
	check(visited_chunk(1, 1, 1) && visited_chunk(40, 20, 1), "a visit marks the chunks around it")
	check(!visited_chunk(1, 1, 2), "other levels stay unvisited")
	// (1,1,2) marks chunks (0,0),(1,0),(0,1),(1,1) of level 2, not column 2.
	mark_visited_around(locate(1, 1, 2))
	check(visited_chunk(17, 17, 2) && !visited_chunk(33, 1, 2), "a corner visit marks only its neighbours")
	var/list/record = map_storage.visited_capture()
	check(valid_visited_record(record, 40, 20, 2), "the captured record is valid: [json_encode(record)]")
	check(record["levels"]["1"] == "111111" && record["levels"]["2"] == "110110", "levels encode chunks row by row: [json_encode(record["levels"])]")
	check(game_lines.len == 1 && findtext(game_lines[1], "level 1 6 of 6, level 2 4 of 6"), "the save logs visited counts: [json_encode(game_lines)]")
	// A loaded save's record adds to what this world marked, and keeps the older start.
	var/since = record["since"]
	persistence_visited_levels = list()
	persistence_visited_since = 0
	mark_visited_around(locate(40, 20, 2))
	record["since"] = 1
	map_storage.visited_loaded(list("visited" = json_decode(json_encode(record))))
	check(persistence_visited_since == 1, "the loaded record's older start wins")
	check(visited_chunk(1, 1, 1) && visited_chunk(1, 20, 2) && visited_chunk(40, 20, 2), "the loaded record merges with new visits")
	record["since"] = since
	// The round-state check rejects malformed records.
	check(!valid_visited_record(record, 40, 20, 3), "a record for another level count is rejected")
	check(!valid_visited_record(record, 80, 20, 2), "a record for another width is rejected")
	var/list/bad = json_decode(json_encode(record))
	bad["levels"]["1"] = "11x111"
	check(!valid_visited_record(bad, 40, 20, 2), "only 0 and 1 are allowed")
	bad = json_decode(json_encode(record))
	bad["chunk"] = 8
	check(!valid_visited_record(bad, 40, 20, 2), "another chunk size is rejected")
	bad = json_decode(json_encode(record))
	bad["extra"] = 1
	check(!valid_visited_record(bad, 40, 20, 2), "unknown fields are rejected")
	map_storage.visited_loaded(list("visited" = bad))
	check(persistence_visited_since == 1, "an invalid record is ignored")
	check_wildlife()

// Level 2 now has chunks (0,0)-(1,1) unvisited except around (40,20); level 1 is
// fully visited from the loaded record.
/proc/check_wildlife()
	var/turf/far = locate(1, 1, 2)
	persistence_visited_levels = list()
	mark_visited_around(locate(40, 20, 2))
	var/mob/living/simple_animal/deer/deer = new(far)
	check(map_storage.save_skips_wildlife(deer), "a wild deer where nobody has been is left out")
	check(map_storage.saving_skipped_wildlife.len == 1 && map_storage.save_skips_wildlife(deer) && map_storage.saving_skipped_wildlife.len == 1, "a skipped animal is counted once")
	var/mob/living/simple_animal/deer/seen = new(locate(40, 20, 2))
	check(!map_storage.save_skips_wildlife(seen), "an animal where a player has been is kept")
	var/mob/living/simple_animal/deer/tame = new(far)
	tame.friends += "someone"
	check(!map_storage.save_skips_wildlife(tame), "an animal with friends is kept")
	var/mob/living/simple_animal/deer/ridden = new(far)
	ridden.rider = "someone"
	check(!map_storage.save_skips_wildlife(ridden), "a ridden animal is kept")
	var/mob/living/simple_animal/deer/dead = new(far)
	dead.stat = DEAD
	check(!map_storage.save_skips_wildlife(dead), "a carcass is kept")
	var/mob/living/simple_animal/deer/played = new(far)
	played.key = "player"
	check(!map_storage.save_skips_wildlife(played), "a player's animal is kept")
	check(!map_storage.save_skips_wildlife(new /mob/living/simple_animal/unique_boss(far)), "an animal no spawner repopulates is kept")
	check(map_storage.save_skips_wildlife(new /mob/living/simple_animal/sea/shoal(far)), "spawned sea life where nobody has been is left out")
	check(!map_storage.save_skips_wildlife(new /mob/living/simple_animal/sea/mystery(far)), "sea life outside the spawn table is kept")
	var/obj/crate = new(far)
	var/mob/living/simple_animal/deer/boxed = new(crate)
	check(!map_storage.save_skips_wildlife(boxed), "an animal inside something is kept")
	persistence_visited_since = 0
	check(!map_storage.save_skips_wildlife(deer), "nothing is left out before any player has been tracked")

/world/New()
	..()
	spawn(1)
		try
			run_probe()
		catch(var/exception/e)
			failures += "probe error: [e] on [e.file]:[e.line]"
		text2file(json_encode(list("failures" = failures.len, "messages" = failures)), "result.json")
		shutdown()

/proc/get_turf(atom/A)
	while(A && !isturf(A)) A = A.loc
	return A
