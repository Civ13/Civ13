/mob/living/human/corpse
	icon = 'icons/mob/human.dmi'
	icon_state = "corpse_map_state"
	var/corpse_job = ""
	var/corpse_name = ""
	var/corpse_s_tone = 0
	var/s_tone_min = 0
	var/s_tone_max = 0

/mob/living/human/corpse/New()
	..()
	if (corpse_job == "" && corpse_name == "" && corpse_s_tone == 0 && s_tone_min == 0 && s_tone_max == 0 && icon_state == "corpse_map_state")
		death()
		return

	if (icon_state == "corpse_map_state")
		icon_state = "human_m_s"

	invisibility = 101
	var/spawntime = 0
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master && corpse_job != "")
			qdel(src)
			return
		if (corpse_job != "")
			job_master.EquipRank(src, corpse_job)
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30, 60))
		if (corpse_name != "")
			name = corpse_name
		if (corpse_s_tone != 0)
			s_tone = corpse_s_tone
		else if (s_tone_min != 0 || s_tone_max != 0)
			s_tone = rand(s_tone_min, s_tone_max)
		invisibility = 0
		spawn (5)
			death()

/mob/living/human/corpse/pirate
	gender = MALE
	corpse_job = "Pirate"
	corpse_name = "Pirate"

/mob/living/human/corpse/spanish
	gender = MALE
	corpse_job = "Marinero"
	corpse_name = "Marinero"
	s_tone_min = -65
	s_tone_max = -75

/mob/living/human/corpse/spanish_cpt
	gender = MALE
	corpse_job = "Capitan"
	corpse_name = "Capitan"
	s_tone_min = -65
	s_tone_max = -75

/mob/living/human/corpse/spanish_lt
	gender = MALE
	corpse_job = "Contramaestre"
	corpse_name = "Contramaestre"
	s_tone_min = -65
	s_tone_max = -75

/mob/living/human/corpse/spanish_sgt
	gender = MALE
	corpse_job = "Guardiamarina"
	corpse_name = "Guardiamarina"
	s_tone_min = -65
	s_tone_max = -75

/mob/living/human/corpse/spanish_soldier
	gender = MALE
	corpse_job = "Military Soldado"
	corpse_name = "Soldado"
	s_tone_min = -65
	s_tone_max = -75

/mob/living/human/corpse/spanish_rifleman
	gender = MALE
	corpse_job = "Rifle Soldado"
	corpse_name = "Rifleman"
	s_tone_min = -65
	s_tone_max = -75
////////////////////////////////////////////////////////////////
mob/living/human/corpse/british_sailor
	gender = MALE
	corpse_job = "Royal Navy Seaman"
	corpse_name = "Royal Navy Seaman"

/mob/living/human/corpse/british
	gender = MALE
	corpse_job = "British Town Guard"
	corpse_name = "Redcoat Soldier"

/mob/living/human/corpse/japanese
	gender = MALE
	corpse_job = "Shiro Nitohei"
	corpse_name = "Japanese Soldier"

/mob/living/human/corpse/japanese_ww2
	gender = MALE
	corpse_job = "Ittohei"
	corpse_name = "Japanese Soldier"

/mob/living/human/corpse/japanese_ww2_antitank
	gender = MALE
	corpse_job = "Nitohei Taisen-sha"
	corpse_name = "Japanese Soldier"

/mob/living/human/corpse/ww2_jap_sl
	gender = MALE
	corpse_job = "IJA Gunso"
	corpse_name = "Japanese Sergeant"

/mob/living/human/corpse/ww2_jap_seaman
	gender = MALE
	corpse_job = "Santosuihei"
	corpse_name = "Japanese Seaman"

/mob/living/human/corpse/ww2_jap_seaman_po
	gender = MALE
	corpse_job = "Kaigun Nitoheiso"
	corpse_name = "Japanese Petty Officer"

/mob/living/human/corpse/ww2_jap_seaman_officer
	gender = MALE
	corpse_job = "Kaigun-Dai-i"
	corpse_name = "Japanese Naval Officer"

/mob/living/human/corpse/ww2_jap_medic
	gender = MALE
	corpse_job = "Sento-i"
	corpse_name = "Japanese Medic"

/mob/living/human/corpse/ww2_jap_mg
	gender = MALE
	corpse_job = "Taiho"
	corpse_name = "Japanese Machinegunner"

/mob/living/human/corpse/chinese_ww2
	gender = MALE
	corpse_job = "Erdeng Bing"
	corpse_name = "Chinese Soldier"

/mob/living/human/corpse/russian
	gender = MALE
	corpse_job = "Ryadovoy"
	corpse_name = "Russian Soldier"

