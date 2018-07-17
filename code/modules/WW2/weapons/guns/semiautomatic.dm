/obj/item/weapon/gun/projectile/semiautomatic

	// pistol accuracy, rifle skill & decent KD chance
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 73,
			SHORT_RANGE_MOVING = 48,

			MEDIUM_RANGE_STILL = 63,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 53,
			LONG_RANGE_MOVING = 35,

			VERY_LONG_RANGE_STILL = 43,
			VERY_LONG_RANGE_MOVING = 28),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 78,
			SHORT_RANGE_MOVING = 51,

			MEDIUM_RANGE_STILL = 68,
			MEDIUM_RANGE_MOVING = 45,

			LONG_RANGE_STILL = 58,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 48,
			VERY_LONG_RANGE_MOVING = 32),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 48,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 42,

			VERY_LONG_RANGE_STILL = 53,
			VERY_LONG_RANGE_MOVING = 35),
	)

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_MEDIUM
	stat = "rifle"
	load_delay = 5
	aim_miss_chance_divider = 2.50

	headshot_kill_chance = 35
	KO_chance = 30

	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/semiautomatic/handle_post_fire()
	..()

	if (istype(src, /obj/item/weapon/gun/projectile/semiautomatic/stg) || istype(src, /obj/item/weapon/gun/projectile/semiautomatic/fg42))
		return

	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/semiautomatic/svt
	name = "SVT-40"
	desc = "Soviet semi-automatic rifle chambered in 7.62x54mmR. Used by some guard units and defense units."
	icon_state = "svt"
	item_state = "svt-mag"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	slot_flags = SLOT_BACK
	magazine_type = /obj/item/ammo_magazine/mosin
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)

	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	force = 10
	throwforce = 20

/obj/item/weapon/gun/projectile/semiautomatic/svt/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "svt"
		item_state = "svt-mag"
	else
		icon_state = "svt"
		item_state = "svt-mag"
	return

/obj/item/weapon/gun/projectile/semiautomatic/g41
	name = "Gewehr 41"
	desc = "German semi-automatic rifle using 7.92x57mm Mauser ammunition in a 10 round magazine. Devastating rifle."
	icon_state = "g41"
	item_state = "g41"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a792x57"
//	origin_tech = "combat=4;materials=2"
	slot_flags = SLOT_BACK
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/kar98k
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/semiautomatic/g41/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "g41"
		item_state = "g41"
	else
		icon_state = "g41"
		item_state = "g41"
	return

/obj/item/weapon/gun/projectile/semiautomatic/m1garand
	name = "M1 Garand"
	desc = "American semi-automatic rifle, standard-issue to Army units. Carries 8 30-06 rounds."
	icon_state = "M1Garand"
	item_state = "m1garand"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 8
	caliber = "c762x63"
//	origin_tech = "combat=4;materials=2"
	slot_flags = SLOT_BACK
	ammo_type = /obj/item/ammo_casing/c762x63
	magazine_type = /obj/item/ammo_magazine/c762x63
	weight = 4.3
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/semiautomatic/m1garand/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "M1Garand"
		item_state = "m1garand"
	else
		icon_state = "M1Garand"
		item_state = "m1garand"
	return

/obj/item/weapon/gun/projectile/semiautomatic/fg42
	name = "FG42"
	desc = "German assault rifle with a 20 round magazine, it is chambered in 7.92x57mm. Luftwaffe's elite weapon."
	icon_state = "fg42"
	item_state = "fg42"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK
	w_class = 4
	caliber = "7.92x57mm"
	magazine_type = /obj/item/ammo_magazine/c792x57_fg42
	ammo_type = /obj/item/ammo_casing/c792x57_fg42
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL|ATTACH_SCOPE

	firemodes = list(
		list(name="semi automatic",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.6)),
		list(name="short bursts",	burst=3, burst_delay=1.0, move_delay=3, dispersion = list(0.4, 0.8, 0.8, 0.8, 1.0)),
		list(name="long bursts",	burst=5, burst_delay=1.2, move_delay=4, dispersion = list(0.6, 1.0, 1.0, 1.0, 1.2)),
		)


