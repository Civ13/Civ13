var/list/gamemode_cache = list()

/datum/configuration

	var/server_name = null				// server name (for world name / status)
	var/server_suffix = FALSE				// generate numeric suffix based on server port

	var/list/lobby_screens = list("1") // Which lobby screens are available

	var/lobby_countdown = 90
	var/round_end_countdown = 90

	var/log_ooc = FALSE						// log OOC channel
	var/log_access = FALSE					// log login/logout
	var/log_say = FALSE						// log client say
	var/log_admin = FALSE					// log admin actions
	var/log_debug = TRUE					// log debug output
	var/log_game = FALSE					// log game events
	var/log_vote = FALSE					// log voting
	var/log_whisper = FALSE					// log client whisper
	var/log_emote = FALSE					// log emotes
	var/log_attack = FALSE					// log attack messages
	var/log_adminchat = FALSE				// log admin chat messages
	var/log_adminwarn = FALSE				// log warnings admins get about bomb construction and such
	var/log_hrefs = FALSE					// logs all links clicked in-game. Could be used for debugging and tracking down exploits
	var/log_runtimes = FALSE				// logs world.log to a file
	var/log_world_output = FALSE			// log world.log << messages
	var/allow_vote_restart = TRUE 			// allow votes to restart
	var/ert_admin_call_only = FALSE
	var/allow_vote_mode = TRUE				// allow votes to change mode
	var/allow_admin_jump = TRUE			// allows admin jumping
	var/allow_admin_spawning = TRUE		// allows admin item spawning
	var/allow_admin_rev = TRUE				// allows admin revives
	var/vote_delay = 6000				// minimum time between voting sessions (deciseconds, 10 minute default)
	var/vote_period = 600				// length of voting period (deciseconds, default 1 minute)
	var/vote_autogamemode_timeleft = 45 //Length of time before round start when autogamemode vote is called (in seconds, default 100).
	var/vote_no_default = FALSE				// vote does not default to nochange/norestart (tbi)
	var/vote_no_dead = FALSE				// dead people can't vote (tbi)
//	var/enable_authentication = FALSE		// goon authentication
	var/del_new_on_log = TRUE				// del's new players if they log before they spawn in
	var/objectives_disabled = FALSE 			//if objectives are disabled or not
	var/protect_roles_from_antagonist = FALSE// If security and such can be traitor/cult/other
	var/popup_admin_pm = FALSE				//adminPMs to non-admins show in a pop-up 'reply' window when set to 1.
	var/Ticklag = 0.9
	var/Tickcomp = FALSE
//	var/socket_talk	= FALSE					// use socket_talk to communicate with other processes
	var/list/mode_names = list()
	var/list/modes = list()				// allowed modes
	var/list/votable_modes = list()		// votable modes
	var/list/probabilities = list()		// relative probability of each mode
	var/allow_random_events = FALSE			// enables random events mid-round when set to TRUE
	var/guest_jobban = TRUE
	var/useapprovedlist = FALSE
	var/use_job_whitelist =  FALSE
	var/show_mods = FALSE
	var/show_mentors = FALSE
	var/mods_can_tempban = FALSE
	var/mods_can_job_tempban = FALSE
	var/disable_fov = FALSE
	var/mod_tempban_max = 1440
	var/mod_job_tempban_max = 1440
	var/ToRban = FALSE
	var/automute_on = FALSE					//enables automuting/spam prevention

	var/tts_on = TRUE
	var/guests_allowed = TRUE
	var/debugparanoid = FALSE

	var/ssd_invisibility_timer = 10

	var/masterdir = "/home/1713"

	var/serverurl
	var/server
	var/banappeals
	var/wikiurl
	var/websiteurl
	var/donationurl
	var/rulesurl
	var/discordurl
	var/githuburl

	//game_options.txt configs

	var/health_threshold_softcrit = FALSE
	var/health_threshold_crit = -60
	var/health_threshold_dead = -80

	var/organ_health_multiplier = 0.33
	var/organ_regeneration_multiplier = 0.7
	var/organs_decay
	var/default_brain_health = 200

	//Paincrit knocks someone down once they hit 60 shock_stage, so by default make it so that close to 100 additional damage needs to be dealt,
	//so that it's similar to HALLOSS. Lowered it a bit since hitting paincrit takes much longer to wear off than a halloss stun.
	var/organ_damage_spillover_multiplier = 0.5

	var/no_click_cooldown = FALSE

	var/simultaneous_pm_warning_timeout = 100

	var/use_recursive_explosions //Defines whether the server uses recursive or circular explosions.

	var/ghost_interaction = FALSE

	var/enter_allowed = TRUE

	var/abandon_allowed = TRUE
	var/ooc_allowed = TRUE
	var/looc_allowed = TRUE
	var/dooc_allowed = TRUE
	var/dsay_allowed = TRUE

	var/list/language_prefixes = list(",","#","-")//Default language prefixes

	var/ghosts_can_possess_animals = FALSE

	var/no_respawn_delays = FALSE
	var/allowedgamemodes = "ALL"

	// hub stuff

	var/hub = FALSE
	var/testing_port = -1
	var/hubtesting_port = -2
	var/open_hub_discord_in_new_window = TRUE
	var/hub_body = ""
	var/hub_banner_url = "https://i.imgur.com/napac0L.png"

	// dumb memes
	var/allow_dabbing = FALSE

	// seasons and weather
	var/list/allowed_seasons = list(1)

	var/list/slog = list()
	var/list/wlog = list()

	// testing
	var/use_hunger = TRUE
	var/use_thirst = TRUE
	var/allow_selfheal = FALSE

	// python
	var/scripts_directory = null

	var/daynight_on = TRUE
	var/seasons_on = TRUE
	var/skip_persistence_saving = FALSE
