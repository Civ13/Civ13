
/obj/map_metadata/pioneers
	ID = MAP_PIONEERS
	title = "Pioneers (200x200x2)"
	lobby_icon_state = "wildwest"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!

	no_winner ="The round is proceeding normally."
	faction_organization = list(
		CIVILIAN,
		INDIANS)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(INDIANS) = /area/caribbean/british
		)
	age = "1873"
	is_RP = TRUE
	ordinal_age = 4
	faction_distribution_coeffs = list( CIVILIAN = 0.8,INDIANS = 0.2)
	battle_name = "new frontier"
	mission_start_message = "<big>Pioneers</b> have reached the frontier! The <b>Pioneers</b> must build their town. The gracewall will be up after 25 minutes.</big><br><span class = 'notice'><i>THIS IS A RP MAP - PIONEERS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Pioneer Building RP"
	is_singlefaction = TRUE

/obj/map_metadata/pioneers/New()
	..()
	spawn(18000)
		seasons()
	civilians_forceEnabled = TRUE

obj/map_metadata/pioneers/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_pioneer == TRUE)
			. = TRUE
		else if (J.is_civil_war == TRUE)
			. = FALSE
		else
			. = FALSE

/obj/map_metadata/pioneers/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/pioneers/cross_message(faction)
	return ""


