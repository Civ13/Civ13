/obj/item/weapon/gun/projectile/submachinegun
	force = 10
	throwforce = 20

	// more accuracy than MGs, less than everything else
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

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_LOW
	stat = "SMG"

/obj/item/weapon/gun/projectile/submachinegun/mp40
	name = "MP-40"
	desc = "German submachinegun chambered in 9x19 Parabellum, with a 32 magazine magazine layout. Standard issue amongst most troops."
	icon_state = "mp40"
	item_state = "mp40"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	weight = 3.97
	caliber = "9x19mm"
	magazine_type = /obj/item/ammo_magazine/mp40

	firemodes = list(
		list(name="single shot",	burst=1, burst_delay=1.0, recoil=0.4, move_delay=2, dispersion = list(0.4, 0.6, 0.6, 0.6, 0.8)),
		list(name="short bursts",	burst=3, burst_delay=1.2, recoil=0.7, move_delay=3, dispersion = list(0.8, 1.2, 1.2, 1.2, 1.4)),
		list(name="long bursts",	burst=6, burst_delay=1.4, recoil=0.9, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.6)),
		)

	sel_mode = 2
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/submachinegun/mp40/update_icon()
	if (ammo_magazine)
		icon_state = "mp40"
/*		if (wielded)
			item_state = "mp40-w"
		else
			item_state = "mp40"*/
	else
		icon_state = "mp400"
/*		if (wielded)
			item_state = "mp40-w"
		else
			item_state = "mp400"*/
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/ppsh
	name = "PPSh-41"
	desc = "Soviet submachinegun with a very large drum magazine. Capable of bringing many targets down in Stalin's name."
	icon_state = "ppsh"
	item_state = "ppsh"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	fire_sound = 'sound/weapons/m16.ogg'
	caliber = "a762x25"
	magazine_type = /obj/item/ammo_magazine/a556/ppsh
	weight = 3.63
	firemodes = list(
		list(name="single shot",	burst=1, burst_delay=0.8, recoil=0.4, move_delay=2, dispersion = list(0.5, 0.7, 0.7, 0.7, 0.9)),
		list(name="short bursts",	burst=4, burst_delay=1.0, recoil=0.6, move_delay=3, dispersion = list(1.0, 1.4, 1.4, 1.4, 1.6)),
		list(name="long bursts",	burst=8, burst_delay=1.2, recoil=0.8, move_delay=4, dispersion = list(1.4, 1.6, 1.6, 1.6, 1.8)),
		)

//	can_wield = TRUE

	sel_mode = 2

/obj/item/weapon/gun/projectile/submachinegun/ppsh/update_icon()
	if (ammo_magazine)
		icon_state = "ppsh"
/*		if (wielded)
			item_state = "ppsh"
		else
			item_state = "ppsh"*/
	else
		icon_state = "ppsh_empty"
/*		if (wielded)
			item_state = "ppsh_empty"
		else
			item_state = "ppsh_empty"*/
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/pps
	name = "PPS-43"
	desc = "Russian submachine gun chambered in 7.62x25mm Tokarev."
	icon_state = "pps"
	item_state = "pps"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	//fire_sound = ''
	caliber = "7.62x25mm"
	magazine_type = /obj/item/ammo_magazine/c762x25mm_pps
	weight = 3.04
	firemodes = list(
		list(name="short bursts",	burst=3, burst_delay=1.0, recoil=0.6, move_delay=3, dispersion = list(0.9, 1.3, 1.3, 1.3, 1.5)),
		list(name="long bursts",	burst=6, burst_delay=1.2, recoil=0.8, move_delay=4, dispersion = list(1.4, 1.6, 1.6, 1.6, 1.8)),
		)

//	can_wield = TRUE

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/pps/update_icon()
	if (ammo_magazine)
		icon_state = "pps"
	else
		icon_state = "pps0"
	return

