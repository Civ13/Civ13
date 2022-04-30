var/global/obj/map_metadata/map = null
//Max levels showing players how far to advance, appears on the Character tab
var/civmax_research = list(230,230,230)

/obj/map_metadata
	name = "control"
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x2"
	anchored = TRUE
	simulated = FALSE
	invisibility = 0
	var/ID = null // MUST be text, or aspects will break
	var/no_winner = "Neither side has captured the other side's base."
	var/title = null
	var/lobby_icon_state = "civ13"
	var/list/caribbean_blocking_area_types = list()
	var/list/allow_bullets_through_blocks = list()
	var/last_crossing_block_status[3]
	var/admin_ended_all_grace_periods = FALSE
	var/min_autobalance_players = 0
	var/respawn_delay = 3000
	var/list/valid_weather_types = list(WEATHER_WET, WEATHER_EXTREME, WEATHER_NONE, WEATHER_SMOG)
	var/availablefactions_run = FALSE
	var/list/availablefactions = list("Red Goose Tribesman")

//faction stuff
	var/faction1 = BRITISH
	var/faction2 = PIRATES
	var/faction1_points = 0
	var/faction2_points = 0
	var/list/faction_organization = list()
	var/list/initial_faction_organization = list()
	var/list/faction_distribution_coeffs = list(INFINITY) // list(INFINITY) = no hard locks on factions
	var/list/roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/pirates,
		list(BRITISH) = /area/caribbean/british)
	var/list/ambience = list('sound/ambience/ship1.ogg')
	var/list/songs = list(
		"Nassau Shores:1" = "sound/music/nassau_shores.ogg",)
	var/mission_start_message = "Round will start soon!"
	var/is_RP = FALSE
	var/squads = 1
	var/list/faction1_squads = list(
		1 = list(),
		2 = list(),
		3 = list(),
		4 = list(),
		5 = list(),
		6 = list(),
		7 = list(),
	)
	var/list/faction2_squads = list(
		1 = list(),
		2 = list(),
		3 = list(),
		4 = list(),
		5 = list(),
		6 = list(),
		7 = list(),
	)
	var/list/faction1_squad_leaders = list(
		1 = null,
		2 = null,
		3 = null,
		4 = null,
		5 = null,
		6 = null,
		7 = null,
	)
	var/list/faction2_squad_leaders = list(
		1 = null,
		2 = null,
		3 = null,
		4 = null,
		5 = null,
		6 = null,
		7 = null,
	)
	var/required_players = 1
	var/time_both_sides_locked = -1
	var/time_to_end_round_after_both_sides_locked = 9000
	var/admins_triggered_roundend = FALSE
	var/admins_triggered_noroundend = FALSE
	var/list/faction_targets = list()

	// win conditions 3.0 - Kachnov
	var/datum/win_condition/win_condition = null
	var/current_win_condition = "Neither side has captured the other side's base."
	var/last_win_condition = null // this is a hash
	var/current_winner = null
	var/current_loser = null
	var/next_win = -1
	var/win_condition_spam_check = FALSE
	var/list/awards = list()
	var/list/scores = list()
	var/list/warrants = list()
	var/list/vehicle_registations = list()
	var/list/gun_registations = list()
	// lighting
	var/list/times_of_day = list("Early Morning", "Morning", "Midday", "Afternoon", "Evening", "Night")
	var/list/zlevels_without_lighting = list()
	var/list/areas_without_lighting = list()

	var/round_finished = FALSE

	// fluff
	var/meme = FALSE
	var/battle_name = null

	//age (313 B.C., 1013, 1713, etc)
	var/age = "5000 B.C."
	var/ordinal_age = 0

	//weather
	var/blizzard = FALSE
	var/heat_wave = FALSE
	var/sandstorm = FALSE
	var/triggered_heatwave = FALSE
	var/triggered_blizzard = FALSE
	var/triggered_sandstorm = FALSE
	//civ stuff
	var/civilizations = FALSE
	var/nomads = FALSE
	var/has_hunger = FALSE
	var/list/custom_faction_nr = list()
	var/list/custom_civs = list()
	var/list/custom_religions = list()
	var/list/custom_religion_nr = list()
	var/list/custom_company = list() //name; percentage; realized (withdrawable) profits
	var/list/custom_company_nr = list()
	var/list/custom_company_value = list()
	var/list/sales_registry = list()
	var/list/custom_company_colors = list("Global" = list("#000000","#FFFFFF")) //1st color, 2nd color
	var/is_singlefaction = FALSE
	//1st value: industrial (crafting, philosophy) 2nd value: military (gunpowder, fencing, archery), 3rd value: health (anatomy, medical), 4th value: leader. 5th value: victory points
	var/civa_research = list(0,0,0,null,0)
	var/civb_research = list(0,0,0,null,0)
	var/civc_research = list(0,0,0,null,0)
	var/civd_research = list(0,0,0,null,0)
	var/cive_research = list(0,0,0,null,0)
	var/civf_research = list(0,0,0,null,0)

	var/list/facl = list()

	var/chad_mode = FALSE //Virgins BTFO
	var/chad_mode_plus = FALSE //SUPER CHAD
	var/gamemode = "Team Deathmatch"
	var/research_active = FALSE //if research can be done
	var/default_research = 0 //the starting research level
	var/is_zombie = FALSE
	var/is_fantrace = FALSE
	var/perschadplus = FALSE

	//autoresearch
	var/autoresearch = FALSE //if autoresearch is active
	var/autoresearch_mult = 0.4 // the amount research goes up per minute. Can be edited by admins.
	var/resourceresearch = FALSE

	var/age1_lim = 75
	var/age1_done = 0
	var/age1_top = 35

	var/age2_lim = 135
	var/age2_done = 0
	var/age2_timer = 24*36000
	var/age2_top = 65

	var/age3_lim = 230
	var/age3_done = 0
	var/age3_timer = 2*24*36000
	var/age3_top = 95

	var/age4_lim = 290
	var/age4_done = 0
	var/age4_timer = 3*24*36000
	var/age4_top = 105

	var/age5_lim = 335
	var/age5_done = 0
	var/age5_timer = 4*24*36000
	var/age5_top = 125

	var/age6_lim = 420
	var/age6_done = 0
	var/age6_timer = 5*24*36000
	var/age6_top = 178

	var/age7_lim = 540
	var/age7_done = 0
	var/age7_timer = 6*24*36000
	var/age7_top = 195

	var/age8_lim = 620
	var/age8_done = 0
	var/age8_timer = 7*24*36000
	var/age8_top = 230

	var/orespawners = 0

	var/pollutionmeter = 0

	var/list/globalmarketplace = list()
	var/list/marketplaceaccounts = list()
	var/list/pending_warrants = list()
	var/list/emails = list("support@monkeysoft.ug" = list())

	var/list/assign_precursors = list(
		"Rednikov Industries" = list("verdine crystals","indigon crystals","galdonium crystals"),
		"Giovanni Blu Stocks" = list("crimsonite crystals","verdine crystals","galdonium crystals"),
		"Kogama Kraftsmen" = list("crimsonite crystals","indigon crystals","galdonium crystals"),
		"Goldstein Solutions" = list("crimsonite crystals","indigon crystals","verdine crystals"),
)
	var/list/precursor_stocks = list(
		"indigon crystals" = list(7,60),
		"crimsonite crystals" = list(7,60),
		"verdine crystals" = list(7,60),
		"galdonium crystals" = list(7,60),
	)
	var/winddirection = "East"
	var/windspeedvar = 1 // 0 to 4
	var/windspeed = "a light breeze" // calm, light breeze, moderate breeze, strong breeze, gale
	var/winddesc = "A light Eastern breeze."

	var/artillery_count = 0
	var/artillery_timer = 3000
	var/artillery_last = 0
	var/list/valid_artillery = list("Explosive","Napalm","White Phosphorus")

	var/list/orc = list()
	var/list/human = list()
	var/list/gorilla = list()
	var/list/ant = list()
	var/list/lizard = list()
	var/list/wolfman = list()
	var/list/crab = list()

	var/list/berryeffects = list(list("neutral","neutral","water"), list("tinto","neutral","water"), list("amar","neutral","water"), list("majo","neutral","water"), list("narco","neutral","water"), list("azul","neutral","water"), list("zelenyy","neutral","water"), list("marron","neutral","water"), list("corcairghorm","neutral","water"))

	var/persistence = FALSE
	var/battleroyale = FALSE
	var/override_mapgen = FALSE
	var/force_mapgen = FALSE

	var/lastcheck = 0

	var/ar_to_close = ""
	var/ar_to_close_string = "None"
	var/ar_to_close_timeleft = 0

	var/no_hardcore = FALSE
