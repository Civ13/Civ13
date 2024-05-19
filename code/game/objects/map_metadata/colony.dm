
/obj/map_metadata/colony
	ID = MAP_COLONY
	title = "Colony"
	lobby_icon = 'icons/lobby/imperial.png'
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,
		INDIANS,
		PIRATES,
		SPANISH)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/british,
		list(SPANISH) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(INDIANS = 0.4, CIVILIAN = 0.4, PIRATE = 0.1, SPANISH = 0.1)
	battle_name = "new colony"
	mission_start_message = "<big>Europeans</b> have reached the shore! The <b>Colonists</b> must build their villages. The gracewall will be up after 25 minutes.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND COLONISTS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Colony Building RP"
	is_RP = TRUE
	grace_wall_timer = 15000
/obj/map_metadata/colony/New()
	..()
	spawn(18000)
		seasons()

obj/map_metadata/colony/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_1713 && !J.is_deathmatch)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/colony/cross_message(faction)
	return ""


