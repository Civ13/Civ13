#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/gladiators
	ID = MAP_GLADIATORS
	title = "Gladiators (100x80x1)"
	lobby_icon_state = "ancient"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	faction_organization = list(
		ROMAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/british,
		)
	age = "313 B.C."
	ordinal_age = 1
	faction_distribution_coeffs = list(ROMAN = 1)
	battle_name = "gladiator fights"
	mission_start_message = "<big><font color='yellow' size=3><B>AVE IMPERATOR, MORITVRI TE SALVTANT!</font><br>Organize gladiatoral fights and become the best!</B></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = ROMAN
	songs = list(
		"Divinitus:1" = 'sound/music/divinitus.ogg',)
	gamemode = "Gladiatorial Combat"
	is_singlefaction = TRUE
	var/list/gladiator_stats = list()
obj/map_metadata/gladiators/New()
	..()
	load_gladiators()

obj/map_metadata/gladiators/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/roman))
		if (J.is_gladiator == TRUE)
			. = TRUE
		else
			. = FALSE
/obj/map_metadata/gladiators/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/gladiators/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/gladiators/cross_message(faction)
	return "The gracewall is now removed."

/obj/map_metadata/gladiators/proc/load_gladiators()
	var/F = file("SQL/gladiator_stats.txt")
	if (fexists(F))
		world << "Gladiator list found, loading..."
		var/list/temp_stats1 = file2list(F,"\n")
		gladiator_stats = list()
		for (var/i = 1, i <= temp_stats1, i++)
			if (findtext(temp_stats1[i], ";"))
				var/list/temp_stats2 = splittext(temp_stats1[i], ";")
				gladiator_stats += list(list(temp_stats2[1],temp_stats2[2],temp_stats2[3],temp_stats2[4],temp_stats2[5]))
		world << "Gladiator list loaded."
		return TRUE
	else
		world << "Gladiator list not found!"
		return FALSE

/obj/map_metadata/gladiators/proc/save_gladiators()
	var/F = file("SQL/gladiator_stats.txt")
	if (!gladiator_stats.len)
		return
	if (fexists(F))
		fcopy("SQL/gladiator_stats.txt","SQL/gladiator_stats_backup.txt")
		fdel(F)
	for (var/i = 1, i <= gladiator_stats.len, i++)
		var/txtexport = list2text(gladiator_stats[i])
		text2file(txtexport,F)
	return


#undef NO_WINNER