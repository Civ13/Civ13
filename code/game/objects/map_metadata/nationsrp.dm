/obj/map_metadata/nationsrp
	ID = MAP_NATIONSRP
	title = "Nations RP"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE


	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1873"
	no_winner = "The round is proceeding normally."
	is_RP = TRUE
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the nations"
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	mission_start_message = "<big>Two industrial nations rule this land. This is an RP focused map, people of both nations start friendly by default.</big><br><b>Wiki Guide: http://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	nomads = TRUE
	availablefactions_run = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	default_research = 105
	gamemode = "Nations RP"
	ordinal_age = 4
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	research_active = FALSE

/obj/map_metadata/nationsrp/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/nationsrp/faction2_can_cross_blocks()
	return (admin_ended_all_grace_periods)

/obj/map_metadata/nationsrp/faction1_can_cross_blocks()
	return (admin_ended_all_grace_periods)

/obj/map_metadata/nationsrp/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
