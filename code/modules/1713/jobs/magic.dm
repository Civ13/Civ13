/datum/job/civilian/magic
	title = "Wizard Boy"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 100
	max_positions = 100
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
		if (WB.house_info[H.ckey])
			switch(WB.house_info[H.ckey])
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
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/red(H), slot_wear_suit)
//glasses
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/magic/wand/wizard(H), slot_belt)
	H.add_note("Role", "You're a wizard boy with magic powers. What shenanigans will you get up to?")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("magic", STAT_NORMAL)

	// Grant all base spells
	for (var/spell_name in all_spells)
		if (istype(all_spells[spell_name], /datum/spell))
			var/datum/spell/S = all_spells[spell_name]
			if (S.learnable == TRUE)
				H.add_spell(S)
	spawn(30)
		H.client.screen += new/obj/screen/spellshow("Spell","7,14", H, null, "")

/mob/living/human/corpse/wizard
	gender = MALE
	h_style = "Fade"
	corpse_job = "Wizard Boy"
	corpse_name = "wizard boy"

/obj/item/clothing/under/civ2/wizard
	name = "wizard clothing"
	desc = "An old-school white shirt and black trousers, commonly used by wizards."
	icon_state = "civuni2"
	item_state = "civuni2"
	
/obj/item/clothing/suit/storage/jacket/wizard
	name = "wizard robe"
	desc = "A black robe worn by wizards."
	icon_state = "magic_boy_robe"
	item_state = "magic_boy_robe"
	var/house_colors = "#000000"
	var/uncolored = TRUE

	New()
		..()
		spawn(1)
			var/image/lines = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "magic_boy_robe_decoration")
			lines.color = house_colors
			overlays += lines
			update_icon()

/obj/item/clothing/suit/storage/jacket/wizard/red
	name = "Rubywyrm wizard robe"
	house_colors = "#7F0000"

/obj/item/clothing/suit/storage/jacket/wizard/green
	name = "Mintysnek wizard robe"
	house_colors = "#007F00"

/obj/item/clothing/suit/storage/jacket/wizard/blue
	name = "Slatepie wizard robe"
	house_colors = "#0000c8"

/obj/item/clothing/suit/storage/jacket/wizard/yellow
	name = "Mustardweasel wizard robe"
	house_colors = "#cbb600"

/obj/item/clothing/head/wizard
	name = "wizard's hat"
	desc = "A wide brim black wizard's hat."
	icon_state = "blackwizard"
	item_state = "blackwizard"

/obj/structure/sign/crest
	name = "house crest"
	desc = "The crest of one of the houses."
	icon = 'icons/misc/crests.dmi'
	icon_state = ""

/obj/structure/sign/crest/mintysnek
	name = "Mintysnek crest"
	desc = "The crest of the Mintysnek house. A minty green lizard and a leek."
	icon_state = "mintysnek"

/obj/structure/sign/crest/rubywyrm
	name = "Rubywyrm crest"
	desc = "The crest of the Rubywyrm house. A welsh dragon coiled around a ruby."
	icon_state = "rubywyrm"

/obj/structure/sign/crest/slatepie
	name = "Slatepie crest"
	desc = "The crest of the Slatepie house. A magpie sitting on top of welsh slate."
	icon_state = "slatepie"

/obj/structure/sign/crest/mustardweasel
	name = "Mustardweasel crest"
	desc = "The crest of the Mustardweasel house. A ferret with a daffodil over its ear."
	icon_state = "mustardweasel"