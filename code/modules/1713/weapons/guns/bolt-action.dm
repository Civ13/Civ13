//all bolt-action weapons

/obj/item/weapon/gun/projectile/boltaction
	name = "bolt-action rifle"
	desc = "A bolt-action rifle of true ww2 (You shouldn't be seeing this)"
	icon_state = "mosin"
	item_state = "mosin" //placeholder
	var/base_icon = "mosin"
	w_class = 4
	force = 10
	throwforce = 20
	max_shells = 5
	slot_flags = SLOT_BACK
	caliber = "a762x54"
	recoil = 2 //extra kickback
	//fire_sound = 'sound/weapons/sniper.ogg'
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	//+2 accuracy over the LWAP because only one shot
	accuracy = TRUE
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 2
	fire_delay = 2

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

/obj/item/weapon/gun/projectile/boltaction/New()
	..()
	loaded = list()
	chambered = null

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
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
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
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt open.</span>"
	else
		playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You work the bolt closed.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/boltaction/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	return ..()

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
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))
	last_fire = world.time

/obj/item/weapon/gun/projectile/boltaction/update_icon()
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
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a4570"
	weight = 4.5
	effectiveness_mod = 0.99
	bolt_safety = FALSE
	value = 80
	recoil = 3
	slot_flags = SLOT_BACK
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a4570
	magazine_type = /obj/item/ammo_magazine/sharps
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	max_shells = 1

/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry
	name = "Martini-Henry Rifle"
	desc = "A single-shot, falling block rifle, with a long range. Uses .577/450 cartridges."
	icon_state ="martini_henry"
	item_state ="shotgun"
	base_icon = "martini_henry"
	force = 13
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a577"
	weight = 5
	effectiveness_mod = 0.98
	bolt_safety = FALSE
	value = 90
	recoil = 4
	slot_flags = SLOT_BACK
	throwforce = 17
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a577
	magazine_type = /obj/item/ammo_magazine/c577
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	max_shells = 1
	load_delay = 7

/obj/item/weapon/gun/projectile/boltaction/singleshot/special_check(mob/user)
	if (bolt_open)
		user << "<span class='warning'>You can't fire [src] while the breech is open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/boltaction/singleshot/attack_self(mob/user)
	if (!check_bolt)//Keeps people from spamming the bolt
		check_bolt++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_bolt--
			return
	else return
	bolt_open = !bolt_open
	if (bolt_open)
		if (chambered)
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You open the breech lever, ejecting [chambered]!</span>"
			chambered.loc = get_turf(src)
			chambered.randomrotation()
			loaded -= chambered
			chambered = null
		else
			playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
			user << "<span class='notice'>You open the breech lever.</span>"
	else
		playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You close the breech lever.</span>"
		bolt_open = FALSE
	add_fingerprint(user)
	update_icon()
	check_bolt--

/obj/item/weapon/gun/projectile/boltaction/mosin
	name = "Mosin-Nagant M1891"
	desc = "Russian bolt-action rifle chambered in 7.62x54mmR cartridges."
	icon_state ="mosin"
	item_state ="mosin"
	base_icon = "mosin"
	force = 12
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a762x54"
	weight = 4.3
	effectiveness_mod = 0.96
	bolt_safety = FALSE
	value = 100
	recoil = 2
	slot_flags = SLOT_BACK
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'


/obj/item/weapon/gun/projectile/boltaction/mosin/m30
	name = "Mosin-Nagant M1891/30"
	desc = "A shortened version of the original M1891. Bolt-action rifle chambered in 7.62x54mmR cartridges."
	icon_state ="mosin30"
	item_state ="mosin30"
	base_icon = "mosin30"
	weight = 4
	effectiveness_mod = 1.02

/obj/item/weapon/gun/projectile/boltaction/arisaka30
	name = "Arisaka Type 30"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon_state = "arisaka30"
	item_state = "arisaka30"
	base_icon = "arisaka30"
	caliber = "a65x50"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a65x50
	magazine_type = /obj/item/ammo_magazine/arisaka
	bolt_safety = FALSE
	effectiveness_mod = 0.95
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'


