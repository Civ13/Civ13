/obj/item/weapon/gun/projectile/revolver
	move_delay = 1
	fire_delay = 3
	name = "revolver"
	desc = "A simple revolver."
	icon_state = "revolver"
	item_state = "revolver"
	caliber = "a45"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	ammo_type = /obj/item/ammo_casing/a45
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/revolver_fire.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE
	var/base_icon = null
	equiptimer = 5
	gun_type = GUN_TYPE_PISTOL

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
	load_delay = 6

/obj/item/weapon/gun/projectile/revolver/update_icon()
	..()
	if (base_icon)
		if (cocked)
			icon_state = "[base_icon]_cocked"
		else
			icon_state = base_icon
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
/obj/item/weapon/gun/projectile/revolver/attack_self(mob/user)
	if (single_action)
		if (!cocked)
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='warning'>[user] cocks the [src]!</span>","<span class='warning'>You cock the [src]!</span>")
			cocked = TRUE
			update_icon()
		else
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='notice'>[user] uncocks the [src].</span>","<span class='notice'>You uncock the [src].</span>")
			cocked = FALSE
			update_icon()

/obj/item/weapon/gun/projectile/revolver/special_check(mob/user)
	var/mob/living/carbon/human/H = user
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (istype(H) && (H.faction_text == "INDIANS" || H.crab))
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE
	if (!cocked && single_action)
		user << "<span class='warning'>You can't fire \the [src] while the weapon is uncocked!</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/revolver/handle_post_fire()
	..()
	if (single_action)
		cocked = FALSE
	else
		cocked = TRUE
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))

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


/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	name = "Nagant revolver"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	w_class = 2
	caliber = "a762x38"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	weight = 1.45
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/m1892
	name = "Modele 1892 revolver"
	desc = "French officer's revolver."
	icon_state = "m1892"
	w_class = 2
	caliber = "a8x27"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c8x27
	weight = 1.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/peacemaker
	name = "Colt Peacemaker"
	desc = "Officialy the M1873 Colt Single Action Army Revolver."
	icon_state = "peacemaker"
	base_icon = "peacemaker"
	w_class = 2
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/frontier
	name = "Colt Frontier"
	desc = "Officialy the M1873 Colt Single Action Army Revolver. This one uses .44 Winchester ammuniton."
	icon_state = "peacemaker2"
	base_icon = "peacemaker2"
	w_class = 2
	caliber = "a44"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c44
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/t26_revolver
	name = "Type 26 revolver"
	desc = "Japanese officer's revolver."
	icon_state = "t26revolver"
	w_class = 2
	caliber = "c9mm_jap_revolver"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c9mm_jap_revolver
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 5

/obj/item/weapon/gun/projectile/revolver/webley
	name = "Webley revolver"
	desc = "British officer's revolver."
	icon_state = "webley"
	w_class = 2
	caliber = "a455"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c455
	weight = 1.6
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/panther
	name = "Panther revolver"
	desc = "a .44 caliber revolver."
	icon_state = "panther"
	item_state = "panther"
	w_class = 2
	caliber = "a44p"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c44p
	weight = 0.8
	load_method = SINGLE_CASING
	load_delay = 6
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/derringer
	name = "Derringer M95 pistol"
	desc = "Officialy the Remington Model 95, this small pistol has two barrels."
	icon_state = "derringer"
	item_state = "pistol"
	w_class = 1
	caliber = "a41"
	magazine_type = /obj/item/ammo_magazine/c41
	weight = 0.31
	load_method = SINGLE_CASING
	max_shells = 2
	force = 4
	slot_flags = SLOT_HOLSTER | SLOT_POCKET | SLOT_BELT
	handle_casings = HOLD_CASINGS
	move_delay = 4
	var/open = FALSE
	var/recentpump = FALSE // to prevent spammage
	load_delay = 6
	blackpowder = TRUE

	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 40,

			MEDIUM_RANGE_STILL = 53*0.9,
			MEDIUM_RANGE_MOVING = 35*0.9,

			LONG_RANGE_STILL = 45*0.7,
			LONG_RANGE_MOVING = 30*0.7,

			VERY_LONG_RANGE_STILL = 38*0.5,
			VERY_LONG_RANGE_MOVING = 25*0.5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 64,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 56*0.9,
			MEDIUM_RANGE_MOVING = 38*0.9,

			LONG_RANGE_STILL = 49*0.7,
			LONG_RANGE_MOVING = 32*0.7,

			VERY_LONG_RANGE_STILL = 41*0.5,
			VERY_LONG_RANGE_MOVING = 27*0.5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 68,
			SHORT_RANGE_MOVING = 44,

			MEDIUM_RANGE_STILL = 60*0.9,
			MEDIUM_RANGE_MOVING = 40*0.9,

			LONG_RANGE_STILL = 53*0.7,
			LONG_RANGE_MOVING = 35*0.7,

			VERY_LONG_RANGE_STILL = 45*0.5,
			VERY_LONG_RANGE_MOVING = 30*0.5),
	)
