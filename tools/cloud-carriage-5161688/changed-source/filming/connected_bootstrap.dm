// SOURCE PREPARATION ONLY: no invocation admitted by this include.
#define INTRO_CONNECTED_RELEASED TRUE
var/client/intro_connected_client
var/datum/preferences/intro_connected_default_preferences
var/datum/chat/intro_connected_chat
var/list/intro_connected_phases = list()
var/mob/intro_connected_observer
var/intro_connected_disconnect_requested = FALSE

/proc/intro_connected_initialize(client/C)
	intro_check(INTRO_CONNECTED_RELEASED, "connected bootstrap held")
	intro_check(C && C == intro_observer_client && IsGuestKey(C.key) && C.address == "127.0.0.1", "same owned loopback guest")
	intro_check(!intro_connected_client && !C.prefs && !C.chat && config && movementMachine && GLOB.nanomanager && processes && islist(clients) && islist(directory), "fresh client dependencies")
	intro_check(!config.webhook_can_fire, "production webhook guard disabled")
	config.log_access = FALSE // production log_access guard; no access DB/file writes
	intro_check(!fexists("SQL/charprefs.txt") && !fexists("SQL/playerlogs.txt"), "isolated profile store absent")
	// Real constructor's null-client branch makes player_setup/default UI fields
	// without entering SQL read/save. Keep both persistence identity fields null.
	intro_connected_default_preferences = new /datum/preferences(null)
	intro_check(intro_connected_default_preferences.player_setup && intro_connected_default_preferences.player_setup.categories.len && !intro_connected_default_preferences.client && !intro_connected_default_preferences.client_ckey, "real unbound default preferences")
	intro_check(global.HUDdatums[intro_connected_default_preferences.UI_style], "actual configured HUD definition initialized")
	C.prefs = intro_connected_default_preferences
	intro_connected_chat = new /datum/chat(C)
	C.chat = intro_connected_chat
	clients |= C
	directory[C.ckey] = C
	intro_connected_client = C
	intro_check(!fexists("SQL/charprefs.txt") && !fexists("SQL/playerlogs.txt"), "bootstrap no persistent profile writes")

/proc/intro_connected_receipt(phase)
	intro_check(INTRO_CONNECTED_RELEASED && (phase in list("observer_before", "driver_login", "east_handler", "south_handler", "drive_start", "drive_end", "observer_after", "disconnect_requested")), "bounded connected phase")
	var/client/C = intro_connected_client
	intro_check(C && C == intro_observer_client && C.prefs == intro_connected_default_preferences && C.chat == intro_connected_chat && C.chat.client == C, "owned real client datums unchanged")
	intro_check(!C.prefs.client && !C.prefs.client_ckey && !config.webhook_can_fire && !fexists("SQL/charprefs.txt") && !fexists("SQL/playerlogs.txt"), "no database or webhook admission")
	intro_check(!(phase in intro_connected_phases), "phase emitted once")
	intro_connected_phases += phase
	text2file(json_encode(list("probe"="connected_driver_source_v1", "source"="5260b60f0efef2c0af70fae204b1180106ef50b3", "phase"=phase, "time"=world.time, "client"="\ref[C]", "body"="\ref[C.mob]", "eye"="\ref[C.eye]", "driver"="\ref[intro_driver]", "observer"=istype(C.mob,/mob/intro_observer), "driver_attached"=(C.mob==intro_driver && intro_driver.client==C), "eye_is_body"=(C.eye==C.mob), "perspective"=C.perspective, "mob_perspective"=(C.perspective==MOB_PERSPECTIVE), "body_glide"=C.mob.glide_size, "client_glide"=C.glide_size, "client_fps"=C.fps, "world_fps"=world.fps, "visual_owned"=C.human_subtile_visual_owned, "visual_actor"="\ref[C.human_subtile_visual_actor]", "carriage_owned"=!!intro_driver.carriage_glide_owner)), "intro-connected-phases.jsonl")

/proc/intro_connected_attach_and_steer()
	intro_check(INTRO_CONNECTED_RELEASED, "connected handlers held")
	var/client/C = intro_connected_client
	intro_check(C && C.mob && istype(C.mob,/mob/intro_observer) && intro_driver && !intro_driver.client && intro_carriage.driver==intro_driver && !intro_carriage.moving, "stationary native driver admission")
	intro_connected_observer=C.mob
	intro_connected_receipt("observer_before")
	C.mob=intro_driver // Actual human/living/mob Login: no replacement or direct eye fix.
	intro_check(C.mob==intro_driver && intro_driver.client==C && C.eye==intro_driver && C.perspective==MOB_PERSPECTIVE && intro_driver.hud_used && intro_driver.mind && intro_driver.mind.active, "real Login HUD mind camera")
	intro_connected_receipt("driver_login")
	// Fixture-only, exact original verb availability; never fake usr or directions.
	intro_check(C.verbs.len == 0, "steering admission starts with empty client verb table")
	var/list/steering_verbs = list(/client/verb/startmovingright, /client/verb/stopmovingright, /client/verb/startmovingdown, /client/verb/stopmovingdown)
	try
		for (var/V in steering_verbs)
			C.verbs += V
		intro_check(C.verbs.len == 4, "exact four original steering verbs admitted")
		for (var/V in steering_verbs)
			intro_check((V in C.verbs), "each admitted steering verb present")
		intro_connected_steering_state("before_east")
		intro_connected_check_steering_verbs(C, steering_verbs)
		C.startmovingright() // Actual production verb and Move; NOT keyboard delivery.
		intro_connected_check_steering_verbs(C, steering_verbs)
		intro_connected_steering_state("after_east_before_stop")
		intro_connected_check_steering_verbs(C, steering_verbs)
		C.stopmovingright()
		intro_connected_check_steering_verbs(C, steering_verbs)
		intro_connected_steering_state("after_east_stop")
		intro_check(intro_driver.dir==EAST && intro_carriage.dir==EAST, "production east handler")
		intro_connected_receipt("east_handler")
		intro_connected_check_steering_verbs(C, steering_verbs)
		C.startmovingdown()
		intro_connected_check_steering_verbs(C, steering_verbs)
		intro_connected_check_steering_verbs(C, steering_verbs)
		C.stopmovingdown()
		intro_connected_check_steering_verbs(C, steering_verbs)
		intro_check(intro_driver.dir==SOUTH && intro_carriage.dir==SOUTH, "production south handler")
		intro_connected_receipt("south_handler")
	catch (var/steering_error)
		intro_connected_remove_steering_verbs(C, steering_verbs)
		throw steering_error
	intro_connected_remove_steering_verbs(C, steering_verbs)

