//all bolt-action weapons

/obj/item/weapon/gun/projectile/boltaction
	name = "bolt-action rifle"
	icon = 'icons/obj/guns/rifles.dmi'
	desc = "A bolt-action rifle of true ww2 (You shouldn't be seeing this)"
	icon_state = "mosin"
	item_state = "mosin" //placeholder
	var/base_icon = "mosin"
	w_class = ITEM_SIZE_LARGE
	force = 10
	throwforce = 20
	max_shells = 5
	slot_flags = SLOT_SHOULDER
	caliber = "a762x54"
	recoil = 0 //extra kickback
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	good_mags = list(/obj/item/ammo_magazine)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/battle_rifle.ogg'
	var/bolt_open_sound = 'sound/weapons/guns/interact/bolt_open.ogg'
	var/bolt_close_sound = 'sound/weapons/guns/interact/bolt_close.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 2
	fire_delay = 2
	equiptimer = 15
	gun_safety = TRUE
	maxhealth = 20
	gtype = "rifle"
	// 5x as accurate as MGs for now
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 87,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 77,
			MEDIUM_RANGE_MOVING = 47,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 56,
			VERY_LONG_RANGE_MOVING = 30),

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
			SHORT_RANGE_STILL = 98,
			SHORT_RANGE_MOVING = 49,

			MEDIUM_RANGE_STILL = 90,
			MEDIUM_RANGE_MOVING = 50,

			LONG_RANGE_STILL = 77,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 69,
			VERY_LONG_RANGE_MOVING = 31),
	)

	load_delay = 4
	aim_miss_chance_divider = 3.00

	var/bolt_open = FALSE
	var/check_bolt = FALSE //Keeps the bolt from being interfered with
	var/check_bolt_lock = FALSE //For locking the bolt. Didn't put this in with check_bolt to avoid issues
	var/bolt_safety = FALSE //If true, locks the bolt when gun is empty
	var/next_reload = -1
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/boltaction/attack_self(mob/user)
	if (!check_bolt)//Keeps people from spamming the bolt
		check_bolt++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_bolt--
			return
	else return
	if (check_bolt_lock)
		user << "<span class='notice'>The bolt won't move, the gun is empty!</span>"
		check_bolt--
		return
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			playsound(loc, bolt_open_sound, 50, TRUE)
			user << "<span class='notice'>You work the bolt open, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			chambered.randomrotation()
			loaded -= chambered
			chambered = null
			if (bolt_safety)
				if (!loaded.len)
					check_bolt_lock++
					user << "<span class='notice'>The bolt is locked!</span>"
		else
			playsound(loc, bolt_open_sound, 50, TRUE)
			user << "<span class='notice'>You work the bolt open.</span>"
	else
		playsound(loc, bolt_close_sound, 50, TRUE)
		user << "<span class='notice'>You work the bolt closed.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/boltaction/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE) && !istype(src,/obj/item/weapon/gun/projectile/boltaction/mosin/obrez))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/boltaction/load_ammo(var/obj/item/A, mob/user)
	if (!bolt_open)
		return
	if (check_bolt_lock)
		--check_bolt_lock // preincrement is superior
	..()

/obj/item/weapon/gun/projectile/boltaction/unload_ammo(mob/user, var/allow_dump=1)
	if (!bolt_open)
		return
	..()

/obj/item/weapon/gun/projectile/boltaction/handle_post_fire()
	..()
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100

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

	if (prob(jamcheck*reverse_health_percentage))
		jammed_until = max(world.time + (jamcheck * 5), 50)
		jamcheck = 0
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))
	last_fire = world.time

/obj/item/weapon/gun/projectile/boltaction/update_icon()
	if (sniper_scope)
		if (bolt_open)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (!bolt_open)
			icon_state = base_icon
		else
			icon_state = "[base_icon]_open"
	update_held_icon()
	return
