/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////BRITISH///////////////////////////////////////////////////////

/datum/job/british
	faction = "Human"

/datum/job/british/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/british/captain
	title = "Royal Navy Captain"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Captain"
	is_navy = TRUE

	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/british/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/qm
	title = "Royal Navy Quartermaster"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Quartermaster"
	is_navy = TRUE
	spawn_location = "JoinLateRNQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/british/qm/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Captain</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/boatswain
	title = "Royal Navy Boatswain"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Boatswain"
	is_navy = TRUE

	spawn_location = "JoinLateRNBoatswain"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/boatswain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/midshipman
	title = "Royal Navy Midshipman"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Midshipman"
	is_navy = TRUE
	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE



	min_positions = 1
	max_positions = 10

/datum/job/british/midshipman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Boatswain</b>'s orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/surgeon
	title = "Royal Navy Surgeon"
	en_meaning = "Medic"
	rank_abbreviation = "Surgeon"
	is_navy = TRUE
	spawn_location = "JoinLateRNSurgeon"
	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/british/surgeon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the sailors healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/british/carpenter
	title = "Royal Navy Carpenter"
	en_meaning = "Carpenter"
	rank_abbreviation = "Carpenter"
	is_navy = TRUE
	spawn_location = "JoinLateRNCarpenter"



	min_positions = 1
	max_positions = 10

/datum/job/british/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/british_scarf/british_scarf_a = new /obj/item/clothing/accessory/armband/british_scarf(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(british_scarf_a, H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartermaster</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/cook
	title = "Royal Navy Cook"
	en_meaning = "Cook"
	rank_abbreviation = "Cook"
	is_navy = TRUE
	spawn_location = "JoinLateRNCook"



	min_positions = 1
	max_positions = 10

/datum/job/british/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Quartermaster</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)





////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/british/seaman
	title = "Royal Navy Seaman"
	en_meaning = "Seaman"
	rank_abbreviation = ""
	is_navy = TRUE
	spawn_location = "JoinLateRN"



	min_positions = 6
	max_positions = 200

/datum/job/british/seaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/british_scarf/british_scarf_a = new /obj/item/clothing/accessory/armband/british_scarf(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(british_scarf_a, H)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the Royal Navy. Follow your Captain's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

//////////////////////////////ARMY////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/british/army_commander
	title = "British Lieutenant"
	en_meaning = "Infantry Commander"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNCap"
	is_officer = TRUE

	is_army = TRUE
	is_commander = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/army_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/duellingpistol(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/duellingpistol(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball_pistol(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball_pistol(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/officer/h = new /obj/item/clothing/accessory/storage/sheath/longer/officer/(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, the commander or this company. Organize your <b>Sergeant</b> and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/british/army_officer
	title = "British Sergeant"
	en_meaning = "Infantry Squad Leader"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE

	is_army = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 20

/datum/job/british/army_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/blunderbuss(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/blunderbuss(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/officer/h = new /obj/item/clothing/accessory/storage/sheath/longer/officer/(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldiers</b> according to your <b>Lieutenant</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/field_medic
	title = "British Army Doctor"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "Doc."

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	is_army = TRUE


	min_positions = 1
	max_positions = 6

/datum/job/british/field_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/opium(H), slot_l_ear)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin(H), slot_r_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the infantry healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/british/soldier
	title = "British Army Soldier"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_army = TRUE
	uses_squads = TRUE

	min_positions = 12
	max_positions = 100

/datum/job/british/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/brownbess(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the British Colonial Army. Follow your Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


	return TRUE


/datum/job/british/chasseur
	title = "British Light Infantry"
	en_meaning = "Light Infantry"
	rank_abbreviation = "Cha."

	spawn_location = "JoinLateRN"

	is_army = TRUE
	uses_squads = TRUE

	min_positions = 4
	max_positions = 20

/datum/job/british/chasseur/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chasseur_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/sabre(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_casing/musketball(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/musketoon(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a light infantry soldier. You are very skilled in melee weapons and can move fast. Your job relies on hit-and-run tactics.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

//////////////////////////////////////////////////////
////////////////////////////WW1///////////////////////
//////////////////////////////////////////////////////
/datum/job/british/ww1captain
	title = "Army Captain"
	rank_abbreviation = "Cap."


	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/ww1captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the British Forces!</big></b>"
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

/datum/job/british/ww1lieutenant
	title = "Army 1st Lieutenant"
	rank_abbreviation = "1Lt."


	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/ww1lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the British Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/british/ww1second_lieutenant
	title = "Army 2nd Lieutenant"
	rank_abbreviation = "2Lt."


	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/ww1second_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the British Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/british/ww1sergeant
	title = "Army Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"
	is_officer = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/british/ww1sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/mk1brodieag(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/enfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Lieutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/ww1doctor
	title = "Army Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateRNSurgeon"

	is_ww1 = TRUE

	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/british/ww1doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/british/ww1shocktroop
	title = "Shock Troop"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN" //for testing!
	uses_squads = TRUE

	is_ww1 = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/british/ww1shocktroop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/mk1brodieag(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley4(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/british/newplate = new /obj/item/clothing/accessory/armor/modern/british(null)
	uniform.attackby(newplate, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier specialized in infiltration and shock tactics. Lead the way for your fellow soldiers to the enemy trenches!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/british/ww1infantry
	title = "Army Private"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN" //for testing!
	uses_squads = TRUE

	is_ww1 = TRUE


	min_positions = 12
	max_positions = 400

/datum/job/british/ww1infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/mk1brodieag(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/enfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/british/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/british(null)
	uniform.attackby(fullwebbing, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/enfield, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////WW2//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/british/ww2lieutenant_pow
	title = "POW Lieutenant"
	rank_abbreviation = "Lt."


	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/british/ww2lieutenant_pow/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british_off(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/britishoffcap_tropical(H), slot_head)
//weapons
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Lieutenant of the British POWs!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the POWs and their behaviour. The organizationa and survival of POWs relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/ww2sergeant_pow
	title = "POW Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"
	is_officer = TRUE

	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 1
	max_positions = 4

/datum/job/british/ww2sergeant_pow/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/britishoffcap(H), slot_head)
//weapons
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad of POWs. Organize your group according to the <b>Captain or Lieutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/ww2pow
	title = "British P.O.W."
	rank_abbreviation = ""

	spawn_location = "JoinLateRN" //for testing!

	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 12
	max_positions = 124

/datum/job/british/ww2pow/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british(H), slot_w_uniform)
//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/british_hat(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/british_tropical_hat(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/british_beret(H), slot_head)
//back
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Army captured and are now a Prisoner of War. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/ww2doctor_pow
	title = "POW Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 1
	max_positions = 3

/datum/job/british/ww2doctor_pow/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/britishoffcap(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the POWs healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE