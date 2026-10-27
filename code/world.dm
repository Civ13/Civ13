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
	generate_gameid()

	makeDatumRefLists()
	load_configuration()

	initialize_chemical_reagents()
	initialize_chemical_reactions()

	qdel(src) //we're done

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
/world/New()
	initialize_persistence_zones()
	map_storage.record_compiled_dimensions()
	// Detect before any startup yield, ticker setup or admission can run.
	persistence_restart.detect_startup()

	if (map && istype(map,/obj/map_metadata/nomads/persistence_beta))
		loop_checks = FALSE
	config.post_load()

	if (config && config.server_name != null && config.server_suffix && world.port > 0)
		// dumb and hardcoded but I don't care~
		config.server_name += " #[(world.port % 1000) / 100]"

	world.SetConfig("APP/admin", ckey("Taislin"), "role=root")

	callHook("startup")
	//Emergency Fix
//	load_mods()
	//end-emergency fix

	lobby_titlecard = new /datum/titlecard()
	lobby_titlecard.set_pregame_html()
	
	update_status()

	..()

	// This is kinda important. Set up details of what the hell things are made of.
	populate_material_list()
	// Build the shared research-tree node registry (faction-agnostic).
	build_research_tree()
	processScheduler = new

	var/datum/persistence_area_startup/area_startup = new
	persistence_area_startup_token = area_startup
	spawn(1)
		try
			processScheduler.deferSetupFor (/process/ticker)
			processScheduler.setup()
			setup_everything(area_startup)
		catch(var/exception/E)
			area_startup.close()
			throw E
		area_startup.close()
//		master_controller.setup()
#ifdef UNIT_TEST
		initialize_unit_tests()
#endif

	spawn (2)

		// removed the 'sleep_offline' = TRUE here, it interferes with serverswap - kachnov
		#ifdef UNIT_TEST
			log_unit_test("Unit Tests Enabled.  This will destroy the world when testing is complete.")
			load_unit_test_changes()
		#endif

		world.log = file("data/logs/runtime/[time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]-runtime.txt")
		world.log << "STARTED RUNTIME LOGGING"

		attack_log = file("data/logs/attack/[time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]-attack.log")
		attack_log << "STARTED ATTACK LOGGING"

		//logs
		var/date_string = time2text(world.realtime, "YYYY/MM-Month/DD-Day")
		href_logfile = file("data/logs/[date_string]-hrefs.htm")
		diary = file("data/logs/[date_string].log")
		diary << "[log_end]\n[log_end]\nStarting up. (ID: [game_id]) [time2text(world.timeofday, "hh:mm.ss")][log_end]\n---------------------[log_end]"
		var/oocdiary = file("ooc.log")
		oocdiary << "> \[[time_stamp()]] New round [game_id] starting!"
		webhook_send_round_start(game_id)
		if (byond_version < RECOMMENDED_VERSION)
			diary << "Your server's byond version does not meet the recommended requirements for this server. Please update BYOND."

	spawn(3000)		//so we aren't adding to the round-start lag
		if (config.ToRban)
			ToRban_autoupdate()

#undef RECOMMENDED_VERSION

	return

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

/world/Topic(T, addr, master, key)
// Пока без тгс
//	TGS_TOPIC	//redirect to server tools if necessary

	var/static/list/bannedsourceaddrs = list()

	var/static/list/lasttimeaddr = list()
	var/static/list/topic_handlers = TopicHandlers()

	//LEAVE THIS COOLDOWN HANDLING IN PLACE, OR SO HELP ME I WILL MAKE YOU SUFFER
	if (bannedsourceaddrs[addr])
		return

	var/list/filtering_whitelist = config.topic_filtering_whitelist
	var/host = splittext_char(addr, ":")
	if(!(host[1] in filtering_whitelist)) // Supports the configured positional host list and associative keys.
		if(length_char(T) >= MAX_TOPIC_LEN)
			/*log_admin_private("*/
			diary << "TOPIC: [addr] banned from topic calls for a round for too long status message"
			bannedsourceaddrs[addr] = TOPIC_BANNED
			return

		if(lasttimeaddr[addr])
			var/lasttime = lasttimeaddr[addr]
			if(world.time < lasttime)
				/*log_admin_private("*/
				diary << "TOPIC: [addr] banned from topic calls for a round for too frequent messages"
				bannedsourceaddrs[addr] = TOPIC_BANNED
				return

		lasttimeaddr[addr] = world.time + 1200 //2 секунды

	var/list/input = params2list(T)
	// Lifecycle credentials never enter generic Topic logging or dispatch.
	if("nomads_lifecycle" in input)
		return nomads_lifecycle.handle(input, addr)
	var/datum/world_topic/handler
	for(var/I in topic_handlers)
		if(I in input)
			handler = topic_handlers[I]
			break

	if((!handler || initial(handler.log)) && config) //&& CONFIG_GET(flag/log_world_topic))
		diary << "TOPIC: \"[T]\", from:[addr], master:[master], key:[key]"

	if(!handler)
		return

	handler = new handler()
	return handler.TryRun(input)


