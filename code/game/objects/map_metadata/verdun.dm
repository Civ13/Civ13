
/obj/map_metadata/verdun
	ID = MAP_VERDUN
	title = "Battle of Verdun"
	lobby_icon = "icons/lobby/ww1.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 300
	no_hardcore = TRUE

	faction_organization = list(
		BRITISH,
		FRENCH,
		GERMAN)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/french/land/inside/objective,
		list(FRENCH) = /area/caribbean/french/land/inside/objective,
		list(GERMAN) = /area/caribbean/german/inside/objective
		)
	age = "1916"
	ordinal_age = 5
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5, GERMAN = 0.6)
	battle_name = "battle of Verdun"
	mission_start_message = "<font size=4>The <b>German</b> and the <b>Allied</b> forces are facing eachother at the Douaumont Fort in Verdun! Get ready for the battle! It will start in <b>5 minutes</b>. The French Army must defend for 20 minutes!</font>"
	faction1 = GERMAN
	faction2 = FRENCH
	grace_wall_timer = 3000
	songs = list(
		"Argonnerwaldlied:1" = "sound/music/argonnerwaldlied.ogg")

	valid_weather_types = list(WEATHER_WET)

/obj/map_metadata/verdun/New()
	..()
	spawn(1)
		faction2 = FRENCH
	faction_distribution_coeffs = list(faction2 = 0.5, GERMAN = 0.6)
	setup_autobalance(FALSE)
	spawn(2)
		if (faction2 == FRENCH)
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
/obj/map_metadata/verdun/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww1 == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/verdun/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "French"
		if (GERMAN)
			return "German"

/obj/map_metadata/verdun/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "French Army"
		if (GERMAN)
			return "Imperial German Army"
/obj/map_metadata/verdun/army2name(army)
	..()
	switch (army)
		if ("French")
			return "French"
		if ("Germans")
			return "German"

/obj/map_metadata/verdun/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 3>The Imperial German Army may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 3>The Imperial German Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/verdun/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Imperial German Army may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The Imperial German Army may no longer cross the invisible wall!</span>"
	else
		return ""

var/no_loop_verdun = FALSE
/obj/map_metadata/verdun/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>French Army</b> has successfuly defended Fort Douaumont! The Imperial German Army has halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_verdun == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Imperial German Army</b> has captured Fort Douaumont's Command! The battle for Fort Douaumont is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_verdun = TRUE
		return FALSE

	// 1st major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.33, TRUE))
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


/obj/map_metadata/verdun/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE