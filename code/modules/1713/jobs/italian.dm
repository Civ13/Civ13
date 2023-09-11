/datum/job/italian
	faction = "Human"

/datum/job/italian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name

/datum/job/italian/soldier
	title = "Soldato"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateIT" //for testing!

	uses_squads = TRUE

	min_positions = 1
	max_positions = 999

/datum/job/italian/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/pickelhaube2(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Italian Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
