/obj/map_metadata/hunt
	ID = MAP_HUNT
	title = "Hunt"
	lobby_icon = "icons/lobby/hunt.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE

	no_winner ="The round is proceeding normally."
	faction_organization = list(
		INDIANS,
		PIRATES)

	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(INDIANS = 0.5, PIRATE = 0.5)
	battle_name = "marooned pirates"
	mission_start_message = "<big>After a major storm, a Pirate shipwreck has washed ashore on an unknown Island. However; they are not alone...<br> The gracewall will drop after <b>25 minutes</b>.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND PIRATES ARE NEUTRAL BY DEFAULT.</b> Attacking the other team without valid reason (including but not limited to sprinting to their spawn to pick a fight with them as soon as the grace wall drops) will be considered griefing and will not be tolerated.<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = PIRATES
	songs = list(
		"Blade and Dagger:1" = "sound/music/blade_and_dagger.ogg",)
	gamemode = "Survival RP"
	is_RP = TRUE
	grace_wall_timer = 15000

/obj/map_metadata/hunt/New()
	..()
	spawn(200)
		load_new_recipes()
	spawn(1200)
		for (var/i = 1, i <= 50, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/island/river))
			new/obj/structure/piranha(areaspawn)
	spawn(18000)
		seasons()
obj/map_metadata/hunt/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/pirates))
		if (istype(J, /datum/job/pirates/marooned))
			. = TRUE
		else
			. = FALSE
	if (istype(J, /datum/job/indians))
		if (istype(J, /datum/job/indians/tribes/red))
			. = TRUE
		else
			. = FALSE
		if (J.is_warlords)
			. = FALSE

/obj/map_metadata/hunt/cross_message(faction)
	return "The gracewall is now removed."