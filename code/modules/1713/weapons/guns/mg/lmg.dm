
/obj/item/weapon/gun/projectile/automatic
	force = 15
	throwforce = 30
	var/base_icon = "automatic"
	equiptimer = 22
	load_delay = 12
	gun_safety = TRUE
	slowdown = 0.6
	// not accurate at all
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

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_VERY_LOW
	stat = "mg"
	w_class = 5
	heavy = TRUE
	load_method = MAGAZINE
	slot_flags = SLOT_BACK
	sel_mode = 1
	full_auto = TRUE
	attachment_slots = ATTACH_IRONSIGHTS
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=0.8, move_delay=8, dispersion = list(0.7, 1.1, 1.1, 1.1, 1.3), recoil = 1.0),)

	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/automatic/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return
/obj/item/weapon/gun/projectile/automatic/New()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/automatic/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (jammed_until > world.time)
		user << "<span class = 'danger'>\The [src] has jammed! You can't fire it until it has unjammed.</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/automatic/madsen
	name = "Madsen light machine gun"
	desc = "The Madsen Machine Gun, is a light machine gun (LMG) designed in Denmark in the 1896. Many countries ordered models of it in different calibers. This one is 7.62x54mmR, mosin rounds."
	icon_state = "madsen"
	item_state = "madsen"
	base_icon = "madsen"
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/madsen
	weight = 9.12

	force = 20
	throwforce = 30

/obj/item/weapon/gun/projectile/automatic/m60
	name = "M60 machine gun"
	desc = "An american machinegun chambered in 7.62x51mm NATO rounds. Heavy and handles like a pig."
	icon_state = "m60"
	item_state = "m60"
	base_icon = "m60"
	caliber = "a762x51_weak"
	magazine_type = /obj/item/ammo_magazine/b762
	weight = 10.5
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 2),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 1

/obj/item/weapon/gun/projectile/automatic/handle_post_fire()
	..()

	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		++jamcheck

	if (prob(jamcheck/4))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/automatic/pkm
	name = "PKM machine gun"
	desc = "A soviet machinegun chambered in 7.62x54mmR rounds."
	icon_state = "pkmp"
	item_state = "pkmp"
	base_icon = "pkmp"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/pkm/c100
	weight = 7.5
	firemodes = list(
		list(name="full auto",	burst=1, burst_delay=1.3, move_delay=7, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.6), recoil = 1.8),)
	slot_flags = 0
	force = 20
	nothrow = TRUE
	throwforce = 30
	equiptimer = 25
	load_delay = 50
	slowdown = 0.8