/mob/living/human/corpse/greenistani_ambassador
	gender = MALE
/mob/living/human/corpse/greenistani_ambassador/New()
	corpse_name = "Ambassador Bogdan Nogoonbayev"
	..()
	faction = CHECHEN
	nationality = "Greenistan"
	equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(src), slot_shoes)
	equip_to_slot_or_del(new /obj/item/clothing/under/expensive/green(src), slot_w_uniform)
	equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/really_black_suit(src), slot_wear_suit)
	equip_to_slot_or_del(new /obj/item/weapon/storage/briefcase(src), slot_r_hand)
	h_style = "CIA"
	corpse_s_tone = -66
	change_skin_tone(s_tone)
	add_language("Blugoslavian",FALSE)
	add_language("Redmenian",FALSE)
	add_language("Greenistani",FALSE)
	for (var/datum/language/greenistani/A in languages)
		default_language = A
	real_name = "Ambassador Bogdan Nogoonbayev"

/mob/living/human/corpse/war_correspondent
	gender = MALE
/mob/living/human/corpse/war_correspondent/New()
	corpse_name = "War Correspondent"
	..()
	faction = AMERICAN
	nationality = "American"
	equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(src), slot_shoes)
	equip_to_slot_or_del(new /obj/item/clothing/under/reporter(src), slot_w_uniform)
	equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet/press(src), slot_head)
	equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard/yellow(src), slot_r_store)
	var/obj/item/clothing/under/uniform = w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/press/press_armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/press(null)
	uniform.attackby(press_armor, src)
	h_style = "Gelled Back"
	f_style = "Full Beard"
	var/hex_hair = hair_colors["Dirty Blond"]
	r_hair = hex2num(copytext(hex_hair, 2, 4))
	g_hair = hex2num(copytext(hex_hair, 4, 6))
	b_hair = hex2num(copytext(hex_hair, 6, 8))
	r_facial = hex2num(copytext(hex_hair, 2, 4))
	g_facial = hex2num(copytext(hex_hair, 4, 6))
	b_facial = hex2num(copytext(hex_hair, 6, 8))
	update_hair()
	add_language("Blugoslavian",FALSE)
	add_language("Redmenian",FALSE)
	add_language("English",FALSE)
	for (var/datum/language/english/A in languages)
		default_language = A


/mob/living/human/corpse/russian_soviet
	gender = MALE
	corpse_job = "K.A. Soldat"
	corpse_name = "Russian Soldier"

/mob/living/human/corpse/russian_soviet_sgt
	gender = MALE
	corpse_job = "K.A. Serjant"
	corpse_name = "Russian Sergeant"

mob/living/human/corpse/russian_soviet_tanker
	gender = MALE
	corpse_job = "Tankist"
	corpse_name = "Russian Tanker"

/mob/living/human/corpse/russiansgt
	gender = MALE
	corpse_job = "Feldvebel"
	corpse_name = "Russian Sergeant"

/mob/living/human/corpse/japanesesgt
	gender = MALE
	corpse_job = "Gunso"
	corpse_name = "Japanese Sergeant"


/mob/living/human/corpse/japanesecap
	gender = MALE
	corpse_job = "Rikugun-Tai-i"
	corpse_name = "Japanese Captain"


/mob/living/human/corpse/Giant
	gender = MALE
	icon_state = "body_m_giant"

/mob/living/human/corpse/prisoner
	gender = MALE
	corpse_job = "DO NOT USE"
	corpse_name = "Escaped Prisoner"

/mob/living/human/corpse/bandit
	gender = MALE
	h_style = "Fade"
	corpse_job = "Bandit"
	corpse_name = "Bandit"


/mob/living/human/corpse/police
	gender = MALE
	h_style = "Fade"
	corpse_job = "Police Officer"
	corpse_name = "Police Officer"



/mob/living/human/corpse/pmc
	gender = MALE
	corpse_job = "Bandit"
	corpse_name = "pmc"


/mob/living/human/corpse/ww2_american
	gender = MALE
	corpse_job = "US Rifleman"
	corpse_name = "American Soldier"


/mob/living/human/corpse/ww2_american_medic
	gender = MALE
	corpse_job = "US Field Medic"
	corpse_name = "American Medic"


/mob/living/human/corpse/ww2_american_sl
	gender = MALE
	corpse_job = "US Sergeant"
	corpse_name = "American Sergeant"


/mob/living/human/corpse/ww2_american_mg
	gender = MALE
	corpse_job = "US Machine Gunner"
	corpse_name = "American Machinegunner"


