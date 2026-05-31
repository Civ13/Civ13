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
			H.nationality = WB.house_info[H.ckey][2]
			switch(WB.house_info[H.ckey][2])
				if("R") // loser
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/loser(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/pinkrobe(H), slot_wear_suit)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/dunce_cap(H), slot_head)
					H.setStat("magic", 10)
				if("0") // idiot
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/idiot(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe(H), slot_wear_suit)
					H.setStat("magic", 0)
				if("1") // unga
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/unga(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.setStat("magic", 10)
				if("2") // coal
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/coal(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.setStat("magic", 20)
				if("3") // slate
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/slate(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
					H.setStat("magic", 40)
				if("4") // based
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/based(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
					H.setStat("magic", 70)
				if("5") // chad
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/chad(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
					H.setStat("magic", 100)
				if("T") // teacher/professor
					H.equip_to_slot_or_del(new /obj/item/weapon/magic_id(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
					H.setStat("magic", 100)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard(H), slot_wear_suit)

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

/obj/item/clothing/suit/storage/jacket/wizard/pinkrobe
	name = "L.O.S.E.R. wizard robe"
	desc = "A pink wizard's robe used by those who have received the 'LLanboarwart Outcast and Substandard Educational Reject' status."
	house_colors = "#000000"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe
	name = "I.D.I.O.T. wizard robe"
	desc = "A grey wizard's robe used by those who have received the 'Inept & Deficient Individual's Ordinary Test' certificate. Not to be left unnatended near crayons."
	house_colors = "#000000"

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

// the school tier pins/certificates
/obj/item/weapon/magic_id
	name = "L.A.M.E. professor badge"
	desc = "A badge worn by professors at the Llanboarwart Academy of Magical Education. It grants the wearer a small amount of magical power, but mostly just serves as a fashion statement."
	icon = 'icons/obj/clothing/badges.dmi'
	item_icons = 'icons/mob/badge.dmi'
	icon_state = "Order of the Patriotic War, 1st Class"
	worn_state = "OPW I, on body"
	item_state = "OPW I, on body"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_ID
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = FALSE
	icon_override = 'icons/mob/badge.dmi'

	attack_hand(mob/M)
		if (istype(M, /mob/living/human))
			var/mob/living/human/H = M
			if (H.wear_id == src)
				return //cannot remove the badge once equipped, so no attack_hand proc
		..()
// Tier 0: I.D.I.O.T. certificate
/obj/item/weapon/magic_id/idiot
	name = "I.D.I.O.T. certificate"
	desc = "The 'Inept & Deficient Individual's Ordinary Test' certificate. Not to be left unnatended near crayons."
	icon_state = "wizard_idiot"
	worn_state = "christian_party_pin"
	item_state = "christian_party_pin"

// Tier 1: U.N.G.A. certificate
/obj/item/weapon/magic_id/unga
	name = "U.N.G.A. certificate"
	desc = "The 'Underperforming Numpty General Assessment' certificate. The most basic magic aptitude level."
	icon_state = "wizard_unga"
	worn_state = "nationalist_party_pin"
	item_state = "nationalist_party_pin"

// Tier 2: C.O.A.L. licence
/obj/item/weapon/magic_id/coal
	name = "C.O.A.L. license"
	desc = "The 'Community Ordinary Amateur License'. The bare minimum required to carry a wand in the valley without being arrested."
	icon_state = "wizard_coal"
	worn_state = "pirate_flag_pin"
	item_state = "pirate_flag_pin"

// Tier 3: G.E.M. licence
/obj/item/weapon/magic_id/slate
	name = "G.E.M. licence"
	desc = "The 'Gravity & Elemental Manipulation'. Granted to those proven unlikely to accidentally collapse the school's slate roofs."
	icon_state = "wizard_gem"
	worn_state = "nationalist_party_pin"
	item_state = "nationalist_party_pin"

// Tier 4: B.A.S.E.D. licence
/obj/item/weapon/magic_id/based
	name = "B.A.S.E.D. licence"
	desc = "The 'Boarwart Advanced Sorcery & Experimental Deeds' licence. Reserved for students whose deeds are considered extremely based, yet highly unstable."
	icon_state = "wizard_based"
	worn_state = "AS, on body"
	item_state = "AS, on body"

// Tier 5: C.H.A.D. degree
/obj/item/weapon/magic_id/chad
	name = "C.H.A.D. degree"
	desc = "The 'Classified High-level Arcane Destruction' degree. The absolute peak of magical education. Absolute gigachad energy required."
	icon_state = "wizard_chad"
	worn_state = "Verwund Geld, on body"
	item_state = "Verwund Geld, on body"

// Tier R: L.O.S.E.R. status
/obj/item/weapon/magic_id/loser
	name = "L.O.S.E.R. status pin"
	desc = "The 'Llanboarwart Outcast & Sub-standard Educational Reject' status. A mark of disciplinary shame for those who have violated school laws."
	icon_state = "wizard_loser"
	worn_state = "globalist_pin"
	item_state = "globalist_pin"