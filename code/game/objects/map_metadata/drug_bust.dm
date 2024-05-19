/obj/map_metadata/drug_bust
	ID = MAP_DRUG_BUST
	title = "The Rednikov Drug Bust"
	lobby_icon = 'icons/lobby/policestories.png'
	no_winner ="The drug bust is still underway."
	caribbean_blocking_area_types = list(
		/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 600
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		CIVILIAN,
		RUSSIAN,)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british/land/inside/objective,
		list(CIVILIAN) = /area/caribbean/japanese/land/inside/command, //doesn't exist on the map
		)

	age = "1993"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.65, RUSSIAN = 0.35)
	battle_name = "Rednikov Drug Bust"
	mission_start_message = "<font size=4>Rednikov have <b>5 minutes</b> to prepare before the SWAT raid the building!<br>The Police will win if they <b>capture the Storage Depot</b> in time! Rednikov will win if they manage to hold off the Police for <b>20 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = RUSSIAN
	grace_wall_timer = 5 MINUTES
	gamemode = "Drug Bust"
	songs = list(
		"D.A.V.E. The Drummer - Amphetamine or Cocaine:1" = 'sound/music/amphetamine_cocaine.ogg',)
	var/list/HVT_list = list()

/obj/map_metadata/drug_bust/New()
	..()
	collector()

/obj/map_metadata/drug_bust/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_heist == TRUE)
		. = TRUE
		if (J.title == "Police Officer")
			J.max_positions = 2
			J.total_positions = 2
		if (J.title == "DEA Agent")
			J.max_positions = 2
			J.total_positions = 2
		if (J.title == "SWAT Officer")
			J.whitelisted = FALSE
			J.max_positions = 30
			J.total_positions = 30
		if (J.title == "Bank Robber")
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/drug_bust/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/drug_bust/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/drug_bust/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "SWAT"
		if (RUSSIAN)
			return "Rednikov"

/obj/map_metadata/drug_bust/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "SWAT"
		if (RUSSIAN)
			return "Rednikov"

/obj/map_metadata/drug_bust/army2name(army)
	..()
	switch (army)
		if ("CIVILIAN")
			return "SWAT"
		if ("Russians")
			return "Rednikov"

/obj/map_metadata/drug_bust/cross_message(faction)
	return "<font size = 4>SWAT have started the raid!</font>"

/obj/map_metadata/drug_bust/reverse_cross_message(faction)
	return ""

/obj/map_metadata/drug_bust/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/drug_bust/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/drug_bust/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	if (processes.ticker.playtime_elapsed >= 20000)
		ticker.finished = TRUE
		var/message = "SWAT retreat out of the Storage Depot with heavy casualties, Rednikov managed to stand their ground!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	for (var/mob/living/human/H in HVT_list)
		if (H.original_job_title == "Vyacheslav Grigoriev" && H.stat != DEAD)
			if (H.restrained())
				var/area/A = get_area(H)
				if (istype(A,/area/caribbean/prison/jail))
					ticker.finished = TRUE
					var/message = "The HVT has been busted!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					show_global_battle_report(null)
					win_condition_spam_check = TRUE
					return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		world << "<font size = 4><span class = 'notice'>SWAT seized total control of the Storage Depot!</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "SWAT are now securing the Storage Depot! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "SWAT are now securing the Storage Depot! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "SWAT are now securing the Storage Depot! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "SWAT are now securing the Storage Depot! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>Rednikov have regained control of the Storage Depot!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/drug_bust/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job.is_outlaw == TRUE && !H.original_job.is_law == TRUE)
				if (!H.restrained())
					return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.original_job.is_law == TRUE && !H.original_job.is_outlaw == TRUE)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/drug_bust/proc/collector()
	for (var/mob/living/human/H in player_list)
		var/area/A = get_area(H)
		if (istype(A,/area/caribbean/british/land/outside))
			if (H.restrained() && H.stat != DEAD && H.faction_text == RUSSIAN)
				for (var/mob/living/human/L in player_list)
					if (L.ckey == H.handcuffed.fingerprintslast && L.faction_text == CIVILIAN)
						L.awards["arrests"] += 1
				spawn(10)
					if (prob(50))
						H.forceMove(locate(51,6,2)) //Hard coded for now
					else
						H.forceMove(locate(55,6,2)) //Hard coded for now
					for (var/obj/item/I in H.contents)
						if (!istype(I,/obj/item/weapon/handcuffs) && !istype(I,/obj/item/organ))
							qdel(I)
					H.equip_to_slot_or_del(new /obj/item/clothing/under/prisoner(H), slot_w_uniform)
					H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
					H.update_icons()
					WWalert(H,"You've been arrested. You may respawn (if possible) in 2 minutes.", "Arrest")
					spawn(1200)
						if (H.stat != DEAD)
							WWalert(H,"You may now respawn (if possible).", "Arrest")
							H.death()
							qdel(H)
	spawn(100)
		collector()


////////////////////////////////Objects and stuff//////////////////////////////////////////////////




