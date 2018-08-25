#define NO_WINNER "No ship has been captured."
/obj/map_metadata/naval
	ID = MAP_NAVAL
	title = "Naval Battle (75x75x4)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		DUTCH,
		FRENCH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(DUTCH) = /area/caribbean/british/ship/lower,
		list(FRENCH) = /area/caribbean/pirates/ship/lower
		)
	front = "Pacific"
	faction_distribution_coeffs = list(DUTCH = 0.5, FRENCH = 0.5)
//	songs = list(
//		"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg')
//	meme = TRUE
	battle_name = "Naval boarding"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = DUTCH
	faction2 = FRENCH

obj/map_metadata/naval/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else
		. = TRUE

/obj/map_metadata/robusta/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/naval/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/naval/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/naval/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

#undef NO_WINNER