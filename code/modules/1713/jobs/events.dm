/datum/job/pirates/event
	title = "Event Participant"
	en_meaning = ""
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateDM"

	is_event_role = TRUE

	min_positions = 50
	max_positions = 200

/datum/job/pirates/event/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	if (map.ID == MAP_HUNGERGAMES)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/squid_contestant(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/squid_coat(H), slot_wear_suit)
	else
		var/randcloth = rand(1,6)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/wastelander(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
		else if (randcloth == 6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
//suit
		var/randsuit = rand(1,7)
		if (randsuit == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/hawaiian/orange(H), slot_wear_suit)
		else if (randsuit == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/hawaiian/green(H), slot_wear_suit)
		else if (randsuit == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randsuit == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown(H), slot_wear_suit)
		else if (randsuit == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/biker(H), slot_wear_suit)
		else if (randsuit == 6)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
		else if (randsuit == 7)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/oldyjacket(H), slot_wear_suit)
//bandages
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)

	H.add_note("Role", "Be the last one to live!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (map.ID == MAP_HUNGERGAMES)
		spawn(20)
		if (H.client)
			H.client.screen += new/obj/screen/areashow("Area Location","8,14", H, null, "")
			H.client.screen += new/obj/screen/areaclosing("Area Closing","1,14", H, null, "")
			H.client.screen += new/obj/screen/playersleft("Players Left","12,14", H, null, "")
		spawn(20)
			if (H.client)
				H.name = H.client.ckey
	return TRUE