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
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	is_1713 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/civilian/banker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

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
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)
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
	additional_languages = list("Hebrew" = 70)
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/yellow/CEO
	title = "Goldstein Solutions CEO"
	is_officer = TRUE
	additional_languages = list("Hebrew" = 100)
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
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
	additional_languages = list("Japanese" = 70)
	min_positions = 3
	max_positions = 50
/datum/job/civilian/businessman/green/CEO
	title = "Kogama Kraftsmen CEO"
	additional_languages = list("Japanese" = 100)
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE

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
	additional_languages = list("Italian" = 70)
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/blue/CEO
	title = "Giovanni Blu Stocks CEO"
	is_officer = TRUE
	additional_languages = list("Italian" = 100)
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE

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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/butcher(H), slot_l_hand)
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
	additional_languages = list("Russian" = 70)
	min_positions = 3
	max_positions = 50

/datum/job/civilian/businessman/red/CEO
	title = "Rednikov Industries CEO"
	is_officer = TRUE
	additional_languages = list("Russian" = 100)
	min_positions = 1
	max_positions = 1
	rank_abbreviation = "CEO"
	whitelisted = TRUE
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
	additional_languages = list("Gaelic" = 50)
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

/datum/job/civilian/sheriffdep/supervisor
	title = "County Sheriff"
	rank_abbreviation = "Sheriff"
	whitelisted = TRUE
	spawn_location = "JoinLateCivL"
	selection_color = "#c3b091"
	can_be_female = TRUE
	is_deal = TRUE
	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/sheriffdep
	title = "County Deputy"
	rank_abbreviation = "Deputy"
	whitelisted = TRUE
	spawn_location = "JoinLateCiv"
	selection_color = "#c3b091"
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
	H.equip_to_slot_or_del(new /obj/item/gunbox(H), slot_l_hand)
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
	H.equip_to_slot_or_del(new /obj/item/gunbox(H), slot_l_hand)
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

/datum/job/civilian/paramedic
	title = "Paramedic"
	en_meaning = ""
	rank_abbreviation = "Paramedic"
	whitelisted = FALSE
	spawn_location = "JoinLateCivE"
	selection_color = "#777777"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 8

/datum/job/civilian/paramedic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Paramedics"
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/highvis/paramedic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/map(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/factionpolice(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/money/dollar/ten(H), slot_l_hand)
	H.add_note("Role", "You are a paramedic. Listen to emergency calls and bring injured to the hospital using the ambulance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	spawn(50)
		H.client.screen += new/obj/screen/areashow_aod("Area Location","8,14", H, null, "")

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
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/modern2(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch/wallet(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/black(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
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
	en_meaning = ""
	rank_abbreviation = ""
	whitelisted = TRUE
	spawn_location = "JoinLateCivG"
	selection_color = "#8b4513"
	is_deal = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 3

/datum/job/civilian/hobo/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gatorpants(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/punk(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/bag/trash(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/punk(H), slot_shoes)
	var/obj/item/clothing/under/uniform1 = H.w_uniform
	var/obj/item/clothing/accessory/armband/punk/armband = new /obj/item/clothing/accessory/armband/punk(null)
	uniform1.attackby(armband, H)
	H.add_note("Role", "You are a Bum. You should find a way to earn some cash. Maybe try helping out one of the gangs in the area.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
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

//UN Troops//
/datum/job/civilian/unitednations
	title = "United Nations Soldier"
	en_meaning = ""
	rank_abbreviation = "UN Pvt."
	spawn_location = "JoinLateUN"
	is_warlords = TRUE
	can_be_female = FALSE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 10)
	whitelisted = TRUE

	min_positions = 2
	max_positions = 6
/datum/job/civilian/unitednations/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armord = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armord, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep both the UN troops and civilians safe!<br>Do not engage the militias (unless they breach the perimeter or fire upon you), but recover the bodies if possible and safe to do so.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

/datum/job/civilian/unitednations/doctor
	title = "United Nations Doctor"
	rank_abbreviation = "UN Dr."
	is_medic = TRUE
	can_be_female = TRUE
	min_positions = 2
	max_positions = 4
	additional_languages = list("Zulu" = 20)
	whitelisted = FALSE

/datum/job/civilian/unitednations/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/un/medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/white = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep both the UN troops and civilians in good health!<br> <b>You are a noncombative role, you may not engage in combat situations</b>.Do not engage the militias (unless they breach the perimeter or fire upon you), but recover the bodies if it's possible and safe to do so.")

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
	spawn_location = "JoinLateUN"
	is_warlords = TRUE
	can_be_female = FALSE
	selection_color = "#53ADD0"
	additional_languages = list("Zulu" = 10)
	whitelisted = FALSE

	min_positions = 2
	max_positions = 2

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
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/full(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/shovel/steel(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. <b>You are a noncombative role, you may not engage in combat situations</b>.<br>Keep the hospital infrastructure intact and develop surrounding areas if it's safe to do so.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)

/datum/job/civilian/unitednations/localpoliceman
	title = "Local Policeman"
	en_meaning = ""
	rank_abbreviation = "Officer"
	spawn_location = "JoinLateLP"
	is_warlords = TRUE
	can_be_female = FALSE
	selection_color = "#007f00"
	additional_languages = list("Zulu" = 100, "Swahili" = 80)
	whitelisted = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/civilian/unitednations/localpoliceman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_black(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/old(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)

	var/obj/item/clothing/under/ww2/british/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/un/blue = new /obj/item/clothing/accessory/armband/un(null)
	uniform.attackby(blue, H)
	uniform.roll_sleeves()
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	var/obj/item/weapon/storage/belt = H.belt
	var/obj/item/weapon/key/civ/police/pk = new /obj/item/weapon/key/civ/police(null)
	belt.attackby(pk, H)

	H.name = H.species.get_random_zulu_name(H.gender)
	H.real_name = H.name
	H.s_tone = rand(-170,-150)
	var/new_hair = pick("Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	H.add_note("Role", "You are a <b>[title]</b>. You're the liaison between the local population and UN. Use your language knowledge to act as an interprator.<br>Do not kill the militias, instead, try to arrest them (unless they breach the perimeter or fire upon you).")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)