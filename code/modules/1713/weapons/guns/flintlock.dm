//All the flintlock weapons

/obj/item/weapon/gun/projectile/flintlock
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	icon = 'icons/obj/guns/ancient.dmi'
	icon_state = "musket"
	item_state = "musket"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 2
	force = 10
	throwforce = 10
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "musketball"
	recoil = 3 //extra kickback
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/musketball
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/musket.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS | ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	gtype = "rifle"
	move_delay = 5
	fire_delay = 5
	equiptimer = 20
	maxhealth = 20
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

	load_delay = 110 //11 seconds for rifles, 8 seconds for pistols & blunderbuss
	aim_miss_chance_divider = 3.00

	var/cocked = FALSE
	var/check_cocked = FALSE //Keeps the bolt from being interfered with
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/flintlock/attack_self(mob/user)
//	var/mob/living/human/H = user
	if (!check_cocked)//Keeps people from spamming the bolt
		check_cocked++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_cocked--
			return
	else return
	if (!cocked)
		playsound(loc, 'sound/weapons/guns/interact/bolt_open.ogg', 50, TRUE)
		user << "<span class='notice'>You cock the [src]!</span>"
		cocked = TRUE
	else
		playsound(loc, 'sound/weapons/guns/interact/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You uncock the [src].</span>"
		cocked = FALSE
	add_fingerprint(user)
	update_icon()
	check_cocked--

/obj/item/weapon/gun/projectile/flintlock/special_check(mob/user)
//	var/mob/living/human/H = user
	if (!cocked)
		user << "<span class='warning'>You can't fire \the [src] while the weapon is uncocked!</span>"
		return FALSE
	if (!(user.has_empty_hand(both = FALSE)) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/duellingpistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistoletmodeleanxiii))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/flintlock/load_ammo(var/obj/item/A, mob/user)
//	var/mob/living/human/H = user
	if (cocked)
		return
	..()

/obj/item/weapon/gun/projectile/flintlock/unload_ammo(mob/user, var/allow_dump=1)
	return
	// you cant, sorry
	..()

/obj/item/weapon/gun/projectile/flintlock/handle_post_fire()
	..()
	if (max_shells == 1)
		loaded = list()
		chambered = null
	cocked = FALSE
	spawn (1)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (5)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (12)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))

/obj/item/weapon/gun/projectile/flintlock/musket
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	force = 12
	caliber = "musketball"
	weight = 6.0
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100

/obj/item/weapon/gun/projectile/flintlock/m1752
	name = "M1752 mosquete"
	desc = "A simple spanish musket of the early XVIII century."
	force = 11.5
	caliber = "musketball"
	weight = 6.0
	effectiveness_mod = 0.98
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "mosquete1752"

/obj/item/weapon/gun/projectile/flintlock/jezail
	name = "Jezail musket"
	desc = "A very simple Arabic musket of the early XVIII century."
	force = 10
	caliber = "musketball"
	weight = 5.0
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "jezail"

/obj/item/weapon/gun/projectile/flintlock/kabyle
	name = "Kabyle musket"
	desc = "A very simple North-African musket of the early XVIII century."
	force = 10.2
	caliber = "musketball"
	weight = 4.7
	effectiveness_mod = 0.93
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "moukalla"

/obj/item/weapon/gun/projectile/flintlock/brownbess
	name = "Brownbess musket"
	desc = "A simple english musket of the early XVIII century."
	force = 11
	caliber = "musketball"
	weight = 5.9
	effectiveness_mod = 0.98
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "brownbess"

/obj/item/weapon/gun/projectile/flintlock/charleville
	name = "Charleville mousquet"
	desc = "A simple french musket of the early XVIII century."
	force = 11.3
	caliber = "musketball"
	weight = 5.6
	effectiveness_mod = 0.98
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "charleville_mousquet"

/obj/item/weapon/gun/projectile/flintlock/plexico
	name = "flintlock musket"
	desc = "A finer flintlock musket, this one seems to be made out of ebony and steel."
	force = 12
	caliber = "musketball"
	weight = 6.0
	effectiveness_mod = 1.20
	ammo_type = /obj/item/ammo_casing/musketball
	value = 110
	item_state = "plexciomusket"
	icon_state = "plexciomusket"

/obj/item/weapon/gun/projectile/flintlock/springfield
	name = "Springfield M1861 Musket"
	desc = "A simple flintlock musket of the 1860's used commonly in the civil war."
	force = 12
	caliber = "musketball"
	weight = 6.0
	effectiveness_mod = 0.97
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "springfield"
	icon_state = "springfield"
	load_delay = 70

/obj/item/weapon/gun/projectile/flintlock/springfield1795
	name = "Springfield 1795 Musket"
	desc = "The Model 1795 was the first musket to be produced in the United States."
	force = 12
	caliber = "musketball"
	weight = 5.0
	effectiveness_mod = 1.09
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "springfield"
	icon_state = "springfield1795"
	load_delay = 80

