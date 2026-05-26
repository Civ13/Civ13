/datum/job/civilian/magic
	title = "Wizard Boy"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 100
	max_positions = 100
	allowed_maps = list(MAP_TESTING)

/datum/job/civilian/magic/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//uniform
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2/wizard(H), slot_w_uniform)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/red(H), slot_wear_suit)
//glasses
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)

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

/obj/item/clothing/under/civ2/wizard
	name = "wizard clothing"
	desc = "A white shirt used by wizards."
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
	house_colors = "#7F0000"

/obj/item/clothing/suit/storage/jacket/wizard/green
	house_colors = "#007F00"

/obj/item/clothing/suit/storage/jacket/wizard/blue
	house_colors = "#0000c8"

/obj/item/clothing/suit/storage/jacket/wizard/yellow
	house_colors = "#cbb600"


/obj/item/weapon/material/magic/wand/wizard
	name = "wizard's wand"
	desc = "Use with care."