/obj/item/weapon/gun/projectile/boltaction/singleshot
	name = "Sharps Rifle"
	desc = "A single-shot, falling block rifle, with a long range. Uses .45-70 cartridges."
	icon_state ="sharps"
	item_state ="shotgun"
	base_icon = "sharps"
	force = 12
	caliber = "a4570"
	weight = 4.5
	effectiveness_mod = 0.99
	bolt_safety = FALSE
	value = 80
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a4570
	magazine_type = /obj/item/ammo_magazine/sharps
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 1
	gun_safety = FALSE
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	var/bolt_delay = 2

/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry
	name = "Martini-Henry Rifle"
	desc = "A single-shot, falling block rifle, with a long range. Uses .577/450 cartridges."
	icon_state ="martini_henry"
	item_state ="shotgun"
	base_icon = "martini_henry"
	force = 13
	caliber = "a577"
	weight = 5
	effectiveness_mod = 0.98
	bolt_safety = FALSE
	value = 90
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 17
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a577
	magazine_type = /obj/item/ammo_magazine/c577
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 1
	load_delay = 7

/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock
	name = "Rolling-Block Rifle"
	desc = "A single-shot, rolling block rifle, with a long range. Uses .45-70 Gov cartridges."
	icon_state ="rollingblock"
	item_state ="rollingblock"
	base_icon = "rollingblock"
	force = 13
	caliber = "a4570"
	weight = 5
	effectiveness_mod = 1.02
	bolt_safety = FALSE
	value = 90
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 17
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a4570
	magazine_type = /obj/item/ammo_magazine/sharps
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 1
	load_delay = 7

/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/spanish
	name = "Rolling-Block Rifle"
	desc = "A single-shot, rolling block rifle, with a long range. This Spanish one uses .43 cartridges."
	caliber = "a43"
	effectiveness_mod = 0.98
	ammo_type = /obj/item/ammo_casing/a43
	magazine_type = /obj/item/ammo_magazine/c43

/obj/item/weapon/gun/projectile/boltaction/singleshot/makeshiftbolt
	name = "Makeshift Bolt"
	desc = "A single-shot, makeshift bolt rifle."
	icon_state ="makeshiftbolt"
	item_state ="shotgun"
	base_icon = "makeshiftbolt"
	force = 13
	caliber = "a762x54"
	weight = 5
	effectiveness_mod = 0.98
	bolt_safety = FALSE
	value = 90
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 17
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	good_mags = list(/obj/item/ammo_magazine/mosin)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 1
	load_delay = 7

/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett
	name = "Barrett M99"
	desc = "A single-shot anti-material rifle designed by the Barrett Firearms Company."
	icon_state = "m99"
	item_state = "m99"
	base_icon = "m99"
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	w_class = ITEM_SIZE_HUGE
	force = 10
	throwforce = 5
	max_shells = 1
	KD_chance = KD_CHANCE_HIGH
	slot_flags = null
	caliber = "a50cal"
	weight = 14.8
	effectiveness_mod = 2.0
	recoil = 3
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = list (/obj/item/ammo_casing/a50cal, /obj/item/ammo_casing/a50cal_ap, /obj/item/ammo_casing/a50cal_he)
	magazine_type = /obj/item/ammo_magazine/mosin
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/BarrettM99.ogg'
	bolt_open_sound = 'sound/weapons/guns/interact/barrett_bolt_open.ogg'
	bolt_close_sound = 'sound/weapons/guns/interact/barrett_bolt_close.ogg'
	accuracy_increase_mod = 2.00
	move_delay = 4
	fire_delay = 10
	equiptimer = 15
	gun_safety = TRUE
	load_delay = 20
	bolt_open = FALSE
	bolt_safety = FALSE
	bolt_delay = 3

