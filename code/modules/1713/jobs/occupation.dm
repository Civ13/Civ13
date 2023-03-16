/obj/item/weapon/civilian_passport
	name = "Civilian's Documents"
	desc = "The identification papers of a civilian."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "passport"
	item_state = "paper"
	throwforce = FALSE
	flags = FALSE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_ID | SLOT_POCKET
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = TRUE
	var/mob/living/human/owner = null
	var/document_name = ""
	var/list/document_details = list()
	var/list/guardnotes = list()
	secondary_action = TRUE
	New()
		..()
		spawn(20)
			if (ishuman(loc))
				var/mob/living/human/H = loc
				document_name = H.real_name
				owner = H
				name = "[document_name] documents"
				desc = "The identification papers of <b>[document_name]</b>."
				var/crimereason = "Criminal Behaviour"
				if (istype(H.original_job, /datum/job/civilian/occupation))
					var/datum/job/civilian/occupation/P = H.original_job
					switch(H.nationality)
						if ("German")
							crimereason = "German civilian relocated to lebensraum."
						if ("Ukrainian")
							crimereason = "Ukrainian civilian. Original city inhabitant."
						if ("Polish")
							crimereason = "Polish civilian. Original city inhabitant."
					document_details = list(H.h_style, H.f_style, crimereason, H.gender, rand(6,32),P.original_eyes, P.randrole)
				if (istype(H.original_job, /datum/job/civilian/ukrainian/occupation))
					var/datum/job/civilian/ukrainian/occupation/P = H.original_job
					switch(H.nationality)
						if ("German")
							crimereason = "German civilian relocated to lebensraum."
						if ("Ukrainian")
							crimereason = "Ukrainian civilian. Original city inhabitant."
						if ("Polish")
							crimereason = "Polish civilian. Original city inhabitant."
					document_details = list(H.h_style, H.f_style, crimereason, H.gender, rand(6,32),P.original_eyes, P.randrole)
/obj/item/weapon/civilian_passport/examine(mob/user)
	user << "<span class='info'>*---------*</span>"
	..(user)
	if (document_details.len >= 7)
		user << "<b><span class='info'>Hair:</b> [document_details[1]]</span>"
		if (document_details[4] == "male")
			user << "<b><span class='info'>Face:</b> [document_details[2]]</span>"
		user << "<b><span class='info'>Eyes:</b> [document_details[6]]</span>"
		user << "<b><span class='info'>Extra Info:</b> [document_details[3]]</span>"
		user << "<b><span class='info'>Job:</b> [document_details[7]]</span>"
	user << "<span class='info'>*---------*</span>"
	if (guardnotes.len)
		for(var/i in guardnotes)
			user << "NOTE: [i]"
		user << "<span class='info'>*---------*</span>"

/obj/item/weapon/civilian_passport/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!ishuman(H))
		return
	if ((istype(I, /obj/item/weapon/pen) && istype(H.original_job, /datum/job/german/occupation)))
		var/confirm = WWinput(H, "Do you want to add a note to these documents?", "Civilian Documents", "No", list("No","Yes"))
		if (confirm == "No")
			return
		else
			var/texttoadd = input(H, "What do you want to write? Up to 150 characters", "Notes", "") as text
			texttoadd = sanitize(texttoadd, 150, FALSE)
			texttoadd = "<i>[texttoadd] - <b>[H.real_name]</b></i>"
			guardnotes += texttoadd
			return

/obj/item/weapon/civilian_passport/secondary_attack_self(mob/living/human/user)
	showoff(user)
	return
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/civilian/ukrainian/occupation
	var/randrole = "none"
	var/original_eyes = "Black"
	var/original_facial = "Shaved"
	var/original_hair = "Black"
