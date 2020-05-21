/obj/map_metadata/battleroyale
	ID = MAP_BATTLEROYALE
	title = "Isla Robusta Battle Royale (125x125x1)"
	lobby_icon_state = "battleroyale"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	is_singlefaction = TRUE

	no_winner ="The fighting is still going."

	faction_organization = list(
		PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Isla Robusta"
	mission_start_message = "<font size=4>You and several other pirates were abandoned at this forsaken island. Only one can survive! <b>Last standing player wins!</b></font>"
	var/winner_name = "Unknown"
	var/winner_ckey = "Unknown"
	faction1 = PIRATES
	faction2 = CIVILIAN
	var/message = ""
	gamemode = "Battleroyale"
	required_players = 6
/obj/map_metadata/battleroyale/job_enabled_specialcheck(var/datum/job/J)

	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale) && !istype(J, /datum/job/pirates/battleroyale/modern))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/battleroyale/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/battleroyale/cross_message(faction)
	if (faction == PIRATES)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"

/obj/map_metadata/battleroyale/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		processes.python.execute("mapswap.py", "BATTLEROYALE_2")
		message = "30 minutes have passed! The combat has ended in a stalemate!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 1200)
		if (alive_n_of_side(PIRATES) <= 1 && !win_condition_spam_check)
			for (var/mob/living/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						winner_name =  H.name
						winner_ckey = H.ckey
						var/warning_sound = sound('sound/effects/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
						for (var/mob/M in player_list)
							M.client << warning_sound
						message = "The battle is over! [winner_name] ([winner_ckey]) was the winner!"
						world << "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>"
						win_condition_spam_check = TRUE
			ticker.finished = TRUE
			if (config.allowedgamemodes == "BR")
				processes.python.execute("mapswap.py", "BATTLEROYALE_2")
			return FALSE


/obj/map_metadata/battleroyale/two
	ID = MAP_BATTLEROYALE_2
	title = "Arab Town Battle Royale (100x100x1)"

	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Arab Town"
	mission_start_message = "<font size=4><b>Last standing player wins!</b><br>TWO MINUTES UNTIL THE INVISIBLE WALL DISAPPEARS!</font>"

	var/list/closed_areas = list()
/obj/map_metadata/battleroyale/two/New()
	..()
	spawn(1000)
		closing_areas()

/obj/map_metadata/battleroyale/two/job_enabled_specialcheck(var/datum/job/J)

	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale/modern))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/two/proc/closing_areas()
	if (processes.ticker.playtime_elapsed < 1200)
		spawn(600)
			closing_areas()
		return "too early to close areas"
	var/list/all_areas = list("one","two","three","four","five","six")
	var/list/possible_areas = all_areas
	if (closed_areas.len)
		for (var/i in closed_areas)
			possible_areas -= i
	if (possible_areas.len > 1)
		var/ar_to_close = pick("one","two","five","six")
		var/ar_to_close_string = ""
		if (closed_areas.len)
			if ("one" in closed_areas)
				if ("two" in closed_areas)
					if ("three" in closed_areas)
						if ("four" in closed_areas)
							if ("five" in closed_areas)
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
								return "too many areas closed"
							else
								ar_to_close = "two"
						else
							ar_to_close = "three"
					else
						ar_to_close = "four"
				else
					ar_to_close = "five"
		switch(ar_to_close)
			if ("one")
				ar_to_close_string = "North-Western"
			if ("two")
				ar_to_close_string = "North-Eastern"
			if ("three")
				ar_to_close_string = "Western"
			if ("four")
				ar_to_close_string = "Eastern"
			if ("five")
				ar_to_close_string = "South-Western"
			if ("six")
				ar_to_close_string = "South-Eastern"
		world << "<big><b>The [ar_to_close_string] area will close in 2 minutes!</big></b>"
		spawn(600)
			world << "<big><b>The [ar_to_close_string] area will close in 1 minute!</big></b>"
			spawn(600)
				close_area(ar_to_close)
				closing_areas()
				return ar_to_close_string
	else
		return "too many areas closed"

/obj/map_metadata/battleroyale/two/proc/close_area(var/artc = null)
	if (closed_areas.len >= 5)
		return
	if (!artc || artc in closed_areas)
		return

	switch(artc)
		if ("one")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/one/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/one/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Western Area")
						H.gib()
			world << "<big>The <b>North-Western</b> area has been closed!</big>"
			closed_areas += list("one")
			return
		if ("two")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/two/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/two/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Eastern Area")
						H.gib()
			world << "<big>The <b>North-Eastern</b> area has been closed!</big>"
			closed_areas += list("two")
			return
		if ("three")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/three/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/three/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Western Area")
						H.gib()
			world << "<big>The <b>Western</b> area has been closed!</big>"
			closed_areas += list("three")
			return
		if ("four")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/four/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/four/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Eastern Area")
						H.gib()
			world << "<big>The <b>Eastern</b> area has been closed!</big>"
			closed_areas += list("four")
			return
		if ("five")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/five/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/five/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Western Area")
						H.gib()
			world << "<big>The <b>South-Western</b> area has been closed!</big>"
			closed_areas += list("five")
			return
		if ("six")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/six/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/six/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in world)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six/inside))
						H.gib()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Eastern Area")
						H.gib()
			world << "<big>The <b>South-Eastern</b> area has been closed!</big>"
			closed_areas += list("six")
			return

/obj/screen/areashow
	maptext = "<center>Unknown Area</center>"
	maptext_width = 32*8
	maptext_x = (32*8 * -0.5)+32
	maptext_y = 32*0.75
	icon_state = "blank"

/obj/screen/areashow/New()
	..()
	var/area/parea = get_area(get_turf(parentmob))
	if (parea)
		maptext = "<center>[parea.name] ([parentmob.x],[parentmob.y])</center>"
	else
		maptext = "<center>Unknown Area</center>"
	icon_state = "blank"
	spawn(50)
		update()

/obj/screen/areashow/proc/update()
	if (!parentmob || !src)
		return
	var/area/parea = get_area(get_turf(parentmob))
	if (parea)
		maptext = "<center>[parea.name] ([parentmob.x],[parentmob.y])</center>"
	else
		maptext = "<center>Unknown Area</center>"
	spawn(10)
		update()