/obj/item/weapon/gun/projectile/flintlock/musketoon
	name = "flintlock musketoon"
	desc = "A smaller version of the flintlock musket, this gun is favored by seamen due to being compact, albeit less accurate."
	icon_state = "compactmusket"
	item_state = "musketoon"
	force = 8
	caliber = "musketball"
	weight = 4.0
	effectiveness_mod = 0.87
	ammo_type = /obj/item/ammo_casing/musketball
	value = 80
	equiptimer = 12

/obj/item/weapon/gun/projectile/flintlock/crude
	name = "crude musket"
	desc = "A crude, homemade version of a musket. Not very reliable and accurate."
	icon_state = "crude"
	item_state = "musketoon"
	force = 8
	caliber = "musketball"
	weight = 4.0
	effectiveness_mod = 0.75
	ammo_type = /obj/item/ammo_casing/musketball
	value = 45
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

			MEDIUM_RANGE_STILL = 60,
			MEDIUM_RANGE_MOVING = 38,

			LONG_RANGE_STILL = 55,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 48,
			VERY_LONG_RANGE_MOVING = 27),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 63,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 58,
			LONG_RANGE_MOVING = 35,

			VERY_LONG_RANGE_STILL = 51,
			VERY_LONG_RANGE_MOVING = 30),
	)
/obj/item/weapon/gun/projectile/flintlock/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	name = "flintlock pistol"
	desc = "A typical flintlock pistol. Good for short ranges, useless otherwise."
	icon_state = "flintpistol"
	item_state = "pistol"
	recoil = 2
	force = 6
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	effectiveness_mod = 1
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	equiptimer = 7
	gun_type = GUN_TYPE_PISTOL
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
	stat = "heavy"
	name = "Blunderbuss"
	desc = "A enlarged version of the musketoon, it can fire bigger bullets. Useless at long range."
	icon_state = "blunderbuss"
	item_state = "blunderbuss"
	recoil = 4
	force = 14
	load_delay = 100
	caliber = "blunderbuss"
	stat = "rifle"
	weight = 4.5
	value = 80
	effectiveness_mod = 0.7
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/blunderbuss
	gun_type = GUN_TYPE_SHOTGUN
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	equiptimer = 15
	// 15% more accurate than SMGs
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 56,
			SHORT_RANGE_MOVING = 45,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 46,

			LONG_RANGE_STILL = 16,
			LONG_RANGE_MOVING = 13,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 65,
			SHORT_RANGE_MOVING = 56,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 46,

			LONG_RANGE_STILL = 18,
			LONG_RANGE_MOVING = 15,

			VERY_LONG_RANGE_STILL = 10,
			VERY_LONG_RANGE_MOVING = 8),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 91,
			SHORT_RANGE_MOVING = 72,

			MEDIUM_RANGE_STILL = 69,
			MEDIUM_RANGE_MOVING = 64,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 36,

			VERY_LONG_RANGE_STILL = 18,
			VERY_LONG_RANGE_MOVING = 15),
	)

	accuracy_increase_mod = 1.05
	accuracy_decrease_mod = 1.10
	KD_chance = KD_CHANCE_HIGH

/obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733
	name = "Pistolet modèle An 1733"
	desc = "A typical French pistol. Used by Calvary units."
	icon_state = "pistolet_modele1733"
	item_state = "pistol"
	recoil = 2.1
	force = 6.1
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	effectiveness_mod = 1
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy_list = list(


		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 40,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 38,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 54,
			MEDIUM_RANGE_MOVING = 48,

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

	accuracy_increase_mod = 1.40
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 1.70

/obj/item/weapon/gun/projectile/flintlock/duellingpistol
	name = "Duelling Flintlock "
	desc = "A typical Duelling Pistol. Used by gentlemen who take part in duels."
	icon_state = "flintlock_duelingpistol"
	item_state = "pistol"
	recoil = 2.5
	force = 8
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.9
	effectiveness_mod = 1
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3.4
	fire_delay = 3.1
	load_delay = 75
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy_list = list(


		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 65,
			MEDIUM_RANGE_MOVING = 65,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 42,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 58,

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

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 35,

			VERY_LONG_RANGE_STILL = 47,
			VERY_LONG_RANGE_MOVING = 35),
	)


/obj/item/weapon/gun/projectile/flintlock/pistoletmodeleanxiii
	name = "Pistolet modèle An XIII"
	desc = "A typical French pistol. Used by Calvary units."
	icon_state = "pistolet_modele13"
	item_state = "pistol"
	recoil = 2.1
	force = 6.1
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	effectiveness_mod = 1
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy_list = list(


		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 40,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 45,
			LONG_RANGE_MOVING = 30,

			VERY_LONG_RANGE_STILL = 38,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 54,
			MEDIUM_RANGE_MOVING = 48,

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

	accuracy_increase_mod = 1.40
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 1.70
/obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol
	stat = "heavy"
	name = "Blunderbuss Pistol"
	desc = "A enlarged version of the musketoon, it can fire bigger bullets. This one has been designed so it can be used with one hand. Useless at medium range."
	icon_state = "flintlock_blunderbusspistol"
	item_state = "pistol"
	recoil = 5
	force = 14
	load_delay = 110
	caliber = "blunderbuss"
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	weight = 2.5
	w_class = ITEM_SIZE_SMALL
	value = 80
	effectiveness_mod = 0.6
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/blunderbuss