/proc/intro_connected_remove_steering_verbs(client/C, list/steering_verbs)
	if (!C)
		return // Deleted client has no usable verb table; outer admission still fails.
	for (var/V in steering_verbs)
		C.verbs -= V
	intro_check(C.verbs.len == 0, "temporary steering verbs removed; client table empty")

/proc/intro_connected_check_steering_verbs(client/C, list/steering_verbs)
	intro_check(C && C.verbs.len == 4, "only four steering verbs remain admitted")
	for (var/V in steering_verbs)
		intro_check((V in C.verbs), "original steering verb membership retained")

// Fixed owned-server request after recording, NOT keyboard or user-window close.
/proc/intro_connected_disconnect()
	intro_check(INTRO_CONNECTED_RELEASED && !intro_connected_disconnect_requested && fexists("intro-cadence-end.json") && fexists("intro-take.json"), "post-capture one-use disconnect")
	intro_connected_disconnect_requested=TRUE
	var/client/C=intro_connected_client
	intro_check(C && C.mob==intro_driver && intro_connected_observer, "owned driver before disconnect")
	C.mob=intro_connected_observer
	intro_check(C.mob==intro_connected_observer && !intro_driver.client && !C.human_subtile_visual_owned && !intro_driver.human_subtile_visual_owner, "actual Logout handoff release")
	intro_connected_receipt("observer_after")
	intro_connected_receipt("disconnect_requested")
	var/old_ckey=C.ckey
	var/old_client_ref="\ref[C]"
	intro_check(directory[old_ckey]==C && (C in clients), "actual client registry before Del")
	del(C) // Exact restored production client Del; source callback stays server-owned.
	spawn(0)
		intro_check(!intro_connected_client && !intro_observer_client && !(old_ckey in directory), "production Del removed client registry")
		intro_check(!intro_driver.client && !intro_driver.human_subtile_visual_owner && !fexists("SQL/charprefs.txt") && !fexists("SQL/playerlogs.txt"), "disconnected owner and database boundary")
		text2file(json_encode(list("probe"="connected_driver_disconnect_v1", "source"="5260b60f0efef2c0af70fae204b1180106ef50b3", "time"=world.time, "client"=old_client_ref, "method"="server_del_client", "client_deleted"=TRUE, "directory_key_absent"=TRUE, "visual_owner_absent"=TRUE, "profile_store_absent"=TRUE, "user_window_close"=FALSE)), "intro-connected-disconnect.json")

// Diagnostic only: observe actual ambient usr and current state without assigning either.
/proc/intro_connected_steering_state(phase)
	var/client/C = intro_connected_client
	var/mob/living/human/H = intro_driver
	var/obj/structure/vehicle/carriage/V = intro_carriage
	intro_check(C && H && V, "steering diagnostic actors exist")
	var/east_deadline = null
	if (H.next_change_dir)
		east_deadline = H.next_change_dir[num2text(EAST)]
	text2file(json_encode(list("probe"="connected_steering_diagnostic_v1", "source"="5260b60f0efef2c0af70fae204b1180106ef50b3", "phase"=phase, "time"=world.time, "usr"="\ref[usr]", "usr_is_driver"=(usr==H), "client"="\ref[C]", "client_mob"="\ref[C.mob]", "driver"="\ref[H]", "human_client"="\ref[H.client]", "driver_flag"=H.driver, "driver_vehicle"="\ref[H.driver_vehicle]", "carriage"="\ref[V]", "carriage_driver"="\ref[V.driver]", "human_dir"=H.dir, "carriage_dir"=V.dir, "human_loc"="\ref[H.loc]", "carriage_loc"="\ref[V.loc]", "human_x"=H.x, "human_y"=H.y, "carriage_x"=V.x, "carriage_y"=V.y, "buckled"="\ref[H.buckled]", "anchored"=H.anchored, "human_canmove"=H.canmove, "client_canmove"=C.canmove, "client_moving"=C.moving, "move_delay"=C.move_delay, "east_direction_deadline"=east_deadline, "movement_eastwest"=H.movement_eastwest)), "intro-checks.txt")
