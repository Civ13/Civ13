#define GAMETICKER_PREGAME_TIME 90

var/global/datum/controller/gameticker/ticker
var/global/datum/lobby_music_player/lobby_music_player = null

/datum/controller/gameticker
	var/const/restart_timeout = 300
	var/current_state = GAME_STATE_PREGAME
	var/admin_started = FALSE

//	var/hide_mode = FALSE
//	var/datum/game_mode/mode = null
	var/post_game = FALSE
	var/event_time = null
	var/event = FALSE

	var/login_music			// music played in pregame lobby

	var/list/datum/mind/minds = list()//The people in the game. Used for objective tracking.

	var/random_players = FALSE 	// if set to nonzero, ALL players who latejoin or declare-ready join will have random appearances/genders

	var/list/syndicate_coalition = list() // list of traitor-compatible factions
	var/list/factions = list()			  // list of all factions
	var/list/availablefactions = list()	  // list of factions with openings

	var/pregame_timeleft = FALSE

	var/delay_end = FALSE	//if set to nonzero, the round will not restart on it's own

//	var/triai = FALSE//Global holder for Triumvirate

	var/round_end_announced = FALSE // Spam Prevention. Announce round end only once.

	var/can_latejoin_ruforce = TRUE
	var/can_latejoin_geforce = TRUE

	var/players_can_join = TRUE

	var/tip = null
	var/maytip = TRUE

	var/finished = FALSE // set to TRUE by the map object

	var/restarting_is_very_bad = FALSE

	//station_explosion used to be a variable for every mob's hud. Which was a waste!
	//Now we have a general cinematic centrally held within the gameticker....far more efficient!
	var/obj/screen/cinematic = null

	//Plus it provides an easy way to make cinematics for other events. Just use this as a template :)

/datum/controller/gameticker/proc/pregame()

	spawn (0)

		current_state = GAME_STATE_PREGAME // just in case

		if (!lobby_music_player)
			lobby_music_player = new

		login_music = lobby_music_player.get_song()

		do
			pregame_timeleft = GAMETICKER_PREGAME_TIME
			maytip = TRUE

			to_chat(world, SPAN_NOTICE("<b>Welcome to the pre-game lobby!</b>"))
			to_chat(world, "The game will start in [pregame_timeleft] seconds.")

			while (current_state == GAME_STATE_PREGAME)
				for (var/i=0, i<10, i++)
					sleep(1)
					vote.process()
				if (round_progressing)
					pregame_timeleft--
				if (pregame_timeleft == config.vote_autogamemode_timeleft)
					if (!vote.time_remaining)
						vote.autogamemode()	//Quit calling this over and over and over and over.
						while (vote.time_remaining)
							for (var/i=0, i<10, i++)
								sleep(1)
								vote.process()
				if (pregame_timeleft == 20)
					if (tip)
						to_chat(world, SPAN_NOTICE("<b>Tip of the round:</b> [tip]"))
					else
						var/list/tips = file2list("config/tips.txt")
						if (tips.len)
							to_chat(world, SPAN_NOTICE("<b>Tip of the round:</b> [pick(tips)]"))
							qdel_list(tips)
					maytip = FALSE
				if (pregame_timeleft <= 0)
					current_state = GAME_STATE_SETTING_UP
					/* if we were force started, still show the tip */
					if (maytip)
						if (tip)
							to_chat(world, SPAN_NOTICE("<b>Tip of the round:</b> [tip]"))
						else
							var/list/tips = file2list("config/tips.txt")
							if (tips.len)
								to_chat(world, SPAN_NOTICE("<b>Tip of the round:</b> [pick(tips)]"))
								qdel_list(tips)
		while (!setup())


/datum/controller/gameticker/proc/setup()

	current_state = GAME_STATE_PLAYING

	job_master.ResetOccupations()

	if (!map || !map.can_start() && !admin_started)
		to_chat(world, "<b>Unable to start the game.</b> Not enough players, [map.required_players] active players needed. Reverting to the pre-game lobby.")
		current_state = GAME_STATE_PREGAME
		job_master.ResetOccupations()
		return FALSE

	create_characters() //Create player characters and transfer them
	collect_minds()
	equip_characters()
//	data_core.manifest()

	// trains setup before roundstart hooks called because SS train ladders rely on it

	TOD_loop()

	callHook("roundstart")

	// shuttle_controller.initialize_shuttles()

	spawn(0)//Forking here so we dont have to wait for this to finish

	//	to_chat(world, SPAN_NOTICE("<b>Enjoy the game!</b>")
		//Holiday Round-start stuff	~Carn

		// todo: make these hooks. Apparently they all fail on /hook/roundstart
		setup_autobalance()


	//close_jobs()//Makes certain jobs unselectable past roundstart. Unneeded atm.
	//start_events() //handles random events and space dust.
	//new random event system is handled from the MC.

	/* TODO: discord bot - Kachnov
	var/admins_number = 0
	for (var/client/C)
		if (C.holder)
			admins_number++

	if (admins_number == 0)
		send2adminirc("Round has started with no admins online.")*/

	return TRUE

/datum/controller/gameticker/proc/close_jobs()
	for (var/datum/job/job in job_master.occupations)
		if (job.title == "Captain")
			job.total_positions = FALSE

/datum/controller/gameticker/proc/create_characters()
	for (var/mob/new_player/player in player_list)
		if (player && player.ready && player.mind)
			if (!player.mind.assigned_role)
				continue
			else
				player.create_character()
				qdel(player)


