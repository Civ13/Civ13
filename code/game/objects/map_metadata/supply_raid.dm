
/obj/map_metadata/supply_raid
	ID = MAP_SUPPLY_RAID
	title = "Supply Raid"
	lobby_icon = "icons/lobby/imperial.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 900
	grace_wall_timer = 3000
	faction_organization = list(
		BRITISH,
		INDIANS)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/ship,
		list(INDIANS) = /area/caribbean/indians/camp
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.35, INDIANS = 0.65)
	battle_name = "Supply Raid on Port Andrew"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts. In order to win the Carib must capture the British Ship and the British must capture the Carib Altar.</font>"
	faction1 = BRITISH
	faction2 = INDIANS

	ambience = list('sound/ambience/jungle1.ogg')

obj/map_metadata/supply_raid/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/indians))
		if (J.is_1713)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/british))
		if (J.is_navy)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE


