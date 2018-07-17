/obj/item/weapon/gun/projectile/shotgun
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

/obj/item/weapon/gun/projectile/shotgun/pump
	name = "shotgun"
	desc = "Useful for sweeping alleys."
	icon_state = "shotgun"
	item_state = "shotgun"
	max_shells = 4
	w_class = 4.0
	force = 10
	flags =  CONDUCT
	slot_flags = SLOT_BACK
	caliber = "shotgun"
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/shotgun/beanbag
	handle_casings = HOLD_CASINGS
	stat = "shotgun"
	move_delay = 4
	var/recentpump = FALSE // to prevent spammage

/obj/item/weapon/gun/projectile/shotgun/pump/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/shotgun/pump/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		pump(user)
		recentpump = world.time

/obj/item/weapon/gun/projectile/shotgun/pump/proc/pump(mob/M as mob)
	playsound(M, 'sound/weapons/shotgunpump.ogg', 60, TRUE)

	if (chambered)//We have a shell in the chamber
		chambered.loc = get_turf(src)//Eject casing
		chambered = null

	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC

	update_icon()

/obj/item/weapon/gun/projectile/shotgun/pump/combat
	name = "combat shotgun"
	icon_state = "cshotgun"
	item_state = "cshotgun"
//	origin_tech = "combat=5;materials=2"
	max_shells = 6 //match the ammo box capacity, also it can hold a round in the chamber anyways, for a total of 8.
	ammo_type = /obj/item/ammo_casing/shotgun
	force = 15
	throwforce = 30
	weight = 3.4

/obj/item/weapon/gun/projectile/shotgun/pump/combat/ithaca37
	icon_state = "ithaca37"
	name = "Ithaca 37"

/obj/item/weapon/gun/projectile/shotgun/pump/combat/winchester1897
	icon_state = "winchester1897"
	name = "Winchester 1897"

/obj/item/weapon/gun/projectile/shotgun/pump/combat/coachgun
	icon_state = "coachgun"
	name = "Coachgun"