/obj/item/weapon/gun/projectile/revolver/derringer/spin_cylinder()
	return
/obj/item/weapon/gun/projectile/revolver/derringer/consume_next_projectile()
	if (chambered)
		return chambered.BB
	return null
/obj/item/weapon/gun/projectile/revolver/derringer/update_icon()
	..()
	if (open)
		icon_state = "derringer_opened"
	else
		icon_state = "derringer"

/obj/item/weapon/gun/projectile/revolver/derringer/attack_self(mob/living/user as mob)
	if (world.time >= recentpump + 10)
		if (open)
			open = FALSE
			user << "<span class='notice'>You close \the [src].</span>"
			icon_state = "derringer"
			if (loaded.len)
				var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
				loaded -= AC //Remove casing from loaded list.
				chambered = AC
		else
			open = TRUE
			user << "<span class='notice'>You break open \the [src].</span>"
			icon_state = "derringer_opened"
		recentpump = world.time

/obj/item/weapon/gun/projectile/revolver/derringer/load_ammo(var/obj/item/A, mob/user)
	if (!open)
		user << "<span class='notice'>You need to open \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/revolver/derringer/unload_ammo(mob/user, var/allow_dump=1)
	if (!open)
		user << "<span class='notice'>You need to open \the [src] first!</span>"
		return
	..()

/obj/item/weapon/gun/projectile/revolver/derringer/special_check(mob/user)
	if (open)
		user << "<span class='warning'>You can't fire \the [src] while it is break open!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/revolver/derringer/handle_post_fire()
	..()
	if (loaded.len)
		var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
		loaded -= AC //Remove casing from loaded list.
		chambered = AC
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))


/////////Revolving Rifle///////////
/obj/item/weapon/gun/projectile/revolving
	move_delay = 1
	fire_delay = 3
	name = "revolving rifle"
	desc = "A simple revolving rifle."
	icon_state = "revolver"
	item_state = "revolver"
	caliber = "a45"
//	origin_tech = list(TECH_COMBAT = 2, TECH_MATERIAL = 2)
	slot_flags = SLOT_BELT|SLOT_POCKET
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	ammo_type = /obj/item/ammo_casing/a45
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/revolver_fire.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE

	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 42,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 37,

			LONG_RANGE_STILL = 53,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 43,
			VERY_LONG_RANGE_MOVING = 23),

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
			SHORT_RANGE_STILL = 93,
			SHORT_RANGE_MOVING = 47,

			MEDIUM_RANGE_STILL = 83,
			MEDIUM_RANGE_MOVING = 42,

			LONG_RANGE_STILL = 73,
			LONG_RANGE_MOVING = 37,

			VERY_LONG_RANGE_STILL = 63,
			VERY_LONG_RANGE_MOVING = 32),
	)

	accuracy_increase_mod = 1.50
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "rifle"
	aim_miss_chance_divider = 2.50
	load_delay = 7

/obj/item/weapon/gun/projectile/revolving/verb/spin_cylinder()
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

/obj/item/weapon/gun/projectile/revolving/consume_next_projectile()
	if (chamber_offset)
		chamber_offset--
		return
	return ..()

/obj/item/weapon/gun/projectile/revolving/load_ammo(var/obj/item/A, mob/user)
	chamber_offset = 0
	return ..()


/obj/item/weapon/gun/projectile/revolving/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()
/obj/item/weapon/gun/projectile/revolving/attack_self(mob/user)
	if (single_action)
		if (!cocked)
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='warning'>[user] cocks the [src]!</span>","<span class='warning'>You cock the [src]!</span>")
			cocked = TRUE
		else
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='notice'>[user] uncocks the [src].</span>","<span class='notice'>You uncock the [src].</span>")
			cocked = FALSE

/obj/item/weapon/gun/projectile/revolving/special_check(mob/user)
	var/mob/living/carbon/human/H = user
	if (istype(H) && (H.faction_text == "INDIANS" || H.crab))
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE
	if (!cocked && single_action)
		user << "<span class='warning'>You can't fire \the [src] while the weapon is uncocked!</span>"
		return FALSE
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/revolving/handle_post_fire()
	..()
	if (single_action)
		cocked = FALSE
	else
		cocked = TRUE
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))

/obj/item/weapon/gun/projectile/revolving/unload_ammo(var/mob/living/carbon/human/user, allow_dump=0)
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

/obj/item/weapon/gun/projectile/revolving/colt
	name = "Colt Revolving Rifle"
	desc = "Officialy the M1855 Colt Single Action Revolving Carbine."
	icon_state = "revolving"
	item_state = "revolving"
	w_class = 2
	caliber = "a44"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c44
	weight = 5.0
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

///////////////////cap n ball revolvers/////////////////

/obj/item/weapon/gun/projectile/capnball
	move_delay = 1
	fire_delay = 3
	name = "revolver"
	desc = "A simple revolver."
	icon_state = "revolver"
	item_state = "revolver"
	caliber = "musketball_pistol"
//	origin_tech = list(TECH_COMBAT = 2, TECH_MATERIAL = 2)
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/revolver_fire.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE
	var/base_icon = null
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 58,
			SHORT_RANGE_MOVING = 39,

			MEDIUM_RANGE_STILL = 53,
			MEDIUM_RANGE_MOVING = 35,

			LONG_RANGE_STILL = 40,
			LONG_RANGE_MOVING = 25,

			VERY_LONG_RANGE_STILL = 30,
			VERY_LONG_RANGE_MOVING = 18),

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
	load_delay = 6

/obj/item/weapon/gun/projectile/capnball/update_icon()
	..()
	if (base_icon)
		if (cocked)
			icon_state = "[base_icon]_cocked"
		else
			icon_state = base_icon
/obj/item/weapon/gun/projectile/capnball/verb/spin_cylinder()
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

/obj/item/weapon/gun/projectile/capnball/consume_next_projectile()
	if (chamber_offset)
		chamber_offset--
		return
	return ..()

/obj/item/weapon/gun/projectile/capnball/load_ammo(var/obj/item/A, mob/user)
	chamber_offset = 0
	return ..()


/obj/item/weapon/gun/projectile/capnball/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()
/obj/item/weapon/gun/projectile/capnball/attack_self(mob/user)
	if (single_action)
		if (!cocked)
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='warning'>[user] cocks the [src]!</span>","<span class='warning'>You cock the [src]!</span>")
			cocked = TRUE
			update_icon()
		else
			playsound(loc, cocked_sound, 50, TRUE)
			visible_message("<span class='notice'>[user] uncocks the [src].</span>","<span class='notice'>You uncock the [src].</span>")
			cocked = FALSE
			update_icon()

/obj/item/weapon/gun/projectile/capnball/special_check(mob/user)
	var/mob/living/carbon/human/H = user
	if (istype(H) && (H.faction_text == "INDIANS" || H.crab))
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE
	if (!cocked && single_action)
		user << "<span class='warning'>You can't fire \the [src] while the weapon is uncocked!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/capnball/handle_post_fire()
	..()
	if (single_action)
		cocked = FALSE
	else
		cocked = TRUE
	if (blackpowder)
		spawn (1)
			new/obj/effect/effect/smoke/chem(get_step(src, dir))

/obj/item/weapon/gun/projectile/capnball/unload_ammo(var/mob/living/carbon/human/user, allow_dump=0)
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

/obj/item/weapon/gun/projectile/capnball/dragoon
	name = "Colt Dragoon"
	desc = "Officialy the M1848 Colt Percussion Cap Revolver."
	icon_state = "dragoon"
	base_icon = "dragoon"
	w_class = 2
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 40