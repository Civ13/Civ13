/obj/map_metadata/lightsout
	ID = MAP_LIGHTS_OUT
	title = "Lights Out"
	description = "Survive a hostile and pitch black jungle armed only with a pistol, flashlight and your courage."

	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle)
	respawn_delay = 300
	no_winner ="The sun is still out."
	faction_organization = list(CIVILIAN)
	times_of_day = list("Dark Night")
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

/obj/map_metadata/lightsout/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/lightsout/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle))
		return !faction1_can_cross_blocks()
	return FALSE


/obj/map_metadata/lightsout/update_win_condition()
	if (ticker.finished && no_loop == FALSE)
		var/message = "Someone has managed to escape!"
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

/obj/map_metadata/lightsout/cross_message(faction)
	return "<font size = 4>The grace wall is lifted!</font>"

/obj/map_metadata/lightsout/reverse_cross_message(faction)
	return ""

/////////////////////////////////////////////////

/datum/job/civilian/survivor
	title = "Survivor"
	spawn_location = "JoinLateCiv"
	min_positions = 60
	max_positions = 60
	can_be_female = TRUE
	allowed_maps = list(MAP_LIGHTS_OUT)

/datum/job/civilian/survivor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	var/obj/item/clothing/under/us_uni/us_lightuni_modern/U = new  /obj/item/clothing/under/us_uni/us_lightuni_modern(H)
	H.equip_to_slot_or_del(U, slot_w_uniform)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	U.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/flashlight/modern/darknight(H), slot_belt)
	var/obj/item/weapon/storage/backpack/BP = new /obj/item/weapon/storage/backpack(null)
	H.equip_to_slot_or_del(BP, slot_back)
	BP.attackby(new /obj/item/ammo_magazine/m9beretta(BP), H)
	BP.attackby(new /obj/item/ammo_magazine/m9beretta(BP), H)
	BP.attackby(new /obj/item/stack/medical/advanced/bruise_pack(BP), H)
	BP.attackby(new /obj/item/weapon/reagent_containers/syringe/morphine(BP), H)
	H.equip_to_slot_or_drop(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)

	H.add_note("Role", "Reach the extraction zone and escape!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)