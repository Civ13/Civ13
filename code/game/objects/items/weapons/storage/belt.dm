/obj/item/weapon/storage/belt
	name = "belt"
	desc = "Can hold various things."
	icon = 'icons/obj/clothing/belts.dmi'
	icon_state = "utilitybelt"
	item_state = "utility"
	storage_slots = 7
	max_w_class = 3
	max_storage_space = 28
	slot_flags = SLOT_BELT
	attack_verb = list("whipped", "lashed", "disciplined")

	var/show_above_suit = FALSE
	var/obj/item/weapon/storage/belt/keychain/keychain = null

/obj/item/weapon/storage/belt/verb/toggle_layer()
	set name = "Switch Belt Layer"
	set category = null

	if (show_above_suit == -1)
		usr << "<span class='notice'>\The [src] cannot be worn above your suit!</span>"
		return
	show_above_suit = !show_above_suit
	update_icon()

/obj/item/weapon/storage/update_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_belt()


/obj/item/weapon/storage/belt/utility
	name = "tool-belt" //Carn: utility belt is nicer, but it bamboozles the text parsing.
	desc = "Can hold various tools."
	icon_state = "utilitybelt"
	item_state = "utility"
	can_hold = list(
		///obj/item/weapon/combitool,
		/obj/item/weapon/crowbar/prybar,
		/obj/item/weapon/hammer,
		/obj/item/weapon/wirecutters/boltcutters,
		/obj/item/weapon/wrench,
		/obj/item/flashlight,
		/obj/item/weapon/material/minihoe,
		/obj/item/weapon/material/hatchet,
		)


/obj/item/weapon/storage/belt/utility/full/New()
	..()
	new /obj/item/weapon/hammer(src)
	new /obj/item/weapon/wrench(src)
	new /obj/item/weapon/crowbar/prybar(src)
	new /obj/item/weapon/wirecutters/boltcutters(src)


/obj/item/weapon/storage/belt/security/tactical
	name = "combat belt"
	desc = "Can hold security gear like handcuffs and flashes, with more pouches for more storage."
	icon_state = "swatbelt"
	item_state = "swatbelt"
	storage_slots = 9

/obj/item/weapon/storage/belt/leather
	name = "leather satchel"
	desc = "Can hold some small stuff, like utensils, seeds, and food."
	icon_state = "belt_satchel"
	item_state = "belt_holster"
	storage_slots = 9
	max_w_class = 2

/obj/item/weapon/storage/belt/leather/farmer
	..()
/obj/item/weapon/storage/belt/leather/farmer/New()
	..()
	new /obj/item/farming/seeds/tomato(src)
	new /obj/item/farming/seeds/tomato(src)
	new /obj/item/farming/seeds/potato(src)
	new /obj/item/farming/seeds/potato(src)
	new /obj/item/farming/seeds/potato(src)
	new /obj/item/farming/seeds/hemp(src)