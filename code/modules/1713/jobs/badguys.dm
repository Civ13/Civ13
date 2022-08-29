////////////////////////////////////////////CIVILIAN///////////////////////////////////////////////////////

/datum/job/american/robber
	title = "Bank Robber"
	rank_abbreviation = ""
	spawn_location = "JoinLateRU"
	
	is_heist = TRUE
	is_outlaw = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 50

/datum/job/american/robber/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Bad Guys"
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/lwh/black(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava(H), slot_wear_mask)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
//gun
	if (prob(95))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5, slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5, slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5, slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5, slot_r_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(pasgt_armor, H)
//extra
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b>, one day you and your mates thought that robbing a bank was a good idea!")
	H.add_note("Objective", "Steal 10.000 from the bank's vault before the police capture the vault!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)