/obj/map_metadata/New()
	..()
	map = src
	icon = null
	icon_state = null
	human = faction_organization.Copy()
	initial_faction_organization = faction_organization.Copy()

	// makes win condition helper datum
	win_condition = new
	if (berryeffects.len)
		for (var/list/i in berryeffects)
			i[2] = pick("neutral", "poisonous", "drug", "healing", "tasty", "disgusting")
			if (i[2] == "poisonous")
				i[3] = pick("amatoxin","cyanide", "food_poisoning", "solanine")
			else if (i[2] == "drug")
				i[3] = pick("peyote", "psilocybin","mindbreaker")
			else if (i[2] == "healing")
				i[3] = pick("paracetamol", "penicillin", "opium", "cocaine", "sal_acid")
	spawn(5000)
		pollution()
	spawn(2400)
		wind()
	spawn(2000)
		religious_timer()
		tip_process()

	if (nomads || civilizations || ID==MAP_COLONY || ID==MAP_FOUR_COLONIES || ID==MAP_PIONEERS)
		var/amt_to_create = (world.maxx*world.maxy)/5000
		if (grass_turf_list.len)
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/tinto(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/azul(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/amar(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/majo(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/narco(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/zelenyy(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/marron(G)
					v++
			for (var/v=1, v<=amt_to_create)
				var/turf/floor/grass/G = pick(grass_turf_list)
				if (G.isemptyfloor())
					new/obj/structure/wild/berrybush/corcairghorm(G)
					v++

/obj/map_metadata/proc/religious_timer()
	if (custom_religions.len > 0)
		for (var/rel in custom_religions)
			if (custom_religions[rel][3] > 0)
				custom_religions[rel][3] -= 0.2
			if (custom_religions[rel][3] < 0)
				custom_religions[rel][3] = 0
	spawn(1200)
		religious_timer()

/obj/map_metadata/proc/wind()
	var/oldwind = winddirection
	var/oldspeed = windspeedvar
	winddirection = pick("North", "South", "East", "West")
	windspeedvar += pick(-1,0,1)
	if (windspeedvar > 4)
		windspeedvar = 4
	if (windspeedvar < 0)
		windspeedvar = 0
	switch (windspeedvar)
		if (0)
			windspeed = "calm"
			winddesc = "No wind."
		if (1)
			windspeed = "a light breeze"
			winddesc = "A light [winddirection]ern breeze."
		if (2)
			windspeed = "a moderate breeze"
			winddesc = "A moderate [winddirection]ern breeze."
		if (3)
			windspeed = "a strong breeze"
			winddesc = "A strong [winddirection]ern breeze."
		if (4)
			windspeed = "a gale"
			winddesc = "A [winddirection]ern gale."
	if (windspeedvar != oldspeed)
		world << "<big>The wind changes strength. It is now <b>[windspeed]</b>.</big>"
	if (winddirection != oldwind)
		world << "<big>The wind changes direction. It is now blowing from the <b>[winddirection]</b>.</big>"
	spawn(rand(3600,6000))
		wind()

/obj/map_metadata/proc/pollution()

	if (pollutionmeter >= 1000)
		change_weather(WEATHER_SMOG)
		world << "The air gets smoggy..."
	pollutionmeter -= 80
	if (pollutionmeter < 0)
		pollutionmeter = 0
	spawn(9000) //every 15 mins
		pollution()

/obj/map_metadata/proc/tip_process()
	var/list/tips = file2list("config/tips.txt")
	show_tip(tips)
	spawn(6000) //every 10 mins
		tip_process()

/obj/map_metadata/proc/show_tip(var/list/tips)
	if (tips.len)
		for(var/client/C in clients)
			if(C.is_preference_enabled(/datum/client_preference/show_tips))
				C << "<font color='#5194BB'>---</font>"
				C << "<font color='#5194BB'><b>Tip:</b> [pick(tips)]</font>"
				C << "<font color='#5194BB'>---</font>"

/obj/map_metadata/proc/set_ordinal_age()
	if (age == "5000 B.C.")
		ordinal_age = 0
	else if (age == "313 B.C.")
		ordinal_age = 1
	else if (age == "1013")
		ordinal_age = 2
	else if (age == "1713")
		ordinal_age = 3
	else if (age == "1873")
		ordinal_age = 4
	else if (age == "1903")
		ordinal_age = 5
	else if (age == "1943")
		ordinal_age = 6
	else if (age == "1969")
		ordinal_age = 7
	else if (age == "2013")
		ordinal_age = 8
	return


/obj/map_metadata/proc/autoresearch_proc()
	if (autoresearch == TRUE && default_research < 230)
		spawn(600) //1 minute = 0.4 points (by default)
			default_research += autoresearch_mult
			if (map.ID == MAP_CIVILIZATIONS)
				civa_research = list(default_research,default_research,default_research,null,0)
				civb_research = list(default_research,default_research,default_research,null,0)
				civc_research = list(default_research,default_research,default_research,null,0)
				civd_research = list(default_research,default_research,default_research,null,0)
				cive_research = list(default_research,default_research,default_research,null,0)
				civf_research = list(default_research,default_research,default_research,null,0)
			else
				for(var/i = 1, i <= map.custom_civs.len, i++)
					var/key = map.custom_civs[i]
					map.custom_civs[key][1] = default_research
					map.custom_civs[key][2] = default_research
					map.custom_civs[key][3] = default_research
			autoresearch_proc()
// called from the map process
/obj/map_metadata/proc/tick()
	if (ar_to_close_timeleft > 0)
		ar_to_close_timeleft--
	if (last_crossing_block_status[faction1] == FALSE)
		if (faction1_can_cross_blocks() && cross_message(faction1) != "")
			world << cross_message(faction1)

	else if (last_crossing_block_status[faction1] == TRUE)
		if (!faction1_can_cross_blocks() && reverse_cross_message(faction1) != "")
			world << reverse_cross_message(faction1)


	if (last_crossing_block_status[faction2] == FALSE)
		if (faction2_can_cross_blocks() && cross_message(faction2) != "")
			world << cross_message(faction2)
			if (battleroyale)
				var/warning_sound = sound('sound/effects/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
				for (var/mob/M in player_list)
					M.client << warning_sound

	else if (last_crossing_block_status[faction2] == TRUE)
		if (!faction2_can_cross_blocks() && reverse_cross_message(faction2) != "")
			world << reverse_cross_message(faction2)

	last_crossing_block_status[faction2] = faction2_can_cross_blocks()
	last_crossing_block_status[faction1] = faction1_can_cross_blocks()

	if (processes.ticker.playtime_elapsed > 6000 && world.realtime > lastcheck && !is_singlefaction && !is_RP && !nomads && !civilizations)
		if (!(alive_n_of_side(faction1)))
			current_winner = roundend_condition_def2army(faction2)
			current_loser = roundend_condition_def2army(faction1)
			ticker.finished = TRUE
			next_win = world.time - 100
		else if (!(alive_n_of_side(faction2)))
			current_winner = roundend_condition_def2army(faction1)
			current_loser = roundend_condition_def2army(faction2)
			ticker.finished = TRUE
			next_win = world.time - 100

		lastcheck = world.realtime + 600

	update_win_condition()
	check_events()
	if (nomads)
		if (age1_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age1_lim && world.time > 36000)
					world << "<big>The world has advanced into the Bronze Age!</big>"
					age = "313 B.C."
					set_ordinal_age()
					age1_done = TRUE
					age2_timer = (world.time + age2_timer)
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 25
					break

		else if (age2_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age2_lim && world.time >= age2_timer)
					world << "<big>The world has advanced into the Medieval Age!</big>"
					age = "1013"
					set_ordinal_age()
					age2_done = TRUE
					age3_timer = (world.time + age3_timer)
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 50
					break

		else if (age3_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age3_lim && world.time >= age3_timer)
					world << "<big>The world has advanced into the Imperial Age!</big>"
					age = "1713"
					set_ordinal_age()
					age3_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 80
					break

		else if (age4_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age4_lim && world.time >= age4_timer)
					world << "<big>The world has advanced into the Industrial Age!</big>"
					age = "1873"
					set_ordinal_age()
					age4_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 105
					break
		else if (age5_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age5_lim && world.time >= age5_timer)
					world << "<big>The world has advanced into the Early Modern Age!</big>"
					age = "1903"
					set_ordinal_age()
					age5_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 120
					break
		else if (age6_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age6_lim && world.time >= age6_timer)
					world << "<big>The world has advanced into the Second World War!</big>"
					age = "1943"
					set_ordinal_age()
					age6_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 145
					break
		else if (age7_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age7_lim && world.time >= age7_timer)
					world << "<big>The world has advanced into the Cold War!</big>"
					age = "1969"
					set_ordinal_age()
					age7_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 175
					break
		else if (age8_done == FALSE)
			var/count = 0
			for(var/i = 1, i <= custom_faction_nr.len, i++)
				count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
				if (count > age8_lim && world.time >= age8_timer)
					world << "<big>The world has advanced into the Modern Age!</big>"
					age = "2013"
					set_ordinal_age()
					age8_done = TRUE
					if (!map.chad_mode && !map.chad_mode_plus)
						default_research = 210
					break
/obj/map_metadata/proc/check_events()
	return TRUE

/obj/map_metadata/proc/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (!H.original_job)
			return FALSE
		else
			if (H.faction_text == faction1)
				return !faction1_can_cross_blocks()
			if (H.faction_text == faction2)
				return !faction2_can_cross_blocks()
	return FALSE

/obj/map_metadata/proc/faction1_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/faction2_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/specialfaction_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/game_really_started()
	return (faction1_can_cross_blocks() && faction2_can_cross_blocks())

/obj/map_metadata/proc/job_enabled_specialcheck(var/datum/job/J)
	if (age == "1013" && !civilizations)
		if (J.is_medieval == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		if (J.is_medieval == FALSE)
			. = TRUE
		else
			. = FALSE
	if (civilizations)
		if (J.is_civilizations == TRUE)
			. = TRUE
		else
			. = FALSE
	else if (!civilizations)
		if (J.is_civilizations == FALSE)
			. = TRUE
		else
			. = FALSE
	if (J.is_nomad == TRUE)
		. = FALSE
/obj/map_metadata/proc/cross_message(faction)
	return "<font size = 4>The [faction_const2name(faction,ordinal_age)] may now cross the invisible wall!</font>"

/obj/map_metadata/proc/reverse_cross_message(faction)
	return "<span class = 'userdanger'>The [faction_const2name(faction,ordinal_age)] may no longer cross the invisible wall!</span>"


// old game mode stuff
/obj/map_metadata/proc/can_start()

	var/playercount = 0
	var/only_client_is_host = FALSE
	for (var/mob/new_player/player in new_player_mob_list)
		if (player.client)
			if (!player.client.is_minimized())
				++playercount
			if (player && player.key == world.host) // client.is_minimized() takes a while, so the player may not still exist
				only_client_is_host = TRUE

	if (playercount >= required_players || only_client_is_host)
		world << mission_start_message
		return TRUE

	return FALSE

/obj/map_metadata/proc/update_win_condition()

	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		if (!map.civilizations)
			message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		else
			message = "The round has ended!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	if (nomads == FALSE && is_singlefaction == FALSE)
		// German major
		if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
					next_win = world.time + short_win_time(roundend_condition_sides[2][1])
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		// German minor
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
					next_win = world.time + long_win_time(roundend_condition_sides[2][1])
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		// Soviet major
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
					next_win = world.time + short_win_time(roundend_condition_sides[1][1])
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		// Soviet minor
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
					next_win = world.time + long_win_time(roundend_condition_sides[1][1])
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		else
			if (current_win_condition != no_winner && current_winner && current_loser)
				world << "<font size = 3>The [current_winner] has lost control of the [army2name(current_loser)] base!</font>"
				current_winner = null
				current_loser = null
			next_win = -1
			current_win_condition = no_winner
			win_condition.hash = 0
		last_win_condition = win_condition.hash
		return TRUE

/obj/map_metadata/proc/has_occupied_base(side)

	// hack
	if (current_win_condition == no_winner)
		return FALSE

	var/list/soldiers = list(
		CIVILIAN = 0,
		BRITISH = 0,
		PORTUGUESE = 0,
		SPANISH = 0,
		FRENCH = 0,
		INDIANS = 0,
		PIRATES = 0,
		DUTCH = 0,
		ROMAN = 0,
		GREEK = 0,
		ARAB = 0,
		JAPANESE = 0,
		RUSSIAN = 0,
		CHECHEN = 0,
		FINNISH = 0,
		GERMAN = 0,
		AMERICAN = 0,
		VIETNAMESE = 0,
		CHINESE = 0,
		FILIPINO = 0,)

	if (!(side in soldiers))
		soldiers[side] = 0

	var/s1 = 0
	var/s2 = 0

	for (var/mob/living/human/H in human_mob_list)

		var/datum/job/job = H.original_job

		if (!job)
			continue

		if (H.stat != DEAD && H.stat != UNCONSCIOUS && !H.restrained() && ((H.weakened+H.stunned) == 0) && H.client && roundend_condition_sides.len >= 2)
			if (job.base_type_flag() in soldiers)
				var/H_area = get_area(H)
				if (job.base_type_flag() in roundend_condition_sides[1])
					if (istype(H_area, roundend_condition_sides[roundend_condition_sides[2]]))
						++s1
				else if (job.base_type_flag() in roundend_condition_sides[2])
					if (istype(H_area, roundend_condition_sides[roundend_condition_sides[1]]))
						++s2
			else
				var/M = "WARNING: could not find '[job.base_type_flag()]' in local list soldiers in proc '/obj/map/proc/has_occupied_base()'. Please contact a coder."
				log_admin(M)
				message_admins(M)
				log_debug(M)

	if (side in roundend_condition_sides[1])
		return s2 > s1
	else if (side in roundend_condition_sides[2])
		return s1 > s2

	return FALSE

/obj/map_metadata/proc/next_win_time()
	return round((next_win - world.time)/600)

/obj/map_metadata/proc/current_stat_message()
	var/next_win_time = max(0, next_win_time())
	. = current_win_condition
	. = replacetext(., "{time}", next_win_time)
	if (next_win_time == 1)
		. = replacetext(., "{s}", "")
	else
		. = replacetext(., "{s}", "s")
	return .

/obj/map_metadata/proc/announce_current_win_condition()
	world << "<font size = 3>[current_stat_message()]</font>"

/obj/map_metadata/proc/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		if (clients.len >= 20)
			return 3000 // 5 minutes
		else
			return 1200 // 2 minutes

/obj/map_metadata/proc/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		if (clients.len >= 20)
			return 4200 // 7 minutes
		else
			return 2400 // 4 minutes

/obj/map_metadata/proc/roundend_condition_def2name(define)
	switch (define)
		if (BRITISH)
			return "British"
		if (PIRATES)
			if (map.ID == MAP_CAMPAIGN)
				return "Redmenian"
			return "Pirate"
		if (CIVILIAN)
			if (map.ID == MAP_CAMPAIGN)
				return "Blugoslavian"
			return "Colonist"
		if (INDIANS)
			return "Native"
		if (FRENCH)
			return "French"
		if (PORTUGUESE)
			return "Portuguese"
		if (SPANISH)
			return "Spanish"
		if (DUTCH)
			return "Dutch"
		if (ROMAN)
			if(map.ID == MAP_WHITERUN)
				return "Empire"
			else
				return "Roman"
		if (GERMAN)
			return "German"
		if (GREEK)
			return "Greek"
		if (ARAB)
			return "Arab"
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Russian"
		if (CHECHEN)
			return "Chechen"
		if (FINNISH)
			return "Finnish"
		if (AMERICAN)
			return "American"
		if (VIETNAMESE)
			return "Vietnamese"
		if (CHINESE)
			return "Chinese"
		if (FILIPINO)
			return "Filipino"
/obj/map_metadata/proc/roundend_condition_def2army(define)
	switch (define)
		if (BRITISH)
			return "British Empire"
		if (PIRATES)
			if (map.ID == MAP_CAMPAIGN)
				return "Redmenia Defence Force"
			return "Pirate crew"
		if (CIVILIAN)
			if (map.ID == MAP_CAMPAIGN)
				return "Blugoslavian Armed Forces"
			return "Colonists"
		if (INDIANS)
			return "Native Tribe"
		if (FRENCH)
			return "French Empire"
		if (PORTUGUESE)
			return "Portuguese Empire"
		if (SPANISH)
			return "Spanish Empire"
		if (DUTCH)
			return "Dutch Republic"
		if (ROMAN)
			if (map.ID == MAP_WHITERUN)
				return "Imperial Army"
			else
				return "Roman Republic"
		if (GREEK)
			return "Greek States"
		if (ARAB)
			return "Arabic Caliphate"
		if (JAPANESE)
			return "Japanese Empire"
		if (RUSSIAN)
			return "Russian Empire"
		if (CHECHEN)
			return "Chechen Republic of Ichkeria"
		if (FINNISH)
			return "Republic of Finland"
		if (GERMAN)
			return "German Empire"
		if (AMERICAN)
			return "United States"
		if (VIETNAMESE)
			return "Vietcong group"
		if (CHINESE)
			return "Poeple's Liberation Army"
		if (FILIPINO)
			return "Philippine Revolutionary Army"
/obj/map_metadata/proc/army2name(army)
	switch (army)
		if ("British Empire")
			return "British"
		if ("Pirate crew")
			return "Pirate"
		if ("Redmenia Defence Force")
			return "Redmenian"
		if ("Blugoslavian Armed Forces")
			return "Blugoslavian"
		if ("Colonists")
			return "Colonist"
		if ("Native Tribe")
			return "Native"
		if ("French Empire")
			return "French"
		if ("Portuguese Empire")
			return "Portuguese"
		if ("Spanish Empire")
			return "Spanish"
		if ("Dutch Republic")
			return "Dutch"
		if ("Roman Republic")
			return "Roman"
		if ("Imperial Army")
			return "Empire"
		if ("Greek States")
			return "Greek"
		if ("Arabic Caliphate")
			return "Arab"
		if ("Japanese Empire")
			return "Japanese"
		if ("Russian Empire")
			return "Russian"
		if ("German Empire")
			return "German"
		if ("United States")
			return "American"
		if ("Vietcong group")
			return "Vietnamese"
		if ("People's Liberation Army")
			return "Chinese"
		if ("Philippine Revolutionary Army")
			return "Filipino"
/obj/map_metadata/proc/special_relocate(var/mob/M)
	return FALSE

/////////////////////////////////SEASONS//////////////////////////
/obj/map_metadata/proc/seasons(var/looping = TRUE, var/force = FALSE)
	if (force || config.seasons_on)
		if (season == "FALL")
			season = "WINTER"
			world << "<big>The <b>Winter</b> has started. In the hot climates, the wet season has started.</big>"
			change_weather_somehow()
			spawn(1200)
				for (var/obj/structure/wild/tree/live_tree/TREES in world)
					TREES.change_season()
			for (var/turf/floor/dirt/flooded/D)
				D.ChangeTurf(/turf/floor/beach/water/flooded)
			for (var/turf/floor/dirt/ploughed/flooded/D)
				D.ChangeTurf(/turf/floor/beach/water/flooded)
			for(var/obj/structure/sink/S)
				if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
					S.dry = FALSE
					S.update_icon()
			for (var/turf/floor/beach/drywater/B in get_area_turfs(/area/caribbean/nomads/desert))
				B.ChangeTurf(/turf/floor/beach/water/swamp)
			for (var/turf/floor/beach/drywater2/C in get_area_turfs(/area/caribbean/nomads/desert))
				C.ChangeTurf(/turf/floor/beach/water/deep/swamp)
			for (var/turf/floor/dirt/jungledirt/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
				if (prob(50))
					JD.ChangeTurf(/turf/floor/grass/jungle)
			for (var/turf/floor/dirt/dry_lava/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
				if (prob(50))
					JD.ChangeTurf(/turf/floor/grass/jungle)
			for (var/turf/floor/dirt/jungledirt/JD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
				if (prob(50))
					JD2.ChangeTurf(/turf/floor/grass/jungle)
			for (var/turf/floor/dirt/burned/BD in get_area_turfs(/area/caribbean/nomads/desert))
				if (prob(75))
					BD.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/dirt/burned/BDD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
				if (prob(75))
					BDD.ChangeTurf(/turf/floor/dirt/jungledirt)
			for (var/turf/floor/dirt/burned/BDD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
				if (prob(75))
					BDD2.ChangeTurf(/turf/floor/dirt/jungledirt)
			for (var/turf/floor/dirt/DT in get_area_turfs(/area/caribbean/nomads/forest))
				if (!istype(DT, /turf/floor/dirt/underground))
					if (get_area(DT).climate == "temperate")
						if (prob(75))
							DT.ChangeTurf(/turf/floor/dirt/winter)
					else if (get_area(DT).climate == "tundra" || get_area(DT).climate == "taiga")
						DT.ChangeTurf(/turf/floor/dirt/winter)
			for (var/turf/floor/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
				if (get_area(GT).climate == "temperate")
					if (prob(80))
						GT.ChangeTurf(/turf/floor/winter/grass)
				else if (get_area(GT).climate == "tundra" || get_area(GT).climate == "taiga")
					GT.ChangeTurf(/turf/floor/winter/grass)
			for (var/turf/floor/dirt/DTT in get_area_turfs(/area/caribbean/nomads/snow))
				if (!istype(DTT, /turf/floor/dirt/underground))
					DTT.ChangeTurf(/turf/floor/dirt/winter)
			for (var/turf/floor/grass/GTT in get_area_turfs(/area/caribbean/nomads/snow))
				GTT.ChangeTurf(/turf/floor/winter/grass)

		else if (season == "SPRING")
			season = "SUMMER"
			world << "<big>The <b>Summer</b> has started. In the hot climates, the dry season has started.</big>"
			change_weather_somehow()
			spawn(300)
				for (var/obj/structure/wild/tree/live_tree/TREES in world)
					TREES.change_season()
			for(var/obj/structure/sink/S in get_area_turfs(/area/caribbean/nomads/desert))
				if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
					S.dry = TRUE
					S.update_icon()
			for (var/turf/floor/beach/water/swamp/D in get_area_turfs(/area/caribbean/nomads/desert))
				if (D.z > 1)
					D.ChangeTurf(/turf/floor/beach/drywater)
			for (var/turf/floor/beach/water/deep/swamp/DS in get_area_turfs(/area/caribbean/nomads/desert))
				if (DS.z > 1)
					DS.ChangeTurf(/turf/floor/beach/drywater2)
			for (var/turf/floor/beach/water/flooded/DF)
				if (DF.z > 1)
					DF.ChangeTurf(/turf/floor/dirt/flooded)
			for (var/turf/floor/dirt/winter/DT in get_area_turfs(/area/caribbean/nomads/forest))
				if (get_area(DT).climate == "temperate")
					DT.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
				if (get_area(GT).climate == "temperate")
					GT.ChangeTurf(/turf/floor/grass)
			for (var/turf/floor/winter/WT in get_area_turfs(/area/caribbean/roofed))
				WT.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/dirt/winter/WT in get_area_turfs(/area/caribbean/roofed))
				WT.ChangeTurf(/turf/floor/dirt)
		else if (season == "WINTER")
			season = "SPRING"
			world << "<big>The weather is getting warmer. It is now <b>Spring</b>. In the hot climates, the wet season continues.</big>"
			spawn(900)
				for (var/obj/structure/wild/tree/live_tree/TREES in world)
					TREES.change_season()
			for (var/turf/floor/dirt/winter/D in get_area_turfs(/area/caribbean/nomads/forest))
				if (get_area(D).climate == "temperate")
					if (prob(60))
						if (prob(40))
							D.ChangeTurf(/turf/floor/grass)
						else
							D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
				if (get_area(G).climate == "temperate")
					if (prob(60))
						G.ChangeTurf(/turf/floor/grass)
			spawn(150)
				change_weather(WEATHER_NONE)
				for (var/obj/structure/window/barrier/snowwall/SW1 in world)
					if (get_area(get_turf(SW1)).climate != "tundra" && get_area(get_turf(SW1)).climate != "taiga")
						if (prob(60))
							qdel(SW1)
				for (var/obj/covers/snow_wall/SW2 in world)
					if (get_area(get_turf(SW2)).climate != "tundra" && get_area(get_turf(SW2)).climate != "taiga")
						if (prob(60))
							qdel(SW2)
				for (var/obj/item/weapon/snowwall/SW3 in world)
					if (get_area(get_turf(SW3)).climate != "tundra" && get_area(get_turf(SW3)).climate != "taiga")
						if (prob(60))
							qdel(SW3)
			spawn(3000)
				for (var/turf/floor/dirt/winter/D in get_area_turfs(/area/caribbean/nomads/forest))
					if (get_area(D).climate == "temperate")
						if (prob(40))
							D.ChangeTurf(/turf/floor/grass)
						else
							D.ChangeTurf(/turf/floor/dirt)
				for (var/turf/floor/winter/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
					if (get_area(G).climate == "temperate")
						G.ChangeTurf(/turf/floor/grass)
				for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/semiarid))
					if (get_area(D).climate == "semiarid" && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/underground))
						if (prob(40))
							D.ChangeTurf(/turf/floor/grass)

				for (var/obj/structure/window/barrier/snowwall/SW1 in world)
					if (get_area(get_turf(SW1)).climate != "tundra" && get_area(get_turf(SW1)).climate != "taiga")
						qdel(SW1)
				for (var/obj/covers/snow_wall/SW2 in world)
					if (get_area(get_turf(SW2)).climate != "tundra" && get_area(get_turf(SW2)).climate != "taiga")
						qdel(SW2)
				for (var/obj/item/weapon/snowwall/SW3 in world)
					if (get_area(get_turf(SW3)).climate != "tundra" && get_area(get_turf(SW3)).climate != "taiga")
						qdel(SW3)
		else if (season == "SUMMER")
			season = "FALL"
			world << "<big>The leaves start to fall and the weather gets colder. It is now <b>Fall</b>. In the hot climates, the dry season continues.</big>"
			spawn(900)
				for (var/obj/structure/wild/tree/live_tree/TREES in world)
					TREES.change_season()
			for (var/turf/floor/dirt/burned/BD)
				if ((BD in get_area_turfs(/area/caribbean/nomads/forest/Jungle)) || (BD in get_area_turfs(/area/caribbean/nomads/forest/savanna)))
					BD.ChangeTurf(/turf/floor/dirt/jungledirt)
				else
					BD.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/grass/G)
				G.update_icon()
			spawn(100)
				change_weather(WEATHER_WET)
			spawn(15000)
				change_weather(WEATHER_WET)
				for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
					if (z == world.maxz && prob(40) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !(get_area(D).climate == "jungle"))
						D.ChangeTurf(/turf/floor/dirt/winter)
				for (var/turf/floor/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
					if (get_area(G).climate == "temperate")
						if (prob(40))
							G.ChangeTurf(/turf/floor/winter/grass)
				spawn(1200)
					for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
						if (!istype(D,/turf/floor/dirt/winter) && (get_area(D).climate == "temperate"))
							if (D.z == world.maxz && prob(50) && !istype(D,/turf/floor/dirt/underground))
								D.ChangeTurf(/turf/floor/dirt/winter)
					for (var/turf/floor/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
						if (get_area(G).climate == "temperate")
							if (prob(50))
								G.ChangeTurf(/turf/floor/winter/grass)
	if (looping)
		spawn(18000)
			seasons()

//loads faction-specific recipes, if called on /New()

/obj/map_metadata/proc/load_new_recipes(F3)
	if (!F3)
		F3 = file("config/crafting/material_recipes_carib.txt")

	if (fexists(F3))
		var/list/craftlist_temp = file2list(F3,"\n")
		for (var/i in craftlist_temp)
			if (findtext(i, ",") && findtext(i,"RECIPE: ") && !(findtext(i,"//")))
				var/tmpi = replacetext(i, "RECIPE: ", "")
				var/list/current = splittext(tmpi, ",")
				craftlist_lists["INDIANS"] += list(current)
				if (current.len != 13)
					world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13)."
/obj/map_metadata/proc/give_stock_points(tfaction = "", value = 0)
	if (value == 0)
		return
	for (var/i in map.globalmarketplace)
		if (map.globalmarketplace[i][7]==0 && map.globalmarketplace[i][5]=="bank" && map.globalmarketplace[i][2] && map.globalmarketplace[i][1]==tfaction)
			if (istype(map.globalmarketplace[i][2],/mob/living/human))
				map.marketplaceaccounts[map.globalmarketplace[i][2].name] += value/2.5