/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd
	name = "PTRD-41"
	desc = "A soviet anti-material rifle chambered in 14.5x114mm designed to take out tanks."
	icon_state = "ptrd"
	item_state = "ptrd"
	base_icon = "ptrd"
	attachment_slots = ATTACH_IRONSIGHTS
	w_class = ITEM_SIZE_HUGE
	force = 10
	throwforce = 5
	max_shells = 1
	KD_chance = KD_CHANCE_HIGH
	slot_flags = null
	caliber = "a145"
	weight = 8
	recoil = 3
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = list (/obj/item/ammo_casing/a145, /obj/item/ammo_casing/a145_ap)
	magazine_type = /obj/item/ammo_magazine/mosin
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/ptrd.ogg'
	accuracy_increase_mod = 2.00
	move_delay = 4
	fire_delay = 10
	equiptimer = 20
	gun_safety = FALSE
	load_delay = 20
	bolt_open = FALSE
	bolt_safety = FALSE
	bolt_delay = 6

// /obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd/ptrs - To be added soon, just needs an icon change

/obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39
	name = "PzB 39"
	desc = "A German anti-tank rifle chambered in 7.92x94mm."
	icon_state = "pzb39"
	item_state = "pzb39"
	base_icon = "pzb39"
	attachment_slots = ATTACH_IRONSIGHTS
	w_class = ITEM_SIZE_HUGE
	force = 10
	throwforce = 5
	max_shells = 1
	KD_chance = KD_CHANCE_HIGH
	slot_flags = null
	caliber = "a792x94"
	weight = 8
	recoil = 3
	handle_casings = EJECT_CASINGS
	load_method = SINGLE_CASING | MAGAZINE
	ammo_type = list (/obj/item/ammo_casing/a792x94, /obj/item/ammo_casing/a792x94_ap)
	magazine_type = /obj/item/ammo_magazine/pzb_case
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/ptrd.ogg'
	accuracy_increase_mod = 2.00
	move_delay = 4
	fire_delay = 4
	equiptimer = 20
	gun_safety = FALSE
	load_delay = 20
	bolt_open = FALSE
	bolt_safety = FALSE
	bolt_delay = 6