/datum/job/civilian/ukrainian/occupation/upa_officer
	title = " UPA Khorunzhyj"
	en_meaning = " UPA 2nd Lieutenant"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_ww2 = TRUE
	is_upa = TRUE
	is_occupation = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/ukrainian/occupation/upa_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "UPA"
	H.nationality = "Ukrainian"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	if (prob(30))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)

	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 75
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/attachment/bayonet(H), slot_l_store)
//head
//back
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the UPA in the fight against the fascist occupiers! It's best you do it covertly.")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	var/datum/job/civilian/ukrainian/occupation/P = H.original_job
	if (prob(40))
		P.randrole = "Civilian/Unemployed"
	else if (prob(60))
		P.randrole = "Factory Worker"
	else if (prob(40))
		P.randrole = "Inn Worker"
	else
		P.randrole = "Farmer"
	if (H.r_hair == "09" && H.g_hair == "08" && H.b_hair == "06")
		P.original_hair = "Black"
	else if (H.r_hair == "6A" && H.g_hair == "4E" && H.b_hair == "42")
		P.original_hair = "Light Brown"
	else if (H.r_hair == "3B" && H.g_hair == "30" && H.b_hair == "24")
		P.original_hair = "Dark Brown"
	else if (H.r_hair == "B5" && H.g_hair == "52" && H.b_hair == "39")
		P.original_hair = "Red"
	else if (H.r_hair == "91" && H.g_hair == "55" && H.b_hair == "3D")
		P.original_hair = "Orange"
	else if (H.r_hair == "E6" && H.g_hair == "CE" && H.b_hair == "A8")
		P.original_hair = "Light Blond"
	else if (H.r_hair == "E5" && H.g_hair == "C8" && H.b_hair == "A8")
		P.original_hair = "Blond"
	else if (H.r_hair == "B8" && H.g_hair == "97" && H.b_hair == "78")
		P.original_hair = "Dirty Blond"
	else if (H.r_hair == "d3" && H.g_hair == "d3" && H.b_hair == "d3")
		P.original_hair = "Light Grey"
	else if (H.r_hair == "80" && H.g_hair == "80" && H.b_hair == "80")
		P.original_hair = "Grey"
	P.original_facial = P.original_hair
	return TRUE

/datum/job/civilian/ukrainian/occupation/upa_doctor
	title = " UPA Likar"
	en_meaning = " UPA Doctor"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCivD"

	is_medic = TRUE
	is_ww2 = TRUE
	is_upa = TRUE
	is_occupation = TRUE
	whitelisted = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/civilian/ukrainian/occupation/upa_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "UPA"
	H.nationality = "Ukrainian"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)

//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/pen/reagent/sleepy(H), slot_l_ear)
	if (prob(40))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 75
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your comrades healthy and play your role as a civilian doctor while assisting your UPA allies! Your pen as in injectoor with a powerful sleeping agent and can be refilled!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	var/datum/job/civilian/ukrainian/occupation/P = H.original_job
	P.randrole = "Doctor"
	if (H.r_hair == "09" && H.g_hair == "08" && H.b_hair == "06")
		P.original_hair = "Black"
	else if (H.r_hair == "6A" && H.g_hair == "4E" && H.b_hair == "42")
		P.original_hair = "Light Brown"
	else if (H.r_hair == "3B" && H.g_hair == "30" && H.b_hair == "24")
		P.original_hair = "Dark Brown"
	else if (H.r_hair == "B5" && H.g_hair == "52" && H.b_hair == "39")
		P.original_hair = "Red"
	else if (H.r_hair == "91" && H.g_hair == "55" && H.b_hair == "3D")
		P.original_hair = "Orange"
	else if (H.r_hair == "E6" && H.g_hair == "CE" && H.b_hair == "A8")
		P.original_hair = "Light Blond"
	else if (H.r_hair == "E5" && H.g_hair == "C8" && H.b_hair == "A8")
		P.original_hair = "Blond"
	else if (H.r_hair == "B8" && H.g_hair == "97" && H.b_hair == "78")
		P.original_hair = "Dirty Blond"
	else if (H.r_hair == "d3" && H.g_hair == "d3" && H.b_hair == "d3")
		P.original_hair = "Light Grey"
	else if (H.r_hair == "80" && H.g_hair == "80" && H.b_hair == "80")
		P.original_hair = "Grey"
	P.original_facial = P.original_hair
	return TRUE

/datum/job/civilian/ukrainian/occupation/sergeant_upa
	title = " UPA Vistun"
	en_meaning = " UPA Sergeant"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_upa = TRUE
	is_occupation = TRUE
	whitelisted = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/ukrainian/occupation/sergeant_upa/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "UPA"
	H.nationality = "Ukrainian"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