/obj/item/weapon/gun/projectile/boltaction/gewehr71
	name = "Gewehr 71"
	desc = "A german bolt-action rifle chambered in 7.65x53mm Mauser ammunition."
	icon_state = "gewehr71"
	item_state = "gewehr71"
	base_icon = "gewehr71"
	caliber = "a765x53"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	bolt_safety = FALSE
	effectiveness_mod = 0.85
	value = 90
	slot_flags = SLOT_BACK
	recoil = 2
	force = 10
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'


/obj/item/weapon/gun/projectile/boltaction/mauser1890
	name = "Mauser M1890"
	desc = "A german bolt-action rifle commonly known as the \"Ottoman Mauser\", chambered in 7.65x53mm Mauser ammunition."
	icon_state = "mauser90"
	item_state = "gewehr98"
	base_icon = "mauser90"
	caliber = "a765x53"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	bolt_safety = FALSE
	effectiveness_mod = 0.89
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 10
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/mauser1893
	name = "Mauser M1893"
	desc = "A german bolt-action rifle commonly known as the \"Spanish Mauser\", chambered in 7x57mm Mauser ammunition."
	icon_state = "mauser93"
	item_state = "gewehr98"
	base_icon = "mauser93"
	caliber = "a7x57"
	weight = 3.68
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a7x57
	magazine_type = /obj/item/ammo_magazine/mauser1893
	bolt_safety = FALSE
	effectiveness_mod = 0.91
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 10
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/mauser1893/mauser1893o
	name = "Mauser M1893 (Ottoman)"
	desc = "An Ottoman version of the \"Spanish Mauser\", chambered in 7.65x53mm Mauser ammunition."
	caliber = "a765x53"
	weight = 3.8
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71


/obj/item/weapon/gun/projectile/boltaction/gewehr98
	name = "Gewehr 98"
	desc = "A german bolt-action rifle chambered in 7.92x57mm Mauser ammunition."
	icon_state = "gewehr98"
	item_state = "gewehr98"
	base_icon = "gewehr98"
	caliber = "a792x57"
	weight = 4
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/gewehr98
	bolt_safety = FALSE
	effectiveness_mod = 0.95
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/gewehr98/mauser1903
	name = "Mauser M1903"
	desc = "The ottoman version of the Mauser M1898, chambered in 7.65x53mm Mauser ammunition."
	caliber = "a765x53"
	weight = 3.7
	ammo_type = /obj/item/ammo_casing/a765x53
	magazine_type = /obj/item/ammo_magazine/gewehr71
	effectiveness_mod = 0.96

/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a
	name = "Karabiner 98a"
	desc = "A shortened carabine version of the Gewehr 98, chambered in 7.92x57mm Mauser ammunition."
	icon_state = "kar98a"
	item_state = "kar98k"
	base_icon = "kar98a"
	weight = 3.5
	effectiveness_mod = 0.97

/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k
	name = "Karabiner 98k"
	desc = "A shortened, modernized carabine version of the Gewehr 98, chambered in 7.92x57mm Mauser ammunition."
	icon_state = "kar98k"
	item_state = "kar98k"
	base_icon = "kar98k"
	weight = 3.7
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/boltaction/p14enfield
	name = "Pattern 1914 Enfield"
	desc = "A british bolt-action rifle based on the Mauser line, chambered in .303 Enfield ammunition."
	icon_state = "p14enfield"
	item_state = "p14enfield"
	base_icon = "p14enfield"
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a303"
	weight = 4.2
	bolt_safety = FALSE
	value = 80
	recoil = 2
	throwforce = 16
	ammo_type = /obj/item/ammo_casing/a303
	magazine_type = /obj/item/ammo_magazine/enfield
	effectiveness_mod = 0.97
	slot_flags = SLOT_BACK
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/carcano
	name = "carcano 1891"
	desc = "An italian bolt-action rifle chambered in 6.50x52mm ammunition."
	icon_state = "carcano"
	item_state = "carcano"
	base_icon = "carcano"
	caliber = "a65x52"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a65x52
	magazine_type = /obj/item/ammo_magazine/carcano
	bolt_safety = FALSE
	effectiveness_mod = 0.85
	value = 100
	slot_flags = SLOT_BACK
	recoil = 2
	force = 11
	throwforce = 25
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	load_shell_sound = 'sound/weapons/clip_reload.ogg'

