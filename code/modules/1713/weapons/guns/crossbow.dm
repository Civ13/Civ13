/obj/item/weapon/gun/projectile/bow/crossbow
	name = "crossbow"
	desc = "A heavy and powerful bow."
	icon_state = "crossbow0"
	item_state = "crossbow0"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 5
	force = 8
	throwforce = 8
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "bolt"
	recoil = 1 //little shaking
	fire_sound = 'sound/weapons/guns/fire/Crossbow.ogg'
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/bolt
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	bulletinsert_sound = 'sound/weapons/pull_bow.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
	gun_type = GUN_TYPE_BOW
	attachment_slots = null
	accuracy_increase_mod = 6.00
	accuracy_decrease_mod = 8.00
	KD_chance = KD_CHANCE_HIGH
	stat = "bows"
	move_delay = 6
	fire_delay = 8
	muzzle_flash = FALSE
	value = 10
	flammable = TRUE
	projtype = "bolt"
	icotype = "crossbow"
	equiptimer = 25
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 65,

			MEDIUM_RANGE_STILL = 85,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 55,
			VERY_LONG_RANGE_MOVING = 30),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 95,
			SHORT_RANGE_MOVING = 65,

			MEDIUM_RANGE_STILL = 85,
			MEDIUM_RANGE_MOVING = 55,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 55,
			VERY_LONG_RANGE_MOVING = 30),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 99,
			SHORT_RANGE_MOVING = 75,

			MEDIUM_RANGE_STILL = 90,
			MEDIUM_RANGE_MOVING = 65,

			LONG_RANGE_STILL = 70,
			LONG_RANGE_MOVING = 45,

			VERY_LONG_RANGE_STILL = 60,
			VERY_LONG_RANGE_MOVING = 45),
	)

	load_delay = 60
	aim_miss_chance_divider = 3.00
