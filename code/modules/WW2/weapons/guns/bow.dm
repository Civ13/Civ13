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
	recoil = 0 //no shaking
	fire_sound = 'sound/weapons/arrow_fly.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/arrow
//	magazine_type = /obj/item/ammo_magazine/musketball
	load_shell_sound = 'sound/weapons/pull_bow.ogg'
	bulletinsert_sound = 'sound/weapons/pull_bow.ogg'
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
	loaded = list()

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

	load_delay = 30
	aim_miss_chance_divider = 3.00

/obj/item/weapon/gun/projectile/bow/handle_post_fire()
	..()
	loaded -= chambered
	chambered = null

/obj/item/weapon/gun/projectile/bow/load_ammo(var/obj/item/A, mob/user)
	..()
	icon_state = "bow_loaded"
	qdel(A)

/obj/item/weapon/gun/projectile/bow/unload_ammo(mob/user, var/allow_dump=1)

	icon_state = "bow"

/obj/item/weapon/gun/projectile/bow/update_icon()

	if (chambered)
		icon_state = "bow_loaded"
		return
	else
		icon_state = "bow"
		return

/obj/item/weapon/gun/projectile/bow/handle_click_empty(mob/user)
	if (user)
		user.visible_message("", "<span class='danger'>You don't have an arrow here!</span>")
	else
		visible_message("")