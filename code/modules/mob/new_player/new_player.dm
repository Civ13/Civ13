//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:33

/proc/job2mobtype(rank)
	for (var/datum/job/J in job_master.occupations)
		if (J.title == rank)
			return /mob/living/carbon/human

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


/mob/new_player/New()
	mob_list += src
	new_player_mob_list += src


	spawn (10)
		if (client)
			movementMachine_clients -= client

/mob/new_player/Destroy()
	..()
	new_player_mob_list -= src

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
	<style>
	[common_browser_style]
	</style>
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
		if (map.ID == MAP_TRIBES)
			output += "<p><a href='byond://?src=\ref[src];tribes=1'>Join a Tribe!</a></p>"
		else if (map.civilizations == TRUE && map.nomads == FALSE)
			output += "<p><a href='byond://?src=\ref[src];civilizations=1'>Join a Civilization!</a></p>"
		else if (map.nomads == TRUE)
			output += "<p><a href='byond://?src=\ref[src];nomads=1'>Join!</a></p>"
		else
			output += "<p><a href='byond://?src=\ref[src];late_join=1'>Join Game!</a></p>"

	var/height = 250

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

		if (client && client.quickBan_isbanned("Observe"))
			src << "<span class = 'danger'>You're banned from observing.</span>"
			return TRUE

		if (WWinput(src, "Are you sure you wish to observe?", "Player Setup", "Yes", list("Yes","No")) == "Yes")
			if (!client)	return TRUE
			var/mob/observer/ghost/observer = new(150, 317, 1)

			spawning = TRUE
			src << sound(null, repeat = FALSE, wait = FALSE, volume = 85, channel = TRUE) // MAD JAMS cant last forever yo

			observer.started_as_observer = TRUE
			close_spawn_windows()
			var/obj/O = locate("landmark/Observer-Start")
			if (istype(O))
				src << "<span class='notice'>Now teleporting.</span>"
				observer.loc = O.loc
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
		//	if (!client.holder && !config.antag_hud_allowed)           // For new ghosts we remove the verb from even showing up if it's not allowed.
				//observer.verbs -= /mob/observer/ghost/verb/toggle_antagHUD        // Poor guys, don't know what they are missing!
			observer.key = key
			observer.overlays += icon('icons/mob/uniform.dmi', "civuni[rand(1,3)]")
			observer.original_icon = observer.icon
			observer.original_overlays = list(icon('icons/mob/uniform.dmi', "civuni[rand(1,3)]"))
			qdel(src)

			return TRUE

		if (client && client.quickBan_isbanned("Playing"))
			src << "<span class = 'danger'>You're banned from playing.</span>"
			return TRUE

		if (!ticker.players_can_join)
			src << "<span class = 'danger'>You can't join the game yet.</span>"
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			src << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
			return

		if (client.next_normal_respawn > world.realtime && !config.no_respawn_delays)
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
			src << "<span class = 'danger'>You're banned from playing.</span>"
			return TRUE

		if (!ticker.players_can_join)
			src << "<span class = 'danger'>You can't join the game yet.</span>"
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			src << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
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
			WWalert(src, "Because you died in combat, you must wait [wait] more minutes to respawn. You can still join as a reinforcement.", "Error")
			return FALSE

		if (map && map.ID == MAP_TRIBES)
			close_spawn_windows()
			AttemptLateSpawn(pick(map.availablefactions))
		else
			return
		LateChoices()
		return TRUE

	if (href_list["civilizations"])

		if (client && client.quickBan_isbanned("Playing"))
			src << "<span class = 'danger'>You're banned from playing.</span>"
			return TRUE

		if (!ticker.players_can_join)
			src << "<span class = 'danger'>You can't join the game yet.</span>"
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			src << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
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
			WWalert(src, "Because you died, you must wait [wait] more minutes to respawn. You can still join as a reinforcement.", "Error")
			return FALSE

		if (map && map.civilizations == TRUE)
			close_spawn_windows()
			AttemptLateSpawn(pick(map.availablefactions))
		else
			return
		LateChoices()
		return TRUE

	if (href_list["nomads"])

		if (client && client.quickBan_isbanned("Playing"))
			src << "<span class = 'danger'>You're banned from playing.</span>"
			return TRUE

		if (!ticker.players_can_join)
			src << "<span class = 'danger'>You can't join the game yet.</span>"
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			src << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
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
			WWalert(src, "Because you died, you must wait [wait] more minutes to respawn. You can still join as a reinforcement.", "Error")
			return FALSE

		if (map && map.civilizations == TRUE)
			close_spawn_windows()
			AttemptLateSpawn("Nomad")
		else
			return
		LateChoices()
		return TRUE


	if (href_list["late_join"])

		if (client && client.quickBan_isbanned("Playing"))
			src << "<span class = 'danger'>You're banned from playing.</span>"
			return TRUE

		if (!isemptylist(approved_list) && config.useapprovedlist)
			var/found = FALSE
			for (var/i in approved_list)
				if (i == client.ckey)
					found = TRUE
			if (!found)
				usr << "<span class = 'notice'><font size = 4 color='red'><b>The game is currently only accepting approved players. Visit the Discord to get approved.</b></font></span>"
				return

		if (!ticker.players_can_join)
			src << "<span class = 'danger'>You can't join the game yet.</span>"
			return TRUE

		if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
			src << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
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

		var/datum/job/actual_job = null

		for (var/datum/job/j in job_master.occupations)
			if (j.title == href_list["SelectedJob"])
				actual_job = j
				break

		if (!actual_job)
			return

		var/job_flag = actual_job.base_type_flag()

		if (!config.enter_allowed)
			usr << "<span class='notice'>There is an administrative lock on entering the game!</span>"
			return

		if (map && map.has_occupied_base(job_flag) && map.ID != MAP_CAMP && map.ID != MAP_HILL203)
			usr << "<span class = 'danger'>The enemy is currently occupying your base! You can't be deployed right now.</span>"
			return