/mob/living/human/corpse/beggar
	gender = MALE
	corpse_job = "Beggar"
	corpse_name = "Beggar"


/mob/living/human/corpse/beggar_f
	gender = FEMALE
	corpse_job = "Beggar"
	corpse_name = "Beggar"


/mob/living/human/corpse/nva
	gender = MALE
	corpse_job = "NVA Binh Ni"
	corpse_name = "NVA soldier"

/mob/living/human/corpse/merchant
	gender = MALE
	corpse_job = "Merchant"
	corpse_name = "Merchant"

/mob/living/human/corpse/colony_civ
	gender = MALE
	corpse_job = "Colonist"
	corpse_name = "Civilian"

/mob/living/human/corpse/colony_civ_f
	gender = FEMALE
	corpse_job = "Colonist"
	corpse_name = "Civilian"

/mob/living/human/corpse/barmaiden
	gender = FEMALE
	corpse_job = "Bar Keep/Bar Maiden"
	corpse_name = "Barmaiden"

/mob/living/human/corpse/teller
	gender = MALE
	corpse_job = "Teller"
	corpse_name = "Bank Teller"

/mob/living/human/corpse/teller/modern
	gender = MALE

/mob/living/human/corpse/teller/modern/New()
	corpse_name = "Bank Teller"

	..()
	var/randshoes = rand(1,2)
	switch(randshoes)
		if(1)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(src), slot_shoes)
		if(2)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(src), slot_shoes)
	equip_to_slot_or_del(new /obj/item/clothing/under/expensive/yellow(src), slot_w_uniform)
	var/randsuit = rand(1,5)
	switch(randsuit)
		if(1)
			equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/really_black_suit(src), slot_wear_suit)
		if(2)
			equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(src), slot_wear_suit)
		if(3)
			equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/navy_suit(src), slot_wear_suit)
		if(4)
			equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/checkered_suit(src), slot_wear_suit)
		if(5)
			equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/burgundy_suit(src), slot_wear_suit)
	if (prob(20))
		equip_to_slot_or_del(new /obj/item/clothing/glasses/regular(src), slot_wear_mask)
	h_style = pick("CIA","Business 1", "Business 2", "Business 3", "Regulation Cut")
	f_style = pick("Shaved","Selleck Mustache","Medium Beard")
	var/hex_hair = hair_colors[pick("Black", "Light Brown", "Dark Brown", "Red", "Orange", "Light Blond", "Blond", "Dirty Blond", "Light Grey", "Grey")]
	r_hair = hex2num(copytext(hex_hair, 2, 4))
	g_hair = hex2num(copytext(hex_hair, 4, 6))
	b_hair = hex2num(copytext(hex_hair, 6, 8))
	r_facial = hex2num(copytext(hex_hair, 2, 4))
	g_facial = hex2num(copytext(hex_hair, 4, 6))
	b_facial = hex2num(copytext(hex_hair, 6, 8))
	update_hair()

/mob/living/human/corpse/ww1french
	gender = MALE
	h_style = "Short Hair"
	corpse_job = "Soldat de infanterie"
	corpse_name = "French Soldier"

/mob/living/human/corpse/ww1german
	gender = MALE
	h_style = "Short Hair"
	corpse_job = "Heer Soldat"
	corpse_name = "German Soldier"

/mob/living/human/corpse/ww2_german
	gender = MALE
	corpse_job = "Schutze"
	corpse_name = "German Soldier"

/mob/living/human/corpse/ww2_german_mg
	gender = MALE
	corpse_job = "MG-Schutze"
	corpse_name = "German Machinegunner"

/mob/living/human/corpse/ww2_german_medic
	gender = MALE
	corpse_job = "Feldmediziner"
	corpse_name = "German Medic"

/mob/living/human/corpse/ww2_german_sl
	gender = MALE
	corpse_job = "Unteroffizier"
	corpse_name = "German Squad Leader"

/mob/living/human/corpse/ww2_soviet
	gender = MALE
	corpse_job = "K.A. Soldat"
	corpse_name = "Soviet Soldier"

/mob/living/human/corpse/ww2_soviet_mg
	gender = MALE
	corpse_job = "K.A. Pulemetchik"
	corpse_name = "Soviet Machinegunner"

/mob/living/human/corpse/ww2_soviet_medic
	gender = MALE
	corpse_job = "K.A. Voynenvrach"
	corpse_name = "Soviet Medic"

/mob/living/human/corpse/ww2_soviet_sl
	gender = MALE
	corpse_job = "K.A. Serjant"
	corpse_name = "Soviet Squad Leader"
