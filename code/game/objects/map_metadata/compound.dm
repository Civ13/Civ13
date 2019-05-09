#define NO_WINNER "No ship has been captured."
/obj/map_metadata/compound
	ID = MAP_COMPOUND
	title = "Compound (100x100x2)"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		JAPANESE)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british,
		list(JAPANESE) = /area/caribbean/japanese
		)
	age = "1969"
	faction_distribution_coeffs = list(BRITISH = 0.5, JAPANESE = 0.5)
	battle_name = "jungle compound"
	mission_start_message = "<font size=4>The <b>Vietcong</b> must defend the village from the Americans. The <b>US Army</b> must defend their base.<br>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = BRITISH
	faction2 = JAPANESE
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
obj/map_metadata/compound/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_coldwar == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/compound/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/compound/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/compound/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

#undef NO_WINNER