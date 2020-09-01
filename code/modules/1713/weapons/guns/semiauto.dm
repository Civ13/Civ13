/obj/item/weapon/gun/projectile/semiautomatic
	maxhealth = 60
	fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
	icon = 'icons/obj/guns/rifles.dmi'
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

	gtype = "rifle"

	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	var/base_icon = "semiautomatic"
	equiptimer = 12
	gun_safety = TRUE
	reload_sound = 'sound/weapons/guns/interact/semiauto_magin.ogg'
	unload_sound = 'sound/weapons/guns/interact/semiauto_magout.ogg'

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
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100
	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.4

	if (prob(jamcheck*reverse_health_percentage))
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
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/avtomat
	name = "Fedorov Avtomat"
	desc = "Russian automatic rifle, used during WWI."
	icon_state = "avtomat"
	item_state = "svt"
	base_icon = "avtomat"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 25
	caliber = "a65x50"
	ammo_type = /obj/item/ammo_casing/a65x50
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/avtomat
	weight = 3.85
	load_delay = 8
	firemodes = list(
		list(name="single shot",	burst=1, burst_delay=0.8, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0.2, 0.3)),
		list(name="full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(1, 1.2, 1.3, 1.2, 1.3)),
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.80
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/remington11
	name = "Remington 11"
	desc = "American semi-automatic shotgun."
	icon_state = "remington11"
	item_state = "remington11"
	base_icon = "remington11"
	w_class = 4
	load_method = SINGLE_CASING
	max_shells = 5
	caliber = "12gauge"
	ammo_type = /obj/item/ammo_casing/shotgun
	slot_flags = SLOT_SHOULDER
	weight = 3.85
	load_delay = 4

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.80

/obj/item/weapon/gun/projectile/semiautomatic/sks
	name = "SKS"
	desc = "Soviet semi-automatic rifle chambered in 7.62x39mm."
	icon_state = "sks"
	item_state = "sks"
	base_icon = "sks"
	fire_sound = 'sound/weapons/guns/fire/SKS.ogg'
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a762x39"
	ammo_type = /obj/item/ammo_casing/a762x39
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/sks
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=4)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.03
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/svd
	name = "SVD"
	desc = "Soviet designated marksman's rifle, feeding from detachable 10-round magazines. Chambered in 7.62x54mmR."
	icon_state = "svd"
	item_state = "svd"
	base_icon = "svd"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	damage_modifier = 1.2
	fire_sound = 'sound/weapons/guns/fire/SVD.ogg'
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/svd
	weight = 3.85
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=8)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.03
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/svd/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

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
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/gewehr98
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
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
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/g43
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/semiautomatic/m1garand
	name = "M1 Garand"
	desc = "An American semi-automatic rifle using .30-06 ammunition in a 8 round internal magazine."
	icon_state = "m1garand"
	item_state = "m1garand"
	base_icon = "m1garand"
	w_class = 4
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 8
	caliber = "a3006"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a3006
	magazine_type = /obj/item/ammo_magazine/garand
	reload_sound = 'sound/weapons/guns/interact/GarandLoad.ogg'
	unload_sound = 'sound/weapons/guns/interact/GarandUnload.ogg'
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=4)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.01

/obj/item/weapon/gun/projectile/semiautomatic/ar15
	name = "Bushmaster XM-15"
	desc = "A civilian semi-automatic rifle chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "m4"
	item_state = "m4"
	base_icon = "m4"
	w_class = 4
	load_method = MAGAZINE
	load_delay = 5
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a556x45
	magazine_type = /obj/item/ammo_magazine/m16
	weight = 4.9
	firemodes = list(
		list(name="single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 1.07