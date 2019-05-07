/obj/item/weapon/gun/projectile/submachinegun
	force = 10
	throwforce = 20
	fire_sound = 'sound/weapons/smg.ogg'
	var/base_icon = "smg"
	// more accuracy than MGs, less than everything else
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 49,
			SHORT_RANGE_MOVING = 39,

			MEDIUM_RANGE_STILL = 39,
			MEDIUM_RANGE_MOVING = 31,

			LONG_RANGE_STILL = 14,
			LONG_RANGE_MOVING = 11,

			VERY_LONG_RANGE_STILL = 7,
			VERY_LONG_RANGE_MOVING = 6),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 59,
			SHORT_RANGE_MOVING = 47,

			MEDIUM_RANGE_STILL = 39,
			MEDIUM_RANGE_MOVING = 31,

			LONG_RANGE_STILL = 16,
			LONG_RANGE_MOVING = 13,

			VERY_LONG_RANGE_STILL = 9,
			VERY_LONG_RANGE_MOVING = 7),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 79,
			SHORT_RANGE_MOVING = 63,

			MEDIUM_RANGE_STILL = 59,
			MEDIUM_RANGE_MOVING = 47,

			LONG_RANGE_STILL = 39,
			LONG_RANGE_MOVING = 31,

			VERY_LONG_RANGE_STILL = 16,
			VERY_LONG_RANGE_MOVING = 13),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_VERY_LOW
	stat = "mg"
	w_class = 3
/obj/item/weapon/gun/projectile/submachinegun/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/New()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/submachinegun/mp40
	name = "MP40"
	desc = "German submachinegun chambered in 9x19 Parabellum, with a 32 magazine magazine layout. Standard issue amongst most troops."
	icon_state = "mp40"
	item_state = "mp40"
	base_icon = "mp40"
	weight = 3.97
	caliber = "a9x19"
	fire_sound = 'sound/weapons/mp40.ogg'
	magazine_type = /obj/item/ammo_magazine/mp40
	full_auto = TRUE
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.4, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
	effectiveness_mod = 1.05


/obj/item/weapon/gun/projectile/submachinegun/ppsh
	name = "PPSh-41"
	desc = "Soviet submachinegun with a very large drum magazine. Chambered in 7.62x25mm Tokarev."
	icon_state = "ppsh"
	item_state = "ppsh"
	base_icon = "ppsh"
	caliber = "a762x25"
	magazine_type = /obj/item/ammo_magazine/c762x25_ppsh
	weight = 3.63
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, recoil=0.4, move_delay=2, dispersion = list(0.5, 0.7, 0.7, 0.7, 0.9)),
		list(name="full auto",	burst=1, burst_delay=1.2, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/pps
	name = "PPS-43"
	desc = "Soviet submachine gun chambered in 7.62x25mm Tokarev."
	icon_state = "pps"
	item_state = "pps"
	base_icon = "pps"
	caliber = "a762x25"
	full_auto = TRUE
	magazine_type = /obj/item/ammo_magazine/c762x25_pps
	weight = 3.04
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5)),
		)

	sel_mode = 1
