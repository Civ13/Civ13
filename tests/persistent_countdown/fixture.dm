// Standalone 4x4 world. Only external dependencies/effects are replaced.
#define TRUE 1
#define FALSE 0
#define GAME_STATE_PREGAME 1
#define GAME_STATE_SETTING_UP 2
#define GAME_STATE_PLAYING 3
#define SPAN_NOTICE(x) x

/world
	maxx = 4
	maxy = 4
	maxz = 1
	fps = 10
	visibility = 0

/world/OpenPort(port)
	return ..("none")
/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return list("reason" = "offline fixture")

var/fixture_armed = 0
var/fixture_setting_up = 0
var/fixture_setup_entries = 0
var/fixture_announcements = 0
var/fixture_effects = 0
var/fixture_admissions = 0
var/fixture_vote_callbacks = 0
var/fixture_case = ""
var/list/fixture_failures = list()
var/round_progressing = TRUE
var/persistence_save_in_progress = FALSE
var/persistence_player_restore_ready = FALSE
var/persistence_load_recovery_required = FALSE
var/dimension_recovery_required = FALSE
var/dimension_budget_hold = FALSE
var/datum/fixture_operation/persistence_active_operation
var/datum/fixture_lifecycle/nomads_lifecycle = new
var/datum/controller/gameticker/ticker
var/obj/map_metadata/map
var/datum/fixture_storage/map_storage = new
var/datum/fixture_restart/persistence_restart = new
var/datum/fixture_vote/vote = new
var/datum/fixture_config/config = new
var/datum/lobby_music_player/lobby_music_player
var/datum/fixture_jobs/job_master = new

/datum/controller/gameticker
	var/current_state = GAME_STATE_PREGAME
	var/admin_started = FALSE
	var/pregame_timeleft = FALSE
	var/pregame_autostart_cancelled = FALSE
	var/maytip = TRUE
	var/tip
	var/login_music
/datum/fixture_storage
	var/round_restored = FALSE
/datum/fixture_operation
	var/restoring_players = FALSE
	proc/current(owner, kind)
		return FALSE
/datum/fixture_lifecycle
	var/busy = FALSE
	var/expected_persistence
/proc/player_restoration_blocked()
	return FALSE
/datum/fixture_restart
	var/startup_hold = FALSE
/datum/fixture_config
	var/vote_autogamemode_timeleft = 2
	var/allow_vote_restart = TRUE
/datum/fixture_vote
	var/time_remaining = 0
	proc/process()
		if (fixture_case == "vote" && time_remaining)
			fixture_vote_callbacks++
			// A callback changes policy while the production vote wait is asleep.
			map.persistence = TRUE
			ticker.pregame_timeleft = 0
			time_remaining = 0
	proc/autogamemode()
		time_remaining = 1
/datum/lobby_music_player/proc/get_song()
	return "fixture"
/datum/fixture_jobs/proc/ResetOccupations()
	fixture_effects++
/obj/map_metadata
	var/persistence = FALSE
	var/required_players = 1
	var/research_active = FALSE
	var/autoresearch = TRUE
	var/autoresearch_mult = 0
	var/default_research = 19
	var/gamemode = ""
	proc/uses_durable_metadata()
		return TRUE
	proc/apply_persistence_age_floor()
		return
	proc/autoresearch_proc()
		return
	proc/can_start()
		fixture_admissions++
		if (fixture_case == "admission")
			sleep(3)
			map.persistence = TRUE
		return TRUE
/datum/admins
/proc/to_chat(target, message)
	if (findtext("[message]", "The game will start in")) fixture_announcements++
/proc/WWalert(a, b, c)
	return
/proc/log_admin(a)
	return
/proc/message_admins(a, b)
	return
/proc/file2list(path)
	return list()
/proc/qdel_list(list/L)
	return
/proc/stop_lobby_music()
	fixture_effects++
/datum/controller/gameticker/proc/create_characters()
	fixture_effects++
/datum/controller/gameticker/proc/collect_minds()
	fixture_effects++
/datum/controller/gameticker/proc/equip_characters()
	fixture_effects++
/proc/TOD_loop()
	fixture_effects++
/proc/callHook(kind)
	fixture_effects++
/proc/setup_autobalance()
	fixture_effects++

/proc/check_fixture(ok, label)
	if (!ok) fixture_failures += label

