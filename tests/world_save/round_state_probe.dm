// Actual serializer/header and extracted production setup, with effects counted.
var/fixture_round_equips = 0
var/fixture_round_hooks = 0
var/fixture_round_creates = 0
var/fixture_round_reset = 0
var/fixture_admission_restore = FALSE
var/datum/fixture_jobs/job_master = new
/datum/fixture_jobs/proc/ResetOccupations()
	fixture_round_reset++
/datum/controller/gameticker/var/admin_started = FALSE
/datum/controller/gameticker/proc/create_characters()
	fixture_round_creates++
/datum/controller/gameticker/proc/equip_characters()
	fixture_round_equips++
/proc/callHook(kind)
	fixture_round_hooks++
/proc/setup_autobalance()
	return
/obj/map_metadata/var/required_players = 1
/obj/map_metadata/proc/can_start()
	if(fixture_admission_restore) map_storage.round_restored = TRUE
	return TRUE

/proc/check_round_state()
	check(map_storage.Save_World(), "round probe export failed")
	var/header = file2text("map_saves/round.json")
	var/marker = file2text("map_saves/save_complete.txt")
	var/list/state = map_storage.read_round_state()
	check(state.len == 11, "new save omitted round header")
	var/savefile/F = new("map_saves/1.sav")
	var/generation = F["/generation"]
	F["/generation"] << "another-generation"
	check(!map_storage.validate_world_save(), "mismatched round generation accepted")
	F["/generation"] << generation
	check(map_storage.validate_world_save(), "round generation repair rejected")
	fdel("map_saves/round.json")
	check(!map_storage.validate_world_save(), "missing new round header accepted")
	text2file("{broken", "map_saves/round.json")
	check(!map_storage.validate_world_save(), "malformed round header accepted")
	fdel("map_saves/round.json")
	text2file(header, "map_saves/round.json")
	state["elapsed"] = -1
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")
	var/datum/controller/gameticker/T = new
	check(!T.loadmap() && !persistence_save_in_progress && !map_storage.round_restored, "malformed round load resumed or retained lock")
	fdel("map_saves/round.json")
	text2file(header, "map_saves/round.json")
	check(map_storage.validate_world_save(), "round header repair rejected")
	state = map_storage.read_round_state()
	state["state"] = GAME_STATE_PLAYING
	state["game_id"] = "durable-round-123"
	state["elapsed"] = 987654
	state["roundstart_time"] = 123456
	round_start_time = world.time + 777
	round_elapsed_offset = 0
	game_id = "different-process-round"
	last_roundduration2text = "stale"
	next_duration_update = world.time + 600
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")
	check(T.loadmap(), "round-state disk import failed")
	check(game_id == "durable-round-123" && roundstart_time == 123456, "round identity changed")
	check(round_start_time == world.time && round_elapsed_offset == 987654, "round clock reset across process")
	check(!last_roundduration2text && !next_duration_update && processes.ticker.playtime_elapsed == 987654, "round clock caches or playtime stale")
	check(T.current_state == GAME_STATE_PLAYING && map_storage.round_restored && !T.finished, "saved active phase lost")
	var/obj/item/test/paid = new(locate(2,2,1))
	paid.number = 918
	check(T.setup(), "resumed setup rejected")
	check(!fixture_round_equips && !fixture_round_hooks && !fixture_round_creates && !fixture_round_reset && paid.number == 918, "resumed round reran fresh setup")
	map_storage.round_restored = FALSE
	fixture_admission_restore = TRUE
	check(T.setup() && !fixture_round_equips && !fixture_round_reset, "admission yield reran fresh setup")
	fixture_admission_restore = FALSE
	map_storage.round_restored = FALSE
	var/list/owners = persistence_restored_bodies
	persistence_restored_bodies = list()
	T.current_state = GAME_STATE_PREGAME
	map_storage.restore_round_state(T, list())
	check(T.current_state == GAME_STATE_PREGAME && !map_storage.round_restored, "unowned legacy save resumed")
	var/mob/living/human/H = new(locate(2,2,1))
	H.persistence_restored = TRUE
	H.persistence_owner_ckey = "testaccount"
	persistence_restored_bodies["testaccount"] = list(H)
	map_storage.restore_round_state(T, list())
	check(T.current_state == GAME_STATE_PLAYING && map_storage.round_restored, "owned legacy save did not resume")
	check(game_id == "durable-round-123", "legacy fallback invented historical identity")
	persistence_restored_bodies = owners
	qdel(H)
	qdel(paid)
	map_storage.round_restored = FALSE
	round_start_time = 0
	round_elapsed_offset = 0
	roundstart_time = 0
	game_id = "fixture-round"
	fdel("map_saves/save_complete.txt")
	text2file("legacy timestamp", "map_saves/save_complete.txt")
	var/list/legacy = map_storage.read_round_state()
	check(!legacy.len, "legacy absence rejected")
	fdel("map_saves/save_complete.txt")
	text2file(marker, "map_saves/save_complete.txt")
