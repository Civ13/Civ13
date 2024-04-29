/obj/map_metadata/red_menace
	ID = MAP_RED_MENACE
	title = "The Red Menace"
	lobby_icon = 'icons/lobby/redmenace.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 1200
	no_hardcore = TRUE
	victory_time = 27000
	grace_wall_timer = 3000
	no_winner = "The Townhall remains under American control."
	faction_organization = list(
		AMERICAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(AMERICAN) = /area/caribbean/german/inside/roof/objective,
		)
	age = "1985"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.4, AMERICAN = 0.6)
	battle_name = "Battle for America"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the assault begins!<br>The Americans will win if they hold out for <b>45 minutes</b>.<br>The Soviets will win if they manage to capture the Town Hall!<br>Capture point is on the 2nd floor.<br>The US Army reinforcements will arrive in 20 minutes.</font>"
	faction1 = AMERICAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Killing Joke - Eighties:1" = 'sound/music/eighties.ogg',)
	gamemode = "Siege"
	var/us_reinforcements_time = 20 MINUTES
	var/reinforcements_called = FALSE

/obj/map_metadata/red_menace/New()
	..()
	spawn(1800)
		handle_reinforcements()

/obj/map_metadata/red_menace/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_reds)
		if (J.title == "US Army Lieutenant" || J.title == "US Army Captain")
			if (processes.ticker.playtime_elapsed  < us_reinforcements_time)
				. = FALSE
			else
				. = TRUE
		else
			. = TRUE
	else
		. = FALSE

/obj/map_metadata/red_menace/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/red_menace/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/red_menace/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "American"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/red_menace/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "American"
		if (RUSSIAN)
			return "Soviet"

/obj/map_metadata/red_menace/army2name(army)
	..()
	switch (army)
		if ("AMERICAN")
			return "American"
		if ("RUSSIAN")
			return "Soviet"


/obj/map_metadata/red_menace/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == AMERICAN)
		return "<font size = 4>The Americans may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/red_menace/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == AMERICAN)
		return ""
	else
		return ""


/obj/map_metadata/red_menace/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Americans</b> have successfully defended the Town Hall! The Soviets have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> have captured the Town Hall! The Battle for America is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	// American major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have captured the Town Hall! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// American minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have captured the Town Hall! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have captured Town Hall! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have captured the Town Hall! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Americans</b> have recaptured the Town Hall!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/red_menace/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

// Map-specific objects and mechanics //

/obj/map_metadata/red_menace/proc/handle_reinforcements()
	if (processes.ticker.playtime_elapsed  >= us_reinforcements_time && !reinforcements_called)
		us_reinforcements()
		reinforcements_called = TRUE
		return
	spawn(100)
		handle_reinforcements()

/obj/map_metadata/red_menace/proc/us_reinforcements()
	for (var/obj/effect/spawner/objspawner/m1a1_abrams/MA in world)
		MA.activated = TRUE
		spawn(15)
			MA.activated = FALSE
	for (var/datum/job/J in job_master.occupations)
		if (J.is_reds)
			if (J.title == "US Army Lieutenant")
				J.max_positions = 2
				J.total_positions = 2
				J.spawn_location = "JoinLateRNSL2"
			if (J.title == "US Army Staff Sergeant")
				J.max_positions = 4
				J.total_positions = 4
				J.spawn_location = "JoinLateRNSL2"
			if (J.title == "US Army Radio Operator")
				J.max_positions = 3
				J.total_positions = 3
				J.spawn_location = "JoinLateRN3"
			if (J.title == "US Army Designated Marksman")
				J.max_positions = 5
				J.total_positions = 5
				J.spawn_location = "JoinLateRN3"
			if (J.title == "US Army Automatic Rifleman")
				J.max_positions = 8
				J.total_positions = 8
				J.spawn_location = "JoinLateRN3"
			if (J.title == "US Army Rifleman")
				J.max_positions = 44
				J.total_positions = 44
				J.spawn_location = "JoinLateRN3"
			if (J.title == "US Army Crewman")
				J.max_positions = 12
				J.total_positions = 12
				J.spawn_location = "JoinLateRNT2"
	world << SPAN_NOTICE("<big>American reinforcements have arrived!</big>")

/obj/effect/spawner/objspawner/m1a1_abrams
	name = "M1A1 Abrams spawner"
	max_range = 0
	max_number = 1
	timer = 10
	activated = FALSE
	create_path = /obj/effects/premadevehicles/tank/m1a1_abrams
