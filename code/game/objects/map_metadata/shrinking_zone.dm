// Shrinking play area shared by the Battle Royale and Hunger Games maps. The
// map is split into six zones under /area/caribbean/no_mans_land/battleroyale;
// closing_areas() picks a zone next to the ones already closed, warns players
// and then close_area() walls it off and crushes anyone still inside.

// Zone id -> compass name, used for warnings and the invisible wall area names.
var/global/list/zone_area_names = list(
	"one"   = "North-Western",
	"two"   = "North-Eastern",
	"three" = "Western",
	"four"  = "Eastern",
	"five"  = "South-Western",
	"six"   = "South-Eastern",
	)

/obj/map_metadata
	var/list/closed_areas = list()
	// Round time before the first zone closes, and how often to check until then.
	var/zone_first_close = 1200
	var/zone_recheck_delay = 200

/obj/map_metadata/proc/closing_areas()
	if (processes.ticker.playtime_elapsed < zone_first_close)
		spawn(zone_recheck_delay)
			closing_areas()
		return "too early to close areas"

	var/list/all_areas = list("one","two","three","four","five","six")
	var/list/possible_areas = all_areas
	if (closed_areas.len)
		for (var/i in closed_areas)
			possible_areas -= i
	if (possible_areas.len > 1)
		ar_to_close = pick("one","two","five","six")
		ar_to_close_string = "None"
		if (closed_areas.len)
			if ("one" in closed_areas)
				if ("two" in closed_areas)
					if ("three" in closed_areas)
						if ("four" in closed_areas)
							if ("five" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "five"
						else
							ar_to_close = "four"
					else
						ar_to_close = "three"
				else
					ar_to_close = "two"
			else if ("two" in closed_areas)
				if ("one" in closed_areas)
					if ("four" in closed_areas)
						if ("three" in closed_areas)
							if ("six" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "six"
						else
							ar_to_close = "three"
					else
						ar_to_close = "four"
				else
					ar_to_close = "one"
			else if ("three" in closed_areas)
				if ("one" in closed_areas)
					if ("five" in closed_areas)
						if ("six" in closed_areas)
							if ("two" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "two"
						else
							ar_to_close = "six"
					else
						ar_to_close = "five"
				else
					ar_to_close = "one"
			else if ("four" in closed_areas)
				if ("six" in closed_areas)
					if ("two" in closed_areas)
						if ("five" in closed_areas)
							if ("one" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "one"
						else
							ar_to_close = "five"
					else
						ar_to_close = "two"
				else
					ar_to_close = "six"
			else if ("five" in closed_areas)
				if ("six" in closed_areas)
					if ("three" in closed_areas)
						if ("four" in closed_areas)
							if ("one" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "one"
						else
							ar_to_close = "four"
					else
						ar_to_close = "three"
				else
					ar_to_close = "six"
			else if ("six" in closed_areas)
				if ("five" in closed_areas)
					if ("four" in closed_areas)
						if ("three" in closed_areas)
							if ("two" in closed_areas)
								ar_to_close_string = "None"
								return "too many areas closed"
							else
								ar_to_close = "two"
						else
							ar_to_close = "three"
					else
						ar_to_close = "four"
				else
					ar_to_close = "five"
		ar_to_close_string = zone_area_names[ar_to_close] || "None"
		ar_to_close_timeleft = 30
		to_chat(world, "<big><b>The [ar_to_close_string] Area will close in 60 seconds!</b></big>")
		spawn(275)
			warn_closing_areas(ar_to_close,30)
			spawn(100)
				warn_closing_areas(ar_to_close,20)
				spawn(100)
					warn_closing_areas(ar_to_close,10)
		spawn(300)
			ar_to_close_timeleft = 15
			to_chat(world, "<big><b>The [ar_to_close_string] Area will close in 30 seconds!</b></big>")
			spawn(300)
				close_area(ar_to_close)
				closing_areas()
	else
		return "too many areas closed"

/obj/map_metadata/proc/warn_closing_areas(var/artc = null, var/time=30)
	if (artc == "none") return

	// Define corresponding sounds to the map parts
	var/area_sound_map = list(
		"one"   = "sound/voice/battleroyale/close_nw.ogg",
		"two"   = "sound/voice/battleroyale/close_ne.ogg",
		"three" = "sound/voice/battleroyale/close_w.ogg",
		"four"  = "sound/voice/battleroyale/close_e.ogg",
		"five"  = "sound/voice/battleroyale/close_sw.ogg",
		"six"   = "sound/voice/battleroyale/close_se.ogg"
		)

	var/sound_to_play = area_sound_map[artc]

	for(var/mob/living/human/H in player_list)
		var/area/A = get_area(get_turf(H))

		// Dynamic path construction for checking area types
		var/base_area_path = "/area/caribbean/no_mans_land/battleroyale/" + artc
		var/inside_area_path = base_area_path + "/inside"

		// Convert string paths to actual paths
		var/base_area_type = text2path(base_area_path)
		var/inside_area_type = text2path(inside_area_path)

		// Check if the area matches any of the dynamic paths
		if ((istype(A, base_area_type) || istype(A, inside_area_type)) || (istype(A, /area/caribbean/no_mans_land/invisible_wall) && A.name == "[zone_area_names[artc]] Area"))
			playsound(H, sound_to_play, 100, FALSE, -1)
			spawn(time)
				playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)

/obj/map_metadata/proc/close_area(var/artc = null)
	if (closed_areas.len >= 5)
		return
	if (!artc || (artc in closed_areas))
		return
	var/area_name = zone_area_names[artc]
	if (!area_name)
		return
	var/zone_path = "/area/caribbean/no_mans_land/battleroyale/[artc]"
	var/zone_type = text2path(zone_path)
	var/inside_type = text2path("[zone_path]/inside")
	for (var/turf/T in get_area_turfs(text2path("[zone_path]/border")))
		T.ChangeTurf(/turf/wall/indestructable/black)
	for (var/turf/T in get_area_turfs(text2path("[zone_path]/border/inside")))
		T.ChangeTurf(/turf/wall/indestructable/black)
	spawn(20)
		for(var/mob/living/human/H in player_list)
			var/area/A = get_area(get_turf(H))
			if (istype(A, zone_type) || istype(A, inside_type) || (istype(A, /area/caribbean/no_mans_land/invisible_wall) && A.name == "[area_name] Area"))
				H.crush()
	to_chat(world, "<big>The <b>[area_name]</b> Area has been closed!</big>")
	closed_areas += list(artc)
