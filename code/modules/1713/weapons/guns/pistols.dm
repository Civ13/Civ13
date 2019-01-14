/obj/item/weapon/gun/projectile/revolver
	move_delay = 1
	fire_delay = 3
	name = "revolver"
	desc = "A simple revolver."
	icon_state = "revolver"
	item_state = "revolver"
	caliber = "a45"
//	origin_tech = list(TECH_COMBAT = 2, TECH_MATERIAL = 2)
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	ammo_type = /obj/item/ammo_casing/a45
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/revolver_fire.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE

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

/obj/item/weapon/gun/projectile/revolver/verb/spin_cylinder()
	set name = "Spin cylinder"
	set desc = "Fun when you're bored out of your skull."
	set category = null

	chamber_offset = FALSE
	visible_message("<span class='warning'>\The [usr] spins the cylinder of \the [src]!</span>", \
	"<span class='notice'>You hear something metallic spin and click.</span>")
	playsound(loc, 'sound/weapons/guns/interact/revolver_spin.ogg', 100, TRUE)
	loaded = shuffle(loaded)
	if (rand(1,max_shells) > loaded.len)
		chamber_offset = rand(0,max_shells - loaded.len)

/obj/item/weapon/gun/projectile/revolver/consume_next_projectile()
	if (chamber_offset)
		chamber_offset--
		return
	return ..()

/obj/item/weapon/gun/projectile/revolver/load_ammo(var/obj/item/A, mob/user)
	chamber_offset = 0
	return ..()


/obj/item/weapon/gun/projectile/revolver/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()

/obj/item/weapon/gun/projectile/revolver/unload_ammo(var/mob/living/carbon/human/user, allow_dump=0)
	if (loaded.len)
		//presumably, if it can be speed-loaded, it can be speed-unloaded.
		if (allow_dump && (load_method & SPEEDLOADER))
			var/count = FALSE
			var/turf/T = get_turf(user)
			if (T)
				for (var/obj/item/ammo_casing/C in loaded)
					C.loc = T
					count++
				loaded.Cut()
			if (count)
				visible_message("[user] unloads [src].", "<span class='notice'>You unload [count] round\s from [src].</span>")
				if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
		else if (load_method & SINGLE_CASING)
			var/obj/item/ammo_casing/C = loaded[loaded.len]
			loaded.len--
			user.put_in_hands(C)
			visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
			if (istype(src, /obj/item/weapon/gun/projectile/boltaction))
				var/obj/item/weapon/gun/projectile/boltaction/B = src
				if (B.bolt_safety && !B.loaded.len)
					B.check_bolt_lock++
			if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
	else
		user << "<span class='warning'>[src] is empty.</span>"
	update_icon()

/obj/item/weapon/gun/projectile/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	move_delay = 1
	fire_delay = 3
	item_state = "pistol"
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

/obj/item/weapon/gun/projectile/pistol/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/attachment/bayonet))
		user << "<span class = 'danger'>That won't fit on there.</span>"
		return FALSE
	else
		return ..()

/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	name = "Nagant Revolver"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	w_class = 2
	caliber = "7.62x38mmR"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	weight = 1.2

/obj/item/weapon/gun/projectile/revolver/peacemaker
	name = "Colt Peacemaker"
	desc = "Officialy the M1873 Colt Single Action Army Revolver."
	icon_state = "peacemaker"
	w_class = 2
	caliber = "a45"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	weight = 2.3

/obj/item/weapon/gun/projectile/revolver/nagant_revolver/update_icon()
	..()
	if (loaded.len)
		icon_state = "nagant"
	else
		icon_state = "nagant"
	return

/obj/item/weapon/gun/projectile/pistol/nambu
	name = "Nambu Pistol"
	desc = "Standard issue Japanese pistol. Chambered in 8mm nambu ammunition."
	icon_state = "nambu"
	w_class = 2
	caliber = "c8mmnambu"
	fire_sound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	magazine_type = /obj/item/ammo_magazine/c8mmnambu
	weight = 0.794
	ammo_type = /obj/item/ammo_casing/c8mmnambu
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS

/obj/item/weapon/gun/projectile/pistol/nambu/update_icon()
	..()
	if (ammo_magazine)
		icon_state = "nambu"
	else
		icon_state = "nambu0"
	return

/obj/item/weapon/gun/projectile/revolver/t26_revolver
	name = "Type 26 Revolver"
	desc = "Japanese officer's revolver."
	icon_state = "t26revolver"
	w_class = 2
	caliber = "c9mm_jap_revolver"
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c9mm_jap_revolver
	weight = 0.8
	ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
	handle_casings = CYCLE_CASINGS
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	name = "Nagant Revolver"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	item_state = "nagant"
	w_class = 2
	caliber = "7.62x38"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	weight = 0.8
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/panther
	name = "Panther Revolver"
	desc = "a .44 caliber revolver."
	icon_state = "panther"
	item_state = "panther"
	w_class = 2
	caliber = "44"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c44
	weight = 0.8
	load_method = SINGLE_CASING

/obj/item/weapon/gun/projectile/revolver/c38
	name = ".38 Revolver"
	desc = "a .38 caliber revolver."
	icon_state = "revolver"
	item_state = "revolver"
	w_class = 2
	caliber = "38"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c38
	weight = 0.8
	load_method = SINGLE_CASING