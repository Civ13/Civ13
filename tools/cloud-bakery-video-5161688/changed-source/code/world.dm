#define RESTART_COUNTER_PATH "data/round_counter.txt"
#define MAX_TOPIC_LEN 100
#define TOPIC_BANNED 1
/*
	The initialization of the game happens roughly like this:

	1. All global variables are initialized (including the global_init instance).
	2. The map is initialized, and map objects are created.
	3. world/New() runs, creating the process scheduler (and the old master controller) and spawning their setup.
	4. processScheduler/setup() runs, creating all the processes. game_controller/setup() runs, calling initialize() on all movable atoms in the world.
	5. The gameticker is created.

*/
var/global/datum/global_init/init = new ()
var/global/list/approved_list = list()
var/global/list/whitelist_list = list()
var/global/list/faction_list_blue = list()
var/global/list/faction_list_red = list()
var/global/list/faction_list_organizer = list()
var/global/disable_campaign_whitelist = FALSE
var/global/list/player_faction_list = list()
var/global/list/craftlist_lists = list("global" = list())
var/global/list/dictionary_list = list()

#define DIRECT_OUTPUT(A, B) A << B
#define SEND_TEXT(target, text) DIRECT_OUTPUT(target, text)
/*
	Pre-map initialization stuff should go here.
*/
/datum/global_init/New()
	intro_initialize()

/datum/global_init/Destroy()
	..()
	return TRUE

