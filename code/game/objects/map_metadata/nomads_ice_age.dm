#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_ice_age
	ID = MAP_NOMADS_ICE_AGE
	title = "Nomads (Ice Age) (275x275x2)"
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
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settling down. Will they be able to work together?</big><br><b>Wiki Guide: http://1713.eu/wiki/index.php/Nomads</b>"
	ambience = list('sound/ambience/desert.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/words_through_the_sky.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/real_season = "WINTER"

/obj/map_metadata/nomads_ice_age/New()
	..()
	for (var/obj/structure/wild/tree/live_tree/TREES)
		TREES.update_icon()
	spawn(9000)
		seasons()

/obj/map_metadata/nomads_ice_age/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_ice_age/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_ice_age/cross_message(faction)
	return ""

/obj/map_metadata/nomads_ice_age/proc/seasons()
	if (real_season == "SUMMER")
		season = "WINTER"
		world << "<big>It's getting very cold. <b>Winter</b> has started.</big>"
			change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
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
			change_weather(WEATHER_SNOW)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/W)
			W.ChangeTurf(/turf/floor/beach/water/ice/salty)
		real_season = "WINTER"
	else
		season = "SUMMER"
		world << "<big>The weather gets warmer. <b>Summer</b> has started.</big>"
			change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
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


/obj/map_metadata/nomads_ice_age/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER