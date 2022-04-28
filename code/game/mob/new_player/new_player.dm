//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:33

/proc/job2mobtype(rank)
	for (var/datum/job/J in job_master.occupations)
		if (J.title == rank)
			return /mob/living/human

/mob/new_player
	var/ready = FALSE
	var/spawning = FALSE//Referenced when you want to delete the new_player later on in the code.
	var/totalPlayers = 0		 //Player counts for the Lobby tab
	var/totalPlayersReady = 0
	var/desired_job = null // job title. This is for join queues.
	var/datum/job/delayed_spawning_as_job = null // job title. Self explanatory.
	universal_speak = TRUE

	invisibility = 101

	density = FALSE
	stat = 2
	canmove = FALSE

	anchored = TRUE	//  don't get pushed around

	var/on_welcome_popup = FALSE

var/global/redirect_all_players = null
/mob/new_player/New()
	mob_list += src
	new_player_mob_list += src


	spawn (10)
		if (client)
			movementMachine_clients -= client
	if (!client || !client.holder || (client.holder.rank != "Host" && client.holder.rank != "Admiral"))
		if (redirect_all_players)
			for (var/C in clients)
				winset(C, null, "mainwindow.flash=1")
				C << link(redirect_all_players)
	spawn(20)
		if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
			var/htmlfile = "<!DOCTYPE html><HTML><HEAD><TITLE>Wiki Guide</TITLE><META http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"></HEAD> \
			<BODY><iframe src=\"https://civ13.github.io/civ13-wiki/The_Art_of_the_Deal\"  style=\"position: absolute; height: 97%; width: 97%; border: none\"></iframe></BODY></HTML>"
			src << browse(htmlfile,"window=wiki;size=820x650")
		if (map && map.ID == MAP_GULAG13)
			var/htmlfile = "<!DOCTYPE html><HTML><HEAD><TITLE>Wiki Guide</TITLE><META http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"></HEAD> \
			<BODY><iframe src=\"https://civ13.github.io/civ13-wiki/Gulag_13\"  style=\"position: absolute; height: 97%; width: 97%; border: none\"></iframe></BODY></HTML>"
			src << browse(htmlfile,"window=wiki;size=820x650")

/mob/new_player/Destroy()
	new_player_mob_list -= src
	..()

/mob/new_player/say(var/message)
	message = sanitize(message)

	if (!message)
		return

	log_say("New Player/[key] : [message]")

	if (client)
		if (client.prefs.muted & MUTE_DEADCHAT)
			src << "<span class = 'red'>You cannot talk in lobbychat (muted).</span>"
			return

		if (client.handle_spam_prevention(message,MUTE_DEADCHAT))
			return
		if (!client.holder)
			if (!config.ooc_allowed)
				src << "<span class='danger'>OOC is globally muted.</span>"
				return
			if (!config.dooc_allowed && (stat == DEAD))
				usr << "<span class='danger'>OOC for dead mobs has been turned off.</span>"
				return
			if (client.prefs.muted & MUTE_OOC)
				src << "<span class='danger'>You cannot use OOC (muted).</span>"
				return
			if (client.handle_spam_prevention(message,MUTE_OOC))
				return
			if (findtext(message, "byond://"))
				src << "<b>Advertising other servers is not allowed.</b>"
				log_admin("[key_name(client)] has attempted to advertise in OOC: [message]")
				message_admins("[key_name_admin(client)] has attempted to advertise in OOC: [message]")
				return
	for (var/new_player in new_player_mob_list)
		if (new_player:client) // sanity check
			new_player << "<span class = 'ping'><small>["\["]LOBBY["\]"]</small></span> <span class='deadsay'><b>[capitalize(key)]</b>:</span> [capitalize(message)]"

	return TRUE

/mob/new_player/verb/new_player_panel()
	set src = usr
	new_player_panel_proc()

/mob/new_player/proc/new_player_panel_proc()
	loc = null // so sometimes when people serverswap (tm) they get this window despite not being on the title screen - Kachnov
	// don't know if the above actually works

	var/output_stylized = {"
	<br>
	<html>
	<head>
	[common_browser_style]
	</head>
	<body><center>
	PLACEHOLDER
	</body></html>
	"}

	var/output = "<div align='center'><b>Welcome, [key]!</b>"
	output +="<hr>"
	output += "<p><a href='byond://?src=\ref[src];show_preferences=1'>Setup Character & Preferences</A></p>"

	if (!ticker || ticker.current_state <= GAME_STATE_PREGAME)
		output += "<p><a href='byond://?src=\ref[src];ready=0'>The game has not started yet.</a></p>"
	else
		if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS)
			output += "<p><a href='byond://?src=\ref[src];tribes=1'>Join a Tribe!</a></p>"
		else if (map.civilizations == TRUE && map.nomads == FALSE)
			output += "<p><a href='byond://?src=\ref[src];civilizations=1'>Join a Civilization!</a></p>"
		else if (map.nomads == TRUE)
			output += "<p><a href='byond://?src=\ref[src];nomads=1'>Join!</a></p>"
		else
			if(map.ID == MAP_CAMPAIGN)
				output += "<p><a href='byond://?src=\ref[src];join_campaign=1'>Join Game!</a></p>"
			else
				output += "<p><a href='byond://?src=\ref[src];late_join=1'>Join Game!</a></p>"

	var/height = 250
	if (map && map.ID != MAP_CAMPAIGN || client.holder)
		output += "<p><a href='byond://?src=\ref[src];observe=1'>Observe</A></p>"

	output += "</div>"

	src << browse(null, "window=playersetup;")
	src << browse(replacetext(output_stylized, "PLACEHOLDER", output), "window=playersetup;size=275x[height];can_close=0;can_resize=0")
	return

/mob/new_player/Stat()

	if (client.status_tabs && statpanel("Status") && ticker)
		stat("")
		stat(stat_header("Lobby"))
		stat("")

		// by counting observers, our playercount now looks more impressive - Kachnov
		if (ticker.current_state == GAME_STATE_PREGAME)
			stat("Time Until Joining Allowed:", "[ticker.pregame_timeleft][round_progressing ? "" : " (DELAYED)"]")

		stat("Players in lobby:", totalPlayers)
		stat("")
		stat("")

		totalPlayers = 0

		for (var/player in new_player_mob_list)
			stat(player:key)
			++totalPlayers

		stat("")

	..()