/world/Reboot(var/reason, recovery_generation)
	if(recovery_generation)
		if(!persistence_restart.busy || persistence_restart.startup_hold || recovery_generation != persistence_restart.expected_generation || trim(file2text("map_saves/save_complete.txt")) != recovery_generation)
			return FALSE
#ifndef OPENDREAM
		// Parent reboot performs native shutdown/relogin. Do not stop the
		// scheduler here: a returned/rejected restart must leave it running.
		return ..(reason)
#else
		return FALSE
#endif
	if(persistence_restart.busy || persistence_restart.startup_hold)
		message_admins("Reboot blocked by save/restart recovery; inspect the recovery transaction first.")
		return FALSE
	#ifdef OPENDREAM
	if (!opendream_control_request("restart"))
		log_debug("OpenDream restart rejected: no available local supervisor.")
	return
	#endif

	/* Wait for serverswap to do its magic
	 * this was 50 but now it's 70 to let the entire JOJO meme play even when the server restarts quickly
	 * because sometimes it takes 1 second to restart other times 30 seconds :thinking: - Kachnov */
	spawn (150)
		if(persistence_restart.busy || persistence_restart.startup_hold) return

		var/sleeptime = 0
		to_chat(world, SPAN_DANGER("Rebooting!</span> <span class='notice'>Click here to rejoin (It may take a minute or two): <b>byond://[world.internet_address]:[port]</b>"))

		sleep(sleeptime) // I think this is needed so C << link() doesn't fail
		// sleep(0) yields too. A transaction can acquire ownership while the
		// ordinary reboot callback is asleep; check at the shutdown boundary.
		if(persistence_restart.busy || persistence_restart.startup_hold) return
		if (processScheduler) // just in case
			processScheduler.stop() // will be started again after the serverswap occurs
		..(reason)

#define COLOR_LIGHT_SEPIA "#D4C6B8"

/proc/log_world(text)
	SEND_TEXT(world.log, text)

/hook/startup/proc/loadMOTD()
	world.load_motd()
	return TRUE

/world/proc/load_motd()
	join_motd = file2text("config/motd.txt")

/proc/load_configuration()
	config = new /datum/configuration()
	config.load("config/config.txt", "config")

// Escape literal listing text and attributes without BYOND's URL auto-detection.
/proc/hub_status_text(value)
	var/text = "[value]"
	text = replacetext(text, "&", "&amp;")
	text = replacetext(text, "<", "&lt;")
	text = replacetext(text, ">", "&gt;")
	text = replacetext(text, "\"", "&quot;")
	text = replacetext(text, "'", "&#39;")
	return text

// Only absolute HTTP(S) links with a conservative ASCII URL alphabet belong here.
/proc/hub_status_link(url, label, open_new_window = FALSE)
	if (!istext(url))
		return ""
	var/authority_start
	if (copytext(url, 1, 9) == "https://")
		authority_start = 9
	else if (copytext(url, 1, 8) == "http://")
		authority_start = 8
	else
		return ""
	var/authority_end = length(url) + 1
	for (var/delimiter in list("/", "?", "#"))
		var/delimiter_position = findtext(url, delimiter, authority_start)
		if (delimiter_position && delimiter_position < authority_end)
			authority_end = delimiter_position
	if (authority_start == authority_end)
		return ""
	for (var/i = 1, i <= length(url), i++)
		var/character = lowertext(copytext(url, i, i + 1))
		if (!findtext("abcdefghijklmnopqrstuvwxyz0123456789-._~:/?#@!$&()*+,;=%", character))
			return ""
		if (i >= authority_start && i < authority_end)
			if (!findtext("abcdefghijklmnopqrstuvwxyz0123456789.-:", character))
				return ""
	var/target = ""
	if (open_new_window)
		target = " target=\"_blank\" rel=\"noopener noreferrer\""
	return "<a href=\"[hub_status_text(url)]\"[target]>[hub_status_text(label)]</a>"

