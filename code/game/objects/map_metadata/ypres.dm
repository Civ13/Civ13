
/obj/map_metadata/ypres
	ID = MAP_YPRES
	title = "2nd Battle of Ypres"
	lobby_icon = "icons/lobby/ww1.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300

	faction_organization = list(
		BRITISH,
		FRENCH,
		GERMAN)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/land/inside/objective,
		list(FRENCH) = /area/caribbean/french/land/inside/objective,
		list(GERMAN) = /area/caribbean/german/inside/objective
		)
	age = "1915"
	ordinal_age = 5
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5, GERMAN = 0.5)
	battle_name = "second battle of Ypres"
	mission_start_message = "<font size=4>The <b>German</b> and the <b>Allied</b> forces are facing eachother in the trenches near Ypres! Get ready for the battle! It will start in <b>5 minutes</b>.</font>"
	faction1 = BRITISH
	faction2 = GERMAN
	grace_wall_timer = 3000
	songs = list(
		"Argonnerwaldlied:1" = "sound/music/argonnerwaldlied.ogg")

/obj/map_metadata/ypres/New()
	..()
	spawn(1)
		faction1 = pick(BRITISH,FRENCH)
	faction_distribution_coeffs = list(faction1 = 0.5, GERMAN = 0.5)
	setup_autobalance(FALSE)
	spawn(2)
		if (faction1 == FRENCH)
			for (var/obj/structure/vending/ww1britapparel/BA in world)
				var/turf/T1 = get_turf(BA)
				new/obj/structure/vending/ww1frenchapparel(T1)
				qdel(BA)
			for (var/obj/structure/vending/ww1britweapons/BW in world)
				var/turf/T2 = get_turf(BW)
				new/obj/structure/vending/ww1frenchweapons(T2)
				qdel(BW)
			for (var/obj/structure/closet/crate/ww1/ammo_vickers/AB in world)
				var/turf/T3 = get_turf(AB)
				new/obj/structure/closet/crate/ww1/ammo_hotchkiss(T3)
				qdel(AB)
			for (var/obj/structure/closet/crate/ww1/grenades_british/GR in world)
				var/turf/T4 = get_turf(GR)
				new/obj/structure/closet/crate/ww1/grenades_french(T4)
				qdel(GR)
			for (var/obj/item/weapon/gun/projectile/automatic/stationary/modern/vickers/VK in world)
				var/turf/T5 = get_turf(VK)
				new/obj/item/weapon/gun/projectile/automatic/stationary/modern/hotchkiss1914(T5)
				qdel(VK)
			for (var/obj/structure/sign/flag/uk/UKF in world)
				var/turf/T6 = get_turf(UKF)
				new/obj/structure/sign/flag/french(T6)
				qdel(UKF)
			for (var/turf/floor/trench/A1 in world)
				var/area/A = get_area(A1)
				if (istype(A,/area/caribbean/british/land/inside/objective))
					new/area/caribbean/french/land/inside/objective(get_turf(A1))
				else if (istype(A,/area/caribbean/british/land/inside))
					new/area/caribbean/french/land/inside(get_turf(A1))
				else if (istype(A,/area/caribbean/british/land/outside))
					new/area/caribbean/french/land/outside(get_turf(A1))
				else if (istype(A,/area/caribbean/british/land/outside/objective))
					new/area/caribbean/french/land/outside/objective(get_turf(A1))
			british_toggled = FALSE
			french_toggled = TRUE
		else
			british_toggled = TRUE
			french_toggled = FALSE
	spawn(30)
		world << "<font size=3>This battle will feature <b>[faction1]</b> and <b>[faction2]</b> troops.</font>"
/obj/map_metadata/ypres/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww1 == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/ypres/update_win_condition()

	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE

	// 1st major
	if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 1st minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 2nd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 2nd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 3rd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// 3rd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// 3rd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// 3rd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
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

