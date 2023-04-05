////////////////////////////////////////////CIVILIAN///////////////////////////////////////////////////////
/datum/job/civilian
	faction = "Human"

/datum/job/civilian/give_random_name(var/mob/living/human/H)
	if (is_civilizations || is_nomad)
		H.name = H.species.get_random_name(H.gender)
		H.real_name = H.name
	else
		H.give_random_civ_name()

/datum/job/civilian/governor
	title = "Governor"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governor"
	spawn_location = "JoinLateCivA"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_governor = TRUE
	is_1713 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/architect
	title = "Architect"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Architect"

	spawn_location = "JoinLateCivA"

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_1713 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/architect/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/banker
	title = "Banker"
	en_meaning = "Master of Funds"
	rank_abbreviation = "Banker"


	spawn_location = "JoinLateCivB"
	is_officer = TRUE
	whitelisted = TRUE
	is_vip = TRUE

	is_1713 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/banker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony's funds. Organize your men and tax the poor!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.make_businessman()

	return TRUE

/datum/job/civilian/bank_teller
	title = "Teller"
	en_meaning = "Bank Teller"
	rank_abbreviation = "Teller"
	can_be_female = TRUE
	spawn_location = "JoinLateCivB"
	is_merchant = TRUE

	whitelisted = TRUE
	is_1713 = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/bank_teller/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	if (map.ordinal_age <= 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a teller who decided to move in to the new colony to get rich. Keep your bank secure and jew the people out of their money!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.make_businessman()

	return TRUE

/datum/job/civilian/officer
	title = "Town Guard Officer"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Officer"

	spawn_location = "JoinLateCivC"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_1713 = TRUE


	min_positions = 1
	max_positions = 5

/datum/job/civilian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)
	var/obj/item/clothing/accessory/storage/webbing/filled_a = new /obj/item/clothing/accessory/storage/webbing(null)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(filled_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)


	return TRUE


/datum/job/civilian/veteran
	title = "Town Guard"
	en_meaning = "Colony Security"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivC"

	is_1713 = TRUE


	min_positions = 1
	max_positions = 30

/datum/job/civilian/veteran/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)
	var/obj/item/clothing/accessory/storage/webbing/filled_a = new /obj/item/clothing/accessory/storage/webbing(null)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	filled_a.attackby(new/obj/item/ammo_casing/musketball, H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(filled_a, H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)


	return TRUE



/datum/job/civilian/medic
	title = "Doctor"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Doctor"

	spawn_location = "JoinLateCiv"

	is_medic = TRUE
	is_1713 = TRUE


	min_positions = 1
	max_positions = 20

/datum/job/civilian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE
/datum/job/civilian/merchant
	title = "Merchant"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Merchant"

	spawn_location = "JoinLateCiv"
	is_merchant = TRUE
	can_be_female = TRUE
	whitelisted = TRUE
	is_1713 = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/civilian/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.make_businessman()

	return TRUE
/datum/job/civilian/priest
	title = "Priest"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_religious = TRUE
	is_1713 = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/civilian/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)

	return TRUE

/datum/job/civilian/prospector
	title = "Prospector"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_1713 = TRUE


	min_positions = 3
	max_positions = 40

/datum/job/civilian/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/weapon/material/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/farmer
	title = "Farmer"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_1713 = TRUE


	min_positions = 3
	max_positions = 50

/datum/job/civilian/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("farming", STAT_VERY_HIGH)

	return TRUE
/datum/job/civilian/carpenter
	title = "Carpenter"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_1713 = TRUE


	min_positions = 3
	max_positions = 50

/datum/job/civilian/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/blacksmith
	title = "Blacksmith"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Blacksmith"

	spawn_location = "JoinLateCiv"
	whitelisted = TRUE
	can_be_female = TRUE
	is_1713 = TRUE


	min_positions = 2
	max_positions = 3

/datum/job/civilian/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", 250)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/civilian/inkeeper
	title = "Inkeeper"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Innkeeper"
	can_be_female = TRUE
	spawn_location = "JoinLateCivD"

	is_1713 = TRUE


	min_positions = 1
	max_positions = 2

/datum/job/civilian/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)


	return TRUE

/datum/job/civilian/barkeep
	title = "Bar Keep/Bar Maiden"
	en_meaning = "Colony Taverner"
	rank_abbreviation = "Waiter"
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_1713 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/barkeep/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to man an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)


	return TRUE



/datum/job/civilian/worker
	title = "Colonist"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_1713 = TRUE


	min_positions = 10
	max_positions = 150

/datum/job/civilian/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Colonist</b>. Build your village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/civilian/beggar
	title = "Beggar"
	en_meaning = "Poor Colonist"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	is_1713 = TRUE


	min_positions = 1
	max_positions = 3

