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

/obj/item/weapon/storage/belt/press
	name = "press belt"

/obj/item/weapon/storage/belt/press/New()
	..()
	new /obj/item/weapon/pen(src)
	new /obj/item/camera_film(src)
	new /obj/item/camera_film(src)
	new /obj/item/weapon/clipboard/full(src)
	new /obj/item/weapon/reagent_containers/spray/pepper(src)
	new /obj/item/camera/coldwar(src)
	new /obj/item/weapon/storage/box/firstaid/advsmall(src)
	new /obj/item/weapon/telephone/mobile(src)

/obj/item/weapon/storage/belt/tactical
	name = "combat belt"
	storage_slots = 8
	max_w_class = 3
	max_storage_space = 28

/obj/item/weapon/storage/belt/security
	name = "security belt"
	icon_state = "security"
	item_state = "security"
	storage_slots = 9
	max_w_class = 3
	max_storage_space = 34

/obj/item/weapon/storage/belt/medical
	name = "medical belt"
	can_hold = list(
		/obj/item/stack/medical,
		/obj/item/weapon/storage/pill_bottle,
		/obj/item/weapon/doctor_handbook,
		/obj/item/weapon/surgery,
		)

/obj/item/weapon/storage/belt/medical/full_vc/New()
	..()
	new /obj/item/stack/medical/bruise_pack/bint/medic(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/advanced/sulfa(src)
	new /obj/item/stack/medical/splint(src)
	new /obj/item/weapon/doctor_handbook(src)
	new /obj/item/weapon/storage/pill_bottle/pervitin(src)

/obj/item/weapon/storage/belt/medical/full_us/New()
	..()
	new /obj/item/stack/medical/bruise_pack/bint/medic(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/splint(src)
	new /obj/item/weapon/doctor_handbook(src)
	new /obj/item/weapon/storage/pill_bottle/tramadol(src)


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
		/obj/item/weapon/material/thrown/kunai_normal,
		/obj/item/weapon/material/thrown/throwing_knife,
		/obj/item/weapon/material/thrown/tomahawk,
		/obj/item/weapon/material/thrown/throwing_axe,
		/obj/item/weapon/fire_extinguisher,
		/obj/item/flashlight/flashlight,
		/obj/item/weapon/weldingtool,
		/obj/item/weapon/material/shovel/trench)

/obj/item/weapon/storage/belt/utility/sapper/New()
	..()
	new /obj/item/weapon/wrench(src)
	new /obj/item/weapon/crowbar/prybar(src)
	new /obj/item/weapon/weldingtool(src)
	new /obj/item/weapon/wirecutters/boltcutters(src)
	new /obj/item/weapon/hammer(src)
	new /obj/item/weapon/material/shovel(src)
	new /obj/item/weapon/material/shovel/trench(src)

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

/obj/item/weapon/storage/belt/leather/shaman
	storage_slots = 6
	max_w_class = 3
	max_storage_space = 12
	show_above_suit = TRUE

/obj/item/weapon/storage/belt/leather/shaman/New()
	..()
	new /obj/item/weapon/reagent_containers/food/snacks/grown/peyote(src)
	new /obj/item/flashlight/torch(src)
	new /obj/item/stack/medical/bruise_pack/bint/leather(src)
	new /obj/item/stack/material/rope(src)
	new /obj/item/weapon/material/handle(src)
	new /obj/item/weapon/material/kitchen/utensil/knife/bone(src)

/obj/item/weapon/storage/belt/leather/occinn

/obj/item/weapon/storage/belt/leather/occinn/New()
	..()
	new /obj/item/weapon/key/civ/inn(src)
	new /obj/item/weapon/key/civ/room1(src)
	new /obj/item/weapon/key/civ/room2(src)
	new /obj/item/weapon/key/civ/room3(src)
	new /obj/item/weapon/key/civ/room4(src)
	new /obj/item/weapon/storage/belt/keychain(src)


/obj/item/weapon/storage/belt/leather/farmer/New()
	..()
	new /obj/item/stack/farming/seeds/tomato(src)
	new /obj/item/stack/farming/seeds/potato(src)
	new /obj/item/stack/farming/seeds/hemp(src)
	new /obj/item/stack/farming/seeds/flax(src)

/obj/item/weapon/storage/belt/gator_belt //doesn't hold anything
	name = "alligator scale belt"
	desc = "A purely decorative alligator scale thin belt. It has no pockets or attachments for items"
	icon_state = "gator_belt"
	item_state = "gator_belt"
	storage_slots = 0
	max_w_class = 1
	max_storage_space = 0

/obj/item/weapon/storage/belt/throwing
	name = "throwing belt"
	desc = "A belt made specifically to hold throwing weapons.."
	icon_state = "belt_satchel"
	item_state = "belt_holster"
	storage_slots = 12
	max_w_class = 1
	can_hold = list(
		/obj/item/weapon/material/hatchet,
		/obj/item/weapon/material/thrown/kunai_normal,
		/obj/item/weapon/material/thrown/throwing_knife,
		/obj/item/weapon/material/thrown/tomahawk,
		/obj/item/weapon/material/thrown/throwing_axe,
		)

/obj/item/weapon/storage/belt/throwing/ninja/New()
	..()
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/star(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)
	new /obj/item/weapon/material/thrown/kunai_normal(src)