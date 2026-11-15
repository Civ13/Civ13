/obj/map_metadata/nankou
	ID = MAP_NANKOU
	title = "Nankou"
	description = "The Japanese will win if they capture the Train Station. The Chinese will win if they manage to defend their command for 20 minutes!."
	lobby_icon = "icons/lobby/china.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	no_hardcore = TRUE
	can_spawn_on_base_capture = TRUE
	respawn_delay = 1200
	faction_organization = list(
		CHINESE,
		JAPANESE)

	roundend_condition_sides = list(
		list(CHINESE) = /area/caribbean/russian/land/inside/command,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1937"
	ordinal_age = 6
	faction_distribution_coeffs = list(CHINESE = 0.6, JAPANESE = 0.4)
	battle_name = "battle of Nankou"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Japanese will win if they capture the <b>Train Station</b>. The Chinese will win if they manage to defend their command for <b>20 minutes!</b>.</font>"
	faction1 = CHINESE
	faction2 = JAPANESE
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Mugi to Heitai:1" = "sound/music/mugi_to_heitai.ogg",)
	grace_wall_timer = 3000

/obj/map_metadata/nankou/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (CHINESE)
			return "Chinese"
/obj/map_metadata/nankou/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (CHINESE)
			return "Chinese"

/obj/map_metadata/nankou/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Chinese")
			return "Chinese"


/obj/map_metadata/nankou/cross_message(faction)
	if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"
	else if (faction == CHINESE)
		return ""
	else
		return ""

/obj/map_metadata/nankou/reverse_cross_message(faction)
	if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"
	else if (faction == CHINESE)
		return ""
	else
		return ""
var/no_loop_nk = FALSE

/obj/map_metadata/nankou/update_win_condition()

	if (world.time >= 12000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Chinese</b> have successfully defended the Nankou Train Station!! The Japanese have halted the attack!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_nk == TRUE)
		ticker.finished = TRUE
		var/message = "The <b>Japanese</b> have captured the Nankou Train Station! The battle for Beiping is over!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_nk = TRUE
		return FALSE
	else if (!capture_step(1, 2, 1.33, FALSE, JAPANESE, 1) && \
		!capture_step(1, 2, 1.01, FALSE, JAPANESE, 1) && \
		!capture_step(2, 1, 1.33, FALSE, JAPANESE, 1) && \
		!capture_step(2, 1, 1.01, FALSE, JAPANESE, 1))
		if (current_win_condition != no_winner && current_winner && current_loser)
			to_chat(world, "<font size = 3>The <b>Chinese</b> have recaptured the Nankou Train Station!</font>")
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/nankou/capture_message(id)
	switch (id)
		if (1)
			return "The <b>Japanese</b> have reached the Nankou Train Station! They will win in {time} minutes."

/obj/map_metadata/nankou/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_faction_grace_wall(H, T, faction2, faction1, grace_side = 2)
