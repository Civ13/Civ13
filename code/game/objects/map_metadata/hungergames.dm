/obj/map_metadata/hunger_games
	ID = MAP_HUNGERGAMES
	title = "Hunger Games (need staff)"
	lobby_icon = "icons/lobby/battleroyale.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 36000000
	is_singlefaction = TRUE
	battleroyale = TRUE

	no_winner ="The fighting is still going."

	faction_organization = list(PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "76th annual hunger games"
	mission_start_message = "<font size=4>The 76th Annual Hunger Games will have 40 tributes competing, <b>Last standing tribute wins!</b> 3 minutes beforeyou may step off your platforms.</font>"
	var/winner_name = "Unknown"
	var/winner_ckey = "Unknown"
	faction1 = PIRATES
	var/message = ""
	gamemode = "Battleroyale"
	required_players = 12
	has_hunger = TRUE
	var/list/closed_areas = list()
	grace_wall_timer = 1800

/obj/map_metadata/hunger_games/job_enabled_specialcheck(var/datum/job/J)

	..()
	if (J.is_event_role == TRUE)
		J.total_positions = 40
		J.min_positions = 40
		J.max_positions = 40
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/hunger_games/cross_message(faction)
	if (faction == PIRATES)
		return "<font size = 4><b>The 76th annual hunger games have started!</b></font>"

/obj/map_metadata/hunger_games/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 54000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
		last_win_condition = win_condition.hash
		message = "90 minutes have passed! The hunger games have ended without a winner!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 1800)
		if (alive_n_of_side(PIRATES) <= 1 && !win_condition_spam_check)
			for (var/mob/living/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						winner_name =  H.name
						winner_ckey = H.ckey
						give_award(winner_ckey,winner_name,1)
						var/warning_sound = sound('sound/effects/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
						for (var/mob/M in player_list)
							M.client << warning_sound
						message = "The hunger games are over! <b>[winner_ckey]</b> is the victor!"
						world << "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>"
						win_condition_spam_check = TRUE
			ticker.finished = TRUE
			next_win = -1
			current_win_condition = no_winner
			win_condition.hash = 0
			last_win_condition = win_condition.hash
			return FALSE

/obj/map_metadata/hunger_games/proc/closing_areas()
	if (processes.ticker.playtime_elapsed < 1800)
		spawn(300)
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
			if ("none")
				ar_to_close_string = "None"
		ar_to_close_timeleft = 30
		world << "<big><b>The [ar_to_close_string] Area will close in 60 seconds!</big></b>"
		spawn(275)
			warn_closing_areas(ar_to_close,30)
			spawn(100)
				warn_closing_areas(ar_to_close,20)
				spawn(100)
					warn_closing_areas(ar_to_close,10)
		spawn(300)
			ar_to_close_timeleft = 15
			world << "<big><b>The [ar_to_close_string] Area will close in 30 seconds!</big></b>"
			spawn(300)
				close_area(ar_to_close)
				closing_areas()
				return ar_to_close_string
	else
		return "too many areas closed"

/obj/map_metadata/hunger_games/proc/warn_closing_areas(var/artc = null, var/time=30)
	var/sound_to_play = null
	switch(artc)
		if ("one")
			sound_to_play = 'sound/voice/battleroyale/close_nw.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Western Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("two")
			sound_to_play = 'sound/voice/battleroyale/close_ne.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Eastern Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("three")
			sound_to_play = 'sound/voice/battleroyale/close_w.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Western Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("four")
			sound_to_play = 'sound/voice/battleroyale/close_e.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Eastern Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("five")
			sound_to_play = 'sound/voice/battleroyale/close_sw.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Western Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("six")
			sound_to_play = 'sound/voice/battleroyale/close_se.ogg'
			for(var/mob/living/human/H in player_list)
				if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six) || istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six/inside) || (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Eastern Area"))
					playsound(H, sound_to_play, 100, FALSE, -1)
					spawn(30)
						playsound(H, "sound/voice/battleroyale/close[time].ogg", 100, FALSE, -1)
		if ("none")
			return
/obj/map_metadata/hunger_games/proc/close_area(var/artc = null)
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
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/one/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Western Area")
						H.crush()
			world << "<big>The <b>North-Western</b> Area has been closed!</big>"
			closed_areas += list("one")
			return
		if ("two")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/two/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/two/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/two/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "North-Eastern Area")
						H.crush()
			world << "<big>The <b>North-Eastern</b> Area has been closed!</big>"
			closed_areas += list("two")
			return
		if ("three")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/three/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/three/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/three/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Western Area")
						H.crush()
			world << "<big>The <b>Western</b> Area has been closed!</big>"
			closed_areas += list("three")
			return
		if ("four")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/four/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/four/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/four/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "Eastern Area")
						H.crush()
			world << "<big>The <b>Eastern</b> Area has been closed!</big>"
			closed_areas += list("four")
			return
		if ("five")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/five/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/five/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/five/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Western Area")
						H.crush()
			world << "<big>The <b>South-Western</b> Area has been closed!</big>"
			closed_areas += list("five")
			return
		if ("six")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/six/border))
				T.ChangeTurf(/turf/wall/indestructable/black)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/battleroyale/six/border/inside))
				T.ChangeTurf(/turf/wall/indestructable/black)
			spawn(20)
				for(var/mob/living/human/H in player_list)
					if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/battleroyale/six/inside))
						H.crush()
					else if (istype(get_area(get_turf(H)),/area/caribbean/no_mans_land/invisible_wall) && get_area(get_turf(H)).name == "South-Eastern Area")
						H.crush()
			world << "<big>The <b>South-Eastern</b> Area has been closed!</big>"
			closed_areas += list("six")
			return

/obj/map_metadata/hunger_games/save_awards()
	var/F = file("SQL/awards_br.txt")
	if (!awards.len || awards.len <= 12)
		return
	for (var/i = 1, i <= awards.len, i++)
		if (awards[i][1]!="")
			awards[i][6] =  awards.len
			var/txtexport = list2text(awards[i])
			text2file(txtexport,F)
			var/place2text = ""
			if(awards[i][3] == 1)
				place2text = "1st"
			else if(awards[i][3] == 2)
				place2text = "2nd"
			else if(awards[i][3] == 3)
				place2text = "3rd"
			else if(awards[i][3] == 4)
				place2text = "4th"
			else if(awards[i][3] == 5)
				place2text = "5th"
			else
				place2text = "[awards[i][3]]th"
			world << "[awards[i][2]] ([awards[i][1]]) placed <b>[place2text]</b>!"
	return TRUE

/obj/map_metadata/hunger_games/give_award(var/_ckey, var/charname, var/place)
	awards += list(list(_ckey,charname,place,time2text(world.realtime, "YYYY/MM/DD"),src.title))
	return