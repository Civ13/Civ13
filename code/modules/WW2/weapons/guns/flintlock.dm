//All the flintlock weapons

/obj/item/weapon/gun/projectile/flintlock
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	icon_state = "musket"
	item_state = "musket"
	w_class = 4
	force = 10
	throwforce = 20
	max_shells = 1 //duh
	slot_flags = SLOT_BACK
	caliber = "musketball"
	recoil = 3 //extra kickback
	//fire_sound = 'sound/weapons/sniper.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/musketball
//	magazine_type = /obj/item/ammo_magazine/musketball
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 5
	fire_delay = 5

	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 37,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 53,
			VERY_LONG_RANGE_MOVING = 27),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 88,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 78,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 68,
			LONG_RANGE_MOVING = 34,

			VERY_LONG_RANGE_STILL = 58,
			VERY_LONG_RANGE_MOVING = 29),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 93,
			SHORT_RANGE_MOVING = 47,

			MEDIUM_RANGE_STILL = 83,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 73,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 63,
			VERY_LONG_RANGE_MOVING = 32),
	)

	load_delay = 150 //15 seconds for rifles, 12 seconds for pistols & blunderbuss
	aim_miss_chance_divider = 3.00

	var/cocked = FALSE
	var/check_cocked = FALSE //Keeps the bolt from being interfered with
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/flintlock/attack_self(mob/user)
	if (!check_cocked)//Keeps people from spamming the bolt
		check_cocked++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_cocked--
			return
	else return
	if (!cocked)
		playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
		user << "<span class='notice'>You cock the [src]!</span>"
		cocked = TRUE
	else
		playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You uncock the [src].</span>"
		cocked = FALSE
	add_fingerprint(user)
	update_icon()
	check_cocked--

/obj/item/weapon/gun/projectile/flintlock/special_check(mob/user)
	if (!cocked)
		user << "<span class='warning'>You can't fire the [src] while the weapon is uncocked!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/flintlock/load_ammo(var/obj/item/A, mob/user)
	if (cocked)
		return
	..()

/obj/item/weapon/gun/projectile/flintlock/unload_ammo(mob/user, var/allow_dump=1)
	return
	// you cant, sorry
	..()

/obj/item/weapon/gun/projectile/flintlock/handle_post_fire()
	..()
	loaded -= chambered
	chambered = null
	cocked = FALSE
	if (last_fire != -1)
		if (world.time - last_fire <= 7)
			jamcheck += 4
		else if (world.time - last_fire <= 10)
			jamcheck += 3
		else if (world.time - last_fire <= 20)
			jamcheck += 2
		else if (world.time - last_fire <= 30)
			++jamcheck
		else if (world.time - last_fire <= 40)
			++jamcheck
		else if (world.time - last_fire <= 50)
			++jamcheck
		else
			jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/flintlock/musket
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	force = 12
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "musketball"
	weight = 6.0
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/musketball


/obj/item/weapon/gun/projectile/flintlock/musketoon
	name = "flintlock musketoon"
	desc = "A smaller version of the flintlock musket, this gun is favored by seamen due to being compact, albeit less accurate."
	icon_state = "musketoon"
	item_state = "musketoon"
	force = 8
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "musketball"
	weight = 4.0
	effectiveness_mod = 0.87
	ammo_type = /obj/item/ammo_casing/musketball

/obj/item/weapon/gun/projectile/flintlock/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	name = "flintlock pistol"
	desc = "A typical flintlock pistol. Good for short ranges, useless otherwise."
	icon_state = "flintpistol"
	item_state = "pistol"
	recoil = 2
	force = 8
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	effectiveness_mod = 1
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 120
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


/obj/item/weapon/gun/projectile/flintlock/blunderbuss
	gun_type = GUN_TYPE_SHOTGUN
	fire_sound = 'sound/weapons/guns/fire/shotgunp_fire.ogg'

	// 15% more accurate than SMGs
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 56,
			SHORT_RANGE_MOVING = 45,

			MEDIUM_RANGE_STILL = 45,
			MEDIUM_RANGE_MOVING = 36,

			LONG_RANGE_STILL = 16,
			LONG_RANGE_MOVING = 13,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 54,

			MEDIUM_RANGE_STILL = 45,
			MEDIUM_RANGE_MOVING = 36,

			LONG_RANGE_STILL = 18,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 8),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 68,
			MEDIUM_RANGE_MOVING = 54,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 36,

			VERY_LONG_RANGE_STILL = 18,
			VERY_LONG_RANGE_MOVING = 15),
	)

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	KD_chance = KD_CHANCE_HIGH
	stat = "heavy"
	name = "blunderbuss"
	desc = "A enlarged version of the musketoon, it can fire bigger bullets. Useless at long range."
	icon_state = "blunderbuss"
	item_state = "blunderbuss"
	recoil = 4
	force = 14
	load_delay = 120
	caliber = "blunderbuss"
	weight = 4.5
	effectiveness_mod = 0.7
	ammo_type = /obj/item/ammo_casing/blunderbuss