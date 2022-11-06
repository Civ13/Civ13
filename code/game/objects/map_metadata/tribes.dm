
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes"
	no_winner ="The round is proceeding normally."
	lobby_icon = "icons/lobby/fantasy.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/temperate,/area/caribbean/no_mans_land/invisible_wall/desert,/area/caribbean/no_mans_land/invisible_wall/semiarid,/area/caribbean/no_mans_land/invisible_wall/taiga,/area/caribbean/no_mans_land/invisible_wall/tundra,/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 3600 // 6 minutes!
	force_mapgen = FALSE
	has_hunger = TRUE
	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "The Lost Time"
	ordinal_age = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "The Four Tribes"
	mission_start_message = "<big>Several tribes are settling in this land. Will they be able to get along?<br>The grace wall will be up for <b>25 minutes</b>.</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME, WEATHER_SMOG)
	availablefactions = list("Orc tribesman")
	availablefactions_run = TRUE
	civilizations = TRUE
	is_RP = TRUE
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Faction-Based RP"
	nomads = TRUE
	grace_wall_timer = 15000
/obj/map_metadata/tribes/New()
	var/newnamea = list("Orc Horde" = list(48,48,48,null,0,"skull","#9A1313","#000000",0,0))
	var/newnameb = list("Ant Colony" = list(35,35,35,null,0,"star","#0C1EA7","#67A7CE",0,0))
	var/newnamec = list("Gorilla Tribe" = list(40,40,40,null,0,"sun","#9A9A9A","#098518",0,0))
	var/newnamed = list("Human Kingdom" = list(62,62,62,null,0,"cross","#E5C100","#FFFFFF",0,0))
	var/newnamee = list("Lizard Clan" = list(35,35,35,null,0,"big_cross","#669932","#1E1E1E",0,0))
	var/newnamef = list("Wolfpack" = list(35,35,35,null,0,"moon","#FFFFFF","#848484",0,0))
	var/newnameg = list("Crustacean Union" = list(35,35,35,null,0,"seashell","#EEEEEE","#7F0000",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	custom_civs += newnamee
	custom_civs += newnamef
	custom_civs += newnameg
		//////////////////////////////////////creator, type, points, symbol, color1, color2, clergy style
	var/newnamera = list("Order of the Great Tree" = list(null,"Knowledge",0, "Tree","#098518","#9A9A9A","Shamans")) //gorillas
	var/newnamerb = list("The Great Serpent" = list(null,"Combat",0, "Skull","#654321","#014421","Shamans")) //lizards
	var/newnamerc = list("Father in the Sky" = list(null,"Production",0, "Cross","#FFD700","#FFFFFF","Priests")) //hoo-mans
	var/newnamerd = list("Followers of Morgoth" = list(null,"Combat",0, "Skull","#000000","#9A1313","Cultists")) //orcs
	var/newnamere = list("Followers of the Hive Mother" = list(null,"Knowledge",0, "Star","#67A7CE","#0C1EA7","Monks")) //ants
	var/newnamerf = list("Moon Worshippers" = list(null,"Combat",0, "Moon","#848484","#FFFFFF","Priests")) //wolves
	var/newnamerg = list("Cthulhu" = list(null,"Production",0, "Sun","#ADFF2F","#000000","Cultists")) //crustaceans
	custom_religions += newnamera
	custom_religions += newnamerb
	custom_religions += newnamerc
	custom_religions += newnamerd
	custom_religions += newnamere
	custom_religions += newnamerf
	custom_religions += newnamerg
	spawn(1)
		civilians_forceEnabled = TRUE

	spawn(18000)
		seasons()
	..()

/obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/tribes/cross_message(faction)
	return ""


/obj/map_metadata/tribes/three
	ID = MAP_THREE_TRIBES
	title = "Three Tribes"
	battle_name = "The Three Tribes"