/mob/new_player/Topic(href, href_list[])
	if (!client)	return FALSE

	if (href_list["show_preferences"])
		client.prefs.ShowChoices(src)
		return TRUE

	if (href_list["ready"])
		if (!ticker || ticker.current_state <= GAME_STATE_PREGAME) // Make sure we don't ready up after the round has started
			ready = text2num(href_list["ready"])
		else
			ready = FALSE

	if (href_list["refresh"])
		src << browse(null, "window=playersetup") //closes the player setup window
		new_player_panel_proc()

	if (href_list["observe"])
		if (map.ID == MAP_CAMPAIGN && !client.holder)
			WWalert(src,"You cannot observe during this round.","Error")
			return TRUE

		if (client && client.quickBan_isbanned("Observe"))
			WWalert(src,"You're banned from observing.","Error")
			return TRUE

		if (WWinput(src, "Are you sure you wish to observe?", "Player Setup", "Yes", list("Yes","No")) == "Yes")
			if (!client)	return TRUE
			var/mob/observer/ghost/observer = new(150, 317, 1)

			spawning = TRUE
			src << sound(null, repeat = FALSE, wait = FALSE, volume = 85, channel = TRUE) // MAD JAMS cant last forever yo

			observer.started_as_observer = TRUE
			close_spawn_windows()
			var/turf/T = get_turf(locate(1,1,world.maxz))
			if (T)
				observer.loc = T
			else
				src << "<span class='danger'>Could not locate an observer spawn point. Use the Teleport verb to jump to another map point.</span>"
			observer.timeofdeath = world.time // Set the time of death so that the respawn timer works correctly.

			announce_ghost_joinleave(src)
			client.prefs.update_preview_icons()

			if (client.prefs.preview_icons.len)
				observer.icon = client.prefs.preview_icons[1]

			observer.alpha = 127

			if (client.prefs.be_random_name)
				client.prefs.real_name = random_name(client.prefs.gender)

			observer.real_name = capitalize(key)
			observer.name = observer.real_name
			observer.key = key
			observer.overlays += icon('icons/mob/uniform.dmi', "civuni[rand(1,3)]")
			observer.original_icon = observer.icon
			observer.original_overlays = list(icon('icons/mob/uniform.dmi', "civuni[rand(1,3)]"))
			qdel(src)

			return TRUE

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return TRUE

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client && client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/10)
			if (check_rights(R_ADMIN, FALSE, src))
				if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more seconds to respawn. Do you want to bypass this?", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes")
					var/msg = "[key_name(src)] bypassed a [wait] second wait to respawn."
					log_admin(msg)
					message_admins(msg)
					LateChoices()
					return TRUE
			WWalert(src, "Because you died in combat, you must wait [wait] more seconds to respawn.", "Error")
			return FALSE
		LateChoices()
		return TRUE

	if (href_list["tribes"])

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/600)
			if (check_rights(R_ADMIN, FALSE, src))
				if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more minutes to respawn. Do you want to bypass this? You can still join as a reinforcement.", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes")
					var/msg = "[key_name(src)] bypassed a [wait] minute wait to respawn."
					log_admin(msg)
					message_admins(msg)
					if (map && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES)
						LateChoices()
					else
						close_spawn_windows()
						AttemptLateSpawn(pick(map.availablefactions))
					return TRUE
			WWalert(src, "Because you died in combat, you must wait [wait] more minutes to respawn.", "Error")
			return FALSE

		if (map && (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS))
			close_spawn_windows()
			AttemptLateSpawn(pick(map.availablefactions))
		else
			return
		LateChoices()
		return TRUE

	if (href_list["civilizations"])

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/600)
			if (check_rights(R_ADMIN, FALSE, src))
				if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more minutes to respawn. Do you want to bypass this? You can still join as a reinforcement.", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes" && map.ID != MAP_PIONEERS_WASTELAND_2)
					var/msg = "[key_name(src)] bypassed a [wait] minute wait to respawn."
					log_admin(msg)
					message_admins(msg)
					close_spawn_windows()
					AttemptLateSpawn(pick(map.availablefactions))
					return TRUE
				else if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more minutes to respawn. Do you want to bypass this? You can still join as a reinforcement.", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes")
					var/msg = "[key_name(src)] bypassed a [wait] minute wait to respawn."
					log_admin(msg)
					message_admins(msg)
					LateChoices()
					return TRUE
			WWalert(src, "Because you died, you must wait [wait] more minutes to respawn.", "Error")
			return FALSE

		if (map && map.civilizations == TRUE && map.ID != MAP_PIONEERS_WASTELAND_2)
			close_spawn_windows()
			AttemptLateSpawn(pick(map.availablefactions))
		else if (map && map.ID == MAP_PIONEERS_WASTELAND_2)
			LateChoices()
		else
			return
		return TRUE


	if (href_list["nomads"])

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"<Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/600)
			if (check_rights(R_ADMIN, FALSE, src))
				if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more minutes to respawn. Do you want to bypass this? You can still join as a reinforcement.", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes")
					var/msg = "[key_name(src)] bypassed a [wait] minute wait to respawn."
					log_admin(msg)
					message_admins(msg)
					close_spawn_windows()
					AttemptLateSpawn("Nomad")
					return TRUE
				else
					return FALSE
			WWalert(src, "Because you died, you must wait [wait] more minutes to respawn.", "Error")
			return FALSE

		if (map && map.civilizations == TRUE)
			close_spawn_windows()
			AttemptLateSpawn("Nomad")
			return TRUE
		else
			return
		close_spawn_windows()
		AttemptLateSpawn("Nomad")
		return TRUE

	if (href_list["join_campaign"])

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return TRUE

		if (client.next_normal_respawn > world.realtime)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/600)
			WWalert(src, "Because you died in combat, you must wait [wait] more minutes to respawn.", "Error")
			return FALSE

		var/factjob = "null"
		for (var/i in faction_list_red)
			var/temp_ckey = lowertext(i)
			temp_ckey = replacetext(temp_ckey," ", "")
			temp_ckey = replacetext(temp_ckey,"_", "")
			if (temp_ckey == client.ckey)
				factjob = "RDF"
		if (factjob == "null")
			for (var/i in faction_list_blue)
				var/temp_ckey = lowertext(i)
				temp_ckey = replacetext(temp_ckey," ", "")
				temp_ckey = replacetext(temp_ckey,"_", "")
				if (temp_ckey == client.ckey)
					factjob = "BAF"

		if (factjob != "null")
			LateChoicesCampaign(factjob)
			//AttemptLateSpawn(factjob)
		else
			WWalert(src, "This round is part of an event. You need to be part of one of the two factions to participate. Check the discord for more information.")
			return
		return TRUE

	if (href_list["late_join"])

		if (check_trait_points(client.prefs.traits) > 0)
			WWalert(src,"Your traits are not balanced! You can't join until you balance them (sum has to be <= 0).","Error")
			return FALSE

		if (client && client.quickBan_isbanned("Playing"))
			WWalert(src,"You're banned from playing.","Error")
			return TRUE

		if (!isemptylist(approved_list) && config.useapprovedlist)
			var/found = FALSE
			for (var/i in approved_list)
				if (i == client.ckey)
					found = TRUE
			if (!found)
				if (config.discordurl)
					WWalert(usr,"The game is currently only accepting approved players. Visit the Discord to get approved: [config.discordurl]", "Error")
				else
					WWalert(usr,"The game is currently only accepting approved players. Visit the Discord to get approved.", "Error")
				return

		if (!ticker.players_can_join)
			WWalert(src,"You can't join the game yet.","Error")
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			WWalert(src,"The round is either not ready, or has already finished.","Error")
			return

		if (client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
			var/wait = ceil((client.next_normal_respawn-world.realtime)/600)
			if (check_rights(R_ADMIN, FALSE, src))
				if ((WWinput(src, "If you were a normal player, you would have to wait [wait] more minutes to respawn. Do you want to bypass this? You can still join as a reinforcement.", "Admin Respawn", "Yes", list("Yes", "No"))) == "Yes")
					var/msg = "[key_name(src)] bypassed a [wait] minute wait to respawn."
					log_admin(msg)
					message_admins(msg)
					LateChoices()
					return TRUE
			WWalert(src, "Because you died in combat, you must wait [wait] more minutes to respawn.", "Error")
			return FALSE
		LateChoices()
		return TRUE

	if (href_list["SelectedJob"])
		if (!findtext(href_list["SelectedJob"], "Private") && !findtext(href_list["SelectedJob"], "Machinegunner") && !findtext(href_list["SelectedJob"], "Des. Marksman") && map.ID == MAP_CAMPAIGN)
			if ((input(src, "This is a specialist role. You should have decided with your faction on which roles you should pick. If you haven't done so, its probably better if you join as a Private instead. Are you sure you want to join in as a [href_list["SelectedJob"]]?") in list("Yes", "No")) == "No")
				return
		if(findtext(href_list["SelectedJob"],"BAF"))
			var/obj/map_metadata/campaign/MC = map
			if(findtext(href_list["SelectedJob"],"Squad 1"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_blue["Squad 1"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_blue["Squad 1"]["Machinegunner"]--
				if (findtext(href_list["SelectedJob"],"Des. Marksman"))
					MC.squad_jobs_blue["Squad 1"]["Des. Marksman"]--

			else if(findtext(href_list["SelectedJob"],"Squad 2"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_blue["Squad 2"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_blue["Squad 2"]["Machinegunner"]--
				if (findtext(href_list["SelectedJob"],"Des. Marksman"))
					MC.squad_jobs_blue["Squad 2"]["Des. Marksman"]--

			else if(findtext(href_list["SelectedJob"],"Squad 3"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_blue["Squad 3"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_blue["Squad 3"]["Machinegunner"]--
				if (findtext(href_list["SelectedJob"],"Des. Marksman"))
					MC.squad_jobs_blue["Squad 3"]["Des. Marksman"]--

			else if(findtext(href_list["SelectedJob"],"BAF Medic"))
				MC.squad_jobs_blue["none"]["Medic"]--

			else if(findtext(href_list["SelectedJob"],"BAF Officer"))
				MC.squad_jobs_blue["none"]["Officer"]--
			else if(findtext(href_list["SelectedJob"],"BAF Commander"))
				MC.squad_jobs_blue["none"]["Commander"]--
			else if(findtext(href_list["SelectedJob"],"BAF Recon"))
				MC.squad_jobs_blue["Recon"]["Sniper"]--
			else if(findtext(href_list["SelectedJob"],"BAF Anti-Tank"))
				MC.squad_jobs_blue["AT"]["Anti-Tank"]--
			else if(findtext(href_list["SelectedJob"],"BAF Engineer"))
				MC.squad_jobs_blue["Engineer"]["Engineer"]--
			AttemptLateSpawn(href_list["SelectedJob"])
			return
		else if (findtext(href_list["SelectedJob"],"RDF"))
			var/obj/map_metadata/campaign/MC = map
			if(findtext(href_list["SelectedJob"],"Squad 1"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_red["Squad 1"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_red["Squad 1"]["Machinegunner"]--

			else if(findtext(href_list["SelectedJob"],"Squad 2"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_red["Squad 2"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_red["Squad 2"]["Machinegunner"]--

			else if(findtext(href_list["SelectedJob"],"Squad 3"))
				if (findtext(href_list["SelectedJob"],"Sniper"))
					MC.squad_jobs_red["Squad 3"]["Sniper"]--
				if (findtext(href_list["SelectedJob"],"Machinegunner"))
					MC.squad_jobs_red["Squad 3"]["Machinegunner"]--

			else if(findtext(href_list["SelectedJob"],"RDF Medic"))
				MC.squad_jobs_red["none"]["Medic"]--

			else if(findtext(href_list["SelectedJob"],"RDF Officer"))
				MC.squad_jobs_red["none"]["Officer"]--
			else if(findtext(href_list["SelectedJob"],"RDF Commander"))
				MC.squad_jobs_red["none"]["Commander"]--

			else if(findtext(href_list["SelectedJob"],"RDF Recon"))
				MC.squad_jobs_red["Recon"]["Sniper"]--
			else if(findtext(href_list["SelectedJob"],"RDF Anti-Tank"))
				MC.squad_jobs_red["AT"]["Anti-Tank"]--
			else if(findtext(href_list["SelectedJob"],"RDF Engineer"))
				MC.squad_jobs_red["Engineer"]["Engineer"]--
			AttemptLateSpawn(href_list["SelectedJob"])
			return
		if(href_list["SelectedJob"] == "Company Member")
			AttemptLateSpawn(href_list["SelectedJob"])
			return
		var/datum/job/actual_job = null

		for (var/datum/job/j in job_master.occupations)
			if (j.title == href_list["SelectedJob"])
				actual_job = j
				break

		if (!actual_job)
			return

		var/job_flag = actual_job.base_type_flag()

		if (!config.enter_allowed)
			WWalert(usr,"There is an administrative lock on entering the game!", "Error")
			return

		if (map && map.has_occupied_base(job_flag) && map.ID != MAP_CAPITOL_HILL && map.ID != MAP_CAMP && map.ID != MAP_HILL_203 && map.ID != MAP_CALOOCAN && map.ID != MAP_YELTSIN && map.ID != MAP_HOTEL)
			WWalert(usr,"The enemy is currently occupying your base! You can't be deployed right now.", "Error")
			return

//Sovafghan DRA spawnpoints
		if (map && map.ID == MAP_SOVAFGHAN)
			var/obj/map_metadata/sovafghan/MP = map
			var/randspawn = rand(1,4)
			switch (randspawn)
				if (1)
					if (MP.a1_control != "Mujahideen")
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap1"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA1"
					else
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA"
				if (2)
					if (MP.a2_control != "Mujahideen")
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap2"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA2"
					else
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA"
				if (3)
					if (MP.a3_control != "Mujahideen")
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap3"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA3"
					else
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA"
				if (4)
					if (MP.a4_control != "Mujahideen")
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap4"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA4"
					else
						if (actual_job && actual_job.title == "DRA Sergeant")
							actual_job.spawn_location = "JoinLateDRACap"
						if (actual_job && actual_job.title == "DRA Soldier")
							actual_job.spawn_location = "JoinLateDRA"

//prevent boss spawns if there are enemies in the building
		if (map && map.ID == MAP_CAPITOL_HILL)
			var/obj/map_metadata/capitol_hill/CP = map
			if (CP.gamemode == "Protect the VIP" && isemptylist(CP.HVT_list) && (actual_job && actual_job.title != "US HVT"))
				WWalert(usr,"Someone needs to spawn as the HVT first!", "Error")
				return
		if (map && map.ID == MAP_YELTSIN)
			var/obj/map_metadata/yeltsin/CP = map
			if (CP.gamemode == "Protect the VIP" && isemptylist(CP.HVT_list) && (actual_job && actual_job.title != "Soviet Supreme Chairman"))
				WWalert(usr,"Someone needs to spawn as the HVT first!", "Error")
				return
		if (map && map.ID == MAP_ALLEYWAY)
			if (actual_job && actual_job.title == "Yama Wakagashira")
				for(var/mob/living/human/HM in get_area_turfs(/area/caribbean/houses/nml_two))
					if (HM.original_job.is_ichi)
						WWalert(usr,"The enemy is currently occupying your base! You can't be deployed as an underboss right now.", "Error")
						return
			if (actual_job.title == "Ichi Wakagashira")
				for(var/mob/living/human/HM in get_area_turfs(/area/caribbean/houses/nml_one))
					if (HM.original_job.is_yama)
						WWalert(usr,"The enemy is currently occupying your base! You can't be deployed as an underboss right now.", "Error")
						return
		if (actual_job.whitelisted && !isemptylist(whitelist_list) && config.use_job_whitelist && clients.len > 12)
			var/found = FALSE
			for (var/i in whitelist_list)
				var/temp_ckey = lowertext(i)
				temp_ckey = replacetext(temp_ckey," ", "")
				temp_ckey = replacetext(temp_ckey,"_", "")
				if (temp_ckey == client.ckey)
					found = TRUE
			if (!found)
				WWalert(usr,"You need to be whitelisted to play this job. Apply in the Discord.","Error")
				return

		if (actual_job.is_officer)
			if ((input(src, "This is an officer position. You're expected to coordinate your team's actions instead of engaging in direct combat. Are you sure you want to join in as a [actual_job.title]?") in list("Yes", "No")) == "No")
				return

		if (actual_job.is_squad_leader)
			if ((input(src, "This is a squad leader position. You're expected to coordinate your squad actions and accomplish orders given by your superiors. If you die, your squad members won't be able to spawn on you anymore. Are you sure you want to join in as a [actual_job.title]?") in list("Yes", "No")) == "No")
				return

		if (actual_job.spawn_delay)

			if (delayed_spawning_as_job)
				delayed_spawning_as_job.total_positions += 1
				delayed_spawning_as_job = null

			job_master.spawn_with_delay(src, actual_job)
		else
			AttemptLateSpawn(href_list["SelectedJob"])

	if (!ready && href_list["preference"])
		if (client)
			client.prefs.process_link(src, href_list)
	else if (!href_list["late_join"])
		new_player_panel()

/mob/new_player/proc/IsJobAvailable(rank, var/list/restricted_choices = list())
	var/datum/job/job = job_master.GetJob(rank)
	if (!job)	return FALSE
	if (!job.is_position_available(restricted_choices)) return FALSE
//	if (!job.player_old_enough(client))	return FALSE
	return TRUE

/mob/new_player/proc/jobBanned(title)
	if (client && client.quickBan_isbanned("Job", title))
		return TRUE
	return FALSE

/mob/new_player/proc/factionBanned(faction)
	if (client && client.quickBan_isbanned("Faction", faction))
		return TRUE
	return FALSE

//if the player is "Penal banned", he is reduced to play as a member of a penal battalion
/mob/new_player/proc/penalBanned()
	if (client && client.quickBan_isbanned("Penal"))
		return TRUE
	return FALSE

/mob/new_player/proc/AttemptLateSpawn(rank, var/nomsg = FALSE)
	if (src != usr)
		return FALSE
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		if (!nomsg)
			WWalert(usr,"The round is either not ready, or has already finished.","Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"The round is either not ready, or has already finished.", "Error")
		return FALSE
	if (!config.enter_allowed)
		if (!nomsg)
			WWalert(usr,"There is an administrative lock on entering the game!", "Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"There is an administrative lock on entering the game!", "Error")
		return FALSE
	if (jobBanned(rank))
		if (!nomsg)
			WWalert(usr,"You're banned from this role!", "Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"You're banned from this role!", "Error")

		return FALSE

	if (rank == "Company Member")
		var/y_nr = processes.job_data.get_active_positions_name("Goldstein Solutions")
		var/g_nr = processes.job_data.get_active_positions_name("Kogama Kraftsmen")
		var/r_nr = processes.job_data.get_active_positions_name("Rednikov Industries")
		var/b_nr = processes.job_data.get_active_positions_name("Giovanni Blu Stocks")
		var/list/posslist = list("Goldstein Solutions", "Kogama Kraftsmen", "Rednikov Industries", "Giovanni Blu Stocks")
		if (r_nr > y_nr && r_nr > b_nr && r_nr > g_nr)
			posslist -= "Rednikov Industries"
		if (b_nr > y_nr && b_nr > r_nr && b_nr > g_nr)
			posslist -= "Giovanni Blu Stocks"
		if (g_nr > y_nr && g_nr > b_nr && g_nr > r_nr)
			posslist -= "Kogama Kraftsmen"
		if (y_nr > r_nr && y_nr > b_nr && y_nr > g_nr)
			posslist -= "Goldstein Solutions"
		if (isemptylist(posslist))
			rank = pick("Goldstein Solutions", "Kogama Kraftsmen", "Rednikov Industries", "Giovanni Blu Stocks")
		else
			rank = pick(posslist)
		spawning = TRUE
		close_spawn_windows()
		job_master.AssignRole(src, rank, TRUE)
		var/mob/living/character = create_character(job2mobtype(rank))	//creates the human and transfers vars and mind
		if (!character)
			return FALSE

		character = job_master.EquipRank(character, rank, TRUE)					//equips the human
		job_master.relocate(character)

		if (character.buckled && istype(character.buckled, /obj/structure/bed/chair/wheelchair))
			character.buckled.loc = character.loc
			character.buckled.set_dir(character.dir)

		if (character.mind)
			ticker.minds += character.mind
		character.lastarea = get_area(loc)
		qdel(src)
		return TRUE
	if (!IsJobAvailable(rank))
		if (!nomsg)
			WWalert(src, "'[rank]' has already been taken by someone else.", "Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(src, "'[rank]' has already been taken by someone else.", "Error")
		return FALSE

	var/datum/job/job = job_master.GetJob(rank)

	if (factionBanned(job.base_type_flag(1)))
		if (!nomsg)
			WWalert(usr,"You're banned from this faction!","Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"You're banned from this faction!","Error")
		return FALSE

	if (penalBanned())
		if (job.blacklisted == FALSE)
			if (!nomsg)
				WWalert(usr,"You're under a Penal ban, you can only play as that role!","Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"You're under a Penal ban, you can only play as that role!","Error")
			return FALSE

	else
		if (job.blacklisted == TRUE)
			if (!nomsg)
				WWalert(usr,"This job is reserved as a punishment for those who break server rules.","Error")
			if (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.civilizations == TRUE || map.ID == MAP_FOUR_KINGDOMS)
				abandon_mob()
				spawn(10)
					WWalert(usr,"This job is reserved as a punishment for those who break server rules.","Error")
			return FALSE

	if (job.is_deathmatch)
		if (map && map.faction1_can_cross_blocks())
			WWalert(usr,"This job is not available for joining after the grace period has ended.","Error")
			return FALSE
		if (client && client.prefs.gender == FEMALE)
			WWalert(usr,"You must be male to play as this faction.","Error")
			return FALSE
	if (job.is_ww1)
		if (client && client.prefs.gender == FEMALE)
			WWalert(usr,"You must be male to play as this faction.","Error")
			return FALSE
	if (client && client.prefs.gender == FEMALE && !job.can_be_female)
		WWalert(usr,"You must be male to play as this role.","Error")
		return FALSE
	else if (client && client.prefs.gender == FEMALE && job.can_be_female)
		spawning = TRUE
		close_spawn_windows()
		job_master.AssignRole(src, rank, TRUE)
		var/mob/living/character = create_character(job2mobtype(rank))	//creates the human and transfers vars and mind
		if (!character)
			return FALSE

		character = job_master.EquipRank(character, rank, TRUE)
		return
	if (!job.can_be_minor && client.prefs.age < 18)
		WWalert(usr,"You must be atleast 18 to play this role.","Error")
		return FALSE

	if (istype(job, /datum/job/german/hj_reichstag) && client.prefs.age > 17)
		WWalert(usr,"You must be under 18 to play this role.","Error")
		return FALSE

	if (map.ordinal_age == 2 && !map.civilizations && !istype(job, /datum/job/civilian) && map.ID != MAP_BOHEMIA)
		if (client.prefs.gender == FEMALE)
			WWalert(usr,"You must be male to play as this faction.","Error")
			return FALSE
	if (job.is_yakuza)
		var/yy_nr = processes.job_data.get_active_positions_name("Yamaguchi-Gumi Kaiin")
		var/yi_nr = processes.job_data.get_active_positions_name("Ichiwa-Kai Kaiin")
		for (var/datum/job/joby in job_master.occupations)
			if (istype(joby, /datum/job/japanese/yakuza))
				yy_nr = joby.current_positions
			else if(istype(joby, /datum/job/japanese/yakuza_ichi))
				yi_nr = joby.current_positions
		if (istype(job, /datum/job/japanese/yakuza_ichi))
			if (yi_nr > yy_nr)
				WWalert(usr,"Too many people playing as Ichiwa: [yi_nr] Ichiwa, [yy_nr] Yamaguchi","Error")
				return FALSE
		else if(istype(job, /datum/job/japanese/yakuza))
			if (yy_nr > yi_nr)
				WWalert(usr,"Too many people playing as Yamaguchi: [yi_nr] Ichiwa, [yy_nr] Yamaguchi","Error")
				return FALSE
	if (job.is_samurai)
		var/yy_nr = processes.job_data.get_active_positions_name("Tobu-Ashigaru", "Tobu Enkyori Ashigaru")
		var/yi_nr = processes.job_data.get_active_positions_name("Sei-Ashigaru", "Sei Enkyori Ashigaru")
		for (var/datum/job/joby in job_master.occupations)
			if (istype(joby, /datum/job/japanese/ashigaru))
				yy_nr = joby.current_positions
			else if(istype(joby, /datum/job/japanese/ashigaru_western))
				yi_nr = joby.current_positions
		if (istype(job, /datum/job/japanese/ashigaru_western) || istype(job, /datum/job/japanese/ashigaru_ranged_western))
			if (yi_nr > yy_nr)
				WWalert(usr,"Too many people playing as Western: [yi_nr] Western, [yy_nr] Eastern","Error")
				return FALSE
		else if(istype(job, /datum/job/japanese/ashigaru)|| istype(job, /datum/job/japanese/ashigaru_ranged))
			if (yy_nr > yi_nr)
				WWalert(usr,"Too many people playing as Eastern: [yi_nr] Western, [yy_nr] Eastern","Error")
				return FALSE

	spawning = TRUE
	close_spawn_windows()
	job_master.AssignRole(src, rank, TRUE)
	var/mob/living/character = create_character(job2mobtype(rank))	//creates the human and transfers vars and mind
	if (!character)
		return FALSE

	character = job_master.EquipRank(character, rank, TRUE)					//equips the human

	//squads
	if (ishuman(character) && map.ID != MAP_CAMPAIGN)
		var/mob/living/human/H = character
		if (H.original_job_title == "FBI officer" || H.original_job_title == "KGB officer")
			H.verbs += /mob/living/human/proc/find_hvt
		if (H.original_job.is_commander || H.original_job.is_officer)
			H.verbs += /mob/living/human/proc/Commander_Announcement
		if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
			if (H.original_job_title == "Rednikov Industries CEO" || H.original_job_title == "Giovanni Blu Stocks CEO" || H.original_job_title == "Kogama Kraftsmen CEO" || H.original_job_title == "Goldstein Solutions CEO" || H.original_job_title == "McKellen Manager" || H.original_job_title == "Police Supervisor")
				H.verbs += /mob/living/human/proc/Commander_Announcement
		if (H.original_job.uses_squads)
			H.verbs += /mob/living/human/proc/find_nco
			if (H.original_job.is_squad_leader)
				H.verbs += /mob/living/human/proc/Squad_Announcement
			if (H.faction_text == map.faction1) //lets check the squads and see what is the one with the lowest ammount of members
				if (H.original_job.is_officer || H.original_job.is_squad_leader || H.original_job.is_commander)
					if (map.ordinal_age >= 6 && map.ordinal_age < 8)
						if (map.ID != MAP_YELTSIN)
							H.equip_to_slot_or_del(new/obj/item/weapon/radio/faction1(H),slot_back)
				if (H.original_job.is_squad_leader)
					var/done = FALSE
					for(var/i=1, i<=map.squads, i++)
						if (!map.faction1_squad_leaders[i])
							done = TRUE
							H.squad = i
							map.faction1_squad_leaders[i] = H
							break
					if (!done)
						H.squad = rand(1,map.squads)
				else
					H.squad = rand(1,map.squads)
				map.faction1_squads[H.squad] += list(H)
				H << "<big><b>You have been assigned to Squad [H.squad]!</b></big>"
				if (H.original_job.is_squad_leader)
					if (!map.faction1_squad_leaders[H.squad] || map.faction1_squad_leaders[H.squad] == H)
						H << "<big><b>You are the new squad leader!</b></big>"
						map.faction1_squad_leaders[H.squad] = H
					else if (map.faction1_squad_leaders[H.squad] && map.faction1_squad_leaders[H.squad] != H)
						H << "<big><b>Your squad leader is [map.faction1_squad_leaders[H.squad]].</b></big>"
				else if (map.faction1_squad_leaders[H.squad])
					H << "<big><b>Your squad leader is [map.faction1_squad_leaders[H.squad]].</b></big>"
			else if (H.faction_text == map.faction2)
				if (H.original_job.is_officer || H.original_job.is_squad_leader || H.original_job.is_commander)
					if (map.ordinal_age >= 6 && map.ordinal_age < 8)
						if (map.ID != MAP_YELTSIN)
							H.equip_to_slot_or_del(new/obj/item/weapon/radio/faction2(H),slot_back)
				if (H.original_job.is_squad_leader)
					var/done = FALSE
					for(var/i=1, i<=map.squads, i++)
						if (!map.faction2_squad_leaders[i])
							done = TRUE
							H.squad = i
							map.faction2_squad_leaders[i] = H
							break
					if (!done)
						H.squad = rand(1,map.squads)
				else
					H.squad = rand(1,map.squads)
				map.faction2_squads[H.squad] += list(H)
				H << "<big><b>You have been assigned to Squad [H.squad]!</b></big>"
				if (H.original_job.is_squad_leader)
					if (!map.faction2_squad_leaders[H.squad] || map.faction2_squad_leaders[H.squad] == H)
						H << "<big><b>You are the new squad leader!</b></big>"
						map.faction2_squad_leaders[H.squad] = H
					else if (map.faction2_squad_leaders[H.squad] && map.faction2_squad_leaders[H.squad] != H)
						H << "<big><b>Your squad leader is [map.faction2_squad_leaders[H.squad]].</b></big>"
				else if (map.faction2_squad_leaders[H.squad])
					H << "<big><b>Your squad leader is [map.faction2_squad_leaders[H.squad]].</b></big>"
	//

	job_master.relocate(character)

	if (character.buckled && istype(character.buckled, /obj/structure/bed/chair/wheelchair))
		character.buckled.loc = character.loc
		character.buckled.set_dir(character.dir)

	if (character.mind)
		ticker.minds += character.mind
	character.lastarea = get_area(loc)
	qdel(src)
	return TRUE

/mob/new_player/proc/LateChoices()

	src << browse(null, "window=latechoices")

	//<body style='background-color:#1D2951; color:#ffffff'>
	var/list/dat = list("<center>")
	dat += "<b><big>Welcome, [key].</big></b>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text_days()]"
	dat += "<br>"
	dat += "<b>Current Autobalance Status</b>: "
	if (BRITISH in map.faction_organization)
		dat += "[alive_british.len] British "
	if (PORTUGUESE in map.faction_organization)
		dat += "[alive_portuguese.len] Portuguese "
	if (FRENCH in map.faction_organization)
		dat += "[alive_french.len] French "
	if (SPANISH in map.faction_organization)
		dat += "[alive_spanish.len] Spanish "
	if (DUTCH in map.faction_organization)
		dat += "[alive_dutch.len] Dutch "
	if (PIRATES in map.faction_organization)
		dat += "[alive_pirates.len] Pirates "
	if (INDIANS in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/african_warlords))
			dat += "[alive_indians.len] Africans "
		else
			dat += "[alive_indians.len] Natives "
	if (CIVILIAN in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/tsaritsyn))
			dat += "[alive_civilians.len] Soviets "
		if (map && istype(map, /obj/map_metadata/african_warlords))
			dat += "[alive_civilians.len] UN Peacekeepers "
		if (map && istype(map, /obj/map_metadata/capitol_hill))
			dat += "[alive_civilians.len] Rioters "
		if (map && istype(map, /obj/map_metadata/yeltsin))
			dat += "[alive_civilians.len] Soviet Remnants "
		if (map && istype(map, /obj/map_metadata/missionary_ridge))
			dat += "[alive_civilians.len] Confederates "
		else
			dat += "[alive_civilians.len] Civilians "
	if (GREEK in map.faction_organization)
		dat += "[alive_greek.len] Greeks "
	if (ROMAN in map.faction_organization)
		dat += "[alive_roman.len] Romans "
	if (ARAB in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/sovafghan))
			dat += "[alive_arab.len] Mujahideen "
		else
			dat += "[alive_arab.len] Arabs "
	if (JAPANESE in map.faction_organization)
		dat += "[alive_japanese.len] Japanese "
	if (RUSSIAN in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/yeltsin))
			dat += "[alive_russian.len] Russian Army "
		else
			dat += "[alive_russian.len] Russian "
	if (CHECHEN in map.faction_organization)
		dat += "[alive_chechen.len] Chechen "
	if (FINNISH in map.faction_organization)
		dat += "[alive_finnish.len] Finnish "
	if (GERMAN in map.faction_organization)
		dat += "[alive_german.len] German "
	if (AMERICAN in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/arab_town))
			dat += "[alive_american.len] Israeli "
		if (map && istype(map, /obj/map_metadata/capitol_hill))
			dat += "[alive_american.len] American Government "
		if (map && istype(map, /obj/map_metadata/missionary_ridge))
			dat += "[alive_american.len] Union Soldiers "
		else
			dat += "[alive_american.len] American "
	if (VIETNAMESE in map.faction_organization)
		dat += "[alive_vietnamese.len] Vietnamese "
	if (CHINESE in map.faction_organization)
		dat += "[alive_chinese.len] Chinese "
	if (FILIPINO in map.faction_organization)
		dat += "[alive_filipino.len] Filipino "
	dat += "<br>"
//	dat += "<i>Jobs available for slave-banned players are marked with an *</i>"
//	dat += "<br>"

//	var/list/restricted_choices = list()

	var/list/available_jobs_per_side = list(
		CIVILIAN = FALSE,
		PIRATES = FALSE,
		SPANISH = FALSE,
		FRENCH = FALSE,
		INDIANS = FALSE,
		PORTUGUESE = FALSE,
		DUTCH = FALSE,
		BRITISH = FALSE,
		ROMAN = FALSE,
		GREEK = FALSE,
		ARAB = FALSE,
		RUSSIAN = FALSE,
		CHECHEN = FALSE,
		FINNISH = FALSE,
		JAPANESE = FALSE,
		GERMAN = FALSE,
		AMERICAN = FALSE,
		VIETNAMESE = FALSE,
		CHINESE = FALSE,
		)

	var/prev_side = FALSE
	for (var/datum/job/job in job_master.faction_organized_occupations)

		if (job.faction != "Human")
			continue

		if (job.title == "generic job")
			continue

		if (map && !map.faction_organization.Find(job.base_type_flag()))
			continue

		if (!job.specialcheck())
			continue

		var/job_is_available = job && IsJobAvailable(job.title)

		//	unavailable_message = " <span class = 'color: rgb(255,215,0);'>{WHITELISTED}</span> "

		if (job_master.side_is_hardlocked(job.base_type_flag()))
			job_is_available = FALSE

		if (map && !map.job_enabled_specialcheck(job))
			job_is_available = FALSE

		if (istype(job, /datum/job/british) && !british_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/pirates) && !pirates_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/indians) && !indians_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/civilian) && !civilians_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/portuguese) && !portuguese_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/french) && !french_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/spanish) && !spanish_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/dutch) && !dutch_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/roman) && !roman_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/greek) && !greek_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/arab) && !arab_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/russian) && !russian_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/arab/civilian/chechen) && !chechen_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/finnish) && !finnish_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/german) && !german_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/american) && !american_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/vietnamese) && !vietnamese_toggled)
			job_is_available = FALSE
		if (istype(job, /datum/job/chinese) && !chinese_toggled)
			job_is_available = FALSE
		// check if the job is admin-locked or disabled codewise

		if (!job.enabled)
			job_is_available = FALSE

		// check if the job is autobalance-locked

		if (job)
			var/active = processes.job_data.get_active_positions(job)
			if (job.base_type_flag() != prev_side)
				prev_side = job.base_type_flag()
				var/temp_name = job.get_side_name()
				if (map && map.ID == "ARAB_TOWN" && temp_name == "American")
					temp_name = "Israeli"
				else if (map && map.ID == "AFRICAN_WARLORDS")
					if (temp_name == "Indians")
						temp_name = "Africans"
					else if (temp_name == "Civilian")
						temp_name = "United Nations"
				else if (map && map.ID == "MISSIONARY_RIDGE")
					if (temp_name == "American")
						temp_name = "Union"
					if (temp_name == "Civilian")
						temp_name = "Confederate"
				else if (map && map.ID == "WHITERUN")
					if (temp_name == "Roman")
						temp_name = "Imperials"
					if (temp_name == "Civilian")
						temp_name = "Stormcloaks"
				else if (map && map.ID == "CAPITOL_HILL")
					if (temp_name == "American")
						temp_name = "American Government"
					if (temp_name == "Civilian")
						temp_name = "Rioters"
				else if (map && map.ID == "YELTSIN")
					if (temp_name == "Russian")
						temp_name = "Russian Army"
					if (temp_name == "Civilian")
						temp_name = "Soviet Militia"
				else if (map && map.ID == "SOVAFGHAN")
					if (temp_name == "Russian")
						temp_name = "Soviet Army"
					if (temp_name == "Arab")
						temp_name = "Mujahideen"
				else if (map && map.ID == MAP_CAMPAIGN)
					if (temp_name == "Civilian")
						temp_name = "Red"
					if (temp_name == "Pirates")
						temp_name = "Blue"
				var/side_name = "<b><h1><big>[temp_name]</big></h1></b>&&[job.base_type_flag()]&&"
				if (side_name)
					dat += "<br>[side_name]"

			var/extra_span = "<b>"
			var/end_extra_span = "</b>"
			if (job.is_officer && !job.is_commander)
				extra_span = "<b><font size=2>"
				end_extra_span = "</font></b><br>"
			else if (job.is_commander)
				extra_span = "<font size=3>"
				end_extra_span = "</font></b><br><br>"

			if (!job.en_meaning)
				if (job_is_available)
					dat += "&[job.base_type_flag()]&[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] ([job.current_positions]/[job.total_positions]) (Active: [active])</a>[end_extra_span]"
					++available_jobs_per_side[job.base_type_flag()]
			else
				if (job_is_available)
					dat += "&[job.base_type_flag()]&[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] ([job.en_meaning]) ([job.current_positions]/[job.total_positions]) (Active: [active])</a>[end_extra_span]"
					++available_jobs_per_side[job.base_type_flag()]
	if(map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		dat += "&[CIVILIAN]&<b><a style=\"background-color:#777777;\" href='byond://?src=\ref[src];SelectedJob=Company Member'>Company Member (Random) </b><br>"
	dat += "</center>"

	// shitcode to hide jobs that aren't available
	var/any_available_jobs = FALSE
	for (var/key in available_jobs_per_side)
		var/val = available_jobs_per_side[key]
		if (val == 0)
			var/replaced_faction_title = FALSE
			for (var/v in 1 to dat.len)
				if (findtext(dat[v], "&[key]&") && !findtext(dat[v], "&&[key]&&"))
					dat[v] = null
				else if (!replaced_faction_title && findtext(dat[v], "&&[key]&&"))
					dat[v] = "[replacetext(dat[v], "&&[key]&&", "")] (<span style = 'color:red'>FACTION DISABLED BY AUTOBALANCE</span>)"
					replaced_faction_title = TRUE
		else
			any_available_jobs = TRUE
			var/replaced_faction_title = FALSE
			for (var/v in TRUE to dat.len)
				if (findtext(dat[v], "&[key]&") && !findtext(dat[v], "&&[key]&&"))
					dat[v] = replacetext(dat[v], "&[key]&", "")
				else if (!replaced_faction_title && findtext(dat[v], "&&[key]&&"))
					dat[v] = replacetext(dat[v], "&&[key]&&", "")
					replaced_faction_title = TRUE

	if (!any_available_jobs)
		WWalert(usr,"All roles are disabled by autobalance!","Error")
		return

	var/data = ""
	for (var/line in dat)
		if (line != null)
			if (line != "<br>")
				data += "<span style = 'font-size:2.0rem;'>[line]</span>"
			data += "<br>"

	//<link rel='stylesheet' type='text/css' href='html/browser/common.css'>
	data = {"
		<br>
		<html>
		<head>
		[common_browser_style]
		</head>
		<body>
		[data]
		</body>
		</html>
		<br>
	"}

	spawn (1)
		src << browse(data, "window=latechoices;size=600x640;can_close=1")

/mob/new_player/proc/create_character(mobtype)


	if (delayed_spawning_as_job)
		delayed_spawning_as_job.total_positions += 1
		delayed_spawning_as_job = null

	spawning = TRUE
	close_spawn_windows()

	var/mob/living/human/new_character

	var/use_species_name
	var/datum/species/chosen_species
	if (client && client.prefs.species)
		chosen_species = all_species[client.prefs.species]
		use_species_name = chosen_species.get_station_variant() //Only used by pariahs atm.

	if (chosen_species && use_species_name)
		// Have to recheck admin due to no usr at roundstart. Latejoins are fine though.
		if (is_species_whitelisted(chosen_species) || has_admin_rights())
			new_character = new mobtype(loc, use_species_name)

	if (!new_character)
		new_character = new mobtype(loc)

	new_character.stopDumbDamage = TRUE
	new_character.lastarea = get_area(loc)

	if (client)
		if (ticker.random_players)
			new_character.gender = pick(MALE, FEMALE)
			client.prefs.real_name = random_name(new_character.gender)
			client.prefs.randomize_appearance_for (new_character)
		else
			// no more traps - Kachnov
			var/client_prefs_original_gender = client.prefs.gender

			// traps came back, this should fix them for good - Kachnov
			new_character.gender = client.prefs.gender
			client.prefs.copy_to(new_character)
			client.prefs.gender = client_prefs_original_gender

	src << sound(null, repeat = FALSE, wait = FALSE, volume = 85, channel = TRUE) // MAD JAMS cant last forever yo

	if (mind)
		mind.active = FALSE					//we wish to transfer the key manually
		mind.original = new_character
		mind.transfer_to(new_character)					//won't transfer key since the mind is not active
	if (client && client.prefs.be_random_body)
		client.prefs.randomize_appearance_for (new_character)
	new_character.original_job = original_job
	new_character.name = real_name
	new_character.dna.ready_dna(new_character)

	if (client)
		new_character.dna.b_type = client.prefs.b_type

	new_character.sync_organ_dna()

	// Do the initial caching of the player's body icons.
	new_character.force_update_limbs()
	new_character.update_eyes()
	new_character.regenerate_icons()
	new_character.key = key		//Manually transfer the key to log them in

	return new_character

/mob/new_player/Move()
	return FALSE

/mob/new_player/proc/close_spawn_windows()
	src << browse(null, "window=latechoices") //closes late choices window
	src << browse(null, "window=playersetup") //closes the player setup window

/mob/new_player/proc/has_admin_rights()
	return check_rights(R_ADMIN, FALSE, src)

/mob/new_player/proc/is_species_whitelisted(datum/species/S)
	return FALSE

/mob/new_player/get_gender()
	if (!client || !client.prefs)
		return ..()
	return client.prefs.gender

/mob/new_player/is_ready()
	return ready && ..()

/mob/new_player/hear_say(var/message, var/verb = "says", var/datum/language/language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null)
	return

/mob/new_player/MayRespawn()
	return TRUE