/datum/controller/gameticker/proc/collect_minds()
	for (var/mob/living/player in player_list)
		if (player.mind)
			ticker.minds += player.mind

/datum/controller/gameticker/proc/equip_characters()
	for (var/mob/living/human/player in player_list)
		if (player && player.mind && player.mind.assigned_role)
		//	if (!player_is_antag(player.mind, only_offstation_roles = TRUE))
			job_master.EquipRank(player, player.mind.assigned_role, FALSE)
		//		equip_custom_items(player)

/datum/controller/gameticker/proc/process()
	if (current_state != GAME_STATE_PLAYING)
		return FALSE

	if (finished)
		current_state = GAME_STATE_FINISHED



		spawn(50)

			callHook("roundend")

			var/restart_after = restart_timeout

			if (processes.epochswap)
				if (processes.epochswap.finished_at == -1)
					restart_after = 1200 + (vote.time_remaining * 10)
				else
					var/n = world.time - processes.epochswap.finished_at
					if (n <= 900)
						restart_after = 1200 - n

			if (!delay_end)
				to_chat(world, SPAN_NOTICE("<big>Restarting in <b>90</b> seconds. Next map: <b>TBD</b></big>"))
				if (restart_after > restart_timeout)
					restarting_is_very_bad = TRUE
					spawn (restart_after - restart_timeout)
						restarting_is_very_bad = FALSE

			if (!delay_end)
				sleep(restart_after)
				if (!delay_end)
					world.Reboot()
				else
					to_chat(world, SPAN_NOTICE("<b>An admin has delayed the round end.</b>"))
			else
				to_chat(world, SPAN_NOTICE("<b>An admin has delayed the round end.</b>"))

	return TRUE

/datum/controller/gameticker/proc/station_explosion_cinematic(var/station_missed=0, var/override = null)
	if(cinematic)
		return	//already a cinematic in progress!

	//initialise our cinematic screen object
	cinematic = new(src)
	cinematic.icon = null // 'icons/effects/station_explosion.dmi'
	cinematic.icon_state = "start"
	cinematic.layer = 21
	cinematic.mouse_opacity = 0
	//cinematic.screen_loc = "1,0"
	cinematic.screen_loc = "CENTER-7,CENTER-7"

	var/obj/structure/bed/temp_buckle = new(src)
	//Incredibly hackish. It creates a bed within the gameticker (lol) to stop mobs running around
	if(station_missed)
		for(var/mob/living/M in living_mob_list)
			M.buckled = temp_buckle				//buckles the mob so it can't do anything
			if(M.client)
				M.client.screen += cinematic	//show every client the cinematic
	else	//nuke kills everyone on z-level of a ship to prevent "hurr-durr I survived"
		for(var/mob/living/M in living_mob_list)
			M.buckled = temp_buckle
			if(M.client)
				M.client.screen += cinematic

			if(M.z == 0)	//inside a crate or something
				var/turf/T = get_turf(M)
				if(T) // && !(T.z in vessel_z))				//we don't use M.death(0) because it calls a for(/mob) loop and
					M.health = 0
					M.stat = DEAD

	//Now animate the cinematic
	switch(station_missed)
		if(1)	//nuke was nearby but (mostly) missed
			if(map.gamemode && !override)
				override = map.gamemode
			switch(override)
				if("nuclear emergency") //Nuke wasn't on station when it blew up
					flick("start_nuke",cinematic)
					sleep(35)
//					world << sound('sound/effects/nuke/nukee.ogg')
					flick("explode",cinematic)
					cinematic.icon_state = "loss_nuke"
				else
					flick("start_nuke",cinematic)
					sleep(35)
//					world << sound('sound/effects/nuke/nukee.ogg')
					flick("explode",cinematic)
					cinematic.icon_state = "loss_nuke"

		if(2)	//nuke was nowhere nearby	//TODO: a really distant explosion animation
			sleep(50)
//			world << sound('sound/effects/nuke/nukee.ogg')

		else	//station was destroyed
			if(map.gamemode && !override)
				override = map.gamemode
			switch(override)
				if("nuclear emergency") //Nuke Ops successfully bombed the station
					flick("intro_nuke",cinematic)
					sleep(35)
					flick("station_intact",cinematic)
//					world << sound('sound/effects/explosionfar.ogg')
					cinematic.icon_state = "station_intact"
				if("AI malfunction") //Malf (screen,explosion,summary)
					flick("start_nuke",cinematic)
					sleep(35)
//					world << sound('sound/effects/nuke/nukee.ogg')
					flick("explode",cinematic)
					cinematic.icon_state = "loss_nuke"
				if("blob") //Station nuked (nuke,explosion,summary)
					flick("start_nuke",cinematic)
					sleep(35)
//					world << sound('sound/effects/nuke/nukee.ogg')
					flick("explode",cinematic)
					cinematic.icon_state = "loss_nuke"
				else //Station nuked (nuke,explosion,summary)
					flick("start_nuke",cinematic)
					sleep(35)
//					world << sound('sound/effects/nuke/nukee.ogg')
					flick("explode",cinematic)
					cinematic.icon_state = "loss_nuke"
			for(var/mob/living/M in living_mob_list)
				var/area/A = get_area(M)
				if(!A.nukesafe)
					M.death()
					// M.client.ChromieWinorLoose(M.client, -1)
	//No mercy
	//If its actually the end of the round, wait for it to end.
	//Otherwise if its a verb it will continue on afterwards.
	sleep(300)

	if(cinematic)
		qdel(cinematic)	//end the cinematic
	if(temp_buckle)
		qdel(temp_buckle)	//release everybody
	return