/datum/configuration/proc/load(filename, type = "config") //the type can also be game_options, in which case it uses a different switch. not making it separate to not copypaste code - Urist

	var/list/Lines = file2list(filename)

	for (var/t in Lines)
		if (!t)	continue

		t = trim(t)
		if (length(t) == 0)
			continue
		else if (copytext(t, 1, 2) == "#")
			continue

		var/pos = findtext(t, " ")
		var/name = null
		var/value = null

		if (pos)
			name = lowertext(copytext(t, 1, pos))
			value = copytext(t, pos + 1)
		else
			name = lowertext(t)

		if (!name)
			continue

		if (type == "config")
			switch (name)

				if ("master_directory")
					masterdir = value

				if ("allowed_gamemodes")
					allowedgamemodes = value

				if ("no_respawn_delays")
					no_respawn_delays = text2num(value)

				if ("tts_on")
					tts_on = text2num(value)

				if ("scripts_directory")
					if (!list("null", "Null", "NULL", "nil", "Nil", "NILL").Find(value))
						config.scripts_directory = value
					else
						config.scripts_directory = null
				// allows the global_config to override us with YES/NO
				if ("hub")
					if (!value || !list("yes", "Yes", "YES", "no", "No", "NO").Find(value))
						config.hub = TRUE
					else
						switch (lowertext(value))
							if ("yes")
								config.hub = TRUE
							if ("no")
								config.hub = FALSE
				if ("testing_port")
					config.testing_port = text2num(value)
				if ("hubtesting_port")
					config.hubtesting_port = text2num(value)
				if ("open_hub_discord_in_new_window")
					config.open_hub_discord_in_new_window = text2num(value)
				if ("hub_body")
					config.hub_body = value
				if ("hub_banner_url")
					config.hub_banner_url = value

				if ("use_recursive_explosions")
					use_recursive_explosions = TRUE

				if ("log_ooc")
					config.log_ooc = TRUE

				if ("log_access")
					config.log_access = TRUE

				if ("log_say")
					config.log_say = TRUE

				if ("debug_paranoid")
					config.debugparanoid = TRUE

				if ("log_admin")
					config.log_admin = TRUE

				if ("log_debug")
					config.log_debug = text2num(value)

				if ("log_game")
					config.log_game = TRUE

				if ("log_vote")
					config.log_vote = TRUE

				if ("log_whisper")
					config.log_whisper = TRUE

				if ("log_attack")
					config.log_attack = TRUE

				if ("log_emote")
					config.log_emote = TRUE

				if ("log_adminchat")
					config.log_adminchat = TRUE

				if ("log_adminwarn")
					config.log_adminwarn = TRUE

				if ("log_world_output")
					config.log_world_output = TRUE

				if ("log_hrefs")
					config.log_hrefs = TRUE

				if ("log_runtimes")
					config.log_runtimes = TRUE


				if ("no_click_cooldown")
					config.no_click_cooldown = TRUE

				if ("allow_vote_restart")
					config.allow_vote_restart = TRUE

				if ("allow_vote_mode")
					config.allow_vote_mode = TRUE

				if ("allow_admin_jump")
					config.allow_admin_jump = TRUE

				if ("allow_admin_rev")
					config.allow_admin_rev = TRUE

				if ("allow_admin_spawning")
					config.allow_admin_spawning = TRUE

				if ("no_dead_vote")
					config.vote_no_dead = TRUE

				if ("default_no_vote")
					config.vote_no_default = TRUE

				if ("vote_delay")
					config.vote_delay = text2num(value)

				if ("vote_period")
					config.vote_period = text2num(value)

				if ("vote_autogamemode_timeleft")
					config.vote_autogamemode_timeleft = text2num(value)

				if ("ert_admin_only")
					config.ert_admin_call_only = TRUE

				if ("server_name")
					config.server_name = value

				if ("serversuffix")
					config.server_suffix = TRUE

				if ("serverurl")
					config.serverurl = value

				if ("server")
					config.server = value

				if ("banappeals")
					config.banappeals = value

				if ("wikiurl")
					config.wikiurl = value

				if ("websiteurl")
					config.websiteurl = value

				if ("donationurl")
					config.donationurl = value

				if ("rulesurl")
					config.rulesurl = value

				if ("discordurl")
					config.discordurl = value

				if ("githuburl")
					config.githuburl = value

				if ("ghosts_can_possess_animals")
					config.ghosts_can_possess_animals = value

				if ("guest_jobban")
					config.guest_jobban = TRUE

				if ("guest_ban")
					config.guests_allowed = FALSE

				if ("disable_ooc")
					config.ooc_allowed = FALSE
					config.looc_allowed = FALSE

				if ("disable_entry")
					config.enter_allowed = FALSE

				if ("disable_dead_ooc")
					config.dooc_allowed = FALSE

				if ("disable_dsay")
					config.dsay_allowed = FALSE

				if ("disable_respawn")
					config.abandon_allowed = FALSE

				if ("useapprovedlist")
					config.useapprovedlist = TRUE

				if ("use_job_whitelist")
					config.use_job_whitelist = TRUE

				if ("objectives_disabled")
					config.objectives_disabled = TRUE

				if ("protect_roles_from_antagonist")
					config.protect_roles_from_antagonist = TRUE

				if ("probability")
					var/prob_pos = findtext(value, " ")
					var/prob_name = null
					var/prob_value = null

					if (prob_pos)
						prob_name = lowertext(copytext(value, 1, prob_pos))
						prob_value = copytext(value, prob_pos + 1)
						if (prob_name in config.modes)
							config.probabilities[prob_name] = text2num(prob_value)
						else
							log_misc("Unknown game mode probability configuration definition: [prob_name].")
					else
						log_misc("Incorrect probability configuration definition: [prob_name]  [prob_value].")

				if ("show_mods")
					config.show_mods = TRUE

				if ("show_mentors")
					config.show_mentors = TRUE

				if ("mods_can_tempban")
					config.mods_can_tempban = TRUE

				if ("mods_can_job_tempban")
					config.mods_can_job_tempban = TRUE

				if ("mod_tempban_max")
					config.mod_tempban_max = text2num(value)

				if ("mod_job_tempban_max")
					config.mod_job_tempban_max = text2num(value)

				if ("popup_admin_pm")
					config.popup_admin_pm = TRUE

				if ("ticklag")
					Ticklag = text2num(value)

				if ("tickcomp")
					Tickcomp = TRUE

				if ("tor_ban")
					ToRban = TRUE

				if ("automute_on")
					automute_on = TRUE

				if ("ghost_interaction")
					config.ghost_interaction = TRUE

				if ("default_language_prefixes")
					var/list/values = splittext(value, " ")
					if (values.len > 0)
						language_prefixes = values

				if ("lobby_countdown")
					config.lobby_countdown = text2num(value)

				if ("round_end_countdown")
					config.round_end_countdown = text2num(value)

				if ("disable_fov")
					config.disable_fov = TRUE

				if ("redirect_all_players")
					redirect_all_players = value
				
				if ("skip_persistence_saving")
					config.skip_persistence_saving = TRUE

				else
					log_misc("Unknown setting in configuration: '[name]'")

	if (config.hub)
		world.visibility = TRUE
	else
		world.visibility = FALSE

/datum/configuration/proc/post_load()
	return
