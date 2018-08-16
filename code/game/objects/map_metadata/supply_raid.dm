#define NO_WINNER "The fighting is still going."
/obj/map_metadata/supply_raid
	ID = MAP_SUPPLY_RAID
	title = "Supply Raid (100x75x1)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/land,
		list(PIRATES) = /area/caribbean/pirates/land
		)
	front = "Pacific"
	faction_distribution_coeffs = list(BRITISH = 0.5, PIRATES = 0.5)
//	songs = list(
//		"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg')
//	meme = TRUE
	battle_name = "Supply Raid"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the combat starts.</font>"

obj/map_metadata/supply_raid/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else
		. = TRUE
	return .
/obj/map_metadata/supply_raid/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/supply_raid/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/supply_raid/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

#undef NO_WINNER