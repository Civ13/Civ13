/obj/item/weapon/gun/projectile/submachinegun/ak101
	name = "AK-101"
	desc = "A modern Russian AK variant, chambered in NATO 5.56x45mm."
	icon_state = "ak101"
	item_state = "ak101"
	base_icon = "ak101"
	weight = 3.6
	var/folded = FALSE
	effectiveness_mod = 1.11
	caliber = "a556x45"
	icon = 'icons/obj/guns/assault_rifles.dmi'
	fire_sound = 'sound/weapons/guns/fire/AKM.ogg'
	magazine_type = /obj/item/ammo_magazine/ak101
	good_mags = list(/obj/item/ammo_magazine/ak101, /obj/item/ammo_magazine/ak101/drum)
	equiptimer = 15
	firemodes = list(
		list(name = "semi auto",	burst=1, burst_delay=0.7, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0, 0.1, 0.2)),
		list(name = "full auto",	burst=1, burst_delay=1.2, recoil=0, move_delay=4, dispersion = list(1.1, 1.2, 1.2, 1.3, 1.4)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_ADV_SCOPE|ATTACH_UNDER|ATTACH_BARREL
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 65,
			SHORT_RANGE_MOVING = 54,

			MEDIUM_RANGE_STILL = 54,
			MEDIUM_RANGE_MOVING = 44,

			LONG_RANGE_STILL = 33,
			LONG_RANGE_MOVING = 18,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 84,
			SHORT_RANGE_MOVING = 75,

			MEDIUM_RANGE_STILL = 66,
			MEDIUM_RANGE_MOVING = 57,

			LONG_RANGE_STILL = 47,
			LONG_RANGE_MOVING = 33,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 6),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 94,
			SHORT_RANGE_MOVING = 83,

			MEDIUM_RANGE_STILL = 78,
			MEDIUM_RANGE_MOVING = 70,

			LONG_RANGE_STILL = 59,
			LONG_RANGE_MOVING = 46,

			VERY_LONG_RANGE_STILL = 38,
			VERY_LONG_RANGE_MOVING = 26),
	)

/obj/item/weapon/gun/projectile/submachinegun/ak101/update_icon()
	var/temp_state = base_icon
	if (folded)
		temp_state = "[base_icon]_folded"
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[temp_state]_scope_open"
			return
		else
			icon_state = "[temp_state]_scope"
			return
	else
		var/obj/item/ammo_magazine/MAG
		if (ammo_magazine && istype(MAG, /obj/item/ammo_magazine/ak101/drum))
			icon_state = "[temp_state]_drum"
			item_state = temp_state
		else if (ammo_magazine && !istype(MAG, /obj/item/ammo_magazine/ak101/drum))
			icon_state = temp_state
			item_state = temp_state
		else
			icon_state = "[temp_state]_open"
			item_state = "[temp_state]_open"
	update_held_icon()

	return

/obj/item/weapon/gun/projectile/submachinegun/ak101/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr
	if (folded)
		folded = FALSE
		usr << "You extend the stock on \the [src]."
		equiptimer = 15
		set_stock()
		update_icon()
	else
		folded = TRUE
		usr << "You collapse the stock on \the [src]."
		equiptimer = 7
		set_stock()
		update_icon()

/obj/item/weapon/gun/projectile/submachinegun/ak101/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod *= 0.85
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod /= 0.85


/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102
	name = "AK-102"
	desc = "A modern Russian AK variant, chambered in NATO 5.56x45mm. This is a carbine version of the AK-101."
	icon_state = "ak101"
	item_state = "ak74m"
	base_icon = "ak101"
	weight = 3
	effectiveness_mod = 1.09
	magazine_type = /obj/item/ammo_magazine/ak101
	good_mags = list(/obj/item/ammo_magazine/ak101, /obj/item/ammo_magazine/ak101/drum)
	equiptimer = 12

/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103
	name = "AK-103"
	desc = "A modern Russian AK variant, chambered in 7.62x39mm."
	icon_state = "ak101"
	item_state = "ak101"
	base_icon = "ak101"
	weight = 3.6
	effectiveness_mod = 1.08
	caliber = "a762x39"
	magazine_type = /obj/item/ammo_magazine/ak47
	good_mags = list(/obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/drum)
	equiptimer = 15

/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/ak104
	name = "AK-104"
	desc = "A modern Russian AK variant, chambered in 7.62x39mm. This is a carbine version of the AK-103."
	icon_state = "ak101"
	item_state = "ak74m"
	base_icon = "ak101"
	weight = 3.2
	effectiveness_mod = 1.07
	equiptimer = 12

/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105
	name = "AK-105"
	desc = "A modern Russian AK variant, chambered in 5.45x39mm. This is a carbine version of the AK-74M."
	icon_state = "ak101"
	item_state = "ak74m"
	base_icon = "ak101"
	caliber = "a545x39"
	weight = 3.2
	effectiveness_mod = 1.12
	equiptimer = 12
	magazine_type = /obj/item/ammo_magazine/ak74
	good_mags = list(/obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak74/drum)