/var/game_id = null
/proc/generate_gameid()
	if (game_id != null)
		return
	game_id = ""

	var/list/c = list("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
	var/l = c.len

	var/t = world.timeofday
	for (var/_ = TRUE to 4)
		game_id = "[c[(t % l) + 1]][game_id]"
		t = round(t / l)
	game_id = "-[game_id]"
	t = round(world.realtime / (10 * 60 * 60 * 24))
	for (var/_ = TRUE to 3)
		game_id = "[c[(t % l) + 1]][game_id]"
		t = round(t / l)

var/world_is_open = TRUE

/world
	mob = /mob/new_player
	turf = /turf/floor/dirt
	area = /area/caribbean
	view = 7
	cache_lifespan = FALSE	//stops player uploaded stuff from being kept in the rsc past the current session

#define RECOMMENDED_VERSION 516
var/world_topic_spam_protect_ip = "0.0.0.0"
var/world_topic_spam_protect_time = world.timeofday

// todo: add aspect to this
/world/proc/replace_custom_hub_text(T)

	if (!ticker)
		return ""

	// numerical constants
	T = replacetext(T, "{CLIENTS}", clients.len) // # of clients
	T = replacetext(T, "{PLAYERS}", player_list.len) // # of mobs w/ clients
	T = replacetext(T, "{MOBS}", mob_list.len) // # of mobs
	T = replacetext(T, "{LIVING}", living_mob_list.len) // # of /mob/living
	T = replacetext(T, "{HUMAN}", human_mob_list) // # of humans
	T = replacetext(T, "{HUMAN_CLIENTS}", human_clients_mob_list) // # of humans w/clients
	T = replacetext(T, "{DEAD}", dead_mob_list.len) // # of dead mobs
	T = replacetext(T, "{OBSERVERS}", observer_mob_list.len) // # of observers w/clients
	T = replacetext(T, "{ROUNDTIME}", roundduration2text())
	// UPPERCASE constants
	T = replacetextEx(T, "{TIMEOFDAY}", uppertext(time_of_day))
	T = replacetextEx(T, "{SEASON}", uppertext(season))
	T = replacetextEx(T, "{MAP}", uppertext(map.title)) // name of the map
	// Capitalized constants - no change
	T = replacetextEx(T, "{Timeofday}", time_of_day)
	T = replacetextEx(T, "{Season}", season)
	T = replacetextEx(T, "{Map}", map.title) // name of the map
	// lowercase constants
	T = replacetextEx(T, "{timeofday}", lowertext(time_of_day))
	T = replacetextEx(T, "{season}", lowertext(season))
	T = replacetextEx(T, "{map}", lowertext(map.title)) // name of the map

	return T

#define COLOR_LIGHT_SEPIA "#D4C6B8"

/proc/log_world(text)
	SEND_TEXT(world.log, text)

/hook/startup/proc/loadMOTD()
	world.load_motd()
	return TRUE

/world/proc/load_motd()
	join_motd = file2text("config/motd.txt")

/proc/load_configuration()
	throw EXCEPTION("Carriage fixture: production startup disabled")

/world/proc/update_status()

	if (world.port == config.testing_port)
		visibility = FALSE

	var/s = ""

	if (config.open_hub_discord_in_new_window)
		s += "<center><a href=\"[config.discordurl]\" target=\"_blank\"><b>[customserver_name()]</b></a></center><br>"
	else
		s += "<center><a href=\"[config.discordurl]\"><b>[customserver_name()]</b></a></center><br>"

	if (config.hub_banner_url)
		s += "<img src=\"https://i.imgur.com/napac0L.png\"><br>"
	if (map)
		s += "<b>Map:</b> [map.title] ([roundduration2text()])<br>"

	// we can't execute code in config settings, so this is a workaround.
	config.hub_body = replacetext(config.hub_body, "ROUNDTIME", capitalize(lowertext(roundduration2text())))
	if (map)
		s += "<b>Gamemode:</b> [map.gamemode]"
	if (config.hub_body)
		s += config.hub_body

	status = s

/proc/get_packaged_server_status_data()
	. = ""
	. += "<b>Server Status</b>: Online"
	. += ";"
	. += "<b>Address</b>: byond://[world.internet_address]:[world.port]"
	. += ";"
	. += "<b>Map</b>: [map ? map.title : "???"]"
	. += ";"
	. += "<b>Gamemode</b>: [map ? map.gamemode : "???"]"
	. += ";"
	. += "<b>Players</b>: [clients.len]" // turns out the bot only considers itself a player sometimes? its weird. Maybe it was fixed, not sure - Kachnov
	if (config.useapprovedlist)
		. += ";"
		. += "<b>Approved only</b>: Enabled"
	. += ";"
	. += "realtime=[num2text(world.realtime, 20)]"
	. += ";"
	. += "world.address=[world.address]"
	. += ";"
	. += "round_timer=[roundduration2text()]"
	. += ";"
	if (map)
		. += "map=[map.title]"
		. += ";"
		. += "epoch=[map.age]"
		. += ";"
		. += "season=[get_season()]"
		. += ";"
	. += "ckey_list=[list2params(clients)]"
	. += ";"
	. += "allow_vote_restart=[config.allow_vote_restart?"1":"0"]"
	. += ";"


/proc/start_serverdata_loop()
	throw EXCEPTION("Carriage fixture: production startup disabled")

var/global/nextsave = 0
var/global/persistence_reboot_scheduled = FALSE
/proc/start_persistence_loop()
	throw EXCEPTION("Carriage fixture: production startup disabled")

/proc/persistence_maintenance_reboot()
	to_chat(world, "<font color='yellow' size=4><b>Attention - The server will save the world and restart for scheduled maintenance in 5 minutes.</b></font>")
	sleep(2400)
	to_chat(world, "<font color='yellow' size=4><b>Attention - Saving and restarting in 1 minute. The world will resume from this save after the restart.</b></font>")
	sleep(600)
	nextsave = world.realtime + 216000 // suppress the periodic save around the reboot
	if (ticker && ticker.savemap() && fexists("map_saves/save_complete.txt"))
		to_chat(world, "<font color='yellow' size=4><b>Save complete. Rebooting - you can reconnect in a minute or two.</b></font>")
		sleep(100)
		world.Reboot("Scheduled persistence maintenance reboot.")
	else
		// Deliberately NOT clearing persistence_reboot_scheduled: the loop
		// re-checks every 30s, so clearing it would re-announce "restarting in
		// 5 minutes" and re-attempt a full save for the rest of the hour. The
		// flag resets on the next successful reboot; until then admins decide.
		message_admins("Scheduled maintenance reboot aborted: the map save did not complete. The server keeps running, but memory will not be reclaimed until it is manually saved and rebooted.")

/proc/start_messaging_loop()
	throw EXCEPTION("Carriage fixture: production startup disabled")

/proc/start_serverswap_loop()
	throw EXCEPTION("Carriage fixture: production startup disabled")

/world/proc/on_tickrate_change()
	SStimer.reset_buckets()

/world/proc/change_fps(new_value = 20)
	if(new_value <= 0)
		CRASH("change_fps() called with [new_value] new_value.")
	if(fps == new_value)
		return //No change required.

	fps = new_value
	on_tickrate_change()