/world/New()
	OpenPort("none")
	OpenPort(0)
	text2file("ready\n", "ready.txt")
	fixture_case = world.params["case"]
	map = new
	ticker = new
	var/datum/admins/A = new
	check_fixture(world.port == 0, "port_closed")
	if (fixture_case == "boot")
		map.persistence = TRUE
		ticker.pregame()
		sleep(35)
		check_fixture(fixture_armed == 0, "boot_armed")
		check_fixture(fixture_announcements == 0, "boot_announcement")
		check_fixture(fixture_setting_up == 0 && fixture_setup_entries == 0 && fixture_effects == 0, "boot_setup")
		check_fixture(ticker.current_state == GAME_STATE_PREGAME && ticker.pregame_autostart_cancelled, "boot_state")
	else if (fixture_case == "latch")
		config.vote_autogamemode_timeleft = -1
		ticker.pregame()
		sleep(3)
		A.persistent()
		A.persistent()
		sleep(45)
		check_fixture(fixture_armed == 1 && fixture_announcements == 1, "latch_initial_timer")
		check_fixture(ticker.pregame_autostart_cancelled && !map.persistence && isnull(ticker.pregame_timeleft), "latch_cancelled")
		check_fixture(fixture_setting_up == 0 && fixture_setup_entries == 0 && fixture_effects == 0 && ticker.current_state == GAME_STATE_PREGAME, "latch_no_setup")
	else if (fixture_case == "vote")
		ticker.pregame()
		sleep(35)
		check_fixture(fixture_vote_callbacks == 1 && map.persistence, "vote_callback")
		check_fixture(fixture_setting_up == 0 && fixture_setup_entries == 0 && fixture_effects == 0, "vote_no_setup")
		check_fixture(ticker.pregame_autostart_cancelled && ticker.current_state == GAME_STATE_PREGAME, "vote_cancelled")
	else if (fixture_case == "admission")
		ticker.current_state = GAME_STATE_SETTING_UP
		var/accepted = ticker.setup()
		check_fixture(fixture_admissions == 1 && fixture_setup_entries == 1, "admission_entered")
		check_fixture(!accepted && ticker.current_state == GAME_STATE_PREGAME && ticker.pregame_autostart_cancelled && fixture_effects == 0, "admission_rejected")
	else if (fixture_case == "ordinary")
		config.vote_autogamemode_timeleft = -1
		ticker.pregame()
		sleep(40)
		check_fixture(fixture_armed == 1 && fixture_announcements == 1 && fixture_setting_up == 1 && fixture_setup_entries == 1, "ordinary_path")
		check_fixture(ticker.current_state == GAME_STATE_PLAYING && fixture_admissions == 1 && fixture_effects >= 6 && persistence_player_restore_ready, "ordinary_started")
	else if (fixture_case == "manual")
		map.persistence = TRUE
		ticker.pregame()
		sleep(3)
		var/started = A.startnow()
		sleep(20)
		check_fixture(started && ticker.admin_started && fixture_armed == 0 && fixture_announcements == 0, "manual_override")
		check_fixture(fixture_setting_up == 1 && fixture_setup_entries == 1 && ticker.current_state == GAME_STATE_PLAYING && fixture_admissions == 0 && persistence_player_restore_ready, "manual_started")
	else if (fixture_case == "guards")
		map.persistence = TRUE
		persistence_restart.startup_hold = TRUE
		map_storage.round_restored = TRUE
		check_fixture(!ticker.setup() && fixture_admissions == 0 && !ticker.pregame_autostart_cancelled, "startup_precedes_restore")
		persistence_restart.startup_hold = FALSE
		check_fixture(ticker.setup() && fixture_admissions == 0 && !ticker.pregame_autostart_cancelled, "restore_precedes_persistence")
		map_storage.round_restored = FALSE
		persistence_save_in_progress = TRUE
		check_fixture(!ticker.setup() && !ticker.pregame_autostart_cancelled && fixture_admissions == 0, "save_precedes_persistence")
		spawn(0)
			map_storage.round_restored = TRUE
		// The callback executes only when setup yields at the save guard.
		check_fixture(ticker.setup() && fixture_admissions == 0 && !ticker.pregame_autostart_cancelled, "restore_during_save")
		check_fixture(fixture_setup_entries == 4 && fixture_effects == 0, "guards_no_effects")
	else if (fixture_case == "hold")
		persistence_restart.startup_hold = TRUE
		ticker.pregame()
		sleep(3)
		check_fixture(fixture_armed == 0 && fixture_announcements == 0 && fixture_setup_entries == 0, "hold_blocks_boot")
		map_storage.round_restored = TRUE
		persistence_restart.startup_hold = FALSE
		sleep(12)
		check_fixture(fixture_armed == 0 && fixture_announcements == 0 && fixture_setup_entries == 0 && !ticker.pregame_autostart_cancelled, "hold_restore_precedence")
	else
		fixture_failures += "unknown_case"
	sleep(2)
	var/status = fixture_failures.len ? "FAIL" : "PASS"
	text2file("[status]:[fixture_case]:[jointext(fixture_failures, ",")] armed=[fixture_armed] announced=[fixture_announcements] setting=[fixture_setting_up] setup=[fixture_setup_entries] admission=[fixture_admissions] effects=[fixture_effects] vote=[fixture_vote_callbacks] port=[world.port]\n", "result.txt")
	del(world)
	return
