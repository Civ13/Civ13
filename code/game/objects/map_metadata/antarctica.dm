/obj/map_metadata/antarctica
	ID = MAP_ANTARCTICA
	title = "Antarctica"
	description = "Survive a desolate tundra environment while keeping the furnace alive!"
	lobby_icon = "icons/lobby/antarctica.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle, /area/caribbean/no_mans_land/invisible_wall/inside, /area/caribbean/no_mans_land/invisible_wall/inside/one, /area/caribbean/no_mans_land/invisible_wall/inside/two)
	respawn_delay = 300
	no_winner = "<font style='color:green'>The furnace is burning.</font>"
	current_win_condition = "<font style='color:green'>The furnace is burning.</font>"
	faction_organization = list(CIVILIAN)
	times_of_day = list("Night")
	valid_weather_types = list(WEATHER_WET, WEATHER_EXTREME)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/colonies/british
		)
	age = "1953"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "antarctica survival"
	mission_start_message = "<font size=4>Keep the furnace running until rescue arrives in 90 minutes!</font>"
	faction1 = CIVILIAN
	songs = list("The Thing:1" = "sound/music/the_thing.ogg")
	ambience = list('sound/ambience/winter.ogg')
	is_singlefaction = TRUE
	is_RP = TRUE
	has_hunger = TRUE
	gamemode_vote = FALSE
	var/no_loop = FALSE
	var/obj/structure/oven/big/furnace = null
	var/furnace_timer_check = 0

/obj/map_metadata/antarctica/New()
	..()
	spawn(200)
		change_weather(WEATHER_WET,TRUE)
		update_lighting("Night",null,FALSE)
		furnace_loop()

/obj/map_metadata/antarctica/proc/furnace_loop()
	if (furnace)
		if (furnace.fuel <= 0 || !furnace.on)
			if (furnace_timer_check == 0)
				to_chat(world, "<font size = 4><span class = 'danger'>The furnace has ran out of fuel!</span></font>")
				current_win_condition = "<font style='color:yellow'>The furnace is off!</font>"
			furnace_timer_check += 1
		else
			if (furnace_timer_check > 0)
				current_win_condition = "<font style='color:green'>The furnace is burning.</font>"
			furnace_timer_check = 0
	spawn(100)
		furnace_loop()

/obj/map_metadata/antarctica/faction1_can_cross_blocks()
	return TRUE

/obj/map_metadata/antarctica/current_stat_message()
	return current_win_condition
	
/obj/map_metadata/antarctica/update_win_condition()
	if (furnace_timer_check >= 6 && no_loop == FALSE)
		current_win_condition = "<font style='color:red'>You let the furnace go cold and have lost!</font>"
		to_chat(world, "<font size = 4><span class = 'danger'>You let the furnace go cold and have lost!</span></font>")
		no_loop = TRUE
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		ticker.finished = TRUE
	if (world.time >= 54000 && furnace_timer_check < 6) //90 mins
		ticker.finished = TRUE
		if (ticker.finished && no_loop == FALSE)
			var/message = "You have managed to survive until rescue arrived!"
			to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			no_loop = TRUE
	return TRUE

/obj/map_metadata/antarctica/cross_message(faction)
	return ""

/obj/map_metadata/antarctica/reverse_cross_message(faction)
	return ""

/////////////////////////////////////////////////

/datum/job/civilian/survivor/antarctica
	title = "Antarctic Survivor"
	spawn_location = "JoinLateCiv"
	min_positions = 60
	max_positions = 60
	can_be_female = TRUE
	allowed_maps = list(MAP_ANTARCTICA)

/datum/job/civilian/survivor/antarctica/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	var/obj/item/clothing/under/afghanka/U = new /obj/item/clothing/under/afghanka(H)
	H.equip_to_slot_or_del(U, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/flashlight/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/survival(H), slot_l_store)
	var/obj/item/weapon/storage/backpack/BP = new /obj/item/weapon/storage/backpack(null)
	H.equip_to_slot_or_del(BP, slot_back)
	
	H.add_note("Role", "Keep the furnace burning! If it dies out for more than <b>one minute</b>, all hope will be lost.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
