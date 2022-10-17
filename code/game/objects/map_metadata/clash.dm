/obj/map_metadata/clash
	ID = MAP_CLASH
	title = "Clash"
	lobby_icon = "icons/lobby/clash.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	victory_time = 21600
	no_winner = "The settlement is still held by the Raven Clan."
	respawn_delay = 300
	no_hardcore = TRUE
	faction_organization = list(
		NORWEGIAN,
		DANISH)

	roundend_condition_sides = list(
		list(DANISH) = /area/caribbean/greek,
		list(NORWEGIAN) = /area/caribbean/colonies,
		)

	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(DANISH = 0.5, NORWEGIAN = 0.5)
	battle_name = "Clan War"
	mission_start_message = "<font size=4>The <b>Bear</b> clan is sieging the <b>Raven</b> clan's settlement hidden away in the snowy fjords! The Bear clan will win if they manage to <b>capture the Raven King's Cabin</b>.<br> The Raven Clan must <b>defend their settlement for 30 minutes</b>.<br> The siege will start after <b>6 minutes</b>.</font>"
	faction1 = DANISH
	faction2 = NORWEGIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Danheim - Ivar's Revenge:1" = "sound/music/ivars_revenge.ogg",)
	gamemode = "Siege"

/obj/map_metadata/clash/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_clash == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/clash/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 21600 || admin_ended_all_grace_periods)

/obj/map_metadata/clash/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/clash/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 1200 // 2 minutes

/obj/map_metadata/clash/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/clash/cross_message(faction)
	if (faction == NORWEGIAN)
		return "<font size = 4>The Bear Clan may now cross the invisible wall!</font>"
	else if (faction == DANISH)
		return "<font size = 4>The Bear Clan may now cross the invisible wall!</font>"
	else
		return ""

var/no_loop_clash = FALSE
/obj/map_metadata/clash/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Raven clan has managed to defend their settlement!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_clash == FALSE)
		ticker.finished = TRUE
		var/message = "The Bear clan has captured the King's cabin! The remaining Raven clansmen have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_clash = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan has control over the Raven King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan has control over the Raven King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Bear clan has control over the Raven King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan has control over the Raven King's cabin! They will win in {time} minutes."
				next_win = world.time + short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Raven clan has recaptured the King's cabin!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

///////////map specific objs/////////
/obj/structure/religious/runestone/odinsgift
	var/faction = "none"

/obj/structure/religious/runestone/odinsgift/attackby(obj/item/W, mob/living/human/user)
	if(faction != user.nationality)
		return
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_CLASH)
		if (!W)
			return
		var/obj/item/organ/external/head/HD = W
		var/head_nationality = HD.nationality
		qdel(W)
		if (faction == head_nationality || faction != user.nationality)
			return
		if (!head_nationality || head_nationality == "none")
			return
		user << "You offer the head as a tribute to Odin."

		if	(prob(20))
			var/randmed = rand(1,3)
			switch (randmed)
				if (1)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(user.loc)
				if (2)
					new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/stamina/minor(user.loc)
				if (3)
					new/obj/item/stack/medical/advanced/herbs(user.loc)
		else if (prob (20))
			var/randcloth = rand(1,2)
			switch(randcloth)
				if (1)
					new/obj/item/clothing/head/helmet/medieval/viking/varangian(user.loc)
					new/obj/item/clothing/suit/armor/medieval/varangian(user.loc)
				if (2)
					new/obj/item/clothing/accessory/armor/chainmail(user.loc)
					new/obj/item/clothing/head/helmet/medieval/viking(user.loc)
		else if (prob (25))
			var/randmelee = rand(1,3)
			switch(randmelee)
				if (1)
					new/obj/item/weapon/material/sword/claymore/iron(user.loc)
				if (2)
					new/obj/item/weapon/material/hatchet/battleaxe(user.loc)
				if (3)
					new/obj/item/weapon/reagent_containers/food/snacks/poo(user.loc)
		else if (prob (20))
			new/obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy(user.loc)
		else if (prob (15))
			new/obj/item/weapon/reagent_containers/food/snacks/meatpie(user.loc)
		else if (prob (15))
			new/obj/item/weapon/reagent_containers/food/snacks/rawfish(user.loc)
		else if (prob (10))
			new/obj/item/weapon/material/sword/magic/mjolnir/lesser(user.loc)
		return