/obj/item/weapon/gun/projectile/boltaction/singleshot/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the breech is open!</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/attack_self(mob/user)
	if (!check_bolt)//Keeps people from spamming the bolt
		check_bolt++
		if (!do_after(user, bolt_delay, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_bolt--
			return
	else return
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			playsound(loc, bolt_open_sound, 50, TRUE)
			user << "<span class='notice'>You open the breech lever, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			chambered.randomrotation()
			loaded -= chambered
			chambered = null
		else
			playsound(loc, bolt_open_sound, 50, TRUE)
			user << "<span class='notice'>You open the breech lever.</span>"
	else
		playsound(loc, bolt_close_sound, 50, TRUE)
		user << "<span class='notice'>You close the breech lever.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/boltaction/mosin
	name = "Mosin M1891"
	desc = "Russian bolt-action rifle chambered in 7.62x54mmR cartridges."
	icon_state ="mosin"
	item_state ="mosin"
	base_icon = "mosin"
	fire_sound = 'sound/weapons/guns/fire/Mosin.ogg'
	force = 12
	caliber = "a762x54"
	weight = 4.3
	effectiveness_mod = 0.96
	bolt_safety = FALSE
	value = 100
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	good_mags = list(/obj/item/ammo_magazine/mosin)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 18

/obj/item/weapon/gun/projectile/boltaction/mosin/m30
	name = "Mosin 91/30"
	desc = "A modernized version of the original M1891. Bolt-action rifle chambered in 7.62x54mmR cartridges."
	icon_state ="mosin30"
	item_state ="mosin30"
	base_icon = "mosin30"
	weight = 4
	effectiveness_mod = 1.02
	equiptimer = 15
/obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/arisaka30
	name = "Arisaka Type 30"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon_state = "arisaka30"
	item_state = "arisaka30"
	base_icon = "arisaka30"
	caliber = "a65x50"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a65x50
	magazine_type = /obj/item/ammo_magazine/arisaka
	good_mags = list(/obj/item/ammo_magazine/arisaka)
	effectiveness_mod = 0.95
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	bolt_open_sound = 'sound/weapons/guns/interact/arisaka_open.ogg'
	bolt_close_sound = 'sound/weapons/guns/interact/arisaka_close.ogg'
	equiptimer = 18
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER

/obj/item/weapon/gun/projectile/boltaction/arisaka38
	name = "Arisaka Type 38"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon_state = "arisaka38"
	item_state = "arisaka38"
	base_icon = "arisaka38"
	caliber = "a65x50"
	weight = 3.8
	magazine_type = /obj/item/ammo_magazine/arisaka
	good_mags = list(/obj/item/ammo_magazine/arisaka)
	bolt_safety = FALSE
	effectiveness_mod = 1.05
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	bolt_open_sound = 'sound/weapons/guns/interact/arisaka_open.ogg'
	bolt_close_sound = 'sound/weapons/guns/interact/arisaka_close.ogg'
	equiptimer = 18
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER

/obj/item/weapon/gun/projectile/boltaction/arisaka38/sniper
	name = "Arisaka Type 97"
	desc = "Japanese bolt-action rifle chambered in 6.5x50mm Arisaka ammunition."
/obj/item/weapon/gun/projectile/boltaction/arisaka38/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/arisaka99
	name = "Arisaka Type 99"
	desc = "Japanese bolt-action rifle chambered in 7.7x58mm Arisaka ammunition."
	icon_state = "arisaka99"
	item_state = "arisaka99"
	base_icon = "arisaka99"
	caliber = "a77x58"
	ammo_type = /obj/item/ammo_casing/a77x58
	weight = 3.8
	bolt_safety = FALSE
	effectiveness_mod = 1.05
	value = 100
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/arisaka99
	good_mags = list(/obj/item/ammo_magazine/arisaka99)
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	bolt_open_sound = 'sound/weapons/guns/interact/arisaka_open.ogg'
	bolt_close_sound = 'sound/weapons/guns/interact/arisaka_close.ogg'
	equiptimer = 18
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER

/obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper
	name = "Arisaka Type 99"
	desc = "Japanese bolt-action rifle chambered in 7.7x58mm Arisaka ammunition."
	effectiveness_mod = 1.06
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER
/obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/arisaka99/bayonet

/obj/item/weapon/gun/projectile/boltaction/arisaka99/bayonet/New()
	..()
	var/obj/item/weapon/attachment/bayonet/SP = new/obj/item/weapon/attachment/bayonet(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/arisaka99_training
	name = "Training Arisaka Type 99"
	desc = "Japanese bolt-action rifle chambered in 7.7x58mm Arisaka ammunition. This one is a training rifle that shoots wooden bullets."
	icon_state = "arisaka99"
	item_state = "arisaka99"
	base_icon = "arisaka99"
	caliber = "a77x58_wood"
	weight = 3.8
	fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
	ammo_type = /obj/item/ammo_casing/a77x58_wood
	magazine_type = /obj/item/ammo_magazine/arisaka99_training
	good_mags = list(/obj/item/ammo_magazine/arisaka99, /obj/item/ammo_magazine/arisaka99_training)
	effectiveness_mod = 1.05
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	bolt_open_sound = 'sound/weapons/guns/interact/arisaka_open.ogg'
	bolt_close_sound = 'sound/weapons/guns/interact/arisaka_close.ogg'
	equiptimer = 18
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER

/obj/item/weapon/gun/projectile/boltaction/gewehr71
	name = "Gewehr 71"
	desc = "A german bolt-action rifle chambered in 7.65x53mm Mauser ammunition."
	icon_state = "gewehr71"
	item_state = "gewehr71"
	base_icon = "gewehr71"
	caliber = "a765x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	good_mags = list(/obj/item/ammo_magazine/gewehr71)
	effectiveness_mod = 0.85
	value = 90
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 10
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 19

/obj/item/weapon/gun/projectile/boltaction/madsenm47
	name = "Madsen M47"
	desc = "A Danish bolt action."
	icon_state = "madsenm47"
	item_state = "gewehr71"
	base_icon = "madsenm47"
	caliber = "a765x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a762x51
	magazine_type = /obj/item/ammo_magazine/gewehr71
	good_mags = list(/obj/item/ammo_magazine/gewehr71)
	bolt_safety = FALSE
	effectiveness_mod = 0.85
	value = 90
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 10
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 20

/obj/item/weapon/gun/projectile/boltaction/mauser1890
	name = "Mauser M1890"
	desc = "A german bolt-action rifle commonly known as the \"Ottoman Mauser\", chambered in 7.65x53mm Mauser ammunition."
	icon_state = "mauser90"
	item_state = "gewehr98"
	base_icon = "mauser90"
	fire_sound = 'sound/weapons/guns/fire/Kar98k.ogg'
	caliber = "a765x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	good_mags = list(/obj/item/ammo_magazine/gewehr71)
	bolt_safety = FALSE
	effectiveness_mod = 0.89
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 10
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/mauser1893
	name = "Mauser M1893"
	desc = "A german bolt-action rifle commonly known as the \"Spanish Mauser\", chambered in 7x57mm Mauser ammunition."
	icon_state = "mauser93"
	item_state = "mauser93"
	base_icon = "mauser93"
	fire_sound = 'sound/weapons/guns/fire/Kar98k.ogg'
	caliber = "a7x57"
	weight = 3.68
	ammo_type = /obj/item/ammo_casing/a7x57
	magazine_type = /obj/item/ammo_magazine/mauser1893
	good_mags = list(/obj/item/ammo_magazine/mauser1893)
	bolt_safety = FALSE
	effectiveness_mod = 0.91
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 10
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/mauser1893/mauser1893o
	name = "Mauser M1893 (Ottoman)"
	desc = "An Ottoman version of the \"Spanish Mauser\", chambered in 7.65x53mm Mauser ammunition."
	caliber = "a765x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/gewehr98
	name = "Gewehr 98"
	desc = "A german bolt-action rifle chambered in 7.92x57mm Mauser ammunition."
	icon_state = "gewehr98"
	item_state = "gewehr98"
	base_icon = "gewehr98"
	caliber = "a792x57"
	fire_sound = 'sound/weapons/guns/fire/Kar98k.ogg'
	weight = 4
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/gewehr98
	good_mags = list(/obj/item/ammo_magazine/gewehr98)
	bolt_safety = FALSE
	effectiveness_mod = 0.95
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/vg //for balance reasons this gun wont use the STG mags instead it will use just clips also i dont know how to code in mag usage by bolties
	name = "Volkssturmgewehr"
	desc = "A very primitive german bolt action rifle chambered in 7.92x33mm Kurz."
	icon_state = "vg1"
	item_state = "vg1"
	base_icon = "vg1"
	caliber = "a792x33"
	fire_sound = 'sound/weapons/guns/fire/stg.ogg'
	weight = 4.2
	ammo_type = /obj/item/ammo_casing/a792x33
	magazine_type = /obj/item/ammo_magazine/vgclip
	good_mags = list(/obj/item/ammo_magazine/vgclip)
	bolt_safety = FALSE
	effectiveness_mod = 0.92
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 15
	throwforce = 29
	max_shells = 10
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/gewehr98/mauser1903
	name = "Mauser M1903"
	desc = "The ottoman version of the Mauser M1898, chambered in 7.65x53mm Mauser ammunition."
	caliber = "a765x53"
	weight = 3.7
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	good_mags = list(/obj/item/ammo_magazine/gewehr71)
	effectiveness_mod = 0.96
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a
	name = "Karabiner 98a"
	desc = "A shortened carabine version of the Gewehr 98, chambered in 7.92x57mm Mauser ammunition."
	icon_state = "kar98a"
	item_state = "kar98k"
	base_icon = "kar98a"
	weight = 3.5
	effectiveness_mod = 0.97
	equiptimer = 12

/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k
	name = "Karabiner 98k"
	desc = "A shortened, modernized carabine version of the Gewehr 98, chambered in 7.92x57mm Mauser ammunition."
	icon_state = "kar98k"
	item_state = "kar98k"
	base_icon = "kar98k"
	weight = 3.7
	effectiveness_mod = 1.05
	equiptimer = 12

/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)


/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese
	name = "Chiang Kai-Shek"
	desc = "A shortened, modernized carabine version of the Gewehr 98, chambered in 7.92x57mm Mauser ammunition. This one being adopted by the Chinese."

/obj/item/weapon/gun/projectile/boltaction/p14enfield
	name = "Pattern 1914 Enfield"
	desc = "A british bolt-action rifle based on the Mauser line, chambered in .303 Enfield ammunition."
	icon_state = "p14enfield"
	item_state = "p14enfield"
	base_icon = "p14enfield"
	caliber = "a303"
	weight = 4.2
	bolt_safety = FALSE
	value = 80
	recoil = 0
	throwforce = 16
	ammo_type = /obj/item/ammo_casing/a303
	magazine_type = /obj/item/ammo_magazine/enfield
	good_mags = list(/obj/item/ammo_magazine/enfield)
	effectiveness_mod = 0.97
	slot_flags = SLOT_SHOULDER
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 12

/obj/item/weapon/gun/projectile/boltaction/carcano
	name = "carcano 1891"
	desc = "An italian bolt-action rifle chambered in 6.50x52mm ammunition."
	icon_state = "carcano"
	item_state = "carcano"
	base_icon = "carcano"
	caliber = "a65x52"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a65x52
	magazine_type = /obj/item/ammo_magazine/carcano
	good_mags = list(/obj/item/ammo_magazine/carcano)
	bolt_safety = FALSE
	effectiveness_mod = 0.85
	value = 100
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 14

/obj/item/weapon/gun/projectile/boltaction/arisaka35
	name = "Arisaka Type 35"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon_state = "arisaka35"
	item_state = "arisaka35"
	base_icon = "arisaka35"
	caliber = "a65x50"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a65x50
	bolt_safety = FALSE
	effectiveness_mod = 0.98
	value = 120
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 12
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/arisaka
	good_mags = list(/obj/item/ammo_magazine/arisaka)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/murata
	name = "Type-22 Murata"
	desc = "Japanese bolt-action rifle chambered in 8x53mm Murata ammunition."
	icon_state = "murata"
	item_state = "murata"
	base_icon = "murata"
	caliber = "a8x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a8x53
	bolt_safety = FALSE
	effectiveness_mod = 0.75
	value = 120
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 12
	throwforce = 20
	max_shells = 8
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/murata
	good_mags = list(/obj/item/ammo_magazine/murata)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	blackpowder = TRUE
	equiptimer = 17
	/////need to add:
	///Springfield Model
	///1861,Pattern
	//1853 Enfield,
	//Frank Wesson Rifle,
	//Colt Revolving Rifle,
	//Sharps & Hankins Carbine,
	///Volcanic Carbine,
	///M1817 Common Rifle (All Rifles used during the civil war)

/obj/item/weapon/gun/projectile/boltaction/berdan
	name = "Berdan M1870"
	desc = "Russian bolt-action rifle chambered in 7.62x54mmR cartridges."
	icon_state ="berdan"
	item_state ="berdan"
	base_icon = "berdan"
	force = 12
	caliber = "a762x54"
	weight = 4.0
	effectiveness_mod = 0.96
	bolt_safety = FALSE
	value = 100
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	good_mags = list(/obj/item/ammo_magazine/mosin)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 17

/obj/item/weapon/gun/projectile/boltaction/berdan/update_icon(var/add_scope = FALSE)
	if (bolt_open)
		if (!findtext(icon_state, "_open"))
			icon_state = addtext(icon_state, "_open") //open
	else if (icon_state == "berdan_open") //closed
		icon_state = "berdan"
	else if (icon_state == "berdan")
		return
	else
		icon_state = "berdan"

/obj/item/weapon/gun/projectile/boltaction/enfield
	name = "Lee-Enfield Mk. III"
	desc = "A 10-shot, bolt-action rifle, standard issue for british military, chambered in .303 british."
	icon_state ="enfield"
	item_state ="enfield"
	base_icon = "enfield"
	force = 12
	caliber = "a303"
	weight = 4.5
	effectiveness_mod = 0.99
	bolt_safety = FALSE
	value = 80
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a303
	magazine_type = /obj/item/ammo_magazine/enfield
	good_mags = list(/obj/item/ammo_magazine/enfield)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 10
	equiptimer = 15

/obj/item/weapon/gun/projectile/boltaction/lebel
	name = "Lebel 1886/M93"
	desc = "A 8 round, bolt-action rifle, standard issue for french military, chambered in 8x50mmR Lebel."
	icon_state ="lebel"
	item_state ="lebel"
	base_icon = "lebel"
	force = 12
	caliber = "a8x50"
	weight = 4.4
	effectiveness_mod = 0.97
	bolt_safety = FALSE
	value = 80
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a8x50
	magazine_type = /obj/item/ammo_magazine/c8x50
	good_mags = list(/obj/item/ammo_magazine/c8x50)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 8
	equiptimer = 16

/obj/item/weapon/gun/projectile/boltaction/berthier
	name = "Berthier M1907/15"
	desc = "A 3 round, bolt-action carbine, chambered in 8x50mmR Lebel."
	icon_state ="berthier"
	item_state ="berthier"
	base_icon = "berthier"
	force = 12
	caliber = "a8x50"
	weight = 3
	effectiveness_mod = 0.94
	bolt_safety = FALSE
	value = 80
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a8x50
	magazine_type = /obj/item/ammo_magazine/c8x50_3clip
	good_mags = list(/obj/item/ammo_magazine/c8x50_3clip)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 3
	equiptimer = 13

/obj/item/weapon/gun/projectile/boltaction/berthier/m16
	name = "Berthier M1907/16"
	desc = "A 5 round, bolt-action carbine, chambered in 8x50mmR Lebel."
	magazine_type = /obj/item/ammo_magazine/c8x50_5clip
	good_mags = list(/obj/item/ammo_magazine/c8x50_3clip)
	max_shells = 5
	equiptimer = 13

/obj/item/weapon/gun/projectile/boltaction/mosin/obrez
	name = "Mosin-Nagant \"Obrez\""
	desc = "A makeshift sawn-off Mosin \"pistol\", chambered in 7.62x54mmR cartridges."
	icon_state ="obrez"
	item_state ="pistol"
	base_icon = "obrez"
	force = 5
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
	caliber = "a762x54"
	damage_modifier = 0.8
	weight = 1.4
	w_class = ITEM_SIZE_SMALL
	effectiveness_mod = 0.77
	value = 60
	slot_flags = SLOT_BELT|SLOT_HOLSTER|SLOT_SHOULDER
	equiptimer = 9


/obj/item/weapon/gun/projectile/boltaction/m24
	name = "M24 SWS"
	desc = "A military version of the Remington 700 rifle."
	icon_state = "m24"
	item_state = "m24"
	base_icon = "m24"
	caliber = "a762x51"
	weight = 4
	ammo_type = /obj/item/ammo_casing/a762x51
	damage_modifier = 1.25
	magazine_type = /obj/item/ammo_magazine/m24
	good_mags = list(/obj/item/ammo_magazine/m24)
	bolt_safety = FALSE
	effectiveness_mod = 1.15
	value = 130
	slot_flags = SLOT_SHOULDER
	recoil = 0
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	equiptimer = 12

/obj/item/weapon/gun/projectile/boltaction/m24/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/boltaction/springfield
	name = "M1903 Springfield"
	desc = "A bolt-action rifle made in 1903, chambered in .30-06 with a 5 round internal magazine."
	icon_state ="springfield_ww2"
	item_state ="springfield_ww2"
	base_icon = "springfield_ww2"
	force = 12
	caliber = "a3006"
	weight = 4.5
	effectiveness_mod = 1.2
	bolt_safety = FALSE
	value = 80
	recoil = 0
	slot_flags = SLOT_SHOULDER
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a3006
	magazine_type = /obj/item/ammo_magazine/springfield
	good_mags = list(/obj/item/ammo_magazine/springfield,/obj/item/ammo_magazine/garand)
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	max_shells = 5
	equiptimer = 12

/obj/item/weapon/gun/projectile/boltaction/springfield/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)
