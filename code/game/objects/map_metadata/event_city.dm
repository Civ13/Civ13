/obj/map_metadata/event_city
	ID = MAP_EVENT_CITY
	title = "event city"
	lobby_icon = "icons/lobby/civ13.gif"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	is_singlefaction = TRUE
	grace_wall_timer = 1200

	no_winner ="The fighting is still going."

	faction_organization = list(PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "unknown"
	ordinal_age = 6
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "The hunting"
	mission_start_message = "<font size=4>You and several others are being hunted. Only one can survive. You cannot harm your persuers, only run. <b>Last standing player wins!</b></font>"
	faction1 = PIRATES
	gamemode = "Hunt"
	required_players = 9

/obj/map_metadata/event_city/job_enabled_specialcheck(var/datum/job/J)

	..()
	if (J.is_event_role == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/event_city/cross_message(faction)
	if (faction == PIRATES)
		return ""