/datum/job/civilian/beggar/equip(var/mob/living/human/H)
	if (!H)	return FALSE


	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/lighttunic(H), slot_w_uniform)


	H.add_note("Role", "You are a penyless colonist. Try to survive!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////PIONEERS//////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/civilian/mayor
	title = "Mayor"
	en_meaning = "Town Leader"
	rank_abbreviation = "Mayor"


	spawn_location = "JoinLateCivA"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_governor = TRUE
	is_pioneer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/mayor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
	var/obj/item/clothing/accessory/holster/hip/filled_a = new /obj/item/clothing/accessory/holster/hip(null)
	filled_a.attackby(new/obj/item/weapon/gun/projectile/revolver/peacemaker, H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(filled_a, H)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/really_black_suit(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/top_hat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c45(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/twenty(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/keychain(H), slot_wear_id)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this town. Organize your men and build a town!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/architect_pioneer
	title = "Head Architect"
	en_meaning = "Town Chief Carpenter/Planner"
	rank_abbreviation = "Head Architect"

	spawn_location = "JoinLateCivC"

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_pioneer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/architect_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/money/real/twenty(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are the <b>Head Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the town with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/banker_pioneer
	title = "Town Banker"
	en_meaning = "Banker/Owner"
	rank_abbreviation = "Banker"


	spawn_location = "JoinLateCivB"
	is_officer = TRUE
	whitelisted = TRUE

	is_pioneer = TRUE
	is_vip = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/banker_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/ten(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony's funds. Organize your men and tax the poor!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.make_businessman()

	return TRUE

/datum/job/civilian/bank_teller_pioneer
	title = "Bank Teller"
	en_meaning = "Bank Worker"
	rank_abbreviation = "Teller"

	spawn_location = "JoinLateCivB"
	is_merchant = TRUE
	can_be_female = TRUE
	whitelisted = TRUE
	is_pioneer = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/bank_teller_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/twenty(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/five(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b>, a teller who decided to move in to the new colony to get rich. Keep your bank secure and jew the people out of their money!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.make_businessman()

	return TRUE

/datum/job/civilian/judge_pioneer
	title = "Town Judge"
	en_meaning = "Judge"
	rank_abbreviation = "Judge"


	spawn_location = "JoinLateCivC"
	is_officer = TRUE
	whitelisted = TRUE
	is_vip = TRUE

	is_pioneer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/judge_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifteen(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the judge of the local town. Help sentence justice upon those evil doers!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/officer_pioneer
	title = "Union Guard Officer"
	en_meaning = "Town Security Leader"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateCivC"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_pioneer = TRUE


	min_positions = 1
	max_positions = 5

/datum/job/civilian/officer_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/ten(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)
	var/obj/item/clothing/accessory/holster/hip/filled_a = new /obj/item/clothing/accessory/holster/hip(null)
	filled_a.attackby(new/obj/item/weapon/gun/projectile/revolver/peacemaker, H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(filled_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Mayor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)


	return TRUE


/datum/job/civilian/veteran_pioneer
	title = "Union Guard"
	en_meaning = "Town Security"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivC"
	whitelisted = TRUE
	is_pioneer = TRUE


	min_positions = 1
	max_positions = 30

/datum/job/civilian/veteran_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unioncap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)
	var/obj/item/clothing/accessory/holster/hip/filled_a = new /obj/item/clothing/accessory/holster/hip(null)
	filled_a.attackby(new/obj/item/weapon/gun/projectile/revolver/peacemaker, H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(filled_a, H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)


	return TRUE



/datum/job/civilian/medic_pioneer
	title = "Medical Doctor"
	en_meaning = "Town Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateCiv"

	is_medic = TRUE
	is_pioneer = TRUE


	min_positions = 1
	max_positions = 20

/datum/job/civilian/medic_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifteen(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE
/datum/job/civilian/merchant_pioneer
	title = "Trader"
	en_meaning = "Town Trader"
	rank_abbreviation = "Trader"

	spawn_location = "JoinLateCiv"
	is_merchant = TRUE
	can_be_female = TRUE
	whitelisted = TRUE
	is_pioneer = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/civilian/merchant_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/top_hat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/stack/money/real/twenty(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)
	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.make_businessman()

	return TRUE
/datum/job/civilian/priest_pioneer
	title = "Church Priest"
	en_meaning = "Town Priest"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	is_religious = TRUE
	is_pioneer = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/civilian/priest_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H), slot_wear_id)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)

	return TRUE

/datum/job/civilian/prospector_pioneer
	title = "Town Prospector"
	en_meaning = "Miner/Explorer"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	is_pioneer = TRUE

	can_be_female = TRUE
	min_positions = 3
	max_positions = 40
	default_language = "Chinese"
	additional_languages = list("English" = 100, "Vietnamese" = 10, "Japanese" = 5)
	male_tts_voice = "Takumi" //jap
	female_tts_voice = "Zhiyu" //chinese

/datum/job/civilian/prospector_pioneer/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_chinese_name(H.gender)
	H.real_name = H.name
/datum/job/civilian/prospector_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rice_hat(H), slot_head)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/haori(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/blue(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/red(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee" && H.f_style != "Watson Mustache")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee", "Watson Mustache")
	H.equip_to_slot_or_del(new/obj/item/weapon/material/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.make_businessman()

	return TRUE

/datum/job/civilian/farmer_pioneer
	title = "Local Farmer"
	en_meaning = "Farmer/Rancher"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	is_pioneer = TRUE


	min_positions = 3
	max_positions = 50

/datum/job/civilian/farmer_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("farming", STAT_VERY_HIGH)
	H.make_businessman()

	return TRUE
/datum/job/civilian/carpenter_pioneer
	title = "Town Carpenter"
	en_meaning = "Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"

	spawn_location = "JoinLateCiv"

	is_pioneer = TRUE
	can_be_female = TRUE

	min_positions = 3
	max_positions = 50

/datum/job/civilian/carpenter_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)

	//head
		if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatecap(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/sombrero(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/blacksmith_pioneer
	title = "Pioneer Blacksmith"
	en_meaning = "Town Blacksmith"
	rank_abbreviation = "Blacksmith"

	spawn_location = "JoinLateCiv"
	whitelisted = TRUE

	is_pioneer = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 3

/datum/job/civilian/blacksmith_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)

	//head
		if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatecap(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/sombrero(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/ten(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/shovel/spade/wood(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft things from metal. You can make tools, weapons, guns, and more. However you probably should follow the <b>Mayor's</b> orders!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", 250)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/civilian/inkeeper_pioneer
	title = "Innkeeper"
	en_meaning = "Innkeeper"
	rank_abbreviation = "Innkeeper"

	spawn_location = "JoinLateCivD"

	is_pioneer = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/inkeeper_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/bartender(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/ten(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)


	return TRUE

/datum/job/civilian/barkeep_pioneer
	title = "Bar Keeper"
	en_meaning = "Taverner"
	rank_abbreviation = "Barkeeper"

	spawn_location = "JoinLateCiv"

	is_pioneer = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/barkeep_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/bartender(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/twenty(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to man an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/civilian/worker_pioneer
	title = "Pioneer"
	en_meaning = "Settler"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_pioneer = TRUE
	can_be_female = TRUE

	min_positions = 10
	max_positions = 150

/datum/job/civilian/worker_pioneer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)

		//head
		if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatecap(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
		else if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
		else if (prob(5))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/sombrero(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/five(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Pioneer</b>build your town!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE
////////////////////////////////////////////////////////////////
/////////////////////ART OF THE DEAL GAMEMODE///////////////////
////////////////////////////////////////////////////////////////
/datum/job/civilian/businessman
	title = "Businessman"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivA"

	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 0
	max_positions = 0

/datum/job/civilian/businessman/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//suit
	var/randsuit = pick(1,2,3)
	if (randsuit == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
	else if (randsuit == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/navy_suit(H), slot_wear_suit)
//glasses
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	var/obj/item/clothing/under/uniform = H.w_uniform
//suspenders
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/suspenders/ysuspenders = new /obj/item/clothing/accessory/suspenders(null)
			uniform.attackby(ysuspenders, H)
		else
			var/obj/item/clothing/accessory/suspenders/dark/ysuspenders = new /obj/item/clothing/accessory/suspenders/dark(null)
			uniform.attackby(ysuspenders, H)

	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_r_hand)
//hats
	var/randhat = pick(1,2,3)
	if (randhat == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else if (randhat == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/peakyblinder(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.add_note("Role", "You are a member of the corporation. Make sure the deal goes through!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")
/datum/job/civilian/businessman/yellow
	title = "Goldstein Solutions"
	selection_color = "#7e7e06"
	spawn_location = "JoinLateCivA"
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/yellow/CEO
	title = "Goldstein Solutions CEO"
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
	is_vip = TRUE
/datum/job/civilian/businessman/yellow/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_hebrew_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/yellow(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessyellow(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionyellow(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/armband/spanish/armband = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE
/datum/job/civilian/businessman/yellow/CEO/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_hebrew_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/yellow(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessyellow(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionyellow(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/circumcision(H), slot_l_hand)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform1.attackby(longer, H)
	longer.attackby(new/obj/item/weapon/material/sword/urukhaiscimitar, H)
	uniform1.attackby(longer, H)
	var/obj/item/clothing/accessory/armband/spanish/armband = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE

/datum/job/civilian/businessman/green
	title = "Kogama Kraftsmen"
	selection_color = "#2D632D"
	spawn_location = "JoinLateCivB"
	min_positions = 3
	max_positions = 50
/datum/job/civilian/businessman/green/CEO
	title = "Kogama Kraftsmen CEO"
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
	is_vip = TRUE

/datum/job/civilian/businessman/green/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/green(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessgreen(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factiongreen(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/armband/portuguese/armband = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE
/datum/job/civilian/businessman/green/CEO/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/green(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessgreen(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factiongreen(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/daishoh = new /obj/item/clothing/accessory/storage/sheath/daisho(null)
	uniform1.attackby(daishoh, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/katana, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/wakazashi, H)
	uniform1.attackby(daishoh, H)
	var/obj/item/clothing/accessory/armband/portuguese/armband = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE

/datum/job/civilian/businessman/blue
	title = "Giovanni Blu Stocks"
	selection_color = "#353575"
	spawn_location = "JoinLateCivC"
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/blue/CEO
	title = "Giovanni Blu Stocks CEO"
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
	is_vip = TRUE

/datum/job/civilian/businessman/blue/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessblue(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionblue(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/armband = new /obj/item/clothing/accessory/armband/french(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE
/datum/job/civilian/businessman/blue/CEO/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessblue(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionblue(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_l_hand)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longsword = new /obj/item/clothing/accessory/storage/sheath/longsword(null)
	uniform1.attackby(longsword, H)
	longsword.attackby(new/obj/item/weapon/material/sword/longsword, H)
	var/obj/item/clothing/accessory/armband/french/armband = new /obj/item/clothing/accessory/armband/french(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE

/datum/job/civilian/businessman/red
	title = "Rednikov Industries"
	selection_color = "#632D2D"
	spawn_location = "JoinLateCivD"
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/red/CEO
	title = "Rednikov Industries CEO"
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
	is_vip = TRUE
/datum/job/civilian/businessman/red/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessred(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionred(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE

/datum/job/civilian/businessman/red/CEO/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = replacetext(title," CEO", "")
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/businessred(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionred(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bowie(H), slot_l_hand)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform1.attackby(longer, H)
	longer.attackby(new/obj/item/weapon/material/sword/shashka, H)
	uniform1.attackby(longer, H)
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform1.attackby(armband, H)
	..()
	return TRUE

/datum/job/civilian/businessman/mckellen
	title = "McKellen Staff"
	selection_color = "#ff883e"
	spawn_location = "JoinLateCivJ"
	min_positions = 3
	max_positions = 8
	additional_languages = list("Gaelic" = 100)
	can_be_female = TRUE
	is_deal = TRUE

/datum/job/civilian/businessman/mckellen/manager
	title = "McKellen Manager"
	is_officer = TRUE
	spawn_location = "JoinLateCivK"
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "Manager"
	whitelisted = TRUE
	additional_languages = list("Gaelic" = 100)
	is_vip = TRUE

/datum/job/civilian/businessman/mckellen/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.add_note("Role", "You are a part of McKellen's Entreprises. Your goal is to work the restaurant and produce illegal substances secretly, while also attempting to extort other businesses for their revenue and criminal power.")

	var/found = FALSE
	for (var/i in whitelist_list)
		var/temp_ckey = lowertext(i)
		temp_ckey = replacetext(temp_ckey," ", "")
		temp_ckey = replacetext(temp_ckey,"_", "")
		if (temp_ckey == H.client.ckey)
			found = TRUE
	if (found == TRUE)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
		var/obj/item/clothing/suit = H.wear_suit
		var/obj/item/ammo_magazine/tommy/mag = new /obj/item/ammo_magazine/tommy(null)
		suit.attackby(mag, H)
		suit.attackby(mag, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/tommy(H), slot_l_hand)
		H.add_note("Specialization", "You are a part of McKellen's Entreprises. You're the enforcer, the one who does what needs gettin done.")
		H.setStat("strength", STAT_VERY_HIGH)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_VERY_HIGH)
		H.setStat("dexterity", STAT_VERY_HIGH)
		H.setStat("swords", STAT_VERY_HIGH)
		H.setStat("pistol", STAT_VERY_VERY_HIGH)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_NORMAL)
		H.setStat("machinegun", STAT_MAX)
//clothes
		var/randclothes = rand(1,3)
		switch(randclothes)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
				if (prob(60))
					H.equip_to_slot_or_del(new /obj/item/clothing/head/chefhat(H), slot_head)
				else
					H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
				var/obj/item/clothing/under/uniform = H.w_uniform
				if (prob(50))
					var/obj/item/clothing/accessory/suspenders/dark/ysuspenders = new /obj/item/clothing/accessory/suspenders/dark(null)
					uniform.attackby(ysuspenders, H)
			if (2)
				if (prob(80))
					H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/bartender(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/kilt(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/caubeen(H), slot_head)

//other
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mckellen(H), slot_r_store)

	H.name = H.species.get_random_irish_name(H.gender)
	H.real_name = H.name
	if (prob(70))
		var/new_hair = pick("Red","Orange")
		var/hex_hair = hair_colors[new_hair]
		H.r_hair = hex2num(copytext(hex_hair, 2, 4))
		H.g_hair = hex2num(copytext(hex_hair, 4, 6))
		H.b_hair = hex2num(copytext(hex_hair, 6, 8))
		H.r_facial = hex2num(copytext(hex_hair, 2, 4))
		H.g_facial = hex2num(copytext(hex_hair, 4, 6))
		H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/businessman/mckellen/manager/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.add_note("Role", "You are a part of McKellen's Entreprises. Your goal is to manage the restaurant and produce illegal substances secretly, while also attempting to extort other businesses for their revenue and criminal power.")


//clothes

	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/civ/mckellen/ira1 = new/obj/item/weapon/key/civ/mckellen(null)
	var/obj/item/weapon/key/civ/mckellen/manager/ira2 = new/obj/item/weapon/key/civ/mckellen/manager(null)
	KC.attackby(ira1,H)
	KC.attackby(ira2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/tie/tie = new /obj/item/clothing/accessory/custom/tie(null)
	tie.color = "#ff883e"
	tie.setd = TRUE
	tie.uncolored = FALSE
	uniform.attackby(tie, H)

//other
	H.equip_to_slot_or_del(new /obj/item/weapon/telephone/mobile/mobilefaction/mckellen(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionmckellen(H), slot_l_store)
	H.name = H.species.get_random_irish_name(H.gender)
	H.real_name = H.name
	if (prob(80))
		var/new_hair = pick("Red","Orange")
		var/hex_hair = hair_colors[new_hair]
		H.r_hair = hex2num(copytext(hex_hair, 2, 4))
		H.g_hair = hex2num(copytext(hex_hair, 4, 6))
		H.b_hair = hex2num(copytext(hex_hair, 6, 8))
		H.r_facial = hex2num(copytext(hex_hair, 2, 4))
		H.g_facial = hex2num(copytext(hex_hair, 4, 6))
		H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/policeofficer
	title = "Police Officer"
	rank_abbreviation = "Officer"
	spawn_location = "JoinLateCiv"
	selection_color = "#353575"

	is_heist = TRUE
	is_law = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 50

/datum/job/civilian/policeofficer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Police Department"
	give_random_name(H)

	H.equip_to_slot_or_del(new /obj/item/clothing/under/traffic_police(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
	uniform1.attackby(hiph, H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Officer ","")] police badge"
		pb.desc = "a police badge in star shape, with <b>[replacetext(H.real_name,"Officer ","")]</b> engraved."
	uniform1.attackby(pb, H)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup, slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/traffic_police(H), slot_head)

	var/loadout = rand(1,4)
	var/obj/map_metadata/bank_robbery/MP = map
	if (MP.civilians_evacuated == MP.civilians_alive)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/ar15(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ar15(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ar15(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/glock(H), slot_belt)
	else
		switch(loadout)
			if(1)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
				if (prob(60))
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
				else
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/glock(H), slot_belt)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/snw10(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/shellbox(H), slot_r_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/shellbox/beanbag(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/c38(H), slot_belt)
			if(3)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p220(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p220(H), slot_r_store)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/p220(H), slot_l_hand)
				if (prob(70))
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
				else
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/p220(H), slot_belt)
			if(4)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_r_store)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
				if (prob(40))
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
				else
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/m9(H), slot_belt)

	H.add_note("Role", "You are a member of the police force. Your objective is to arrest (or deal justice to) as many criminals as possible!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)

/datum/job/civilian/swat
	title = "SWAT Officer"
	rank_abbreviation = "Sergeant"
	spawn_location = "JoinLateSwat"
	selection_color = "#1d1d42"

	is_heist = TRUE
	is_law = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 5
	whitelisted = TRUE

/datum/job/civilian/swat/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Police Department"
	give_random_name(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/swat_new(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/swat_new(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/holster/tactical/hiph = new /obj/item/clothing/accessory/holster/tactical(null)
	uniform1.attackby(hiph, H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Officer ","")] police badge"
		pb.desc = "a police badge in star shape, with <b>[replacetext(H.real_name,"Officer ","")]</b> engraved."
	uniform1.attackby(pb, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat_new(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/swat_new(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
	if(prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/mp5(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m16(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/m16(H), slot_belt)
	H.add_note("Role", "You are a member of a SWAT team and you've been called to get the situation under control. Your objective is to arrest (or deal justice to) as many criminals as possible!")

	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("machinegun", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)

/datum/job/civilian/dea_agent
	title = "DEA Agent"
	rank_abbreviation = "Agent"
	spawn_location = "JoinLateCiv"
	selection_color = "#000117"

	is_heist = TRUE
	is_law = TRUE
	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/civilian/dea_agent/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Police Department"
	give_random_name(H)
	var/randclothes = rand(1,4)
	switch(randclothes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective1(H), slot_w_uniform)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective2(H), slot_w_uniform)
		if(4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
	uniform1.attackby(hiph, H)
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar(null)
	uniform1.attackby(armor,H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Agent ","")] DEA badge"
		pb.desc = "a DEA badge, with <b>[replacetext(H.real_name,"Agent ","")]</b> engraved."
	uniform1.attackby(pb, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/dea(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/bank/glock(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/dea(H), slot_wear_suit)

	H.add_note("Role", "You are a federal agent of the Drug Enforcement Administration. Your objective is to arrest (or deal justice to) as many criminals as possible!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)

/datum/job/civilian/sheriffdep
	title = "County Deputy"
	rank_abbreviation = "Deputy"
	whitelisted = TRUE
	spawn_location = "JoinLateCiv"
	selection_color = "#c5a562"
	can_be_female = TRUE
	is_deal = TRUE

	min_positions = 5
	max_positions = 50

/datum/job/civilian/sheriffdep/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Sheriff Office"
	give_random_name(H)
	H.verbs += /mob/living/human/proc/undercover
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/countysheriff/deputy(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/countysheriff/deputy/short(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/police(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police/black(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
	uniform1.attackby(hiph, H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Deputy ","")] Sheriff's Office badge"
		pb.desc = "a sheriff deputy badge in star shape, with <b>[replacetext(H.real_name,"Deputy ","")]</b> engraved."
	uniform1.attackby(pb, H)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	if (prob(50))
		var/randhat = rand(1,2)
		switch(randhat)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/countysheriff_cap/black(H), slot_head)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/countysheriff_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/gunbox/police(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_r_hand)
	H.add_note("Role", "You are a member of the local Sheriff Department. Your objectives are to arrest as many businessmen as possible and aprehend money and disks!")
	H.add_note("Undercover", "If you need to go undercover and conceal your law enforcement officer status, toggle it under the IC tab.")
	H.add_note("Police Codes", "As an LEO, you can use police codes for faster broadcasting. It will be automatically converted to plaintext. Just use the radio prefix followed by the code, for example, \";10-4\" for affirmative.")
	H.add_note("List of Police Codes", "<b>10-0:</b> On my way (shows current location)<br><br> \
		<b>10-1:</b> Report in / share location.<br><br> \
		<b>10-2:</b> Report in as being available.<br><br> \
		<b>10-3:</b> Report in as being busy.<br><br> \
		<b>10-4:</b> Roger that / Affirmative.<br><br> \
		<b>10-5:</b> Negative / Impossible.<br><br> \
		<b>10-6:</b> Returning to the Police Station.<br><br> \
		<b>10-7:</b> Prisoner in custody / Arrested suspect.<br><br> \
		<b>10-8:</b> Request immediate assistance / Officer injured - All non-busy units should answer with a <b>10-0</b> and proceed to location (shows current location)<br><br> \
		<b>10-9:</b> Officer down, all units should answer with a <b>10-0</b> and proceed to location (shows current location) - This is automatically sent if an officer gets killed, no need for manual input, use <b>10-8</b> instead.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/sheriffdep/detective
	title = "Detective"
	rank_abbreviation = "Detective"
	whitelisted = TRUE
	spawn_location = "JoinLateCiv"
	selection_color = "#c5a562"
	can_be_female = TRUE
	is_deal = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/sheriffdep/detective/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Sheriff Office"
	give_random_name(H)
	H.verbs += /mob/living/human/proc/undercover
	var/randuni = rand(1,3)
	switch(randuni)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective1(H), slot_w_uniform)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective2(H), slot_w_uniform)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/police(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/forensics(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police/black(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	if(prob(50))
		var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
		uniform1.attackby(hiph, H)
	else
		var/obj/item/clothing/accessory/holster/armpit/armh = new /obj/item/clothing/accessory/holster/armpit(null)
		uniform1.attackby(armh, H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Detective ","")] Sheriff's Office badge"
		pb.desc = "a Sheriff's Office detective badge in star shape, with <b>[replacetext(H.real_name,"Detective ","")]</b> engraved."
	uniform1.attackby(pb, H)
	if (prob(80))
		var/randtie = rand(1,3)
		switch(randtie)
			if (1)
				var/obj/item/clothing/accessory/tie/tie = new /obj/item/clothing/accessory/tie(null)
				uniform1.attackby(tie, H)
			if (2)
				var/obj/item/clothing/accessory/tie/tieb = new /obj/item/clothing/accessory/tie/blue(null)
				uniform1.attackby(tieb, H)
			if (3)
				var/obj/item/clothing/accessory/tie/tier = new /obj/item/clothing/accessory/tie/red(null)
				uniform1.attackby(tier, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	if (prob(10))
		var/randhat = rand(1,2)
		switch(randhat)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/countysheriff_cap/black(H), slot_head)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/countysheriff_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/gunbox/police(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_r_hand)
	H.add_note("Role", "You are a detective of the local Sheriff Department. Your objectives are to investigate as many crimes as possible and help your fellow deputies to aprehend criminals and contraband!")
	H.add_note("Undercover", "If you need to go undercover and conceal your law enforcement officer status, toggle it under the IC tab.")
	H.add_note("Police Codes", "As an LEO, you can use police codes for faster broadcasting. It will be automatically converted to plaintext. Just use the radio prefix followed by the code, for example, \";10-4\" for affirmative.")
	H.add_note("List of Police Codes", "<b>10-0:</b> On my way (shows current location)<br><br> \
		<b>10-1:</b> Report in / share location.<br><br> \
		<b>10-2:</b> Report in as being available.<br><br> \
		<b>10-3:</b> Report in as being busy.<br><br> \
		<b>10-4:</b> Roger that / Affirmative.<br><br> \
		<b>10-5:</b> Negative / Impossible.<br><br> \
		<b>10-6:</b> Returning to the Police Station.<br><br> \
		<b>10-7:</b> Prisoner in custody / Arrested suspect.<br><br> \
		<b>10-8:</b> Request immediate assistance / Officer injured - All non-busy units should answer with a <b>10-0</b> and proceed to location (shows current location)<br><br> \
		<b>10-9:</b> Officer down, all units should answer with a <b>10-0</b> and proceed to location (shows current location) - This is automatically sent if an officer gets killed, no need for manual input, use <b>10-8</b> instead.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/sheriffdep/supervisor
	title = "County Sheriff"
	rank_abbreviation = "Sheriff"
	whitelisted = TRUE
	spawn_location = "JoinLateCivL"
	selection_color = "#c3b091"
	can_be_female = TRUE
	is_deal = TRUE
	is_officer = TRUE
	is_vip = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/sheriffdep/supervisor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Sheriff Office"
	give_random_name(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/countysheriff(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
	uniform1.attackby(hiph, H)
	var/obj/item/clothing/accessory/armband/policebadge/pb = new /obj/item/clothing/accessory/armband/policebadge(null)
	spawn(15)
		pb.name = "[replacetext(H.real_name,"Sheriff ","")] Sheriff's Office badge"
		pb.desc = "a sheriff badge in star shape, with <b>[replacetext(H.real_name,"Sheriff ","")]</b> engraved."
	uniform1.attackby(pb, H)
	var/obj/item/weapon/storage/belt/keychain/KC2 = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/civ/police/po1 = new/obj/item/weapon/key/civ/police(null)
	var/obj/item/weapon/key/civ/police/chief/po2 = new/obj/item/weapon/key/civ/police/chief(null)
	KC2.attackby(po1,H)
	KC2.attackby(po2,H)
	H.equip_to_slot_or_del(KC2, slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/countysheriff_hat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/gunbox/police(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_r_hand)
	H.add_note("Role", "You are the chief of the local Sheriff Department. Your objectives are to coordinate your fellow deputies in order to arrest as many criminal businessmen as possible and seize illegal money and disks!")
	H.add_note("Police Codes", "As a sheriff, you can use police codes for fast broadcasting. It will be automatically converted to plaintext. Just use the radio prefix followed by the code, for example, \";10-4\" for affirmative.")
	H.add_note("List of Police Codes", "<b>10-0:</b> On my way (shows current location)<br><br> \
		<b>10-1:</b> Report in / share location.<br><br> \
		<b>10-2:</b> Report in as being available.<br><br> \
		<b>10-3:</b> Report in as being busy.<br><br> \
		<b>10-4:</b> Roger that / Affirmative.<br><br> \
		<b>10-5:</b> Negative / Impossible.<br><br> \
		<b>10-6:</b> Returning to the Police Station.<br><br> \
		<b>10-7:</b> Prisoner in custody / Arrested suspect.<br><br> \
		<b>10-8:</b> Request immediate assistance / Officer injured - All non-busy units should answer with a <b>10-0</b> and proceed to location (shows current location)<br><br> \
		<b>10-9:</b> Officer down, all units should answer with a <b>10-0</b> and proceed to location (shows current location) - This is automatically sent if an officer gets killed, no need for manual input, use <b>10-8</b> instead.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/judge_aotd
	title = "County Judge"
	rank_abbreviation = "Judge"

	spawn_location = "JoinLateCivJud"
	is_officer = TRUE
	whitelisted = TRUE
	is_deal = TRUE
	is_vip = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/judge_aotd/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive(H), slot_w_uniform)
//jacket
	var/obj/item/clothing/suit/storage/jacket/custom/blazer/blazer = new /obj/item/clothing/suit/storage/jacket/custom/blazer(null)
	blazer.color = "#141414"
	blazer.uncolored = FALSE
	blazer.update_icon()
	H.equip_to_slot_or_del(blazer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular(H), slot_eyes)
//other
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/scarf/scarf = new /obj/item/clothing/accessory/custom/scarf(null)
	scarf.color = "#f0f0f0"
	scarf.setd = TRUE
	scarf.uncolored = FALSE
	scarf.update_icon()
	uniform.attackby(scarf, H)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/twenty(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/briefcase(H), slot_l_hand)

	H.add_note("Role", "You are a <b>[title]</b>, the judge of the local county. Help sentence justice upon the evil doers!")
	give_random_name(H)
	H.civilization = "Government"
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/paramedic
	title = "Paramedic"
	en_meaning = ""
	rank_abbreviation = "Paramedic"
	spawn_location = "JoinLateCivE"
	selection_color = "#91a6eb"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 3

/datum/job/civilian/paramedic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Paramedics"
	H.equip_to_slot_or_del(new /obj/item/clothing/under/paramedic(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/highvis/paramedic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	var/obj/item/clothing/accessory/stethoscope/stet = new /obj/item/clothing/accessory/stethoscope(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(stet, H)
	if (map.ID == MAP_BANK_ROBBERY)
		H.add_note("Role", "You are a paramedic, and you were called to a bank where a shooting is taking place!")
	else
		H.add_note("Role", "You are a paramedic. Listen to emergency calls and bring injured to the hospital using the ambulance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	give_random_name(H)
	if (map.ID == MAP_THE_ART_OF_THE_DEAL)
		H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
		spawn(50)
			H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

/datum/job/civilian/hospital_doctor
	title = "Physician"
	en_meaning = ""
	rank_abbreviation = "Dr."
	whitelisted = TRUE
	spawn_location = "JoinLateCivE"
	selection_color = "#91a6eb"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/hospital_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Paramedics"
	H.equip_to_slot_or_del(new /obj/item/clothing/under/scrubs/navy(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/surgical_cap/navy(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/twenty(H), slot_l_hand)
	var/obj/item/clothing/accessory/stethoscope/stet = new /obj/item/clothing/accessory/stethoscope(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(stet, H)
	H.add_note("Role", "You are a Physician. Take care of your patients inside the hospital!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	give_random_name(H)

/datum/job/civilian/hospital_nurse
	title = "Nurse"
	en_meaning = ""
	rank_abbreviation = "Nurse"
	whitelisted = FALSE
	spawn_location = "JoinLateCivE"
	selection_color = "#91a6eb"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/hospital_nurse/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Paramedics"
	H.equip_to_slot_or_del(new /obj/item/clothing/under/scrubs/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/twenty(H), slot_l_hand)
	var/obj/item/clothing/accessory/stethoscope/stet = new /obj/item/clothing/accessory/stethoscope(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(stet, H)
	H.add_note("Role", "You are a Nurse. Take care of your patients inside the hospital and follow directives from the physicians!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)

/datum/job/civilian/mechanic
	title = "Mechanic"
	en_meaning = ""
	rank_abbreviation = "Mechanic"
	whitelisted = TRUE
	spawn_location = "JoinLateCivF"
	selection_color = "#cd853f"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/civilian/mechanic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/coveralls(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/black(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_l_hand)
	H.add_note("Role", "You are a Mechanic. You can be payed to repair vehicles that have broken down in the middle of the road. If you're feeling sneaky, maybe help dispose of bodies for some extra cash on the side.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)

/datum/job/civilian/hobo
	title = "Homeless Man"
	whitelisted = FALSE
	spawn_location = "JoinLateCivG"
	selection_color = "#402b01"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 3

/datum/job/civilian/hobo/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	var/randoutfit = rand(1,3)
	switch(randoutfit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/gatorpants(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/punk(H), slot_wear_suit)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/bag/trash(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/punk(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/syringe(H), slot_l_store)
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/opium(H), slot_r_store)
			var/obj/item/clothing/under/uniform1 = H.w_uniform
			var/obj/item/clothing/accessory/armband/punk/armband = new /obj/item/clothing/accessory/armband/punk(null)
			uniform1.attackby(armband, H)
			if (H.h_style != "Mohawk")
				H.h_style = "Mohawk"

		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/beggar_clothing, slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/crack(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/pipe/glass, slot_l_store)
		if (3)
			var/obj/item/clothing/head/custom/fieldcap/headcap = new /obj/item/clothing/head/custom/fieldcap(null)
			headcap.capcolor = "#932310"
			headcap.uncolored1 = FALSE
			headcap.update_icon()
			H.equip_to_slot_or_del(headcap, slot_head)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2, slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket, slot_wear_suit)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless, slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey, slot_l_hand)

	if (prob(60))
		var/randaddiction = rand(1,4)
		switch(randaddiction)
			if (1)
				H.addictions["cocaine"] += rand(10,100)
			if (2)
				H.addictions["opium"] += rand(10,100)
			if (3)
				H.addictions["tobacco"] += rand(10,100)
			if (4)
				H.addictions["alcohol"] += rand(10,100)
	H.add_note("Role", "You are a Bum. You should find a way to earn some cash to fulfill your potential addicition. Maybe try helping out one of the gangs in the area.")
	H.setStat("strength", STAT_VERY_LOW)
	H.setStat("crafting", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
/*
/datum/job/civilian/fireperson
	title = "Fire Response"
	en_meaning = ""
	rank_abbreviation = "Fire Response"
	whitelisted = TRUE
	spawn_location = "JoinLateCivH"
	selection_color = "#880000"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 15

/datum/job/civilian/fireperson/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Fire Response"
	H.equip_to_slot_or_del(new /obj/item/clothing/under/oldfirefighter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/ointment(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/modern2(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/twohanded/fireaxe(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/full(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/fire_extinguisher(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/nbc/olive/fire(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/nbc/olive/fire(H), slot_head)
	H.add_note("Role", "You are a fireperson. Put out fires, fix broken roads, coordinate with other emergency services, and try to keep everyone safe.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")
*/
/datum/job/civilian/businessman/legitimate
	title = "Legitimate Business"
	selection_color = "#6f4e37"
	spawn_location = "JoinLateCivI"
	min_positions = 3
	max_positions = 15
	whitelisted = TRUE
	can_be_female = TRUE

/datum/job/civilian/businessman/legitimate/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/onehundy(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/telephone/mobile(H), slot_r_store)
	H.add_note("Role", "You are a legitimate business person. Find a business to invest in or start your own.")



//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//suit
	var/randsuit = pick(1,2,3)
	if (randsuit == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
	else if (randsuit == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/navy_suit(H), slot_wear_suit)
//glasses
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	var/obj/item/clothing/under/uniform = H.w_uniform
//suspenders
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/suspenders/ysuspenders = new /obj/item/clothing/accessory/suspenders(null)
			uniform.attackby(ysuspenders, H)
		else
			var/obj/item/clothing/accessory/suspenders/dark/ysuspenders = new /obj/item/clothing/accessory/suspenders/dark(null)
			uniform.attackby(ysuspenders, H)

	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_r_hand)

//hats
	var/randhat = pick(1,2,3)
	if (randhat == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else if (randhat == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/peakyblinder(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")




//////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////UN Troops////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/civilian/unitednations/lieutenant
	title = "United Nations Lieutenant"
	rank_abbreviation = "UN Lt."
	spawn_location = "JoinLateUNLt"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_get_coordinates = TRUE
	is_un = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 100)

	min_positions = 1
	max_positions = 1

/datum/job/civilian/unitednations/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/us_sgt(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/un_beret(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fal(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/unbasic(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of all United Nations Personelle. Distrubute your aid accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/unitednations/sergeant
	title = "United Nations Sergeant"
	rank_abbreviation = "UN Sgt."

	spawn_location = "JoinLateUNSgt"
	is_squad_leader = TRUE
	uses_squads = TRUE
	can_get_coordinates = TRUE
	is_un = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 40)
	min_positions = 2
	max_positions = 10

/datum/job/civilian/unitednations/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/greasegun(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/us_lt(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/unsgt(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b in charge of a leading a squad and following your CO's orders!")

	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
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

/datum/job/civilian/unitednations/soldier
	title = "United Nations Soldier"
	en_meaning = ""
	rank_abbreviation = "UN Pvt."
	spawn_location = "JoinLateUN"
	is_un = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 15)
	uses_squads = TRUE

	min_positions = 2
	max_positions = 102
/datum/job/civilian/unitednations/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/un_fal(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/unbasic(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fal(H), slot_shoulder)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>. Follow orders and keep everyone safe!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

/datum/job/civilian/unitednations/radop
	title = "United Nations Radio Operator"
	en_meaning = ""
	rank_abbreviation = "UN Pfc."
	spawn_location = "JoinLateUN"
	is_un = TRUE
	is_radioman = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 30)
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/civilian/unitednations/radop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/un_fal(H), slot_belt)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/un_beret(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fal(H), slot_shoulder)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
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

/datum/job/civilian/unitednations/unsniper
	title = "United Nations Marksman"
	en_meaning = ""
	rank_abbreviation = "UN Spc."
	spawn_location = "JoinLateUN"
	is_un = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 15)

	min_positions = 2
	max_positions = 12

/datum/job/civilian/unitednations/unsniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m14(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/un_beret(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/unsniper(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>, the best shot in the unit. Follow orders, keep your eye to the scope and watch for attack!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

/datum/job/civilian/unitednations/unmg
	title = "United Nations Machine Gunner"
	en_meaning = ""
	rank_abbreviation = "UN Pfc."
	spawn_location = "JoinLateUN"
	is_un = TRUE
	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 15)

	min_positions = 2
	max_positions = 6

/datum/job/civilian/unitednations/unmg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/olive/madsen(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/unmg(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/madsen(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_l_store)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.nationality = "United Nations"
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)

/datum/job/civilian/unitednations/doctor
	title = "United Nations Doctor"
	rank_abbreviation = "UN Dr."
	spawn_location = "JoinLateUNDr"
	selection_color = "#53ADD0"
	is_medic = TRUE
	can_be_female = TRUE
	is_un = TRUE
	min_positions = 2
	max_positions = 4
	additional_languages = list("Zulu" = 60)
	whitelisted = FALSE

/datum/job/civilian/unitednations/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/un_irish(H), slot_w_uniform)
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

/datum/job/civilian/unitednations/engineer
	title = "United Nations Engineer"
	en_meaning = ""
	rank_abbreviation = "UN Eng."
	spawn_location = "JoinLateUNEng"
	is_un = TRUE

	can_be_female = TRUE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 30)


	min_positions = 2
	max_positions =4

/datum/job/civilian/unitednations/engineer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/ungineer(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. <b>You are a noncombative role, you must try to avoid putting yourself in danger</b>.<br>Keep the hospital defenses intact and develop surrounding areas if it's safe to do so.")
	H.nationality = "United Nations"
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)

/////////////////////////////////////spanish civil war republicans/////////////////////////////////////////
/datum/job/civilian/spanish
	is_spainciv = TRUE
	faction = "RepSpain"
	default_language = "Spanish"

/datum/job/civilian/spanish/cir/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_spanish_name(H.gender)
	H.real_name = H.name

/datum/job/civilian/spanish/cap
	title = "Capitan republicano"
	en_meaning = "Republican Captain"
	rank_abbreviation = "Cap."


	spawn_location = "JoinLateSP"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_spainciv = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/spanish/cap/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/republican(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/compass(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armband/spanish/republican/white = new /obj/item/clothing/accessory/armband/spanish/republican(null)
	uniform.attackby(white, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the Republican Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/spanish/sz
	title = "Sargento republicano"
	en_meaning = "Republican Squad Leader"
	rank_abbreviation = "Sar."

	spawn_location = "JoinLateSP"
	is_officer = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_spainciv = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/civilian/spanish/sz/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/republican(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/compass(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/ammo_magazine/c762x25_ppsh, H)
	webbing.attackby(new/obj/item/ammo_magazine/c762x25_ppsh, H)
	webbing.attackby(new/obj/item/ammo_magazine/c762x25_ppsh, H)
	var/obj/item/clothing/accessory/armband/spanish/republican/white = new /obj/item/clothing/accessory/armband/spanish/republican(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your squad according to the <b>Capitans's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/spanish/doc
	title = "Médico de combate republicano"
	en_meaning = "Republican Combat Medic"
	rank_abbreviation = "Med."

	spawn_location = "JoinLateSP"

	is_spainciv = TRUE
	is_medic = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/civilian/spanish/doc/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/republican(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/civilian/spanish/rifle
	title = "Fusilero Republicano"
	en_meaning = "Republican Rifleman"
	rank_abbreviation = ""

	spawn_location = "JoinLateSP"
	can_be_female = FALSE
	is_spainciv = TRUE
	uses_squads = TRUE

	min_positions = 20
	max_positions = 60

/datum/job/civilian/spanish/rifle/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/republican(H), slot_w_uniform)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adriansoviet(H), slot_head)
//weapons
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
		webbing.attackby(new/obj/item/ammo_magazine/mosin, H)
		webbing.attackby(new/obj/item/ammo_magazine/mosin, H)
		webbing.attackby(new/obj/item/ammo_magazine/mosin, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_pps(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
		webbing.attackby(new/obj/item/ammo_magazine/c762x25_pps, H)
		webbing.attackby(new/obj/item/ammo_magazine/c762x25_pps, H)
		webbing.attackby(new/obj/item/ammo_magazine/c762x25_pps, H)
//armband
	var/obj/item/clothing/accessory/armband/spanish/republican/white = new /obj/item/clothing/accessory/armband/spanish/republican(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Republican army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/spanish/intvol
	additional_languages = list("Russian" = 65, "Polish" = 25, "Ukrainian" = 35, "English" = 25, "Latin" = 35,)
	title = "Voluntario internacional"
	en_meaning = "International volunteer"
	rank_abbreviation = ""

	spawn_location = "JoinLateSP"
	can_be_female = TRUE
	is_spainciv = TRUE
	uses_squads = TRUE


	min_positions = 10
	max_positions = 110

/datum/job/civilian/spanish/intvol/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/brigadist(H), slot_w_uniform)
//hats
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	else if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
	else if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
//weapons
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_r_store)
	else if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/enfield(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/enfield(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/enfield(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x50(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x50(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/spanish/republican/white = new /obj/item/clothing/accessory/armband/spanish/republican(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple person who volunteered to fight for the republican spain,listen to your Sergant!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE
