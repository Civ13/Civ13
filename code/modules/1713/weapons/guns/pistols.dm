/obj/item/weapon/gun/projectile/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	move_delay = 1
	fire_delay = 3
	item_state = "pistol"
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 40,

			MEDIUM_RANGE_STILL = 53,
			MEDIUM_RANGE_MOVING = 35,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 38,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 56,
			MEDIUM_RANGE_MOVING = 38,

			LONG_RANGE_STILL = 49,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 41,
			VERY_LONG_RANGE_MOVING = 27),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 60,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 53,
			LONG_RANGE_MOVING = 35,

			VERY_LONG_RANGE_STILL = 45,
			VERY_LONG_RANGE_MOVING = 30),
	)

	accuracy_increase_mod = 1.50
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 2.00

/obj/item/weapon/gun/projectile/pistol/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		user << "<span class = 'danger'>That won't fit on there.</span>"
		return FALSE
	else
		return ..()

<<<<<<< HEAD
/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	name = "Nagant Revolver"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	w_class = 2
	caliber = "7.62x38mmR"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	weight = 1.2

/obj/item/weapon/gun/projectile/revolver/peacemaker
	name = "Colt Peacemaker"
	desc = "Officialy the M1873 Colt Single Action Army Revolver."
	icon_state = "peacemaker"
	w_class = 2
	caliber = "a45"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	weight = 2.3

/obj/item/weapon/gun/projectile/revolver/nagant_revolver/update_icon()
	..()
	if (loaded.len)
		icon_state = "nagant"
	else
		icon_state = "nagant"
	return

=======
>>>>>>> 9a0ba04d0acfa10d9807c36282dc2b1baead9711
/obj/item/weapon/gun/projectile/pistol/nambu
	name = "Nambu Pistol"
	desc = "Standard issue Japanese pistol. Chambered in 8mm nambu ammunition."
	icon_state = "nambu"
	w_class = 2
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS

/obj/item/weapon/gun/projectile/pistol/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu"
	else
		icon_state = "nambu0"
	return
<<<<<<< HEAD

/obj/item/weapon/gun/projectile/revolver/t26_revolver
	name = "Type 26 Revolver"
	desc = "Japanese officer's revolver."
	icon_state = "t26revolver"
	w_class = 2
	caliber = "c9mm_jap_revolver"
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c9mm_jap_revolver
	weight = 0.8
	ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
	handle_casings = CYCLE_CASINGS
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	name = "Nagant Revolver"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	item_state = "nagant"
	w_class = 2
	caliber = "7.62x38"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	weight = 0.8
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/panther
	name = "Panther Revolver"
	desc = "a .44 caliber revolver."
	icon_state = "panther"
	item_state = "panther"
	w_class = 2
	caliber = "44"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c44
	weight = 0.8
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/c38
	name = ".38 Revolver"
	desc = "a .38 caliber revolver."
	icon_state = "revolver"
	item_state = "revolver"
	w_class = 2
	caliber = "38"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c38
	weight = 0.8
	load_method = SINGLE_CASING
=======
>>>>>>> 9a0ba04d0acfa10d9807c36282dc2b1baead9711
