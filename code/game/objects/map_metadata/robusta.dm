#define NO_WINNER "The fighting is still going."
/obj/map_metadata/robusta
	ID = MAP_ROBUSTA
	title = "Isla Robusta (125x125x1)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	front = "Pacific"
	faction_distribution_coeffs = list(PIRATES = 1)
//	songs = list(
//		"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg')
//	meme = TRUE
	battle_name = "Isla Robusta"
	mission_start_message = "<font size=4>You and several other pirates were abandoned at this forsaken island. Only one can survive! <b>Last standing player wins!</b></font>"
	single_faction = TRUE

/obj/map_metadata/robusta/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/robusta/british_can_cross_blocks()
	return FALSE

/obj/map_metadata/robusta/pirates_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/robusta/cross_message(faction)
	return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"
/obj/map_metadata/robusta/reinforcements_ready()
	return (pirates_can_cross_blocks())

#undef NO_WINNER