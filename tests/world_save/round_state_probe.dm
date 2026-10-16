// Actual serializer/header and extracted production setup, with effects counted.
var/fixture_round_equips = 0
var/fixture_round_hooks = 0
var/fixture_round_creates = 0
var/fixture_round_reset = 0
var/fixture_admission_restore = FALSE
var/fixture_round_setup_visits = 0
var/fixture_round_busy_spin = FALSE
var/fixture_round_delayed_load = FALSE
var/fixture_round_load_failure = FALSE
var/TOD_may_automatically_change = TRUE
var/fixture_tod_progress = 0
/proc/progress_time_of_day()
	fixture_tod_progress++
var/round_progressing = TRUE
var/datum/lobby_music_player/lobby_music_player
var/datum/fixture_vote/vote = new
var/datum/fixture_config/config = new
/datum/lobby_music_player/proc/get_song()
	return "fixture song"
/datum/fixture_vote
	var/time_remaining = 0
/datum/fixture_vote/proc/process()
	return
/datum/fixture_vote/proc/autogamemode()
	return
/datum/fixture_config
	var/vote_autogamemode_timeleft = -999
/proc/file2list(path)
	return list()
/proc/qdel_list(list/values)
	return
/proc/add_zero(value, leading)
	return "0[value]"
/proc/Floor(value)
	return round(value)
/datum/controller/gameticker
	var/login_music
	var/pregame_timeleft
	var/maytip
	var/tip
var/datum/fixture_jobs/job_master = new
/datum/fixture_jobs/var/list/occupations = list()
/mob/new_player/var/datum/fixture_job_mind/mind
/mob/new_player/var/datum/job/original_job
/mob/new_player/var/original_job_title
/mob/new_player/var/desired_job
/datum/fixture_job_mind
	var/assigned_role
	var/datum/job/assigned_job
/datum/job/civilian/fixture_disabled
	title = "N/A"
	min_positions = 9
	max_positions = 9
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

/proc/check_restored_nomad_admission(mob/new_player/fresh)
	var/datum/job/nomad = job_master.GetJob("Nomad")
	check(fresh.IsJobAvailable("Nomad"), "restored Nomad fresh-join gate unavailable")
	check(nomad.total_positions == 9999, "restored Nomad capacity differs from fresh setup")
	var/datum/job/disabled = job_master.GetJob("N/A")
	check(disabled.total_positions == 0, "disabled occupation gained capacity")
	fresh.mind = new
	check(job_master.AssignRole(fresh, "Nomad", TRUE), "restored fresh player role assignment failed")
	check(fresh.original_job == nomad && fresh.mind.assigned_job == nomad && fresh.mind.assigned_role == "Nomad", "fresh player role identity changed")
	var/current = nomad.current_positions
	job_master.initialize_position_limits()
	check(nomad.current_positions == current && fresh.IsJobAvailable("Nomad"), "capacity initialization reset occupancy")
	nomad.current_positions = nomad.total_positions
	check(!fresh.IsJobAvailable("Nomad"), "full occupation bypassed fresh-join gate")
	check(!job_master.AssignRole(fresh, "Nomad", TRUE), "full occupation accepted role assignment")
	nomad.current_positions = current
	check(!fresh.IsJobAvailable("unknown job"), "missing occupation bypassed fresh-join gate")

