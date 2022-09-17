
/obj/map_metadata/pioneers
	ID = MAP_PIONEERS
	title = "Pioneers"
	lobby_icon = "icons/lobby/wildwest.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	has_hunger = TRUE
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
	mission_start_message = "<big>Pioneers</b> have reached the frontier! The <b>Pioneers</b> must build their town. The gracewall will be up after 25 minutes.</big><br><span class = 'notice'><i>THIS IS A RP MAP - PLAYERS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	faction2 = INDIANS
	songs = list(
		"Nassau Shores:1" = "sound/music/nassau_shores.ogg",)
	gamemode = "Pioneer Building RP"
	grace_wall_timer = 15000


/obj/map_metadata/pioneers/New()
	..()
	spawn(18000)
		seasons()


obj/map_metadata/pioneers/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_pioneer == TRUE)
			. = TRUE
		else if (J.is_civil_war == TRUE || J.is_deal == TRUE)
			. = FALSE
		else
			. = FALSE
	else if (istype(J, /datum/job/indians))
		if (J.is_1713 == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/pioneers/cross_message(faction)
	return ""


//////////////////////////////////
////////Pioneer Wasteland 2///////////////

/obj/map_metadata/pioneers/wasteland_two
	ID = MAP_PIONEERS_WASTELAND_2
	title = "Pioneers Wasteland II"
	gamemode = "Zombie Wasteland"
	civilizations = TRUE
	is_zombie = TRUE
	mission_start_message = "<big>Something has gone terribly wrong. Monsters roam the world, and society has fallen. Can the town survive?</big><br><br> <i>***Map Mechanics*** <br><br>- Zombies will spawn in some areas; anywhere could be dangerous.<br><br>- Bodies will turn into zombies after a while! To prevent this, <b>remove the head from the body</b>.<br><br>- Getting bit or scratched by a zombie will not automatically turn you into one. However, theres a small chance you get <b>infected with the zombie virus</b>. You will get high fevers and massive headaches. This can be prevented by taking <b>Potassium Iodide</b>, as it will kill the virus, even after symptoms have started.</i>"
	ambience = list('sound/ambience/desert.ogg')
	default_research = 105
	research_active = FALSE
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = FALSE
	age6_done = FALSE
	age7_done = FALSE
	age8_done = FALSE