/obj/item/weapon/gun/projectile/submachinegun/stenmk2
	name = "Sten MKII"
	desc = "British submachine gun chambered in 9x19mm."
	icon_state = "sten"
	item_state = "sten"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	//fire_sound = '' // TO DO
	caliber = "9x19mm"
	magazine_type = /obj/item/ammo_magazine/mp40/c9x19mm_stenmk2
	weight = 3.2
	firemodes = list(
//		list(name="single shot",	burst=1, burst_delay=0.8, recoil=0.4, move_delay=2, dispersion = list(0.6, 0.8, 0.8, 0.8, 1.0)),
		list(name="short burst",	burst=3, burst_delay=1.2, recoil=0.4, move_delay=3, dispersion = list(1.0, 1.4, 1.4, 1.4, 1.6)),
		list(name="long burst", 	burst=6, burst_delay=1.6, recoil=0.8, move_delay=4, dispersion = list(1.5, 1.7, 1.7, 1.7, 1.9)),
		)

//	can_wield = TRUE

	sel_mode = 1

/obj/item/weapon/gun/projectile/submachinegun/stenmk2/update_icon()
	if (ammo_magazine)
		icon_state = "sten"
	else
		icon_state = "sten0"
	return

/obj/item/weapon/gun/projectile/submachinegun/modello38
	name = "Modello 38"
	desc = "Full name MAB 38 'Moschetto Automatico Modello 1938', a standard issue submachine gun used by the Royal Italian Army. You can feel the power of meatballs in your side."
	icon_state = "model38"
	item_state = "model38"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	caliber = "9x19mm"
	magazine_type = /obj/item/ammo_magazine/s9x19mm
	weight = 4.2
	firemodes = list(
		list(name="short burst",	burst=3, burst_delay=1.0, recoil=0.6, move_delay=3, dispersion = list(0.8, 1.2, 1.2, 1.2, 1.4)),
		list(name="long burst", 	burst=6, burst_delay=1.4, recoil=1.2, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.6)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/modello38/update_icon()
	if (ammo_magazine)
		icon_state = "model38"
		item_state = "model38"
	else
		icon_state = "model380"
		item_state = "model380"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/type100
	name = "Type 100"
	desc = "The standard Japanese SMG."
	icon_state = "type100"
	item_state = "model1380"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	caliber = "c8mmnambu_smg"
	magazine_type = /obj/item/ammo_magazine/c8mmnambu_smg
	weight = 4.2
	firemodes = list(
		list(name="short burst",	burst=3, burst_delay=1.0, recoil=0.6, move_delay=3, dispersion = list(0.8, 1.2, 1.2, 1.2, 1.4)),
		list(name="long burst", 	burst=6, burst_delay=1.4, recoil=1.2, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.6)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/type100/update_icon()
	if (ammo_magazine)
		icon_state = "type100"
		item_state = "type100"
	else
		icon_state = "type1000"
		item_state = "type1000"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/grease
	name = "Grease gun"
	desc = "A small, simple SMG issued to some US troops."
	icon_state = "greasegun"
	item_state = "greasegun"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	caliber = "c45_smg"
	magazine_type = /obj/item/ammo_magazine/c45_smg
	weight = 3.7
	firemodes = list(
		list(name="short burst",	burst=3, burst_delay=1.0, recoil=0.6, move_delay=3, dispersion = list(0.8, 1.2, 1.2, 1.2, 1.4)),
		list(name="long burst", 	burst=6, burst_delay=1.4, recoil=1.2, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.6)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/grease/update_icon()
	if (ammo_magazine)
		icon_state = "greasegun"
		item_state = "greasegun"
	else
		icon_state = "greasegun0"
		item_state = "greasegun0"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/submachinegun/thompson
	name = "Thompson M1A1"
	desc = "Used by both gangsters and law enforcement, the Thompson SMG is the standard-issue SMG of the US Army."
	icon_state = "thompson"
	item_state = "thompson"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 3
	caliber = "c45_smg"
	magazine_type = /obj/item/ammo_magazine/c45_smg
	weight = 4.2
	firemodes = list(
		list(name="short burst",	burst=3, burst_delay=1.0, recoil=0.9, move_delay=3, dispersion = list(0.8, 1.2, 1.2, 1.2, 1.4)),
		list(name="long burst", 	burst=6, burst_delay=1.4, recoil=1.8, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.6)),
		)
	sel_mode = 1
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

/obj/item/weapon/gun/projectile/submachinegun/thompson/update_icon()
	if (ammo_magazine)
		icon_state = "thompson"
		item_state = "thompson"
	else
		icon_state = "thompson0"
		item_state = "thompson0"
	update_held_icon()
	return
