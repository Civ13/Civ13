/obj/item/weapon/gun/projectile/semiautomatic
	fire_sound = 'sound/weapons/mosin_shot.ogg'
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
	var/base_icon = "semiautomatic"
	equiptimer = 12
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/update_icon()
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = base_icon
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/semiautomatic/special_check(mob/user)
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

/obj/item/weapon/gun/projectile/semiautomatic/handle_post_fire()
	..()

	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.4

	if (prob(jamcheck))
		jammed_until = max(world.time + (jamcheck * 4), 40)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/semiautomatic/svt
	name = "SVT-40"
	desc = "Soviet semi-automatic rifle chambered in 7.62x54mmR."
	icon_state = "svt"
	item_state = "svt"
	base_icon = "svt"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/svt
	weight = 3.85
	load_delay = 8
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.03
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/sks
	name = "SKS"
	desc = "Soviet semi-automatic rifle chambered in 7.62x54mmR."
	icon_state = "sks"
	item_state = "ks"
	base_icon = "sks"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/mosin
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=4)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.03
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/g41
	name = "Gewehr 41"
	desc = "German semi-automatic rifle using 7.92x57mm Mauser ammunition in a 10 round non-detachable magazine."
	icon_state = "g41"
	item_state = "g41"
	base_icon = "g41"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a792x57"
	fire_sound = 'sound/weapons/kar_shot.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/gewehr98
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/semiautomatic/g43
	name = "Gewehr 43"
	desc = "German semi-automatic rifle using 7.92x57mm Mauser ammunition in a 10 round detachable magazine."
	icon_state = "g43"
	item_state = "g43"
	base_icon = "g43"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	load_delay = 8
	caliber = "a792x57"
	fire_sound = 'sound/weapons/kar_shot.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/g43
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/semiautomatic/stg
	name = "StG 44"
	desc = "German assault rifle chambered in 7.92x33mm Kurz, 30 round magazine."
	icon_state = "stg"
	item_state = "stg"
	base_icon = "stg"
	load_method = MAGAZINE
	slot_flags = SLOT_SHOULDER|SLOT_BELT
	w_class = 4
	caliber = "a792x33"
	fire_sound = 'sound/weapons/stg.ogg'
	load_magazine_sound = 'sound/weapons/stg_reload.ogg'
	magazine_type = /obj/item/ammo_magazine/stg
	weight = 4.6
	load_delay = 8
	equiptimer = 15
	firemodes = list(
		list(name="semi auto",	burst=1, burst_delay=0.8, move_delay=2, dispersion = list(0.2, 0.3, 0.3, 0.4, 0.5)),
		list(name="full auto",	burst=1, burst_delay=1.5, move_delay=4, dispersion = list(1.2, 1.4, 1.4, 1.4, 1.7)),
		)

	sel_mode = 1

/obj/item/weapon/gun/projectile/semiautomatic/m1garand
	name = "M1garand"
	desc = "An American semi-automatic rifle using .30-06 ammunition in a 8 round internal magazine."
	icon_state = "m1garand"
	item_state = "m1garand"
	base_icon = "m1garand"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 8
	caliber = "a3006"
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a3006
	magazine_type = /obj/item/ammo_magazine/garand
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=2)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.05