
/obj/map_metadata/robusta
	ID = MAP_ROBUSTA
	title = "Isla Robusta"
	lobby_icon = 'icons/lobby/imperial.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 900


	faction_organization = list(
		PORTUGUESE,
		SPANISH,
		INDIANS)

	roundend_condition_sides = list(
		list(PORTUGUESE) = /area/caribbean/british/land,
		list(SPANISH) = /area/caribbean/pirates/land,
		list(INDIANS) = /area/caribbean/indians,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PORTUGUESE = 0.4, SPANISH = 0.4, INDIANS = 0.2)
	battle_name = "Battle of Isla Robusta"
	mission_start_message = "<font size=4>All factions have <b>12 minutes</b> to prepare before the combat starts.</font>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = PORTUGUESE
	faction2 = SPANISH
	grace_wall_timer = 7200

/obj/map_metadata/robusta/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP)
		. = FALSE
	else if (J.is_warlords)
		. = FALSE
	else if (J.is_army)
		. = FALSE
	else if (J.is_medieval)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else if (J.is_gta)
		. = FALSE
	else if (J.is_blugi)
		. = FALSE
	else
		. = TRUE
	return .

/obj/map_metadata/robusta/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

