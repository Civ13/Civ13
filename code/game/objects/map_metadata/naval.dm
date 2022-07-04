
/obj/map_metadata/naval
	ID = MAP_NAVAL
	title = "Naval Battle"
	lobby_icon_state = "imperial"
	no_winner ="No ship has been captured."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300


	faction_organization = list(
		FRENCH,
		PIRATES)

	roundend_condition_sides = list(
		list(FRENCH) = /area/caribbean/british/ship/lower,
		list(PIRATES) = /area/caribbean/pirates/ship/lower
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(FRENCH = 0.5, PIRATES = 0.5)
	battle_name = "Naval boarding"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = FRENCH
	faction2 = PIRATES
	grace_wall_timer = 3000

obj/map_metadata/naval/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (J.is_event == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else
		. = TRUE

/obj/map_metadata/naval/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"