/proc/check_round_state()
	check(job_master.SetupOccupations(), "occupation construction failed")
	var/datum/job/nomad = job_master.GetJob("Nomad")
	check(nomad && nomad.min_positions == 9999 && nomad.max_positions == 9999, "production Nomad declaration changed")
	nomad.current_positions = 4
	var/mob/new_player/fresh = new
	check(!fresh.IsJobAvailable("Nomad"), "uninitialized Nomad control unexpectedly available")
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
	state["metadata"] = "wrong-metadata-digest"
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")
	check(!map_storage.validate_world_save(), "metadata digest mismatch accepted")
	fdel("map_saves/round.json")
	text2file(header, "map_saves/round.json")
	fixture_round_load_failure = TRUE
	game_id = "failed-import-session"
	check(!T.loadmap() && !map_storage.round_restored && game_id == "failed-import-session", "failed import restored round state")
	fixture_round_load_failure = FALSE
	state = map_storage.read_round_state()
	state["state"] = GAME_STATE_PLAYING
	state["game_id"] = "durable-round-123"
	state["elapsed"] = 123456
	state["roundstart_time"] = 123456
	prepare_music_fixture()
	qdel(ticker)
	ticker = T
	T.login_music = "fixture song"
	round_start_time = world.time + 777
	round_elapsed_offset = 0
	game_id = "different-process-round"
	last_roundduration2text = "stale"
	next_duration_update = world.time + 600
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")
	check(T.loadmap(), "round-state disk import failed")
	check(nomad.current_positions == 4, "round restoration reset existing occupancy")
	check_restored_nomad_admission(fresh)
	check(!music_test_client.sound_channels["1"] && music_test_client.sound_channels["778"] == "unrelated ambience", "round transition retained lobby music")
	check(game_id == "durable-round-123" && roundstart_time == 123456, "round identity changed")
	check(round_start_time == world.time && round_elapsed_offset == 123456, "round clock reset across process")
	check(!last_roundduration2text && !next_duration_update && processes.ticker.playtime_elapsed == 123456, "round clock caches or playtime stale")
	check(roundduration2text() == "03:25" && roundduration2text_days() == "3 hours, 25 mins", "restored round duration display reset")
	check(T.current_state == GAME_STATE_PLAYING && map_storage.round_restored && !T.finished, "saved active phase lost")
	for(var/phase in list(GAME_STATE_PREGAME, GAME_STATE_FINISHED))
		var/list/phase_state = state.Copy()
		phase_state["state"] = phase
		if(phase == GAME_STATE_PREGAME)
			phase_state["elapsed"] = 0
			phase_state["roundstart_time"] = 0
			nomad.total_positions = 17
		map_storage.restore_round_state(T, phase_state)
		if(phase == GAME_STATE_PREGAME) check(nomad.total_positions == 17, "pregame restore initialized active job capacity")
		check(T.current_state == phase && T.finished == (phase == GAME_STATE_FINISHED), "saved nonplaying phase lost")
		if(phase == GAME_STATE_PREGAME) check(!map_storage.round_restored && roundduration2text() == "00:00", "pregame restore started round clock")
	map_storage.restore_round_state(T, state)
	var/obj/item/test/paid = new(locate(2,2,1))
	paid.number = 918
	check(T.setup(), "resumed setup rejected")
	check(!fixture_round_equips && !fixture_round_hooks && !fixture_round_creates && !fixture_round_reset && paid.number == 918, "resumed round reran fresh setup")
	map_storage.round_restored = FALSE
	fixture_admission_restore = TRUE
	check(T.setup() && !fixture_round_equips && !fixture_round_reset, "admission yield reran fresh setup")
	fixture_admission_restore = FALSE
	// Real production pregame do/while and setup run while an import is asleep.
	// A delayed callback must run after countdown expiration, without a spin.
	fixture_round_setup_visits = 0
	map_storage.round_restored = FALSE
	persistence_save_in_progress = TRUE
	T.pregame()
	spawn(15)
		fixture_round_delayed_load = TRUE
		map_storage.round_restored = TRUE
		T.current_state = GAME_STATE_PLAYING
		persistence_save_in_progress = FALSE
	sleep(25)
	check(fixture_round_delayed_load && !fixture_round_busy_spin, "pregame busy retry did not yield")
	check(T.current_state == GAME_STATE_PLAYING && !fixture_round_equips && !fixture_round_hooks && !fixture_round_creates, "pregame delayed import reran fresh setup")
	check(fixture_tod_progress == 1, "initial TOD worker did not progress")
	TOD_may_automatically_change = TRUE
	TOD_loop()
	sleep(1)
	check(fixture_tod_progress == 1, "round restoration duplicated TOD loop")
	map_storage.round_restored = FALSE
	var/list/owners = persistence_restored_bodies
	persistence_restored_bodies = list()
	T.current_state = GAME_STATE_PREGAME
	job_master.SetupOccupations()
	map_storage.restore_round_state(T, list())
	check(T.current_state == GAME_STATE_PREGAME && !map_storage.round_restored, "unowned legacy save resumed")
	check(!fresh.IsJobAvailable("Nomad"), "unowned legacy initialized job capacity")
	var/mob/living/human/H = new(locate(2,2,1))
	H.persistence_restored = TRUE
	H.persistence_owner_ckey = "testaccount"
	persistence_restored_bodies["testaccount"] = list(H)
	map_storage.restore_round_state(T, list())
	check(T.current_state == GAME_STATE_PLAYING && map_storage.round_restored, "owned legacy save did not resume")
	check_restored_nomad_admission(fresh)
	check(game_id == "durable-round-123", "legacy fallback invented historical identity")
	check_fresh_round_music(T)
	persistence_restored_bodies = owners
	qdel(H)
	qdel(fresh)
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
