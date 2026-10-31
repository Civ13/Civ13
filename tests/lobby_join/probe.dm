// Only control flow is production. Fixture collaborators cannot spawn players,
// write saves, connect clients, modify production state or contact services.
#define FALSE 0
#define TRUE 1
#define GAME_STATE_PREGAME 1
#define GAME_STATE_PLAYING 3
#define MAP_TRIBES "tribes"
#define MAP_THREE_TRIBES "three"
#define MAP_FOUR_KINGDOMS "four"
#define MAP_CAMPAIGN "campaign"
#define CAMPAIGN_MAP_LIST_MAPID_OR "new_campaign"
#define MAP_ANTARCTICA "antarctica"
#define MAP_LIGHTS_OUT "lights"
#define MAP_WIZARD_BOY "wizard"
#define MAP_ROTSTADT "rotstadt"
#define R_ADMIN 1

var/datum/mock_ticker/ticker = new
var/datum/mock_restart/persistence_restart = new
var/datum/mock_global/GLOB = new
var/datum/mock_jobs/job_master = new
var/obj/map_metadata/map
var/game_id = "round-one"
var/list/faction_list_blue = list()
var/list/faction_list_red = list()
var/list/faction_list_organizer = list()
var/list/player_faction_list = list()
var/disable_campaign_whitelist = FALSE
var/mob/new_player/test_actor
var/list/checks = list()
var/list/failures = list()
var/list/verb_metadata = list()

/datum/mock_ticker
	var/current_state = GAME_STATE_PLAYING
	var/players_can_join = TRUE
/datum/mock_restart
	var/startup_hold = FALSE
	var/busy = FALSE
/datum/mock_global
	var/enter_allowed = TRUE
/datum/mock_prefs
	var/traits = 0
/datum/mock_client
	var/mob/mob
	var/ckey = "fixture"
	var/admin = TRUE
	var/banned = FALSE
	var/job_banned = FALSE
	var/faction_banned = FALSE
	var/datum/mock_prefs/prefs = new
/datum/mock_client/proc/quickBan_isbanned(category)
	return category == "Playing" && banned
/obj/map_metadata
	var/ID = "ordinary"
	var/civilizations = FALSE
	var/nomads = FALSE
/datum/job
	var/title = "Scout"
/datum/job/proc/base_type_flag(unused)
	return "blue"
/datum/mock_jobs
	var/datum/job/scout = new
/datum/mock_jobs/proc/GetJob(title)
	return title == "Scout" ? scout : null
/proc/get_trait_selection_error(value)
	return value ? "Invalid fixture trait selection" : null
/proc/to_chat(atom/target, message)
	return
/proc/check_rights(right, ignored, mob/new_player/player)
	return right == R_ADMIN && player.test_client.admin

/mob/new_player
	invisibility = 101
	var/datum/mock_client/test_client
	var/lobby_join_active = FALSE
	var/lobby_join_attempts = 0
	var/lobby_join_phase = "not_entered"
	var/lobby_join_reason = "none"
	var/lobby_join_tick
	var/lobby_join_result
	var/datum/mock_client/lobby_join_client
	var/obj/map_metadata/lobby_join_map
	var/lobby_join_game_id
	var/lobby_join_native = FALSE
	var/lobby_join_selected
	var/lobby_join_validation = FALSE
	var/list/lobby_join_jobs
	var/spawning = FALSE
	var/delayed_spawning_as_job
	var/list/available_jobs = list("Scout")
	var/wait_action
	var/response = "Scout"
	var/dispatches = 0
	var/prompts = 0
	var/nested_result = -1
	var/crash = FALSE
	var/skip_refresh = FALSE

/mob/new_player/proc/jobBanned(title)
	return test_client.job_banned

// BYOND 516.1681 reports explicit set invisibility=0 as -1 and omission as 0.
// Calibrate both distinctly; neither metadata check proves client dispatch.
/mob/new_player/verb/VisibilityZero()
	set invisibility = 0
	return