/obj/item/weapon/gun/projectile/semiautomatic/fg42/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "fg42"
		item_state = "fg42"
	else
		icon_state = "fg42"
		item_state = "fg42"
	return

/obj/item/weapon/gun/projectile/semiautomatic/bar
	name = "M1918 BAR"
	desc = "An american Light Machine Gun. Uses 30-06 rounds."
	icon_state = "bar"
	item_state = "dp0"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK
	w_class = 4
	caliber = "c762x63_smg"
	magazine_type = /obj/item/ammo_magazine/c762x63_smg
	ammo_type = /obj/item/ammo_casing/c762x63_smg
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

	firemodes = list(
		list(name="semi automatic",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.6)),
		list(name="short bursts",	burst=3, burst_delay=1.0, move_delay=3, dispersion = list(0.4, 0.8, 0.8, 0.8, 1.0)),
		list(name="long bursts",	burst=4, burst_delay=1.2, move_delay=4, dispersion = list(0.6, 1.0, 1.0, 1.0, 1.2)),
		)


/obj/item/weapon/gun/projectile/semiautomatic/bar/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "bar"
		item_state = "bar"
	else
		icon_state = "bar0"
		item_state = "bar0"
	return

/obj/item/weapon/gun/projectile/semiautomatic/type99
	name = "Type 99 LMG"
	desc = "A japanese Light Machine Gun. Uses 7.7x58mm arisaka rounds."
	icon_state = "type99"
	item_state = "type99"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK
	w_class = 4
	caliber = "c77x58_smg"
	magazine_type = /obj/item/ammo_magazine/c77x58_smg
	ammo_type = /obj/item/ammo_casing/c77x58_smg
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL

	firemodes = list(
		list(name="semi automatic",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.6)),
		list(name="short bursts",	burst=3, burst_delay=1.0, move_delay=3, dispersion = list(0.4, 0.8, 0.8, 0.8, 1.0)),
		list(name="long bursts",	burst=4, burst_delay=1.2, move_delay=4, dispersion = list(0.6, 1.0, 1.0, 1.0, 1.2)),
		)


/obj/item/weapon/gun/projectile/semiautomatic/type99/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "type99"
		item_state = "type99"
	else
		icon_state = "type990"
		item_state = "type990"
	return

/obj/item/weapon/gun/projectile/semiautomatic/stg
	name = "MP-43/B"
	desc = "German assault rifle chambered in 7.92x33mm Kurz, 30 round magazine. Variant of the STG-44, issued to SS, usually."
	icon_state = "stg"
	item_state = "stg"
	load_method = MAGAZINE
	slot_flags = SLOT_BACK|SLOT_BELT
	w_class = 4
	caliber = "a792x33"
	fire_sound = 'sound/weapons/stg.ogg'
	load_magazine_sound = 'sound/weapons/stg_reload.ogg'
	magazine_type = /obj/item/ammo_magazine/a762/akm
	weight = 4.6

	firemodes = list(
		list(name="semi automatic",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.4, 0.4, 0.4, 0.6)),
		list(name="short bursts",	burst=3, burst_delay=1.0, move_delay=3, dispersion = list(0.6, 1.0, 1.0, 1.0, 1.2)),
		list(name="long bursts",	burst=5, burst_delay=1.2, move_delay=4, dispersion = list(1.0, 1.4, 1.4, 1.4, 1.6)),
		)

	sel_mode = 2

/obj/item/weapon/gun/projectile/semiautomatic/stg/update_icon()
	if (ammo_magazine)
		icon_state = "stg"
/*		if (wielded)
			item_state = "stg-w"
		else
			item_state = "stg"*/
	else
		icon_state = "stg0"
/*		if (wielded)
			item_state = "stg-w"
		else
			item_state = "stg0"*/
	update_held_icon()
	return