//head
	if (prob(50))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)

	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 75
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-35,-25)

	H.add_note("Role", "You are a <b>[title]</b>, a sergeant in the Ukrayins'ka Povstans'ka Armiya, in charge of a squad. Lead your men in covert operations against the fascist occupiers!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	H.setStat("stamina", STAT_VERY_HIGH)
	var/datum/job/civilian/ukrainian/occupation/P = H.original_job
	if (prob(40))
		P.randrole = "Civilian/Unemployed"
	else if (prob(60))
		P.randrole = "Factory Worker"
	else if (prob(40))
		P.randrole = "Inn Worker"
	else
		P.randrole = "Farmer"
	if (H.r_hair == "09" && H.g_hair == "08" && H.b_hair == "06")
		P.original_hair = "Black"
	else if (H.r_hair == "6A" && H.g_hair == "4E" && H.b_hair == "42")
		P.original_hair = "Light Brown"
	else if (H.r_hair == "3B" && H.g_hair == "30" && H.b_hair == "24")
		P.original_hair = "Dark Brown"
	else if (H.r_hair == "B5" && H.g_hair == "52" && H.b_hair == "39")
		P.original_hair = "Red"
	else if (H.r_hair == "91" && H.g_hair == "55" && H.b_hair == "3D")
		P.original_hair = "Orange"
	else if (H.r_hair == "E6" && H.g_hair == "CE" && H.b_hair == "A8")
		P.original_hair = "Light Blond"
	else if (H.r_hair == "E5" && H.g_hair == "C8" && H.b_hair == "A8")
		P.original_hair = "Blond"
	else if (H.r_hair == "B8" && H.g_hair == "97" && H.b_hair == "78")
		P.original_hair = "Dirty Blond"
	else if (H.r_hair == "d3" && H.g_hair == "d3" && H.b_hair == "d3")
		P.original_hair = "Light Grey"
	else if (H.r_hair == "80" && H.g_hair == "80" && H.b_hair == "80")
		P.original_hair = "Grey"
	P.original_facial = P.original_hair
	return TRUE

/datum/job/civilian/ukrainian/occupation/upa_infantry
	title = " UPA Strilets"
	en_meaning = "UPA Partisan"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_upa = TRUE
	is_occupation = TRUE
	min_positions = 3
	max_positions = 6

/datum/job/civilian/ukrainian/occupation/upa_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "UPA"
	H.nationality = "Ukrainian"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
//head
	if (prob(50))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)

	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 50
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
//back
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Ukrayins'ka Povstans'ka Armiya. Fight for the freedom of <b>Ukraine</b>! Fight against the fascist occupiers covertly!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	var/datum/job/civilian/ukrainian/occupation/P = H.original_job
	if (prob(40))
		P.randrole = "Civilian/Unemployed"
	else if (prob(60))
		P.randrole = "Factory Worker"
	else if (prob(40))
		P.randrole = "Inn Worker"
	else
		P.randrole = "Farmer"
	if (H.r_hair == "09" && H.g_hair == "08" && H.b_hair == "06")
		P.original_hair = "Black"
	else if (H.r_hair == "6A" && H.g_hair == "4E" && H.b_hair == "42")
		P.original_hair = "Light Brown"
	else if (H.r_hair == "3B" && H.g_hair == "30" && H.b_hair == "24")
		P.original_hair = "Dark Brown"
	else if (H.r_hair == "B5" && H.g_hair == "52" && H.b_hair == "39")
		P.original_hair = "Red"
	else if (H.r_hair == "91" && H.g_hair == "55" && H.b_hair == "3D")
		P.original_hair = "Orange"
	else if (H.r_hair == "E6" && H.g_hair == "CE" && H.b_hair == "A8")
		P.original_hair = "Light Blond"
	else if (H.r_hair == "E5" && H.g_hair == "C8" && H.b_hair == "A8")
		P.original_hair = "Blond"
	else if (H.r_hair == "B8" && H.g_hair == "97" && H.b_hair == "78")
		P.original_hair = "Dirty Blond"
	else if (H.r_hair == "d3" && H.g_hair == "d3" && H.b_hair == "d3")
		P.original_hair = "Light Grey"
	else if (H.r_hair == "80" && H.g_hair == "80" && H.b_hair == "80")
		P.original_hair = "Grey"
	P.original_facial = P.original_hair
	return TRUE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////GERMAN/////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/occupation
	additional_languages = list("Russian" = 45, "Polish" = 65, "Ukrainian" = 90)
