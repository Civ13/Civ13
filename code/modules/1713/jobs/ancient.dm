////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////ROMAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Human"
	is_ancient = TRUE
/datum/job/roman/give_random_name(var/mob/living/human/H)
	if (title != "Gladiator")
		H.name = H.species.get_random_roman_name()
		H.real_name = H.name
	else
		H.name = H.species.get_random_ancient_name()
		H.real_name = H.name

/datum/job/roman/captain	//Roman - Centurion
	title = "Centurion"
	en_meaning = "Roman Commander"
	rank_abbreviation = "Cen."
	spawn_location = "JoinLateRO"
	is_commander = TRUE
	is_officer = TRUE
	allowed_maps = list(MAP_SIEGE, MAP_HERACLEA, MAP_TEUTOBURG)

	min_positions = 1
	max_positions = 1

/datum/job/roman/captain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/captain/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman_centurion = slot_w_uniform,
	/obj/item/clothing/suit/armor/ancient/scale = slot_wear_suit,
	/obj/item/weapon/shield/roman/praetorian = slot_l_hand,
	/obj/item/clothing/head/helmet/roman_centurion = slot_head,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt)
/datum/job/roman/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a <b>Centuria</b>, a company of Legionaries. Organize your <b>Decurions</b> and lead your soldiers to victory!</b>.")
	apply_job_stats(H)
	give_random_name(H)

	return TRUE



/datum/job/roman/squad_leader	//Roman - Decurion
	title = "Decurion"
	en_meaning = "Roman Squad Leader"
	rank_abbreviation = "Dec."
	spawn_location = "JoinLateRO"
	allowed_maps = list(MAP_SIEGE, MAP_HERACLEA, MAP_TEUTOBURG)
	is_officer = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/roman/squad_leader/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/squad_leader/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman = slot_w_uniform,
	/obj/item/clothing/head/helmet/roman_decurion = slot_head,
	/obj/item/clothing/suit/armor/ancient/scale = slot_wear_suit,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt,
	/obj/item/weapon/material/pilum = slot_back,
	/obj/item/weapon/shield/roman/praetorian = slot_l_hand)
/datum/job/roman/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a Roman legionary squad. Lead your <b>Legionaries</b> to battle, following the orders of the <b>Centurion</b>!")
	apply_job_stats(H)
	give_random_name(H)
	return TRUE

/datum/job/roman/bearer
	title = "Signifer"
	en_meaning = "Roman Standard Bearer"
	rank_abbreviation = ""
	allowed_maps = list(MAP_SIEGE, MAP_HERACLEA, MAP_TEUTOBURG)
	spawn_location = "JoinLateRO"

	min_positions = 1
	max_positions = 6

/datum/job/roman/bearer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/bearer/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman = slot_w_uniform,
	/obj/item/clothing/suit/armor/ancient/scale = slot_wear_suit)
/datum/job/roman/bearer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/lionpelt(H), slot_head)

		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/roman_standard(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, the Legion's standard bearer. Lead your soldiers to battle and keep troops organized! Use your horn!")
	apply_job_stats(H)
	give_random_name(H)
	return TRUE


/datum/job/roman/soldier
	title = "Legionarius"
	en_meaning = "Main Infantry"
	rank_abbreviation = ""
	allowed_maps = list(MAP_SIEGE, MAP_HERACLEA, MAP_TEUTOBURG)
	spawn_location = "JoinLateRO"

	min_positions = 12
	max_positions = 200

/datum/job/roman/soldier/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/soldier/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman = slot_w_uniform,
	/obj/item/clothing/suit/armor/ancient/scale = slot_wear_suit,
	/obj/item/clothing/head/helmet/roman = slot_head,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt,
	/obj/item/weapon/material/pilum = slot_back,
	/obj/item/weapon/shield/roman = slot_l_hand)
/datum/job/roman/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Roman Army. You are equipped with two <b>Pila</b> javelins, your shield and a <b>Gladius</b>.")
	apply_job_stats(H)
	give_random_name(H)

	return TRUE



/datum/job/roman/velites
	title = "Saggitarius"
	en_meaning = "Light Archer"
	rank_abbreviation = ""
	allowed_maps = list(MAP_SIEGE, MAP_HERACLEA, MAP_TEUTOBURG)
	spawn_location = "JoinLateRO"

	min_positions = 8
	max_positions = 100
/datum/job/roman/velites/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_LOW, "bows" = STAT_HIGH, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/velites/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman = slot_w_uniform,
	/obj/item/clothing/suit/armor/ancient/chainmail = slot_wear_suit)
/datum/job/roman/velites/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)

	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt(H), slot_head)

		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a skirmisher in the Roman Army. Your job is to harass the enemy frontline before the <b>Legionaries</b> charge.")
	apply_job_stats(H)
	give_random_name(H)
	return TRUE

////////////////////GLADIATOR///////////////

/datum/job/roman/gladiator
	title = "Gladiator"
	en_meaning = ""
	rank_abbreviation = ""
	allowed_maps = list(MAP_GLADIATORS)

	spawn_location = "JoinLateRO"

	is_gladiator = TRUE

	min_positions = 100
	max_positions = 100
/datum/job/roman/gladiator/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_HIGH)
/datum/job/roman/gladiator/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	var/pickuni = rand(1,3)
	if (pickuni == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_green(H), slot_w_uniform)
	else if (pickuni == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_red(H), slot_w_uniform)
	else if (pickuni == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(H), slot_w_uniform)

	H.add_note("Role", "You are a <b>[title]</b>, fighting in the area. Can you become the best? You can use the beds at the Sleeping Quarters to save your character's name, stats and victories. You will be able to load on respawn.")
	apply_job_stats(H)
	give_random_name(H)
	H.check_profiles() //this will trigger the "give a custom name" proc
	return TRUE


/datum/job/roman/doctor
	title = "Medicus"
	en_meaning = "Doctor"
	rank_abbreviation = "Medicus"
	allowed_maps = list(MAP_GLADIATORS)

	spawn_location = "JoinLateROG"

	is_medic = TRUE
	is_gladiator = TRUE

	min_positions = 3
	max_positions = 8
/datum/job/roman/doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL)
/datum/job/roman/doctor/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/custom/toga = slot_w_uniform,
	/obj/item/weapon/key/ancient/roman = slot_l_store,
	/obj/item/weapon/doctor_handbook = slot_r_store)
/datum/job/roman/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>. Keep the arena clean and the men alive.")
	apply_job_stats(H)
	give_random_name(H)
	return TRUE



/datum/job/roman/guard
	title = "Custos"
	en_meaning = "Arena Guard"
	rank_abbreviation = "Custos"
	allowed_maps = list(MAP_GLADIATORS)

	spawn_location = "JoinLateROG"

	is_officer = TRUE
	whitelisted = TRUE
	is_gladiator = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/roman/guard/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_HIGH, "rifle" = STAT_LOW, "dexterity" = STAT_HIGH, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_HIGH, "medical" = STAT_NORMAL)
/datum/job/roman/guard/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/roman = slot_w_uniform,
	/obj/item/clothing/head/helmet/roman_decurion = slot_head,
	/obj/item/weapon/melee/classic_baton/whip = slot_belt,
	/obj/item/weapon/material/sword/gladius/iron = slot_back)
/datum/job/roman/guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, guarding the arena. Keep the gladiators organized and following the rules, while protecting the Emperor!")
	apply_job_stats(H)
	give_random_name(H)
	return TRUE

/datum/job/roman/emperor
	title = "Imperator"
	en_meaning = "Emperor"
	rank_abbreviation = "Imperator"
	allowed_maps = list(MAP_GLADIATORS)

	spawn_location = "JoinLateROG"

	is_gladiator = TRUE
	is_commander = TRUE

	is_officer = TRUE
	whitelisted = TRUE


	min_positions = 1
	max_positions = 1
/datum/job/roman/emperor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_MEDIUM_HIGH, "medical" = STAT_VERY_HIGH)
/datum/job/roman/emperor/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/custom/toga/purple = slot_w_uniform,
	/obj/item/weapon/key/ancient/roman = slot_l_store,
	/obj/item/weapon/horn = slot_r_store,
	/obj/item/clothing/head/laurelcrown = slot_head)
/datum/job/roman/emperor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)

	H.add_note("Role", "You are the <b>[title]</b>. You are responsible for organizing the games. You can use the interface of the <b>Gladiator Combat Organizer</b> to turn automatic mode on and off. If you decide to manage the games yourself, you will need to attribute the victory using the <b>Gladiator Ledger</b> - click on it and choose the winner!")

	apply_job_stats(H)
	give_random_name(H)
	return TRUE

////////////////Germanic Tribes///////////////////

/datum/job/german/chieftain
	title = "Jarl"
	en_meaning = "Chieftain"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	allowed_maps = list(MAP_TEUTOBURG)
	is_commander = TRUE
	is_officer = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/german/chieftain/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/german/chieftain/job_loadout = list(
	/obj/item/clothing/shoes/steppe_shoes = slot_shoes,
	/obj/item/clothing/under/celtic_red = slot_w_uniform,
	/obj/item/clothing/suit/armor/medieval/bronze_chestplate = slot_wear_suit,
	/obj/item/clothing/head/helmet/asterix/conspicious = slot_head,
	/obj/item/weapon/material/sword/gaelic/iron = slot_belt)
/datum/job/german/chieftain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gaelic/iron(H), slot_l_hand)
	// A scutum is too big for a pocket and would be deleted there (issue 6988).
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the chieftain of your tribe. Lead your men to victory!")

	apply_job_stats(H)
	give_random_name(H)

	return TRUE


/datum/job/german/swordsman
	title = "Sahsnotoz"
	en_meaning = "Swordsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	allowed_maps = list(MAP_TEUTOBURG)

	min_positions = 10
	max_positions = 100

/datum/job/german/swordsman/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_LOW)
/datum/job/german/swordsman/job_loadout = list(
	/obj/item/clothing/shoes/steppe_shoes = slot_shoes,
	/obj/item/clothing/under/celtic_short_braccae = slot_w_uniform,
	/obj/item/clothing/suit/armor/ancient/scaled = slot_wear_suit)
/datum/job/german/swordsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/asterix(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/horned(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gaelic/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_l_hand)

	H.add_note("Role", "You are a <b>[title]</b>, a germanic swordsman.")

	apply_job_stats(H)
	give_random_name(H)

	return TRUE

/datum/job/german/axeman
	title = "Teceitos"
	en_meaning = "Axeman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	allowed_maps = list(MAP_TEUTOBURG)

	min_positions = 10
	max_positions = 100

/datum/job/german/axeman/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_LOW)
/datum/job/german/axeman/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/celtic_short_braccae = slot_w_uniform)
/datum/job/german/axeman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/tribal(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_back)

	H.add_note("Role", "You are a <b>[title]</b>, a celtic axeman. Use your speed to maneuver around the enemy and your axe to destroy their armor and shields.")

	apply_job_stats(H)
	give_random_name(H)

	return TRUE


/datum/job/german/spearman
	title = "Framaharjoz"
	en_meaning = "Spearman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	allowed_maps = list(MAP_TEUTOBURG)

	min_positions = 20
	max_positions = 200

/datum/job/german/spearman/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_LOW)
/datum/job/german/spearman/job_loadout = list(
	/obj/item/clothing/shoes/steppe_shoes = slot_shoes,
	/obj/item/clothing/under/celtic_long_braccae = slot_w_uniform)
/datum/job/german/spearman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/steppe_leather(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt/brown(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt/black(H), slot_head)
		//weapons
	// A pike rides on the shoulder; a belt refuses it and deletes it (issue 6989).
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a germanic spearman.")

	apply_job_stats(H)
	give_random_name(H)

	return TRUE

/datum/job/german/skirmisher
	title = "Swainoz"
	en_meaning = "Skirmisher"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	allowed_maps = list(MAP_TEUTOBURG)

	min_positions = 10
	max_positions = 100

/datum/job/german/skirmisher/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_LOW, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_LOW, "pistol" = STAT_LOW, "bows" = STAT_HIGH, "medical" = STAT_LOW)
/datum/job/german/skirmisher/job_loadout = list(
	/obj/item/clothing/shoes/sandal = slot_shoes,
	/obj/item/clothing/under/celtic_green = slot_w_uniform,
	/obj/item/weapon/material/hatchet = slot_belt,
	/obj/item/weapon/gun/projectile/bow/shortbow = slot_l_hand,
	/obj/item/weapon/storage/backpack/quiver/full = slot_back)
/datum/job/german/skirmisher/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/sheeppelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/goatpelt(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a germanic skirmisher.")

	apply_job_stats(H)
	give_random_name(H)

	return TRUE