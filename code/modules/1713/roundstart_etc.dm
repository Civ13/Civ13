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
			update_lighting(time_of_day, null, FALSE)
			if (!map || !map.meme)
				spawn (0)
					while (!processes.time_of_day_change || !processes.time_of_day_change.setup_lighting)
						sleep(1)
					world << "<br><font size=3><span class = 'notice'>It's <b>[lowertext(processes.time_of_day_change.changeto)]</b>, and the season is <b>[get_season()]</b>.</span></font>"

	// spawn mice so pirates have something to eat after they start starving

	// open squad preparation doors
	for (var/obj/structure/simple_door/key_door/keydoor in door_list)
		if (findtext(keydoor.name, "Squad"))
			if (findtext(keydoor.name, "Preparation"))
				keydoor.Open()
	return TRUE

// this is roundstart because we need to wait for objs to be created
/hook/roundstart/proc/nature()

	if (map.meme)
		return TRUE

	var/nature_chance = 100

	if (season == "WINTER")
		nature_chance = 70

	// create wild grasses in "clumps"
	spawn (1)
//		world << "<span class = 'notice'>Setting up wild grasses.</span>"

	for (var/grass in grass_turf_list)
		var/turf/floor/grass/G = grass
		if (!G || G.z > 1)
			continue

		if (prob(nature_chance))
			G.plant()

	return TRUE

// ditto
/hook/roundstart/proc/do_seasonal_stuff()
	spawn (1)
//		world << "<span class = 'notice'>Setting up seasons.</span>"
	if (map.ID == MAP_NOMADS_DESERT || map.ID == MAP_NOMADS_JUNGLE)
		season = "Wet Season"
	else if (map.ID == MAP_NOMADS_ICE_AGE)
		season = "WINTER"
	else if (map.ID == MAP_HILL203)
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
