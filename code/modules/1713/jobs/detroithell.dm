////////////////////////////////////////////MODERNUN/////////////////////////////////////////////////////////
/datum/job/civilian/unitednations/mod/lieutenant
	title = "United Nations Lieutenant"
	rank_abbreviation = "UN Lt."
	spawn_location = "JoinLateUN"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_get_coordinates = TRUE
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE
	selection_color = "#53ADD0"

	min_positions = 1
	max_positions = 1

/datum/job/civilian/unitednations/mod/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/mk18(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/un/mk(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/mk18(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of all United Nations Personell. Command and lead them!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/civilian/unitednations/mod/sergeant
	title = "United Nations Sergeant"
	rank_abbreviation = "UN Sgt."

	spawn_location = "JoinLateUN"
	is_squad_leader = TRUE
	uses_squads = TRUE
	can_get_coordinates = TRUE
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	min_positions = 2
	max_positions = 10

/datum/job/civilian/unitednations/mod/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/p90(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/un/p90(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/nonfrag/m26(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(armor, H)
	armor.attackby(new/obj/item/ammo_magazine/p90, H)
	armor.attackby(new/obj/item/ammo_magazine/p90, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b in charge of a leading a squad and following your CO's orders!")
	H.nationality = "United Nations"
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/civilian/unitednations/mod/soldier
	title = "United Nations Soldier"
	en_meaning = ""
	rank_abbreviation = "UN Pvt."
	spawn_location = "JoinLateUN"
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	uses_squads = TRUE

	min_positions = 2
	max_positions = 100
/datum/job/civilian/unitednations/mod/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m16(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m16(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(armor, H)
	armor.attackby(new/obj/item/ammo_magazine/m16, H)
	armor.attackby(new/obj/item/ammo_magazine/m16, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. Follow orders!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/civilian/unitednations/mod/doctor
	title = "United Nations Doctor"
	rank_abbreviation = "UN Dr."
	spawn_location = "JoinLateUN"
	selection_color = "#53ADD0"
	is_medic = TRUE
	can_be_female = TRUE
	is_un = TRUE
	min_positions = 2
	max_positions = 4
	whitelisted = FALSE

/datum/job/civilian/unitednations/mod/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un/medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/stethoscope(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/white = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(armor, H)
	armor.attackby(new/obj/item/ammo_magazine/sten2, H)
	armor.attackby(new/obj/item/ammo_magazine/sten2, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep both the UN troops and any civilians in good health!<br><b>You are a noncombative role, you must try to avoid putting yourself in danger</b>.")
	H.nationality = "United Nations"
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/civilian/unitednations/mod/radop
	title = "United Nations Radio Operator"
	en_meaning = ""
	rank_abbreviation = "UN Pfc."
	spawn_location = "JoinLateUN"
	is_detroit = TRUE
	is_un = FALSE
	can_get_coordinates = TRUE
	is_radioman = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/civilian/unitednations/mod/radop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/sten(H), slot_belt)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/un_beret(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(armor, H)
	armor.attackby(new/obj/item/ammo_magazine/sten2, H)
	armor.attackby(new/obj/item/ammo_magazine/sten2, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. Follow orders, ensure communication between your squad and your superiors and call in airstrikes!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/civilian/unitednations/mod/press
	title = "United Nations Mobile Press"
	en_meaning = ""
	rank_abbreviation = "Press."
	spawn_location = "JoinLateUN"
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE
	whitelisted = TRUE
	selection_color = "#53ADD0"

	min_positions = 1
	max_positions = 1

/datum/job/civilian/unitednations/mod/press/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/press(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet/press(H), slot_head)
//other
	H.equip_to_slot_or_del(new /obj/item/camera_film(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/camera/coldwar(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/video_camera(H), slot_l_hand)
//armor
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/press/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/press(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. Follow orders, ensure communication between your squad and your superiors and call in airstrikes!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE
///////////////////////////////////////////////////////////detroiters///////////////////////////////////////////////////////////////

/datum/job/american/detroit/leader
	title = "Detroit Crackhead Leader"
	en_meaning = ""
	rank_abbreviation = "Boss."

	spawn_location = "JoinLateKH"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_get_coordinates = TRUE
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/civilian/detroit/leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	var/randimc = rand(1,7)
	switch(randimc)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
//head
	var/randimh = rand(1,5)
	switch(randimh)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads/down(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tophat(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/sten(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_l_store)

		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_l_store)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m16(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m16(H), slot_l_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a underground crack selling ring leader, lead your people and take over the city, they rely on you and your cheap crack!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/american/detroit/crackhead
	title = "crackhead"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = "JoinLateKH"
	uses_squads = TRUE
	is_detroit = TRUE
	is_un = FALSE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 200

/datum/job/civilian/detroit/crackhead(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	var/randimc = rand(1,7)
	switch(randimc)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/sten(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/sten2(H), slot_l_store)

		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_l_store)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple crackhead, these UN pieces of shit are trying to take your crack, go kick their ass!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE
