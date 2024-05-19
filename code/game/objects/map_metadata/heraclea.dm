/obj/map_metadata/heraclea
	ID = MAP_HERACLEA
	title = "Heraclea"
	lobby_icon = 'icons/lobby/ancient.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300


	faction_organization = list(
		ROMAN,
		GREEK)

	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/roman,
		list(GREEK) = /area/caribbean/greek
		)
	age = "313 B.C."
	ordinal_age = 1
	faction_distribution_coeffs = list(ROMAN = 0.5, GREEK = 0.5)
	battle_name = "battle of Heraclea"
	mission_start_message = "<font size=4>The <b>Greek</b> and <b>Roman</b> armies are facing each other in southern Italy! Get ready for the battle! It will start in <b>5 minutes</b>.</font>"
	faction1 = ROMAN
	faction2 = GREEK
	ambience = list('sound/ambience/jungle1.ogg')
	songs = list(
		"Divinitus:1" = 'sound/music/divinitus.ogg',)
	grace_wall_timer = 3000
obj/map_metadata/heraclea/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/roman))
		if (J.is_gladiator == TRUE || J.is_skyrim == TRUE)
			. = FALSE
		else
			. = TRUE
	if (istype(J, /datum/job/greek))
		if (J.is_ancient == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

