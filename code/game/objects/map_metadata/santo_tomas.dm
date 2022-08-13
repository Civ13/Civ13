/obj/map_metadata/santo_tomas
	ID = MAP_SANTO_TOMAS
	title = "Santo Tomas"
	lobby_icon = "icons/lobby/ph_us_war.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300


	faction_organization = list(
		AMERICAN,
		FILIPINO)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british/land/inside/objective,
		list(FILIPINO) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1899"
	ordinal_age = 5
	grace_wall_timer = 3000
	faction_distribution_coeffs = list(AMERICAN = 0.5, FILIPINO = 0.5)
	battle_name = "Santo Tomas"
	mission_start_message = "<font size=4>The <b>Filipino</b> and <b>American</b> armies are facing each other by Santo Tomas! The each side needs to capture each others' bases! It will start in <b>5 minutes</b></font>"
	faction1 = AMERICAN
	faction2 = FILIPINO
	ambience = list('sound/ambience/jungle1.ogg')

/obj/map_metadata/santo_tomas/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ph_us_war == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/santo_tomas/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Americans may now cross the invisible wall!</font>"
	else if (faction == FILIPINO)
		return "<font size = 4>The Filipinos may now cross the invisible wall!</font>"

/obj/map_metadata/santo_tomas/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Americans may no longer cross the invisible wall!</span>"
	else if (faction == FILIPINO)
		return "<span class = 'userdanger'>The Filipinos may no longer cross the invisible wall!</span>"