/mob/new_player/verb/VisibilityOne()
	set invisibility = 1
	return
/mob/new_player/verb/VisibilityInherited()
	return
/mob/new_player/proc/factionBanned(faction)
	return test_client.faction_banned
/mob/new_player/proc/LateChoices()
	return show_latechoices_window(list(), available_jobs.Copy())
/mob/new_player/proc/LateChoicesRotstadt()
	return LateChoices()
/mob/new_player/proc/LateChoicesCampaign(factjob)
	return show_latechoices_window(list(), factjob == "blue" ? available_jobs.Copy() : list())
/mob/new_player/proc/LateChoicesCampaignNew(factjob)
	return LateChoicesCampaign(factjob)

// Admission collaborator, not a substitute test of production SelectedJob.
/mob/new_player/proc/process_lobby_join(list/request)
	if(crash)
		throw EXCEPTION("injected collaborator failure")
	if(!lobby_join_admission_current()) return FALSE
	if(request["SelectedJob"])
		if(!skip_refresh && !lobby_join_job_available(request["SelectedJob"])) return FALSE
		dispatches++
		return TRUE
	return LateChoices()

/proc/WWinput(mob/new_player/player, message, title, default_value, list/choices)
	player.prompts++
	var/action = player.wait_action
	player.wait_action = null
	switch(action)
		if("cancel") return null
		if("transfer") player.test_client.mob = null
		if("disconnect") player.test_client = null
		if("reconnect")
			player.test_client = new
			player.test_client.mob = player
		if("map") map = new
		if("round") game_id = "round-two"
		if("hold") persistence_restart.startup_hold = TRUE
		if("busy") persistence_restart.busy = TRUE
		if("not_playing") ticker.current_state = GAME_STATE_PREGAME
		if("closed") ticker.players_can_join = FALSE
		if("banned") player.test_client.banned = TRUE
		if("traits") player.test_client.prefs.traits = 1
		if("job") player.test_client.job_banned = TRUE
		if("faction") player.test_client.faction_banned = TRUE
		if("quota") player.available_jobs = list()
		if("deadmin") player.test_client.admin = FALSE
		if("whitelist") disable_campaign_whitelist = FALSE
		if("campaign_membership") faction_list_blue = list()
		if("duplicate") player.nested_result = player.handle_lobby_join(list("late_join" = 1), TRUE)
	return player.response

/proc/expect(name, condition)
	checks += name
	if(!condition) failures += name

/proc/fresh_player(player_type = /mob/new_player)
	map = new
	ticker.current_state = GAME_STATE_PLAYING
	ticker.players_can_join = TRUE
	persistence_restart.startup_hold = FALSE
	persistence_restart.busy = FALSE
	GLOB.enter_allowed = TRUE
	game_id = "round-one"
	disable_campaign_whitelist = FALSE
	faction_list_blue = list()
	faction_list_red = list()
	faction_list_organizer = list()
	player_faction_list = list()
	var/mob/new_player/player = new player_type
	player.test_client = new
	player.test_client.mob = player
	test_actor = player
	return player

/proc/arm(mob/new_player/player)
	player.lobby_join_active = TRUE
	player.lobby_join_client = player.test_client
	player.lobby_join_map = map
	player.lobby_join_game_id = game_id
	player.lobby_join_native = TRUE

