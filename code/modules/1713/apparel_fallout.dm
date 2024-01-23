/obj/item/clothing/under/fallout/ncr
	name = "NCR uniform"
	desc = "NCR Trooper Fatigues"
	icon_state = "ncr_fatigues"
	item_state = "ncr_fatigues"
	worn_state = "ncr_fatigues"
	var/rolled = FALSE
	var/maskup = FALSE

/obj/item/clothing/under/fallout/ncr/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/fallout/ncr)
		return
	else
		if (!maskup)
			if (rolled)
				flags_inv = null
				worn_state = "ncr_fatigues"
				item_state = "ncr_fatigues"
				icon_state = "ncr_fatigues"
				item_state_slots["w_uniform"] = "ncr_fatigues"
				usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			if (!rolled)
				flags_inv = null
				worn_state = "ncr_fatigues_rolled"
				item_state = "ncr_fatigues_rolled"
				icon_state = "ncr_fatigues_rolled"
				item_state_slots["w_uniform"] = "ncr_fatigues_rolled"
				usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
				rolled = TRUE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
		else
			if (rolled)
				flags_inv = HIDEFACE
				worn_state = "ncr_fatigues_maskup"
				item_state = "ncr_fatigues_maskup"
				icon_state = "ncr_fatigues_maskup"
				item_state_slots["w_uniform"] = "ncr_fatigues_maskup"
				usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			else
				flags_inv = HIDEFACE
				worn_state = "ncr_fatigues_maskup_rolled"
				item_state = "ncr_fatigues_maskup_rolled"
				icon_state = "ncr_fatigues_maskup_rolled"
				item_state_slots["w_uniform"] = "ncr_fatigues_maskup_rolled"
				usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
				rolled = TRUE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
/obj/item/clothing/under/fallout/ncr/verb/adjust_mask()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/fallout/ncr)
		return
	else
		if (maskup)
			if (!rolled)
				worn_state = "ncr_fatigues"
				item_state = "ncr_fatigues"
				icon_state = "ncr_fatigues"
				item_state_slots["w_uniform"] = "ncr_fatigues"
				usr << "<span class = 'danger'>You lower your mask.</span>"
				maskup = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			else
				worn_state = "ncr_fatigues_rolled"
				item_state = "ncr_fatigues_rolled"
				icon_state = "ncr_fatigues_rolled"
				item_state_slots["w_uniform"] = "ncr_fatigues_rolled"
				usr << "<span class = 'danger'>You lower your mask.</span>"
				maskup = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
		else
			if (!rolled)
				worn_state = "ncr_fatigues_maskup"
				item_state = "ncr_fatigues_maskup"
				icon_state = "ncr_fatigues_maskup"
				item_state_slots["w_uniform"] = "ncr_fatigues_maskup"
				usr << "<span class = 'danger'>You raise your mask.</span>"
				maskup = TRUE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return
			else
				worn_state = "ncr_fatigues_maskup_rolled"
				item_state = "ncr_fatigues_maskup_rolled"
				icon_state = "ncr_fatigues_maskup_rolled"
				item_state_slots["w_uniform"] = "ncr_fatigues_maskup_rolled"
				usr << "<span class = 'danger'>You raise your mask.</span>"
				maskup = TRUE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return

/obj/item/clothing/under/fallout/ncr/New()
	..()
	update_clothing_icon()

/obj/item/clothing/shoes/heavyboots/wrappedboots/ncr
	name = "NCR wrapped boots"
	icon_state = "ncr_boots"
	armor = list(melee = 20, arrow = 10, gun = FALSE, energy = 25, bomb = 10, bio = 10, rad = 40)

/obj/item/clothing/gloves/fingerless/ncr
	name = "hand wraps"
	icon_state = "ncr_handwraps"
	item_state = "ncr_handwraps"

/obj/item/clothing/suit/armor/fallout/ncr
	name = "NCR Trooper Armor"
	desc = "An NCR Armored Vest"
	icon_state = "ncr_armor"
	item_state = "ncr_armor"
	worn_state = "ncr_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 40, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	flammable = TRUE
	slowdown = 0.1

/obj/item/clothing/head/helmet/fallout/ncr
	name = "Trooper Helmet"
	desc = "A typical rounded steel helmet."
	icon_state = "ncr_helmet"
	item_state = "ncr_helmet"
	worn_state = "ncr_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/fallout/ncr/goggles
	name = "Goggles Helmet"
	desc = "A typical rounded steel helmet. This one has a pair of biker goggles attached."
	icon_state = "ncr_helmet_goggles"
	item_state = "ncr_helmet_goggles"
	worn_state = "ncr_helmet_goggles"
	var/goggles = FALSE

/obj/item/clothing/head/helmet/fallout/ncr/goggles/verb/adjust_goggles()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/fallout/ncr/goggles)
		return
	else
		if (goggles)
			item_state = "ncr_helmet_goggles"
			worn_state = "ncr_helmet_goggles"
			item_state_slots["slot_head"] = "ncr_helmet_goggles"
			usr << "<span class = 'danger'>You adjust your goggles.</span>"
			goggles = FALSE
		else if (!goggles)
			item_state = "ncr_helmet_goggles_down"
			worn_state = "ncr_helmet_goggles_down"
			item_state_slots["slot_head"] = "ncr_helmet_goggles_down"
			usr << "<span class = 'danger'>You adjust your goggles.</span>"
			goggles = TRUE
	update_clothing_icon()

/obj/item/clothing/head/helmet/fallout/ncr/goggles/down
	goggles = TRUE

/obj/item/clothing/head/helmet/fallout/ncr/goggles/down/New()
	..()
	update_clothing_icon()

/obj/item/weapon/storage/belt/fallout/ncr
	name = "NCR Trooper belt"
	desc = "A belt that can hold gear like pistols, ammo and other things."
	icon_state = "ncr_belt"
	item_state = "ncr_belt"
	storage_slots = 12
	max_w_class = 3
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/handcuffs,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		/obj/item/weapon/melee/classic_baton,
		/obj/item/weapon/material,
		/obj/item/flashlight,
		/obj/item/weapon/whistle
		)
/obj/item/weapon/storage/belt/fallout/ncr
/obj/item/weapon/storage/belt/fallout/ncr/New()
	..()
	for (var/i=1, i<=6, i++)
		new /obj/item/ammo_magazine/service_rifle(src)
	new /obj/item/weapon/attachment/bayonet(src)
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/us(src)
