/datum/job/civilian/magic
	title = "Wizard Boy"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 100
	max_positions = 100
	can_be_female = TRUE
	allowed_maps = list(MAP_WIZARD_BOY)

/datum/job/civilian/magic/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//uniform
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2/wizard(H), slot_w_uniform)
//suit
	if (map && istype(map, /obj/map_metadata/wizard_boy))
		var/obj/map_metadata/wizard_boy/WB = map
		if (!WB.house_info[H.ckey])
			WB.load_houses()
		if (WB.house_info[H.ckey])
			H.nationality = WB.house_info[H.ckey][2]
			if (H.nationality != "R" && WB.house_info[H.ckey][2] != "0")
				switch(WB.house_info[H.ckey][1])
					if("Rubywyrm")
						H.faction = "Rubywyrm"
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/red(H), slot_wear_suit)
					if("Mintysnek")
						H.faction = "Mintysnek"
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/green(H), slot_wear_suit)
					if("Slatepie")
						H.faction = "Slatepie"
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/blue(H), slot_wear_suit)
					if("Mustardweasel")
						H.faction = "Mustardweasel"
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/yellow(H), slot_wear_suit)
					else
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)
			switch(WB.house_info[H.ckey][2])
				if("R") // loser
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/loser(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/pinkrobe(H), slot_wear_suit)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/dunce_cap(H), slot_head)
					H.setStat("magic", 10)
				if("0") // idiot
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/idiot(H), slot_wear_id)
					switch(WB.house_info[H.ckey][1])
						if("Rubywyrm")
							H.faction = "Rubywyrm"
							H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe/red(H), slot_wear_suit)
						if("Mintysnek")
							H.faction = "Mintysnek"
							H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe/green(H), slot_wear_suit)
						if("Slatepie")
							H.faction = "Slatepie"
							H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe/blue(H), slot_wear_suit)
						if("Mustardweasel")
							H.faction = "Mustardweasel"
							H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe/yellow(H), slot_wear_suit)
						else
							H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe(H), slot_wear_suit)
					H.setStat("magic", 0)
				if("1") // unga
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/unga(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 10)
				if("2") // coal
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/coal(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 20)
				if("3") // gem
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/slate(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 40)
				if("4") // based
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/based(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 70)
				if("5") // chad
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/chad(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 100)
				if("T") // teacher/professor
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(WB.load_wand(H) || new /obj/item/weapon/material/magic/wand/crafted/standard(H), slot_belt)
					H.setStat("magic", 100)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)
	H.add_note("Role", "You're a wizard boy with magic powers. What shenanigans will you get up to?")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)

	// Grant all base spells
	for (var/spell_name in all_spells)
		if (istype(all_spells[spell_name], /datum/spell))
			var/datum/spell/S = all_spells[spell_name]
			if (S.learnable == TRUE)
				H.add_spell(S)
	spawn(30)
		if (H && H.client)
			H.client.screen += new/obj/screen/spellshow("Spell","7,14", H, null, "")

/mob/living/human/corpse/wizard
	gender = MALE
	h_style = "Fade"
	corpse_job = "Wizard Boy"
	corpse_name = "wizard boy"