/world/proc/update_status()

	if (world.port == config.testing_port)
		visibility = FALSE

	var/s = ""

	var/server_title = hub_status_link(config.discordurl, customserver_name(), config.open_hub_discord_in_new_window)
	if (!server_title)
		server_title = hub_status_text(customserver_name())
	s += "<center><b>[server_title]</b></center><br>"

	var/list/community_links = list()
	var/discord_link = hub_status_link(config.discordurl, "Discord", config.open_hub_discord_in_new_window)
	var/website_link = hub_status_link(config.websiteurl, "Website")
	if (discord_link)
		community_links += discord_link
	if (website_link)
		community_links += website_link
	if (community_links.len)
		s += "[jointext(community_links, " | ")]<br>"

	if (config.hub_banner_url)
		s += "<img src=\"https://i.imgur.com/napac0L.png\"><br>"
	if (map)
		s += "<b>Map:</b> [hub_status_text(map.title)] ([hub_status_text(roundduration2text())])<br>"

	// we can't execute code in config settings, so this is a workaround.
	config.hub_body = replacetext(config.hub_body, "ROUNDTIME", capitalize(lowertext(roundduration2text())))
	if (map)
		s += "<b>Gamemode:</b> [hub_status_text(map.gamemode)]"
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
	spawn while (1)
		var/F = file("serverdata.txt")
		if (fexists("serverdata.txt"))
			fdel(F)
		F << get_packaged_server_status_data()
		sleep (100)

