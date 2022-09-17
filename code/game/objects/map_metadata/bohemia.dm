/obj/map_metadata/bohemia
	ID = MAP_BOHEMIA
	title = "Bohemia"
	lobby_icon = "icons/lobby/medieval.png"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	has_hunger = TRUE

	faction_organization = list(
		GERMAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/british,
		)
	age = "1013"
	ordinal_age = 2
	faction_distribution_coeffs = list( GERMAN = 1)
	battle_name = "bohemia"
	mission_start_message = "<big>Europeans</b> have built a kingdom! The <b>People</b> must thrive on their industry and live peacefully!.</big><br><span class = 'notice'><i>THIS IS AN HRP MAP - </b>No griefing will be tolerated. If you break the rules, you will be banned from the server!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = GERMAN
	songs = list(
		"Nassau Shores:1" = "sound/music/nassau_shores.ogg",)
	gamemode = "Medieval RP"
	is_singlefaction = TRUE
	force_mapgen = TRUE
	is_RP = TRUE
/obj/map_metadata/bohemia/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/bohemia/job_enabled_specialcheck(var/datum/job/J)
	..()
	if ((istype(J, /datum/job/german)) && (J.is_medieval == TRUE) && (J.is_rp == TRUE))
		. = TRUE
	else
		. = FALSE
