//All the flintlock weapons

/obj/item/weapon/gun/projectile/bow
	name = "bow"
	desc = "A simple and crude bow. Outdated but faster than muskets."
	icon_state = "bow"
	item_state = "bow"
	w_class = 4
	throw_range = 5
	throw_speed = 5
	force = 6
	throwforce = 6
	max_shells = 1 //duh
	slot_flags = SLOT_BACK
	caliber = "arrow"
	recoil = 1 //extra kickback
	fire_sound = 'sound/weapons/arrow_fly.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/arrow
//	magazine_type = /obj/item/ammo_magazine/musketball
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 3.00
	accuracy_decrease_mod = 7.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 5
	fire_delay = 5

	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 90,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 80,
			MEDIUM_RANGE_MOVING = 40,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 32,

			VERY_LONG_RANGE_STILL = 50,
			VERY_LONG_RANGE_MOVING = 25),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 79,
			MEDIUM_RANGE_MOVING = 39,

			LONG_RANGE_STILL = 68,
			LONG_RANGE_MOVING = 34,

			VERY_LONG_RANGE_STILL = 58,
			VERY_LONG_RANGE_MOVING = 29),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 99,
			SHORT_RANGE_MOVING = 54,

			MEDIUM_RANGE_STILL = 83,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 73,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 63,
			VERY_LONG_RANGE_MOVING = 32),
	)

	load_delay = 30 //15 seconds for rifles, 12 seconds for pistols & blunderbuss
	aim_miss_chance_divider = 3.00


/obj/item/weapon/gun/projectile/bow/handle_post_fire()
	..()
	loaded -= chambered
	chambered = null