var/global/nextsave = 0
var/global/persistence_reboot_scheduled = FALSE
/proc/start_persistence_loop()
	if (! config.skip_persistence_saving)
		spawn(300)
			if (map && map.persistence && !persistence_restart.startup_hold && !persistence_restart.busy)
				var/minsleft = 60-text2num(time2text(world.realtime,"mm"))
				var/secsleft = 60-text2num(time2text(world.realtime,"ss"))
				var/hr = (text2num(time2text(world.realtime,"hh")) & 0x1) //only odd hours
				if (minsleft <= 2 && hr)
					to_chat(world, "<font color='yellow' size=4><b>Attention - Round will be saved in approximately <b>[minsleft-1] minutes</b> and <b>[secsleft-1] seconds</b>. Game might lag up to a couple of minutes.</b></font>")
				if (nextsave <= world.realtime)
					nextsave = world.realtime + 216000
					spawn(0)
						ticker.savemap()
				// BYOND never returns freed memory to the OS, so a world that runs for days
				// eventually hits the process memory ceiling and crashes. Once a day, save the
				// map and reboot; setup_everything() restores the save on startup.
				// The world.time check keeps a freshly restarted server from rebooting again
				// within the same clock hour.
				if (config.persistence_reboot_hour >= 0 && !persistence_reboot_scheduled)
					if (text2num(time2text(world.realtime,"hh")) == config.persistence_reboot_hour && world.time > 36000)
						persistence_reboot_scheduled = TRUE
						spawn(0)
							persistence_maintenance_reboot()
			start_persistence_loop()

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
	spawn while (1)
		var/F = file("SQL/discord2ooc.txt")
		if (fexists(F))
			var/list/messages_read = splittext(file2text(F), "\n")
			for(var/msg in messages_read)
				var/list/tempmsg = splittext(msg, ":::")
				if (tempmsg.len == 2)
					var/dmsg =  "<IMG src='\ref[text_tag_icons]' class='text_tag' iconstate='discord' alt='Discord'><b><font color='#31A8DE'>[tempmsg[1]]: [tempmsg[2]]</font></b>"
					to_chat(world, dmsg)
					log_discord(dmsg)
					//to_chat(world, "<span class = 'ping'><small>["\["]DISCORD["\]"]</small></span> <span class='deadsay'><b>[tempmsg[1]]</b>:</span> [tempmsg[2]]")
			fdel(F)
			to_chat(F, "")

		var/G = file("SQL/discord2admin.txt")
		if (fexists(G))
			var/list/messages_read = splittext(file2text(G), "\n")
			for(var/msg in messages_read)
				var/list/tempmsg = splittext(msg, ":::")
				if (tempmsg.len == 2)

					for (var/client/C in admins)
						if (R_MENTOR & C.holder.rights || R_MOD & C.holder.rights)
							to_chat(C, "<span class='admin_channel'><IMG src='\ref[text_tag_icons]' class='text_tag' iconstate='a-discord' alt='ASAY-Discord'> <span class='name'>[tempmsg[1]]</span>(Discord): <span class='message'>[tempmsg[2]]</span></span>")
					log_discord_asay(msg)
			fdel(G)
			to_chat(G, "")

		var/H = file("SQL/discord2dm.txt")
		if (fexists(H))
			var/list/messages_read = splittext(file2text(H), "\n")
			for(var/msg in messages_read)
				var/list/tempmsg = splittext(msg, ":::")
				if (tempmsg.len == 3)
					var/temp_ckey = lowertext(tempmsg[2])
					temp_ckey = replacetext(temp_ckey," ", "")
					temp_ckey = replacetext(temp_ckey,"_", "")
					for(var/client/C in clients)
						if (C.ckey == temp_ckey)
							cmd_admin_pm_fromdiscord(C, tempmsg[3], tempmsg[1])
			fdel(H)
			to_chat(H, "")

		var/I = file("SQL/discord2ban.txt")
		if (fexists(I))
			var/list/messages_read = splittext(file2text(I), "\n")
			for(var/msg in messages_read)
				var/list/tempmsg = splittext(msg, ":::")
				if (tempmsg.len == 4)
					var/temp_ckey = lowertext(tempmsg[2])
					temp_ckey = replacetext(temp_ckey," ", "")
					temp_ckey = replacetext(temp_ckey,"_", "")
					//ckey to ban, duration, ban reason, who banned
					if (quickBan_discord(temp_ckey, tempmsg[3], tempmsg[4], tempmsg[1]) == "successful.")
						discord_admin_ban(tempmsg[1],temp_ckey,tempmsg[3],tempmsg[4])
			fdel(I)
			to_chat(I, "")
		var/J = file("SQL/discord2unban.txt")
		if (fexists(J))
			var/list/messages_read = splittext(file2text(J), "\n")
			for(var/msg in messages_read)
				var/list/tempmsg = splittext(msg, ":::")
				if (tempmsg.len == 2)
					var/temp_ckey = lowertext(tempmsg[2])
					temp_ckey = replacetext(temp_ckey," ", "")
					temp_ckey = replacetext(temp_ckey,"_", "")
					discord_admin_unban(tempmsg[1],temp_ckey)
			fdel(J)
			to_chat(J, "")
		sleep (100)

/proc/start_serverswap_loop()
	spawn while (1)

		try

			// make sure processScheduler is running when the world starts up
			if (!processScheduler.isRunning)
				processScheduler.start()
				message_admins("The process scheduler has been started. There are [processes.get_num_processes()] active processes.")
				log_admin("processScheduler.start() was called at start_serverswap_loop().")

			// some sanity for the processScheduler
			if (processScheduler.last_process != -1 && world.time - processScheduler.last_process >= processScheduler.scheduler_sleep_interval*300)
				processScheduler.start()


			// make sure movementMachine is running when the world starts up
			if (!movementMachine)
				movementMachine = new
				movementMachine.start()
				message_admins("The movement scheduler has been started.")
				log_admin("movementMachine.start() was called at start_serverswap_loop().")

			// some sanity for the movementMachine
			if (movementMachine.last_run != -1 && world.time - movementMachine.last_run >= movementMachine.interval*300)
				movementMachine.start()

		catch(var/exception/e)
			log_debug("Exception in serverswap loop: [e.name]/[e.desc]")

		sleep(10)

/world/proc/on_tickrate_change()
	SStimer.reset_buckets()

/world/proc/change_fps(new_value = 20)
	if(new_value <= 0)
		CRASH("change_fps() called with [new_value] new_value.")
	if(fps == new_value)
		return //No change required.

	fps = new_value
	on_tickrate_change()