/obj/item/weapon/paper/police/searchwarrant/drug
	icon_state = "police_warrant"
	base_icon = "police_warrant"
	name = "Search Warrant"
	New()
		..()
		arn = rand(100,999)
		icon_state = "police_warrant"
		spawn(10)
			info = "<center>DEPARTMENT OF JUSTICE<hr><large><b>Search Warrant No. [arn]</b></large><hr><br>Law Enforcement Agencies are hereby authorized and directed to search all and every property owned by <b>Vyacheslav Grigoriev</b>. They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf.<br><br><small><center><i>Form Model 13-C1</i></center></small><hr>"

/obj/item/weapon/reagent_containers/cocaineblock
	icon = 'icons/obj/drugs.dmi'
	name = "block of cocaine"
	desc = "A block of very pure cocaine."
	icon_state = "single_brick"
	pixel_y = 6
	var/vol = 500
	var/torn = FALSE
	value = 100
	is_contraband = TRUE
	New()
		..()
		reagents.add_reagent("cocaine", 500)
		desc = "A block of very pure cocaine. Contains [vol] grams."

/obj/item/weapon/reagent_containers/cocaineblock/update_icon()
	if (torn)
		icon_state = "single_brick_torn"
		desc = "A block of very pure cocaine that's been cut or torn from the outside. Contains [vol] grams."
	else
		icon_state = "single_brick"


/obj/item/weapon/reagent_containers/cocaineblock/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/reagent_containers/cocaineblock/))
		user << "You stack the blocks together."
		new /obj/item/weapon/reagent_containers/cocaineblocks(src.loc)
		qdel(src)
		qdel(I)
		return
	if (!istype(I, /obj/item/weapon/material/kitchen/utensil/knife))
		user << "You need a knife to cut the [src]."
		return
	if (reagents.get_reagent_amount("cocaine") <= 0)
		qdel(src)
		return
	if (reagents.get_reagent_amount("cocaine") <= 25)
		new/obj/item/weapon/reagent_containers/pill/cocaine(src.loc)
		qdel(src)
		return
	if (!torn)
		torn = TRUE
		update_icon()
	user << "You take out some cocaine from the [src]."
	reagents.remove_reagent("cocaine",25)
	var/obj/item/weapon/reagent_containers/pill/cocaine/coca = new/obj/item/weapon/reagent_containers/pill/cocaine(user)
	user.put_in_hands(coca)
	vol = reagents.get_reagent_amount("cocaine")

/*/obj/item/weapon/reagent_containers/cocaineblock/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/reagent_containers/pill/cocaine_line))
		user << "You put \the [I] into \the [src]."
		reagents.add_reagent("cocaine",I.reagents.get_reagent_amount("cocaine"))
		vol = reagents.get_reagent_amount("cocaine")/25
		desc = "A pile of very pure cocaine. Contains [vol] grams."
		if (reagents.get_reagent_amount("cocaine") >= 500)
			name = "block of cocaine"
			desc = "A block of very pure cocaine."
			icon_state = "single_brick"
		else
			name = "torn block of cocaine"
			desc = "A block of very pure cocaine that's been cut or torn from the outside."
			icon_state = "single_brick_torn"
		qdel(I)
	else
		..()*/

/obj/item/weapon/reagent_containers/cocaineblock/torn
	icon_state = "single_brick_torn"
	vol = 400
	value = 100
	torn = TRUE
	New()
		..()
		reagents.add_reagent("cocaine", 400)
		desc = "A block of very pure cocaine. Contains [vol] grams."

/obj/item/weapon/reagent_containers/cocaineblocks
	name = "blocks of cocaine"
	icon = 'icons/obj/drugs.dmi'
	icon_state = "brick_stack2"
	pixel_y = 6
	var/blocks_amount = 2
	is_contraband = TRUE
	New()
		..()
		desc = "[blocks_amount] blocks of very pure cocaine, packed together for shipping."
		value = blocks_amount*100

/obj/item/weapon/reagent_containers/cocaineblocks/three
	blocks_amount = 3
	icon_state = "brick_stack3"

/obj/item/weapon/reagent_containers/cocaineblocks/four
	blocks_amount = 4
	icon_state = "brick_stack4"

/obj/item/weapon/reagent_containers/cocaineblocks/five
	blocks_amount = 5
	icon_state = "brick_stack5"

/obj/item/weapon/reagent_containers/cocaineblocks/six
	blocks_amount = 6
	icon_state = "brick_stack6"

/obj/item/weapon/reagent_containers/cocaineblocks/update_icon()
	icon_state = "brick_stack[blocks_amount]"
	desc = "[blocks_amount] blocks of very pure cocaine, packed together for shipping."

/obj/item/weapon/reagent_containers/cocaineblocks/attack_hand(mob/living/user)
	if (src == user.l_hand || src == user.r_hand)
		var/obj/item/weapon/reagent_containers/cocaineblock/block = new/obj/item/weapon/reagent_containers/cocaineblock(user)
		user.put_in_hands(block)
		user << "You split the [src] apart."
		if (blocks_amount > 2)
			blocks_amount -= 1
			update_icon()
		else
			new/obj/item/weapon/reagent_containers/cocaineblock(user.loc)
			qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/cocaineblocks/attackby(var/obj/item/I, var/mob/user)
	if (!istype(I, /obj/item/weapon/reagent_containers/cocaineblock))
		return
	if (blocks_amount >= 6)
		to_chat(user, SPAN_WARNING("You cannot stack more blocks!"))
		return
	qdel(I)
	blocks_amount += 1
	update_icon()