/* "Old" whitelisting proccess
		if (actual_job.whitelisted)
			if (!actual_job.validate(client))
				usr << "<span class = 'notice'>You need to be whitelisted to play this job. Apply in the Discord.</span>"
				return
*/
		if (actual_job.whitelisted && !isemptylist(whitelist_list) && config.use_job_whitelist)
			var/found = FALSE
			for (var/i in whitelist_list)
				if (i == client.ckey)
					found = TRUE
			if (!found)
				usr << "<span class = 'notice'><font size = 4><b>You need to be whitelisted to play this job. Apply in the Discord.</b></font></span>"
				return

		if (actual_job.is_officer)
			if ((input(src, "This is an officer position. Are you sure you want to join in as a [actual_job.title]?") in list("Yes", "No")) == "No")
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

/mob/new_player/proc/officerBanned()
	if (client && client.quickBan_isbanned("Officer"))
		return TRUE
	return FALSE

//if the player is "Penal banned", he is reduced to play as a member of a penal battalion
/mob/new_player/proc/penalBanned()
	if (client && client.quickBan_isbanned("Penal"))
		return TRUE
	return FALSE

/mob/new_player/proc/LateSpawnForced(rank, needs_random_name = FALSE)

	spawning = TRUE
	close_spawn_windows()

	job_master.AssignRole(src, rank, TRUE)
	var/mob/living/character = create_character(job2mobtype(rank))	//creates the human and transfers vars and mind
	character = job_master.EquipRank(character, rank, TRUE)					//equips the human

	job_master.relocate(character)

	if (character.buckled && istype(character.buckled, /obj/structure/bed/chair/wheelchair))
		character.buckled.loc = character.loc
		character.buckled.set_dir(character.dir)

	ticker.minds += character.mind

	character.lastarea = get_area(loc)

	qdel(src)

