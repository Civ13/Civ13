
/obj/map_metadata/skullisland
	ID = MAP_SKULLISLAND
	title = "Skull Island"
	lobby_icon = "icons/lobby/imperial.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 600

	no_winner ="No faction has captured the enemy's base."
	var/do_once_activations = TRUE

	faction_organization = list(
		PIRATES,
		BRITISH)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/pirates/land/inside,
		list(BRITISH) = /area/caribbean/british/ship/office
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 0.5, BRITISH = 0.5)
	//songs = list()
	faction1 = PIRATES
	faction2 = BRITISH
	meme = TRUE
	battle_name = "Skull Island"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts. Each team must capture the other's command post to win.</font>"
	var/done = FALSE
	grace_wall_timer = 3000

/obj/map_metadata/skullisland/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/pirates))
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

/obj/map_metadata/skullisland/tick()
	..()
	if (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)
		for (var/obj/effect/area_teleporter/AT)
			AT.Activated()
		do_once_activations = FALSE

