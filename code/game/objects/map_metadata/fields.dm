/obj/map_metadata/fields
	ID = MAP_FIELDS
	title = "Fields"
	lobby_icon = "icons/lobby/imperial.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300


	faction_organization = list(
		BRITISH,
		FRENCH)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/colonies/british,
		list(FRENCH) = /area/caribbean/colonies/french
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	battle_name = "Canadian Fields"
	mission_start_message = "<font size=4>The <b>French</b> and <b>British</b> armies are facing each other in Canada! Get ready for the line battle! It will start in <b>5 minutes</b></font>"
	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list('sound/ambience/jungle1.ogg')
	grace_wall_timer = 3000

obj/map_metadata/fields/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_army == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/fields/bridge
	ID = MAP_BRIDGE
	title = "Bridge"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/,/area/caribbean/no_mans_land/invisible_wall/sea)

	battle_name = "Battle for the St. Charles River Bridge."
	mission_start_message = "<font size=4>The <b>French</b> and <b>British</b> armies are facing each other across the St. Charles River Bridge!<br> Each army must fight to the other end of the bridge and capture the enemy camp to win.<br> Get ready for the line battle, it will start in <b>5 minutes!</b></font>"