/mob/new_player/proc/AttemptLateSpawn(rank, var/nomsg = FALSE)

	if (src != usr)
		return FALSE
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		if (!nomsg)
			usr << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'red'>The round is either not ready, or has already finished.</span>"
		return FALSE
	if (!config.enter_allowed)
		if (!nomsg)
			usr << "<span class='notice'>There is an administrative lock on entering the game!</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class='notice'>There is an administrative lock on entering the game!</span>"
		return FALSE
	if (jobBanned(rank))
		if (!nomsg)
			usr << "<span class = 'warning'>You're banned from this role!</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'warning'>You're banned from this role!</span>"

		return FALSE
	if (!IsJobAvailable(rank))
		if (!nomsg)
			WWalert(src, "'[rank]' has already been taken by someone else.", "Error")
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					WWalert(src, "'[rank]' has already been taken by someone else.", "Error")
		return FALSE

	var/datum/job/job = job_master.GetJob(rank)

	if (factionBanned(job.base_type_flag(1)))
		if (!nomsg)
			usr << "<span class = 'warning'>You're banned from this faction!</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'warning'>You're banned from this faction!</span>"
		return FALSE

	if (officerBanned() && job.is_officer)
		if (!nomsg)
			usr << "<span class = 'warning'>You're banned from officer positions!</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'warning'>You're banned from officer positions!</span>"
		return FALSE

	if (penalBanned())
		if (job.blacklisted == FALSE)
			if (!nomsg)
				usr << "<span class = 'warning'>You're under a Penal ban, you can only play as that role!</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'warning'>You're under a Penal ban, you can only play as that role!</span>"
			return FALSE

	else
		if (job.blacklisted == TRUE)
			if (!nomsg)
				usr << "<span class = 'warning'>This job is reserved as a punishment for those who break server rules.</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					usr << "<span class = 'warning'>This job is reserved as a punishment for those who break server rules.</span>"
			return FALSE

	if (job_master.is_side_locked(job.base_type_flag()))
		if (!nomsg)
			src << "<span class = 'red'>Currently this side is locked for joining.</span>"
			if (map.ID == MAP_TRIBES || map.civilizations == TRUE)
				abandon_mob()
				spawn(10)
					src << "<span class = 'red'>Currently this side is locked for joining.</span>"
		return

	if (job.is_deathmatch)
		if (map && map.faction1_can_cross_blocks())
			src << "<span class = 'red'>This job is not available for joining after the grace period has ended.</span>"
			return
		if (client && client.prefs.gender == FEMALE)
			usr << "<span class='danger'>You must be male to play as this faction.</span>"
			return
	if (client && client.prefs.gender == FEMALE && (istype(job, /datum/job/american) || istype(job, /datum/job/arab)))
		usr << "<span class='danger'>You must be male to play as this faction.</span>"
		return
	if (job.is_ww1)
		if (client && client.prefs.gender == FEMALE)
			usr << "<span class='danger'>You must be male to play as this faction.</span>"
			return
	if (map.ordinal_age == 2 && !map.civilizations && !istype(job, /datum/job/civilian))
		if (client.prefs.gender == FEMALE)
			usr << "<span class='danger'>You must be male to play as this faction.</span>"
			return
			return
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

	return TRUE