/datum/job/german/occupation/hauptsturmfuhrer
	title = "SS Hauptsturmfuhrer"
	en_meaning = "SS Captain"
	rank_abbreviation = "Hptsrmfhr."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_occupation = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/german/occupation/hauptsturmfuhrer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "SS"
	H.nationality = "German"
	H.make_commander()
	H.faction_perms = list(0,0,0,1)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ss_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/german/G1 = new/obj/item/weapon/key/german(null)
	var/obj/item/weapon/key/german/officer/G2 = new/obj/item/weapon/key/german/officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/accessory/rank/SS_hauptsturmfuhrer = new /obj/item/clothing/accessory/rank/SS_hauptsturmfuhrer(null)
	var/obj/item/clothing/accessory/medal/german/ww2/ss_sadler = new /obj/item/clothing/accessory/medal/german/ww2/ss_sadler(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	uniform.attackby(SS_hauptsturmfuhrer, H)
	uniform.attackby(ss_sadler, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Hauptsturmfuhrer of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the SS troops and organize them to find and apprehend the UPA partisans.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MAX)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)


	return TRUE

/datum/job/german/obersturmmfuhrer
	title = "SS Obersturmmfuhrer"
	en_meaning = "SS First Lieutenant"
	rank_abbreviation = "Obstmfhr."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	is_occupation = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/german/obersturmmfuhrer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "SS"
	H.nationality = "SS"
	H.make_commander()
	H.faction_perms = list(0,0,0,1)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ss_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/german/G1 = new/obj/item/weapon/key/german(null)
	var/obj/item/weapon/key/german/officer/G2 = new/obj/item/weapon/key/german/officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/accessory/rank/SS_oberscharfuhrer = new /obj/item/clothing/accessory/rank/SS_oberscharfuhrer(null)
	var/obj/item/clothing/accessory/medal/german/ww2/ss_sadler = new /obj/item/clothing/accessory/medal/german/ww2/ss_sadler(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	uniform.attackby(SS_oberscharfuhrer, H)
	uniform.attackby(ss_sadler, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the SS troops and organize them to victory according to the Hauptsturmfuhrer's orders.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)

	return TRUE

/datum/job/german/untersturmmfuhrer
	title = "SS Untersturmmfuhrer"
	en_meaning = "SS Second Lieutenant"
	rank_abbreviation = "Untstmfhr."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	is_occupation = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/german/untersturmmfuhrer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "SS"
	H.nationality = "SS"
	H.make_commander()
	H.faction_perms = list(0,0,0,1)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ss_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/german/G1 = new/obj/item/weapon/key/german(null)
	var/obj/item/weapon/key/german/officer/G2 = new/obj/item/weapon/key/german/officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/accessory/rank/SS_unterscharfuhrer = new /obj/item/clothing/accessory/rank/SS_unterscharfuhrer(null)
	var/obj/item/clothing/accessory/medal/german/ww2/ss_sadler = new /obj/item/clothing/accessory/medal/german/ww2/ss_sadler(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	uniform.attackby(SS_unterscharfuhrer, H)
	uniform.attackby(ss_sadler, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the german troops and organize them to victory according to the Hauptmann's orders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)


	return TRUE

/datum/job/german/scharfuhrer
	title = "SS Scharfuhrer"
	en_meaning = "SS Squad Leader"
	rank_abbreviation = "Schfhr."

	spawn_location = "JoinLateGE"
	is_squad_leader = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_occupation = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/german/scharfuhrer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "SS"
	H.nationality = "SS"
	H.faction_perms = list(0,0,0,1)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ss_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/german/G1 = new/obj/item/weapon/key/german(null)
	KC.attackby(G1,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/accessory/rank/SS_scharfuhrer = new /obj/item/clothing/accessory/rank/SS_scharfuhrer(null)
	var/obj/item/clothing/accessory/medal/german/ww2/ss_sadler = new /obj/item/clothing/accessory/medal/german/ww2/ss_sadler(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	uniform.attackby(SS_scharfuhrer, H)
	uniform.attackby(ss_sadler, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Hauptsturmfuhrer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/german/schutzestaffel_soldaten
	title = "SS Sturmman"
	en_meaning = "SS Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_occupation = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE

	min_positions = 8
	max_positions = 20

/datum/job/german/schutzestaffel_soldaten/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "SS"
	H.nationality = "SS"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)

//head
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss/dark(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	else
		if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/german/G1 = new/obj/item/weapon/key/german(null)
	var/obj/item/clothing/accessory/medal/german/ww2/ss_sadler = new /obj/item/clothing/accessory/medal/german/ww2/ss_sadler(null)
	KC.attackby(G1,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(webbing, H)
	uniform.attackby(ss_sadler, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the SS Occupying forces. Follow your <b>Scharfuhrer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////Civilians/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/mob/living/human/proc/give_nationality_occupation(var/mob/living/human)
	if (istype(original_job, /datum/job/civilian/occupation))
		var/datum/job/civilian/occupation/PJ = original_job
		if (src.client.ckey == "kanohashinobi")
			src.add_note("Known Languages", "Ukrainian")
			src.remove_language("English")
			src.name = "Haji Petrovich"
			src.real_name = name
			src.add_note("Group", "You are a Ukrainian civilian.")
			src.nationality = "Ukrainian"
			src.add_language("German",FALSE)
			src.h_style = "Short Hair"
			src.f_style = "Short Facial Hair"
			src.r_hair = 22
			src.g_hair = 22
			src.b_hair = 22
			src.r_facial = 22
			src.g_facial = 22
			src.b_facial = 22
			update_body()
			return
		var/randpick = rand(1,3)
		switch(randpick)
			if (1)
				if (src.nationality == "none")
					src.add_note("Known Languages", "Polish")
					src.remove_language("English")
					src.name = species.get_random_polish_name(gender)
					src.real_name = name
					src.add_note("Group", "You are a Polish civilian. You are part of the <b>Polish</b> faction. Keep your faction powerful! Watch out for the UPA, they might kill you.")
					src.nationality = "Polish"
					src.add_language("Polish",FALSE)
			if (2)
				if (src.nationality == "none")
					src.add_note("Known Languages", "Ukrainian")
					src.remove_language("English")
					src.name = species.get_random_ukrainian_name(gender)
					src.real_name = name
					src.add_note("Group", "You are a Ukrainian civilian. You are part of the <b>Ukrainian</b> faction. Keep your faction powerful!")
					src.nationality = "Ukrainian"
					src.add_language("Ukrainian",FALSE)
			if (3)
				if (src.nationality == "none")
					src.add_note("Known Languages", "German")
					src.remove_language("English")
					src.name = species.get_random_german_name(gender)
					src.real_name = name
					src.add_note("Group", "You are a German civilian who has been relocated to occupied territories. You are part of the <b>German</b> faction. Keep your faction powerful!")
					src.nationality = "German"
					src.add_language("German",FALSE)

		PJ.original_hair = pick("Black", "Light Brown", "Dark Brown", "Red", "Orange", "Light Blond", "Blond", "Dirty Blond", "Light Grey", "Grey")
		PJ.original_facial = PJ.original_hair
		var/hex_hair = hair_colors[PJ.original_hair]
		var/red = hex2num(copytext(hex_hair, 2, 4))
		var/green = hex2num(copytext(hex_hair, 4, 6))
		var/blue = hex2num(copytext(hex_hair, 6, 8))
		src.r_hair = red
		src.g_hair = green
		src.b_hair = blue
		src.r_facial = red
		src.g_facial = green
		src.b_facial = blue
		PJ.original_eyes = pick("Black", "Brown", "Dark Brown", "Green", "Blue")
		var/hex_eyes = eye_colors[PJ.original_eyes]
		red = hex2num(copytext(hex_eyes, 2, 4))
		green = hex2num(copytext(hex_eyes, 4, 6))
		blue = hex2num(copytext(hex_eyes, 6, 8))
		src.r_eyes = red
		src.g_eyes = green
		src.b_eyes = blue

		src.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Parted","Bedhead","Shoulder-length Hair")
		src.f_style = pick("Shaved","Chinstrap","Medium Beard","Long Beard","Full Beard","Very Long Beard")
		update_body()
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/civilian/occupation
	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	rank_abbreviation = ""
	title = "DONT USE"
	default_language = "Ukrainian"
	is_occupation = TRUE
	var/randrole = "none"
	var/original_eyes = "Black"
	var/original_facial = "Shaved"
	var/original_hair = "Black"
	can_be_female = TRUE
/datum/job/civilian/occupation/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.nationality = "none"
	H.give_nationality_occupation()
	if (H.original_job == "Auxillary Police")
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armband/nsdap = new /obj/item/clothing/accessory/armband/nsdap(null)
		var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
		uniform.attackby(nsdap, H)
		uniform.attackby(holsterh, H)
		holsterh.attackby(new/obj/item/weapon/gun/projectile/revolver/nagant_revolver, H)
		var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
		RUB.amount = 75
		H.equip_to_slot_or_del(RUB, slot_r_store)
		H.setStat("strength", STAT_HIGH)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_HIGH)
		H.setStat("dexterity", STAT_MEDIUM_LOW)
		H.setStat("swords", STAT_NORMAL)
		H.setStat("pistol", STAT_HIGH)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_MEDIUM_HIGH)
		H.setStat("machinegun", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
		H.gulag_languages()
		return TRUE
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
//head
		if (prob(30))
			if (prob(50))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
		else if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)

		var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
		RUB.amount = 50
		H.equip_to_slot_or_del(RUB, slot_r_store)
		H.setStat("strength", STAT_MEDIUM_LOW)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_NORMAL)
		H.setStat("dexterity", STAT_MEDIUM_LOW)
		H.setStat("swords", STAT_NORMAL)
		H.setStat("pistol", STAT_NORMAL)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_MEDIUM_LOW)
		H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
		H.gulag_languages()

/datum/job/civilian/occupation/worker
	title = "Factory Worker"
	en_meaning = ""
	min_positions = 2
	max_positions = 8
	can_be_female = TRUE
	spawn_location = "JoinLateCivA"
	equip(var/mob/living/human/H)
		..()
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
		else
			if (prob(50))
				H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		H.add_note("Role", "You are a <b>Factory Worker</b>. Your job is to work for the german occupiers in either the munitions factory or the motorcycle assembly plant. Misbehaviour can be met with severe punishment.")
		randrole = title
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/medal/pin/worker/factory = new /obj/item/clothing/accessory/medal/pin/worker/factory(null)
		uniform.attackby(factory, H)

/datum/job/civilian/occupation/inn
	title = "Inn Worker"
	spawn_location = "JoinLateCivB"
	en_meaning = ""
	min_positions = 1
	max_positions = 4
	can_be_female = TRUE
	equip(var/mob/living/human/H)
		..()
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/leather/occinn(H), slot_belt)
		H.add_note("Role", "You are an <b>Inn Keeper</b>. Your job is to man the inn and provide food and shelter to those paying for it.")
		randrole = title
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/medal/pin/worker/aristocrat = new /obj/item/clothing/accessory/medal/pin/worker/aristocrat(null)
		uniform.attackby(aristocrat, H)
		H.setStat("medical", STAT_NORMAL)

/datum/job/civilian/occupation/farmer
	title = "Civilian Farmer"
	spawn_location = "JoinLateCivC"
	en_meaning = ""
	can_be_female = TRUE
	min_positions = 1
	max_positions = 3
	equip(var/mob/living/human/H)
		..()
		H.add_note("Role", "You are a <b>Farmer</b>. Your job is to work for the german occupiers in either the fields or the woods. Misbehaviour can be met with severe punishment.")
		randrole = "Farmer"
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/medal/pin/worker/farmer = new /obj/item/clothing/accessory/medal/pin/worker/farmer(null)
		uniform.attackby(farmer, H)

/datum/job/civilian/occupation/doctor
	title = "Civilian Doctor"
	spawn_location = "JoinLateCivD"
	en_meaning = ""
	min_positions = 2
	max_positions = 4
/datum/job/civilian/occupation/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.nationality = "none"
	H.give_nationality_occupation()
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/roller_holder(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/medal/pin/worker/medic = new /obj/item/clothing/accessory/medal/pin/worker/medic(null)
	uniform.attackby(medic, H)
	if (prob(40))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 75
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>Doctor</b>. Your job is to to heal the sick and advise the healthy on staying that way. Misbehaviour can be met with severe punishment.")
	randrole = "Doctor"
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_VERY_HIGH)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	H.gulag_languages()

/datum/job/civilian/occupation/collaborator
	title = "Auxillary Police"
	en_meaning = ""
	spawn_location = "JoinLateCivE"

	min_positions = 2
	max_positions = 5
/datum/job/civilian/occupation/collaborator/equip(var/mob/living/human/H)
	if (!H)	return FALSE

	H.nationality = "none"
	H.give_nationality_occupation()
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard_SS(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/nsdap = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(nsdap, H)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/revolver/nagant_revolver, H)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 75
	H.equip_to_slot_or_del(RUB, slot_r_store)
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	H.equip_to_slot_or_del(new /obj/item/weapon/civilian_passport(H), slot_wear_id)
	H.gulag_languages()
	randrole = title
	H.add_note("Primary Role", "You are an <b>Auxillary Police</b>. Your job is to get information and pass it to the SS. Be careful, the civilians might not like your presence.")
	return TRUE

/datum/job/civilian/occupation/basic
	title = "Basic Civilian"
	en_meaning = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	min_positions = 8
	max_positions = 30
	equip(var/mob/living/human/H)
		..()
		H.add_note("Role", "You are a <b>Basic Civilian</b>. Your job is to find a job. Maybe the SS have work for you. Misbehaviour will be met with severe punishment.")
		randrole = "Civilian/Unemployed"