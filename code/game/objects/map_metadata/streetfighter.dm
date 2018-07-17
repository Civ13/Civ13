/obj/map_metadata/streetfighter
	ID = MAP_STREETFIGHTER
	title = "Street Riots 1929 (50x50x1)"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall,
	/area/prishtina/no_mans_land/invisible_wall/inside)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
	reinforcements = FALSE
	no_subfaction_chance = FALSE
	subfaction_is_main_faction = TRUE

	faction_organization = list(
		NSDAP, //nsdap
		KPD, //kpd
		CIVILIAN //police
	)
	roundend_condition_sides = list(
		list(NSDAP) = /area/prishtina/german,
		list(KPD) = /area/prishtina/soviet
		)
	available_subfactions = list(
		NSDAP,
		KPD
	)
	custom_loadout = FALSE // so people do not spawn with guns!
	var/modded_num_of_nsdap = FALSE
	var/modded_num_of_kpd = FALSE
	faction_distribution_coeffs = list(NSDAP = 0.5, KPD = 0.5)
	battle_name = "Berlin street fights of 1929"

/obj/map_metadata/streetfighter/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/streetfighter/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/streetfighter/job_enabled_specialcheck(var/datum/job/J)
	. = TRUE
	if (istype(J, /datum/job/nsdap))
		if (!J.is_weimar)
			. = FALSE
		else
//			if (istype(J, /datum/job/nsdap/commander))
//				J.total_positions = 1
			if (istype(J, /datum/job/nsdap/sa_scharfuhrer))
				J.total_positions = max(2, round(clients.len*0.20))
				J.min_positions = 2
				J.max_positions = 8
			if (istype(J, /datum/job/nsdap/sa_mann) && !modded_num_of_nsdap)
				J.total_positions = max(10, round(clients.len*0.80))
				J.min_positions = 10
				J.max_positions = 60
				modded_num_of_nsdap = TRUE
	else if (istype(J, /datum/job/kpd))
		if (!J.is_weimar)
			. = FALSE
		else
//			if (istype(J, /datum/job/kpd/commander))
//				J.total_positions = 1
			if (istype(J, /datum/job/kpd/squad_leader))
				J.total_positions = max(2, round(clients.len*0.20))
				J.min_positions = 2
				J.max_positions = 8
			if (istype(J, /datum/job/kpd/trooper) && !modded_num_of_kpd)
				J.total_positions = max(10, round(clients.len*0.80))
				J.min_positions = 10
				J.max_positions = 60
				modded_num_of_kpd = TRUE
	return .

/obj/map_metadata/streetfighter/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>6 minutes</b> to prepare before combat will begin!</font>"

/obj/map_metadata/streetfighter/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())