/obj/item/weapon/gun/projectile/boltaction/arisaka35
	name = "Arisaka Type 35"
	desc = "Japanese bolt-action rifle chambered in 6.50x50mm Arisaka ammunition."
	icon_state = "arisaka35"
	item_state = "arisaka35"
	base_icon = "arisaka35"
	caliber = "a65x50"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a65x50
	bolt_safety = FALSE
	effectiveness_mod = 0.98
	value = 120
	slot_flags = SLOT_BACK
	recoil = 2
	force = 12
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/arisaka
	load_shell_sound = 'sound/weapons/clip_reload.ogg'


/obj/item/weapon/gun/projectile/boltaction/murata
	name = "Type-22 Murata"
	desc = "Japanese bolt-action rifle chambered in 8x53mm Murata ammunition."
	icon_state = "murata"
	item_state = "murata"
	base_icon = "murata"
	caliber = "a8x53"
	weight = 3.8
	fire_sound = 'sound/weapons/kar_shot.ogg'
	ammo_type = /obj/item/ammo_casing/a8x53
	bolt_safety = FALSE
	effectiveness_mod = 0.75
	value = 120
	slot_flags = SLOT_BACK
	recoil = 2
	force = 12
	throwforce = 20
	max_shells = 8
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	magazine_type = /obj/item/ammo_magazine/murata
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	blackpowder = TRUE

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
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a762x54"
	weight = 4.0
	effectiveness_mod = 0.96
	bolt_safety = FALSE
	value = 100
	recoil = 2
	slot_flags = SLOT_BACK
	throwforce = 20
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a762x54
	magazine_type = /obj/item/ammo_magazine/mosin
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
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
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a303"
	weight = 4.5
	effectiveness_mod = 0.99
	bolt_safety = FALSE
	value = 80
	recoil = 3
	slot_flags = SLOT_BACK
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a303
	magazine_type = /obj/item/ammo_magazine/enfield
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	max_shells = 10

/obj/item/weapon/gun/projectile/boltaction/lebel
	name = "Lebel 1886/M93"
	desc = "A 8 round, bolt-action rifle, standard issue for french military, chambered in 8×50mmR Lebel."
	icon_state ="lebel"
	item_state ="lebel"
	base_icon = "lebel"
	force = 12
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a8x50"
	weight = 4.4
	effectiveness_mod = 0.97
	bolt_safety = FALSE
	value = 80
	recoil = 3
	slot_flags = SLOT_BACK
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/a8x50
	magazine_type = /obj/item/ammo_magazine/c8x50
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	max_shells = 8

/obj/item/weapon/gun/projectile/boltaction/berthier
	name = "Berthier M1907/15"
	desc = "A 3 round, bolt-action carbine, chambered in 8×50mmR Lebel."
	icon_state ="berthier"
	item_state ="berthier"
	base_icon = "berthier"
	force = 12
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a8x50"
	weight = 3
	effectiveness_mod = 0.94
	bolt_safety = FALSE
	value = 80
	recoil = 3
	slot_flags = SLOT_BACK
	throwforce = 16
	handle_casings = HOLD_CASINGS
	load_method = SINGLE_CASING | SPEEDLOADER
	ammo_type = /obj/item/ammo_casing/a8x50
	magazine_type = /obj/item/ammo_magazine/c8x50_3clip
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	max_shells = 3

/obj/item/weapon/gun/projectile/boltaction/berthier/m16
	name = "Berthier M1907/16"
	desc = "A 5 round, bolt-action carbine, chambered in 8×50mmR Lebel."
	magazine_type = /obj/item/ammo_magazine/c8x50_5clip
	max_shells = 5

/obj/item/weapon/gun/projectile/boltaction/mosin/obrez
	name = "Mosin-Nagant \"Obrez\""
	desc = "A makeshift sawn-off Mosin \"pistol\", chambered in 7.62x54mmR cartridges."
	icon_state ="obrez"
	item_state ="pistol"
	base_icon = "obrez"
	force = 5
	fire_sound = 'sound/weapons/mosin_shot.ogg'
	caliber = "a762x54"
	weight = 1.4
	effectiveness_mod = 0.77
	value = 60
	slot_flags = SLOT_BELT