#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_continental
	ID = MAP_NOMADS_CONTINENTAL
	title = "Nomads (Continents) (200x500x2)"
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
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/empire_earth_intro.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()
	var/real_season = "wet"
/obj/map_metadata/nomads_continental/New()
	..()
	spawn(2500)
		for (var/i = 1, i <= 40, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/sea/sea))
			new/obj/structure/fish/salmon(areaspawn)

	spawn(1200)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_continental/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_continental/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_continental/cross_message(faction)
	return ""

/obj/map_metadata/nomads_continental/proc/seasons()
	if (real_season == "dry")
		season = "Wet Season"
		world << "<big>The <b>Wet Season</b> has started.</big>"
			change_weather_somehow()
		for (var/turf/floor/dirt/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for (var/turf/floor/dirt/ploughed/flooded/D)
			for(var/obj/OB in src.loc)
				if ( istype(OB, /obj/item) || istype(OB, /obj/structure) || istype(OB, /obj/effect) || istype(OB, /obj/small_fire) )
					qdel(OB)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = FALSE
				S.update_icon()
		for (var/turf/floor/beach/drywater/B)
			B.ChangeTurf(/turf/floor/beach/water/swamp)
		for (var/turf/floor/beach/drywater2/C)
			C.ChangeTurf(/turf/floor/beach/water/deep/swamp)
		for (var/turf/floor/dirt/jungledirt/JD)
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/burned/BD in get_area_turfs(/area/caribbean/nomads/desert))
			if (prob(75))
				BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/burned/BDD in get_area_turfs(/area/caribbean/nomads/forest))
			if (prob(75))
				BDD.ChangeTurf(/turf/floor/dirt/jungledirt)
		real_season = "wet"
	else
		season = "Dry Season"
		world << "<big>The <b>Dry Season</b> has started.</big>"
			change_weather_somehow()
		real_season = "dry"
		for(var/obj/structure/sink/S in get_area_turfs(/area/caribbean/nomads/desert))
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = TRUE
				S.update_icon()
		for (var/turf/floor/beach/water/swamp/D)
			if (D.z > 1)
				D.ChangeTurf(/turf/floor/beach/drywater)
		for (var/turf/floor/beach/water/deep/swamp/DS)
			if (DS.z > 1)
				DS.ChangeTurf(/turf/floor/beach/drywater2)
		for (var/turf/floor/beach/water/flooded/DF)
			if (DF.z > 1)
				DF.ChangeTurf(/turf/floor/dirt/flooded)
		spawn(12000)
			world << "<big>The sky starts to get cloudy... The <b>Wet Season</b> is coming in 10 minutes.</big>"

	spawn(20000)
		seasons()


/obj/map_metadata/nomads_continental/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER

