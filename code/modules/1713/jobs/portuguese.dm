/datum/job/portuguese
	faction = "Human"

/datum/job/portuguese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_portuguese_name(H.gender)
	H.real_name = H.name

/datum/job/portuguese/captain
	title = "Capitao"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Capitao"
	allowed_maps = list(MAP_ROBUSTA)


	spawn_location = "JoinLatePTCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/portuguese/captain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_portuguese(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	to_chat(world, "<big><b>[H.real_name] is the Captain of the Portuguese Navy ship!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/qm
	title = "Imediato"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Imediato"
	spawn_location = "JoinLatePTQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	allowed_maps = list(MAP_ROBUSTA)

	min_positions = 1
	max_positions = 1

/datum/job/portuguese/qm/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/qm/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_portuguese(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	to_chat(world, "<big><b>[H.real_name] is the Quartermaster of the Portuguese Navy ship!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Capitao</b>.")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/boatswain
	title = "Contramestre"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Contramestre"
	spawn_location = "JoinLatePTBoatswain"
	whitelisted = TRUE
	allowed_maps = list(MAP_ROBUSTA)

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/portuguese/boatswain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/boatswain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_portuguese(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	to_chat(world, "<big><b>[H.real_name] is the Boatswain of the Portuguese Navy ship!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/midshipman
	title = "Aspirante"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Aspirante"
	allowed_maps = list(MAP_ROBUSTA)
	spawn_location = "JoinLatePTMidshipman"
	is_officer = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/portuguese/midshipman/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/midshipman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer, slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Contramestre</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/surgeon
	title = "Medico Naval"
	en_meaning = "Medic"
	rank_abbreviation = "Medico"
	spawn_location = "JoinLatePTSurgeon"
	allowed_maps = list(MAP_ROBUSTA)
	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/portuguese/surgeon/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/portuguese/surgeon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor1(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the sailors healthy.")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/carpenter
	title = "Carpinteiro Naval"
	en_meaning = "Carpenter"
	rank_abbreviation = "Carpinteiro"
	allowed_maps = list(MAP_ROBUSTA)
	spawn_location = "JoinLatePTCarpenter"

	min_positions = 1
	max_positions = 10

/datum/job/portuguese/carpenter/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor4(H), slot_w_uniform)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Imediato</b> to ensure everything is in good conditions!")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/cook
	title = "Cozinheiro"
	en_meaning = "Cook"
	rank_abbreviation = "Cozinheiro"
	allowed_maps = list(MAP_ROBUSTA)
	spawn_location = "JoinLatePTCook"

	min_positions = 1
	max_positions = 10

/datum/job/portuguese/cook/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Imediato</b> orders!")
	apply_job_stats(H)





////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/portuguese/seaman
	title = "Marinheiro"
	en_meaning = "Seaman"
	rank_abbreviation = ""
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_ROBUSTA)

	min_positions = 6
	max_positions = 200

/datum/job/portuguese/seaman/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/seaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_sailor4(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the Portuguese Marinha Real. Follow your <b>Capitao</b> orders!")
	apply_job_stats(H)


	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/portuguese/army_commander
	title = "Tenente"
	en_meaning = "Infantry Commander"
	rank_abbreviation = "Ten."

	spawn_location = "JoinLatePTCap"
	is_officer = TRUE
	is_commander = TRUE

	is_army = TRUE
	allowed_maps = list(MAP_RECIFE)


	min_positions = 1
	max_positions = 1

/datum/job/portuguese/army_commander/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_VERY_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/army_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_portuguese(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, the commander or this company. Organize your <b>Sargentos</b> and lead your country to victory!")
	apply_job_stats(H)


	return TRUE
/datum/job/portuguese/army_officer
	title = "Sargento"
	en_meaning = "Infantry Squad Leader"
	rank_abbreviation = "Srg."

	spawn_location = "JoinLatePTMidshipman"
	is_officer = TRUE

	is_army = TRUE
	allowed_maps = list(MAP_RECIFE)


	min_positions = 2
	max_positions = 20

/datum/job/portuguese/army_officer/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/army_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldados</b> according to your <b>Tenente</b>'s orders!")
	apply_job_stats(H)


	return TRUE
/datum/job/portuguese/field_medic
	title = "Medico de Campo"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLatePTSurgeon"

	is_medic = TRUE
	is_army = TRUE
	allowed_maps = list(MAP_RECIFE)


	min_positions = 1
	max_positions = 6

/datum/job/portuguese/field_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/portuguese/field_medic/equip(var/mob/living/human/H)
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

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the infantry healthy.")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/soldier
	title = "Soldado"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_RECIFE)

	is_army = TRUE


	min_positions = 12
	max_positions = 100

/datum/job/portuguese/soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the Portuguese Colonial Army. Follow your Officer's orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/portuguese/chasseur
	title = "Cacador"
	en_meaning = "Light Infantry"
	rank_abbreviation = "Cac."

	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_RECIFE)

	is_army = TRUE


	min_positions = 4
	max_positions = 20

/datum/job/portuguese/chasseur/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_VERY_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/chasseur/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/portuguese_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chasseur_portuguese(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/cutlass(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/musketoon(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a light infantry soldier. You are very skilled in melee weapons and can move fast. Your job relies on hit-and-run tactics.")
	apply_job_stats(H)


	return TRUE