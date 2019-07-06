#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/civilizations
	ID = MAP_CIVILIZATIONS
	title = "Two Kingdoms (300x100x2)"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1013"
	civilizations = TRUE
	var/tribes_nr = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the kingdoms"
	mission_start_message = "<big>Two medieval kingdoms rule this land. They have <b>24 hours</b> to fortify and build a military. Who will win?</big><br><b>Wiki Guide: http://1713.eu/wiki/index.php/Civilizations</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions_run = TRUE
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/words_through_the_sky.ogg',)
	default_research = 48
	gamemode = "Two Kingdoms"
	ordinal_age = 2
	age1_done = TRUE
	age2_done = TRUE
	research_active = FALSE

/obj/map_metadata/civilizations/New()
	var/newnamea = list("West Kingdom" = list(default_research,default_research,default_research,null,0,"saltire","#D4AF37","#660000"))
	var/newnameb = list("East Kingdom" = list(default_research,default_research,default_research,null,0,"saltire","#C0C0C0","#006600"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	spawn(1)

	..()
	spawn(18000)
		seasons()

/obj/map_metadata/civilizations/proc/walldown()
	for (var/turf/wall/rockwall/RW)
		RW.ChangeTurf(/turf/floor/dirt/jungledirt)
	world << "<font color=#CECE00><big><b>THE WALL HAS GONE DOWN!</b></big></font>"
	admin_ended_all_grace_periods = TRUE
	return
/obj/map_metadata/civilizations/proc/wallup()
	for (var/turf/floor/dirt/jungledirt/JD)
		JD.ChangeTurf(/turf/wall/rockwall)
	world <<"<font color=#CECE00><big><b>THE WALL HAS GONE UP!</b></big></font>"
	admin_ended_all_grace_periods = FALSE
	return

/obj/map_metadata/civilizations/faction2_can_cross_blocks()
	return (admin_ended_all_grace_periods)

/obj/map_metadata/civilizations/faction1_can_cross_blocks()
	return (admin_ended_all_grace_periods)

/obj/map_metadata/civilizations/cross_message(faction)
	return "<big><b>THE GRACE PERIOD HAS ENDED!</b></big>"

/obj/map_metadata/civilizations/proc/seasons()
	if (season == "WINTER")
		season = "SPRING"
		world << "<big>The weather is getting warmer. It is now <b>Spring</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/winter/D)
			if (prob(60))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(60))
				G.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/dirt/burned/B)
			if (get_area(B).location == AREA_OUTSIDE)
				if (prob(60))
					B.ChangeTurf(/turf/floor/dirt)
		spawn(150)
			change_weather(WEATHER_NONE)
			for (var/obj/structure/window/snowwall/SW1)
				if (prob(60))
					qdel(SW1)
			for (var/obj/covers/snow_wall/SW2)
				if (prob(60))
					qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3)
				if (prob(60))
					qdel(SW3)
		spawn(1500)
			for (var/turf/floor/beach/water/ice/salty/SW)
				SW.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			for (var/turf/floor/beach/water/ice/W)
				W.ChangeTurf(/turf/floor/beach/water)
		spawn(3000)
			for (var/turf/floor/dirt/winter/D)
				D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G)
				G.ChangeTurf(/turf/floor/grass)
			for (var/obj/structure/window/snowwall/SW1)
				qdel(SW1)
			for (var/obj/covers/snow_wall/SW2)
				qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3)
				qdel(SW3)
	else if (season == "SUMMER")
		season = "FALL"
		world << "<big>The leaves start to fall and the weather gets colder. It is now <b>Fall</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/D)
			if (prob(50) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/ploughed) && D.z == world.maxz)
				D.ChangeTurf(/turf/floor/grass)
			D.update_icon()
		for (var/turf/floor/dirt/burned/BD)
			BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/grass/G)
			G.update_icon()
		spawn(100)
			change_weather(WEATHER_RAIN)
		spawn(15000)
			change_weather(WEATHER_SNOW)
			for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
				if (z == world.maxz && prob(40) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust))
					D.ChangeTurf(/turf/floor/dirt/winter)
			for (var/turf/floor/grass/G)
				if (prob(40))
					G.ChangeTurf(/turf/floor/winter/grass)
			spawn(1200)
				for (var/turf/floor/dirt/D)
					if (!istype(D,/turf/floor/dirt/winter))
						if (D.z == world.maxz && prob(50))
							D.ChangeTurf(/turf/floor/dirt/winter)
				for (var/turf/floor/grass/G)
					if (prob(50))
						G.ChangeTurf(/turf/floor/winter/grass)
	else if (season == "FALL")
		season = "WINTER"
		world << "<big>The weather gets very cold. <b>Winter</b> has arrived.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
			if (!istype(D,/turf/floor/dirt/winter) && !istype(D,/turf/floor/dirt/underground))
				if (D.z == world.maxz)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/G)
			G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_SNOW)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/SW)
			if (SW.water_level <= 50 && SW.z > 1)
				SW.ChangeTurf(/turf/floor/beach/water/ice/salty)
		for (var/turf/floor/beach/water/W)
			if (W.water_level <= 50 && W.z > 1)
				W.ChangeTurf(/turf/floor/beach/water/ice)
		spawn(12000)
			for (var/turf/floor/dirt/winter/D)
				if (prob(20))
					D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G)
				if (prob(20))
					G.ChangeTurf(/turf/floor/grass)
	else if (season == "SPRING")
		season = "SUMMER"
		world << "<big>The weather is warm. It is now <b>Summer</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/winter/D)
			D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			G.ChangeTurf(/turf/floor/grass)
		spawn(100)
			change_weather(WEATHER_NONE)
	spawn(18000)
		seasons()

#undef NO_WINNER