/proc/run_checks()
	var/join_verb = /client/verb/Join
	var/unsafe_verb = /client/verb/UnsafeJoin
	var/zero_verb = /mob/new_player/verb/VisibilityZero
	var/one_verb = /mob/new_player/verb/VisibilityOne
	var/inherited_verb = /mob/new_player/verb/VisibilityInherited
	var/inherited_join = /client/verb/InheritedJoin
	var/mob/new_player/visibility_actor = new
	verb_metadata = list("join" = join_verb:invisibility, "join_isnull" = isnull(join_verb:invisibility), "join_isnum" = isnum(join_verb:invisibility), "unsafe" = unsafe_verb:invisibility, "zero" = zero_verb:invisibility, "one" = one_verb:invisibility, "inherited" = inherited_verb:invisibility, "inherited_join" = inherited_join:invisibility, "inherited_isnull" = isnull(inherited_verb:invisibility), "lobby_invisibility" = visibility_actor.invisibility)
	expect("engine_explicit_zero_metadata", isnum(zero_verb:invisibility) && zero_verb:invisibility == -1)
	expect("engine_nonzero_metadata", one_verb:invisibility == 1)
	expect("negative_control_inherited_verb_detected", inherited_verb:invisibility == 0 && inherited_join:invisibility == 0 && inherited_join:invisibility != join_verb:invisibility && visibility_actor.invisibility == 101)
	expect("native_join_verb_visible", join_verb:invisibility == -1 && join_verb:invisibility == zero_verb:invisibility)
	expect("negative_control_invisible_verb_detected", unsafe_verb:invisibility == 101)
	var/mob/new_player/player = fresh_player()
	expect("client_entry_not_entered", player.test_client.lobby_native_join_attempts == 0 && player.test_client.lobby_native_join_reason == "not_entered")
	player.test_client.invoke_native_join()
	expect("client_entry_forwards_own_lobby", player.test_client.lobby_native_join_attempts == 1 && player.test_client.lobby_native_join_reason == "forwarded" && player.dispatches == 1 && player.lobby_join_attempts == 1)
	player = fresh_player()
	player.test_client.mob = new /mob
	player.test_client.invoke_native_join()
	expect("client_entry_rejects_other_mob", player.test_client.lobby_native_join_reason == "not_current_lobby" && player.dispatches == 0 && player.lobby_join_attempts == 0)
	player = fresh_player()
	var/datum/mock_client/other_client = new
	other_client.mob = player
	other_client.invoke_native_join()
	expect("client_entry_rejects_other_client", other_client.lobby_native_join_reason == "not_current_lobby" && player.dispatches == 0 && player.lobby_join_attempts == 0)
	player = fresh_player()
	test_actor = null
	player.test_client.lobby_native_join_attempts = 65535
	player.test_client.invoke_native_join()
	expect("client_entry_no_actor_and_bounded", player.test_client.lobby_native_join_attempts == 65535 && player.test_client.lobby_native_join_reason == "not_current_lobby" && player.dispatches == 0)
	player = fresh_player()
	expect("trace_not_entered", player.lobby_join_attempts == 0 && player.lobby_join_phase == "not_entered" && isnull(player.lobby_join_tick))
	player.lobby_join_trace("native_entry", "none")
	expect("trace_entry_distinct", player.lobby_join_phase == "native_entry" && player.lobby_join_tick == world.time)
	player.lobby_join_trace("handler_denied", "owner_or_busy")
	expect("trace_denial_distinct", player.lobby_join_phase == "handler_denied" && player.lobby_join_reason == "owner_or_busy")
	player.lobby_join_trace(jointext(new/list(100), "x"), jointext(new/list(100), "y"))
	expect("trace_bounded", length(player.lobby_join_phase) == 64 && length(player.lobby_join_reason) == 64)
	expect("native_select_once", player.handle_lobby_join(list("late_join" = 1), TRUE) && player.dispatches == 1 && player.prompts == 1)
	expect("trace_result_survives_cleanup", player.lobby_join_result == TRUE && player.lobby_join_phase == "handler_entered")
	expect("normal_cleanup", !player.lobby_join_active && !player.lobby_join_client && !player.lobby_join_map && !player.lobby_join_jobs)
	for(var/action in list("cancel", "transfer", "disconnect", "reconnect", "map", "round", "hold", "busy", "not_playing", "closed", "banned", "traits", "job", "faction", "quota"))
		player = fresh_player()
		player.wait_action = action
		player.handle_lobby_join(list("late_join" = 1), TRUE)
		expect("reject_after_wait_[action]", player.dispatches == 0 && !player.lobby_join_active && !player.lobby_join_client && !player.lobby_join_selected)
	player = fresh_player()
	player.wait_action = "duplicate"
	player.handle_lobby_join(list("late_join" = 1), TRUE)
	expect("duplicate_locked", player.nested_result == FALSE && player.dispatches == 1 && player.prompts == 1)
	player = fresh_player()
	player.crash = TRUE
	var/caught = FALSE
	try
		player.handle_lobby_join(list("late_join" = 1), TRUE)
	catch
		caught = TRUE
	expect("exception_cleanup", caught && !player.lobby_join_active && !player.lobby_join_client && !player.lobby_join_map)
	player.crash = FALSE
	expect("exception_allows_retry", player.handle_lobby_join(list("late_join" = 1), TRUE) && player.dispatches == 1)
	player = fresh_player()
	player.delayed_spawning_as_job = new /datum
	player.handle_lobby_join(list("late_join" = 1), TRUE)
	expect("queued_role_not_blanket_blocked", player.dispatches == 1)
	player = fresh_player()
	arm(player)
	player.wait_action = "deadmin"
	player.response = "Yes"
	expect("revoked_admin_rejected", isnull(player.lobby_join_input("Respawn?", "Admin Respawn", "No", list("Yes", "No"))))
	player = fresh_player()
	arm(player)
	disable_campaign_whitelist = TRUE
	player.wait_action = "whitelist"
	player.response = "blue"
	expect("changed_whitelist_policy_rejected", isnull(player.lobby_join_input("Faction?", "Faction Choice", "blue", list("blue", "red"))))
	for(var/action in list("job", "faction", "quota", "round", "map", "hold", "cancel"))
		player = fresh_player()
		arm(player)
		player.wait_action = action
		player.response = "Yes"
		expect("confirmation_rejects_[action]", player.lobby_join_confirmation("Role?", "Scout") == "No")
	player = fresh_player()
	arm(player)
	map.ID = MAP_CAMPAIGN
	faction_list_blue = list("fixture")
	player.wait_action = "campaign_membership"
	player.response = "Yes"
	expect("confirmation_campaign_membership_refresh", player.lobby_join_confirmation("Role?", "Scout") == "No")
	player = fresh_player()
	map.civilizations = TRUE
	map.nomads = TRUE
	expect("nomads_mode", player.lobby_join_mode() == "nomads")
	map.ID = MAP_TRIBES
	expect("tribes_precede_nomads", player.lobby_join_mode() == "tribes")
	map.ID = MAP_CAMPAIGN
	expect("campaign_precedes_civilizations", player.lobby_join_mode() == "join_campaign")
	map.ID = "ordinary"
	map.nomads = FALSE
	expect("civilization_mode", player.lobby_join_mode() == "civilizations")
	map.civilizations = FALSE
	expect("ordinary_mode", player.lobby_join_mode() == "late_join")
	ticker.current_state = GAME_STATE_PREGAME
	expect("pregame_no_mode", isnull(player.lobby_join_mode()))
	player = fresh_player(/mob/new_player/unsafe_round)
	player.wait_action = "round"
	player.handle_lobby_join(list("late_join" = 1), TRUE)
	expect("negative_control_stale_round_detected", player.dispatches == 1)
	player = fresh_player(/mob/new_player/unsafe_role)
	arm(player)
	player.wait_action = "quota"
	player.response = "Yes"
	expect("negative_control_stale_role_detected", player.lobby_join_confirmation("Role?", "Scout") == "Yes")

/world
	maxx = 1
	maxy = 1
	maxz = 1
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/New()
	world.OpenPort("none")
	spawn(1)
		try
			run_checks()
		catch(var/exception/error)
			failures += "unexpected_exception:[error]"
		text2file(json_encode(list("pass" = !failures.len, "checks" = checks, "failures" = failures, "verb_metadata" = verb_metadata, "port" = world.port)), "result.json")
		del(world)
		return
