/obj/item/weapon/gun/projectile/heavy
	gun_type = GUN_TYPE_HEAVY
	// mg accuracy now - Kachnov
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 30,
			SHORT_RANGE_MOVING = 27,

			MEDIUM_RANGE_STILL = 21,
			MEDIUM_RANGE_MOVING = 19,

			LONG_RANGE_STILL = 11,
			LONG_RANGE_MOVING = 10,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 38,
			SHORT_RANGE_MOVING = 34,

			MEDIUM_RANGE_STILL = 30,
			MEDIUM_RANGE_MOVING = 27,

			LONG_RANGE_STILL = 23,
			LONG_RANGE_MOVING = 21,

			VERY_LONG_RANGE_STILL = 11,
			VERY_LONG_RANGE_MOVING = 10),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 45,
			SHORT_RANGE_MOVING = 41,

			MEDIUM_RANGE_STILL = 38,
			MEDIUM_RANGE_MOVING = 34,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 15,
			VERY_LONG_RANGE_MOVING = 14),
	)

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "heavyweapon"

/obj/item/weapon/gun/projectile/heavy/ptrd
	name = "PTRD anti-tank rifle"
	desc = "A portable anti-armour rifle. Uses 14.5mm shells."
	icon_state = "ptrd"
	item_state = "l6closednomag" //placeholder
	w_class = 4
	force = 10
	slot_flags = SLOT_BACK
	caliber = "14.5mm"
	recoil = 3 //extra kickback
	fire_sound = 'sound/weapons/WW2/ptrd_fire.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	max_shells = TRUE
	ammo_type = /obj/item/ammo_casing/a145

	firemodes = list(
		list(name="single shot",	burst=1, move_delay=4, fire_delay=10, dispersion = list(0))
		)


/obj/item/weapon/gun/projectile/heavy/ptrd/german
	name = "14.5mm PaB 783"

/obj/item/weapon/gun/projectile/heavy/ptrd/update_icon()
	if (bolt_open)
		icon_state = "ptrd"
	else
		icon_state = "ptrd"


/obj/item/weapon/gun/projectile/heavy/mk12
	name = "\improper MK12"
	desc = "Heavy scoped rifle."
	icon_state = "mk12_loaded"
	item_state = "mk12_loaded"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK
	w_class = 5
	caliber = "a556x45"
	magazine_type = /obj/item/ammo_magazine/a556x45

	firemodes = list(
		list(name="single shot",	burst=1, move_delay=4, fire_delay=10, dispersion = list(0))
		)

/obj/item/weapon/gun/projectile/heavy/mk12/update_icon()
	if (ammo_magazine)
		icon_state = "mk12_loaded"
/*		if (wielded)
			item_state = "mk12_loaded_wielded"
		else
			item_state = "mk12_loaded"*/
	else
		icon_state = "mk12_empty"
	/*	if (wielded)
			item_state = "mk12_empty_wielded"
		else
			item_state = "mk12_empty"*/
	update_held_icon()
	return