/mob/new_player/proc/LateChoices()

	src << browse(null, "window=latechoices")

	//<body style='background-color:#1D2951; color:#ffffff'>
	var/list/dat = list("<center>")
	dat += "<b><big>Welcome, [key].</big></b>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text()]"
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
		dat += "[alive_indians.len] Natives "
	if (CIVILIAN in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/tsaritsyn))
			dat += "[alive_civilians.len] Soviets "
		else
			dat += "[alive_civilians.len] Civilians "
	if (GREEK in map.faction_organization)
		dat += "[alive_greek.len] Greeks "
	if (ROMAN in map.faction_organization)
		dat += "[alive_roman.len] Romans "
	if (ARAB in map.faction_organization)
		dat += "[alive_arab.len] Arabs "
	if (JAPANESE in map.faction_organization)
		dat += "[alive_japanese.len] Japanese "
	if (RUSSIAN in map.faction_organization)
		dat += "[alive_russian.len] Russian "
	if (GERMAN in map.faction_organization)
		dat += "[alive_german.len] German "
	if (AMERICAN in map.faction_organization)
		if (map && istype(map, /obj/map_metadata/arab_town))
			dat += "[alive_american.len] Israeli "
		else
			dat += "[alive_american.len] American "
	if (VIETNAMESE in map.faction_organization)
		dat += "[alive_vietnamese.len] Vietnamese "
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
		JAPANESE = FALSE,
		GERMAN = FALSE,
		AMERICAN = FALSE,
		VIETNAMESE = FALSE,
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

		if (job_master.is_side_locked(job.base_type_flag()))
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

		if (istype(job, /datum/job/german) && !german_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/american) && !american_toggled)
			job_is_available = FALSE

		if (istype(job, /datum/job/vietnamese) && !vietnamese_toggled)
			job_is_available = FALSE
		// check if the job is admin-locked or disabled codewise

		if (!job.enabled)
			job_is_available = FALSE

		// check if the job is autobalance-locked

		if (job)
			var/active = processes.job_data.get_active_positions(job)
			if (job.base_type_flag() != prev_side)
				prev_side = job.base_type_flag()
				var/side_name = "<b><h1><big>[job.get_side_name()]</big></h1></b>&&[job.base_type_flag()]&&"
				if (side_name)
					if (map && map.ID== "ARAB_TOWN" && side_name == "American")
						side_name = "Israeli"
					dat += "<br><br>[side_name]<br>"

			var/extra_span = ""
			var/end_extra_span = ""

			if (job.is_officer && !job.is_commander)
				extra_span = "<h3>"
				end_extra_span = "</h3>"
			else if (job.is_commander)
				extra_span = "<h2>"
				end_extra_span = "</h2>"

			if (!job.en_meaning)
				if (job_is_available)
					dat += "&[job.base_type_flag()]&[extra_span]<a href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] ([job.current_positions]/[job.total_positions]) (Active: [active])</a>[end_extra_span]"
					++available_jobs_per_side[job.base_type_flag()]
			/*	else
					dat += "&[job.base_type_flag()]&[unavailable_message]<span style = 'color:red'><strike>[job.title] ([job.current_positions]/[job.total_positions]) (Active: [active])</strike></span><br>"
				*/
			else
				if (job_is_available)
					dat += "&[job.base_type_flag()]&[extra_span]<a href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] ([job.en_meaning]) ([job.current_positions]/[job.total_positions]) (Active: [active])</a>[end_extra_span]"
					++available_jobs_per_side[job.base_type_flag()]
		/*		else
					dat += "&[job.base_type_flag()]&[unavailable_message]<span style = 'color:red'><strike>[job.title] ([job.en_meaning]) ([job.current_positions]/[job.total_positions]) (Active: [active])</strike></span><br>"
				*/

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
		src << "<span class = 'danger'><font size = 3>All roles are disabled by autobalance!</font></span>"
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
		<style>
		[common_browser_style]
		</style>
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

	var/mob/living/carbon/human/new_character

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
	if (client.prefs.be_random_body)
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
/*
/mob/new_player/proc/ViewManifest()
	var/dat = "<html><body>"
	dat += "<h4>Show Crew Manifest</h4>"
	dat += data_core.get_manifest(OOC = TRUE)
	src << browse(dat, "window=manifest;size=370x420;can_close=1")
*/
/mob/new_player/Move()
	return FALSE

/mob/new_player/proc/close_spawn_windows()
	src << browse(null, "window=latechoices") //closes late choices window
	src << browse(null, "window=playersetup") //closes the player setup window

/mob/new_player/proc/has_admin_rights()
	return check_rights(R_ADMIN, FALSE, src)

/mob/new_player/proc/is_species_whitelisted(datum/species/S)
	return FALSE

/mob/new_player/get_species()
	var/datum/species/chosen_species
	if (client.prefs.species)
		chosen_species = all_species[client.prefs.species]

	if (!chosen_species)
		return "Human"

	if (is_species_whitelisted(chosen_species) || has_admin_rights())
		return chosen_species.name

	return "Human"

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
