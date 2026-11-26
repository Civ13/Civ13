
/obj/map_metadata/nomads/extended
	ID = MAP_NOMADS_EXTENDED
	title = "Nomads: Oil Rush"

	mission_start_message = "<big>To win, your faction must collect <b>3000</b> liters of Oil! The grace wall will be up for 40 minutes.</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"

	songs = list("Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
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
	gamemode_vote = FALSE

	var/oiltarget = 3000
	// Derived only from deposits, never stored in the faction tax ledger.
	var/tmp/list/oil_rush_progress

/obj/map_metadata/nomads/extended/New()
	..()
	if(!durable_schedule("nomads_oil_check", 1200))
		spawn(1200)
			check_oil()

/obj/map_metadata/nomads/extended/proc/oil_rush_open()
	return admin_ended_all_grace_periods || (processes && processes.ticker && processes.ticker.playtime_elapsed >= grace_wall_timer)

/obj/map_metadata/nomads/extended/persistence_runtime_var(key)
	return key == "oil_rush_progress" || ..()

/obj/map_metadata/nomads/extended/proc/sample_oil_progress()
	var/list/totals = list()
	for (var/obj/structure/oil_deposits/OD in world)
		if (!QDELETED(OD) && OD.faction && OD.storedvalue > 0)
			totals[OD.faction] = (totals[OD.faction] || 0) + OD.storedvalue
	return totals

/obj/map_metadata/nomads/extended/proc/check_oil()
	if (oil_rush_open())
		oil_rush_progress = sample_oil_progress()
		if (custom_faction_nr.len)
			to_chat(world, "<big><b>Current Status:</b></big>")
		for (var/faction in custom_faction_nr)
			var/total = oil_rush_progress[faction]
			if (total > 0)
				to_chat(world, "<b>[faction]:</b> [total] of [oiltarget]")

	if(durable_schedule("nomads_oil_check", 1200)) return
	spawn(1200)
		check_oil()

/obj/map_metadata/nomads/extended/cross_message(faction)
	return "<big><b>The grace wall is lifted!</b></big>"

/obj/map_metadata/nomads/extended/update_win_condition()
	if (win_condition_spam_check || !oil_rush_open() || !oil_rush_progress)
		return FALSE
	for (var/faction in custom_faction_nr)
		if ((oil_rush_progress[faction] || 0) >= oiltarget)
			var/message = "[faction] has reached [oiltarget] liters of oil! They have won!"
			to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
