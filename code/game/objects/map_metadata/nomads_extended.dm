
/obj/map_metadata/nomads_extended
	ID = MAP_NOMADS_EXTENDED
	title = "Nomads: Oil Rush"
	lobby_icon = "icons/lobby/civ13.gif"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // q0 minutes!
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>To win, your faction must collect <b>3000</b> liters of Oil! The grace wall will be up for 40 minutes.</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	nomads = TRUE
	gamemode = "Oil Rush"
	ordinal_age = 5
	age = "1903"
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	research_active = FALSE
	default_research = 135
	grace_wall_timer = 24000

	var/oiltarget = 3000
/obj/map_metadata/nomads_extended/New()
	..()
	spawn(1200)
		check_oil()
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_extended/proc/check_oil()
	if (processes.ticker.playtime_elapsed >= 24000 || admin_ended_all_grace_periods)
		if (custom_faction_nr.len >= 1)
			world << "<big><b>Current Status:</b></big>"
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			custom_civs[custom_faction_nr[i]][5]=0
			for (var/obj/structure/oil_deposits/OD in world)
				if (OD.faction == custom_faction_nr[i])
					custom_civs[custom_faction_nr[i]][5] += OD.storedvalue
			if (custom_civs[custom_faction_nr[i]][5] > 0)
				world << "<b>[custom_faction_nr[i]]:</b> [custom_civs[custom_faction_nr[i]][5]] of 3000"

	spawn(1200)
		check_oil()

/obj/map_metadata/nomads_extended/cross_message(faction)
	return "<b><big>The grace wall is lifted!</big></b>"


/obj/map_metadata/nomads_extended/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/nomads_extended/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for(var/i = 1, i <= custom_faction_nr.len, i++)
		if (custom_civs[custom_faction_nr[i]][5] >= oiltarget)
			var/message = "[custom_faction_nr[i]] has reached [oiltarget] liters of oil! They have won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
