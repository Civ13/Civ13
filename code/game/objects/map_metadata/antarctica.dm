/obj/map_metadata/antarctica
	ID = MAP_ANTARCTICA
	title = "Antarctica"
	description = "Survive and keep the furnace alive!"
	lobby_icon = "icons/lobby/antarctica.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle, /area/caribbean/no_mans_land/invisible_wall/inside, /area/caribbean/no_mans_land/invisible_wall/inside/one, /area/caribbean/no_mans_land/invisible_wall/inside/two)
	respawn_delay = 300
	no_winner ="The furnace is burning."
	faction_organization = list(CIVILIAN)
	times_of_day = list("Night")
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/colonies/british
		)
	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the escape"
	mission_start_message = "<font size=4>RUN!</font>"
	faction1 = CIVILIAN
	valid_weather_types = list(WEATHER_WET)
	songs = list("Akira:1" = "sound/music/akira.ogg",)
	is_singlefaction = TRUE
	is_RP = TRUE
	var/no_loop = FALSE
	var/obj/structure/oven/big/furnace = null

/obj/map_metadata/antarctica/faction1_can_cross_blocks()
	return TRUE

/obj/map_metadata/antarctica/update_win_condition()
	if (ticker.finished && no_loop == FALSE)
		var/message = "You have managed to survive until rescue arrived!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop = TRUE
		return FALSE
	else
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
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