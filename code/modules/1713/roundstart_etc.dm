var/roundstart_time = 0
var/grace_period = TRUE
var/game_started = FALSE
var/train_checked = FALSE
var/secret_ladder_message = null
var/GRACE_PERIOD_LENGTH = 7

/hook/roundstart/proc/game_start()

	roundstart_time = world.realtime

	// after the game mode has been announced.
	spawn (5)
		spawn (0)
			while (ticker.current_state != GAME_STATE_PLAYING)
				sleep(1)
			if (map)
				switch (map.ID)
					if (MAP_FOOTBALL)
						time_of_day = "Midday"
					if (MAP_FOOTBALL_CAMPAIGN)
						time_of_day = "Midday"
					if (MAP_CAMPAIGN)
						time_of_day = "Morning"
					if (MAP_DRUG_BUST)
						time_of_day = "Night"
			update_lighting(time_of_day, null, FALSE)
			if (!map || !map.no_time_of_day_cycle)
				spawn (0)
					while (!processes.time_of_day_change || !processes.time_of_day_change.setup_lighting)
						sleep(1)
					world << "<br><font size=3><span class = 'notice'>It's <b>[lowertext(processes.time_of_day_change.changeto)]</b>, and the season is <b>[get_season()]</b>.</span></font>"

	// open squad preparation doors
	for (var/obj/structure/simple_door/key_door/keydoor in door_list)
		if (findtext(keydoor.name, "Squad"))
			if (findtext(keydoor.name, "Preparation"))
				keydoor.Open()
	return TRUE

// this is roundstart because we need to wait for objs to be created
/hook/roundstart/proc/nature()
	spawn(1)
	if (map && (map.nomads && !map.override_mapgen) || map.force_mapgen)
		spawn(10)
			map.seed_the_map()
	return TRUE

/obj/map_metadata/proc/seed_the_map()
	var/list/jungleriverturfs = list()
	var/list/seaturfs = list()
	var/list/riverturfs = list()
	var/list/jungleturfs = list()
	for (var/turf/floor/F in world)
		F.plant()
		if (istype(F, /turf/floor/dirt/jungledirt))
			jungleturfs += F
		else if (istype(F, /turf/floor/beach/water/shallowsaltwater) || istype(F, /turf/floor/beach/water/deep/saltwater))
			seaturfs += F
		else if (istype(F, /turf/floor/beach/water/jungle))
			jungleriverturfs += F
			riverturfs += F
		else if (istype(F, /turf/floor/beach/water) && !istype(F, /turf/floor/beach/water/ice) && !istype(F, /turf/floor/beach/water/swamp) && !istype(F, /turf/floor/beach/water/flooded))
			riverturfs += F
	//gets the total number of tiles in the world, to dinamically distribute fauna and flora
	spawn(200)
		for (var/i = 1, i <= riverturfs.len/800, i++)
			var/turf/areaspawn = safepick(riverturfs)
			new/obj/structure/fish/salmon(areaspawn)
	spawn(300)
		for (var/i = 1, i <= seaturfs.len/1400, i++)
			var/turf/areaspawn = safepick(seaturfs)
			new/obj/structure/fish(areaspawn)
	spawn(400)
		for (var/i = 1, i <= jungleriverturfs.len/15, i++)
			var/turf/areaspawn = safepick(jungleriverturfs)
			new/obj/structure/piranha(areaspawn)
	spawn(500)
		for (var/i = 1, i <= jungleturfs.len/1200, i++)
			var/turf/areaspawn = safepick(jungleturfs)
			new/obj/structure/anthill(areaspawn)
// ditto
/hook/roundstart/proc/do_seasonal_stuff()
	spawn (1)
//		world << "<span class = 'notice'>Setting up seasons.</span>"
	if (map.ID == MAP_NOMADS_DESERT || map.ID == MAP_NOMADS_JUNGLE || map.ID == MAP_ROAD_TO_DAK_TO || map.ID == MAP_ALLEYWAY)
		season = "Wet Season"
	else if (map.ID == MAP_NOMADS_ICE_AGE || map.ID == MAP_GULAG13)
		season = "WINTER"
	else if (map.ID == MAP_HILL_203)
		season = "FALL"
	else if (map.ID == MAP_TSARITSYN)
		season = "FALL"
	else
		season = "SPRING"

	return TRUE

	for (var/grass in grass_turf_list)

		var/turf/floor/grass/G = grass

		if (!G || G.z > 1 || (!G.uses_winter_overlay))
			continue

		G.season = season

		var/area/A = get_area(G)

		if (A.location == AREA_INSIDE)
			continue

		if (G.season != "SPRING")
			G.overlays.Cut()

		if (G.uses_winter_overlay)
			if (G.season == "WINTER")
				if (G.uses_winter_overlay)
					G.color = DEAD_COLOR

				for (var/obj/structure/wild/W in G.contents)
					if (istype(W))
						W.color = DEAD_COLOR
						var/icon/W_icon = icon(W.icon, W.icon_state)
						W_icon.Blend(icon('icons/turf/snow.dmi', (istype(W, /obj/structure/wild/tree) ? "wild_overlay" : "tree_overlay")), ICON_MULTIPLY)
						W.icon = W_icon

			else if (G.season == "SUMMER")
				if (G.uses_winter_overlay)
					G.color = SUMMER_COLOR
				for (var/obj/structure/wild/W in G.contents)
					if (istype(W))
						var/obj/W_overlay = new(G)
						W_overlay.icon = W.icon
						W_overlay.icon_state = W.icon_state
						W_overlay.layer = W.layer + 0.01
						W_overlay.alpha = 133
						W_overlay.pixel_x = W.pixel_x
						W_overlay.pixel_y = W.pixel_y
						W_overlay.name = ""
						W_overlay.color = SUMMER_COLOR
						W_overlay.special_id = "seasons"

			else if (G.season == "FALL")
				if (G.uses_winter_overlay)
					G.color = FALL_COLOR
				for (var/obj/structure/wild/W in G.contents)
					if (istype(W))
						var/obj/W_overlay = new(G)
						W_overlay.icon = W.icon
						W_overlay.icon_state = W.icon_state
						W_overlay.layer = W.layer + 0.01
						W_overlay.alpha = 133
						W_overlay.pixel_x = W.pixel_x
						W_overlay.pixel_y = W.pixel_y
						W_overlay.name = ""
						W_overlay.color = FALL_COLOR
						W_overlay.special_id = "seasons"

		if (G.season != "SPRING" && G.uses_winter_overlay)
			for (var/cache_key in G.floor_decal_cache_keys)
				var/image/decal = floor_decals[cache_key]
				var/obj/o = new(G)
				o.icon = decal.icon
				o.icon_state = decal.icon_state
				o.dir = decal.dir
				o.color = decal.color
				o.layer = 2.04 // above snow
				o.alpha = decal.alpha
				o.name = ""

//		spawn (0)
//			for (var/obj/snow_maker/SM in G)
//				qdel(SM)

	return TRUE