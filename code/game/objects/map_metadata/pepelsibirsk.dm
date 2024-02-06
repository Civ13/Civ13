/obj/map_metadata/pepelsibirsk
	ID = MAP_PEPELSIBIRSK
	title = "Pepelsibirsk"
	lobby_icon = "icons/lobby/civ13.gif"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 12000 // 2 minutes
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1976 A.D."
	ordinal_age = 7
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>Following a limited thermonuclear exchange which saw most central authorities in the northern hemisphere collapse, it appears Pepelsibirsk was left mostly untouched. You must bring the city to prosperity!</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/toska.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Cold War"
	var/real_season = "WINTER" // for seasons

	//Trader spawnpoint
	var/trader_spawnpoint = "TraderArrivals"
	
	// Variables defining starting faction relations
	var/civ_relations = 50
	var/mil_relations = 50
	var/china_relations = 50
	var/soviet_relations = 50
	var/pacific_relations = 50
	
/obj/map_metadata/pepelsibirsk/New()
	..()
	for (var/obj/structure/wild/tree/live_tree/TREES)
		TREES.change_season()
	spawn(9000)
		seasons()

/obj/map_metadata/pepelsibirsk/seasons()
	if (real_season == "SUMMER")
		season = "WINTER"
		world << "<big>It's getting very cold. <b>Winter</b> has started.</big>"
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/SB)
			new/obj/structure/wild/smallbush/winter(SB.loc)
			qdel(SB)
		for (var/turf/floor/dirt/D)
			if (!istype(D,/turf/floor/dirt/winter) && !istype(D,/turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust))
				var/area/A = get_area(D)
				if  (A.location != AREA_INSIDE)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/G)
			var/area/A = get_area(G)
			if  (A.location != AREA_INSIDE)
				G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_WET)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/W)
			W.ChangeTurf(/turf/floor/beach/water/ice/salty)
		real_season = "WINTER"
	else
		season = "SUMMER"
		world << "<big>The weather gets warmer. <b>Summer</b> has started.</big>"
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/winter/SBW)
			new/obj/structure/wild/smallbush(SBW.loc)
			qdel(SBW)
		for (var/turf/floor/dirt/winter/D)
			if (prob(50))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(50))
				G.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/dirt/burned/B)
			if (prob(60))
				B.ChangeTurf(/turf/floor/grass)
		spawn(150)
			change_weather(WEATHER_NONE)
		spawn(1500)
		for (var/turf/floor/beach/water/ice/salty/W)
			if (prob(65) && W.water_level >= 50)
				W.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
		real_season = "SUMMER"

	if (real_season == "SUMMER")
		spawn(9000)
			seasons()
	else if (real_season == "WINTER")
		spawn(27000)
			seasons()

/obj/map_metadata/pepelsibirsk/cross_message(faction)
	return ""

/obj/map_metadata/pepelsibirsk/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/pepelsibirsk/proc/send_traders() //Picks a turf from traders_arrivals and sends traders there if relations are high enough.
	var/spawnpoint
	var/list/turfs = list()
	spawn (1)
		turfs = latejoin_turfs[trader_spawnpoint]
		spawnpoint = pick(turfs)
		if (china_relations >= 26)
			// spawn a trader from the PRC

		if (soviet_relations >= 26)
			// spawn a trader from the USSR

		if (pacific_relations >= 26)
			// spawn a trader from the USP

		
	spawn (6000) //Deletes all the traders after 10 minutes
		
		return

	spawn (18000)
		send_traders()
		return

/obj/map_metadata/pepelsibirsk/proc/check_relations_msg()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Diplomatic Relations:</b></font></span>"
		world << "<br><font size = 3><span class = 'notice'>Narodnyygorod: <b>[civ_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>Pepelsibirsk 1: <b>[mil_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>People's Republic of China: <b>[china_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>Union of Soviet Socialist Republics: <b>[soviet_relations]</b></span></font>"
		world << "<br><font size = 3><span class = 'notice'>United States of the Pacific: <b>[pacific_relations]</b></span></font>"

	spawn(3000)
		check_relations_msg()
	return