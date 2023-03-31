/obj/item/weapon/gun/projectile/revolver
	move_delay = 1
	fire_delay = 3
	icon = 'icons/obj/guns/pistols.dmi'
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
	fire_sound = 'sound/weapons/guns/fire/revolver.ogg'
	silencer_fire_sound = 'sound/weapons/guns/fire/Glock17-SD.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE
	var/base_icon = null
	equiptimer = 5
	gun_type = GUN_TYPE_PISTOL
	maxhealth = 55
	gtype = "pistol"
	load_method = SINGLE_CASING|SPEEDLOADER

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
	KD_chance = KD_CHANCE_MEDIUM
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
//	var/mob/living/human/H = user
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
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

/obj/item/weapon/gun/projectile/revolver/unload_ammo(var/mob/living/human/user, allow_dump=0)
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
	name = "M1895 Nagant"
	desc = "Russian officer's revolver."
	icon_state = "nagant"
	w_class = ITEM_SIZE_SMALL
	caliber = "a762x38"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c762x38mmR
	ammo_type = /obj/item/ammo_casing/a762x38
	weight = 1.45
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/nagant_revolver/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/revolver/m1892
	name = "Modèle 1892 Revolver"
	desc = "French officer's revolver."
	icon_state = "m1892"
	w_class = ITEM_SIZE_SMALL
	caliber = "a8x27"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c8x27
	ammo_type = /obj/item/ammo_casing/a8x27
	weight = 1.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5
	gun_safety = TRUE

/obj/item/weapon/gun/projectile/revolver/peacemaker
	name = "Colt Peacemaker"
	desc = "Officialy the M1873 Colt Single Action Army Revolver."
	icon_state = "coltsaa"
	base_icon = "peacemaker"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/peacemaker/ivory
	name = "Colt Peacemaker Ivory"
	desc = "Officialy the M1873 Colt Single Action Army Revolver with an Ivory grip."
	icon_state = "coltsaa_ivory"
	base_icon = "peacemaker"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 2.4
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/peacemaker/storekeeper
	name = "Colt Storekeeper"
	desc = "Officialy a variant of M1873 Colt Single Action Army Revolver."
	icon_state = "coltsaa_storekeeper"
	base_icon = "peacemaker"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 1.6
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/peacemaker/ivory
	name = "Colt Storekeeper Ivory"
	desc = "Officialy a variant of M1873 Colt Single Action Army Revolver with an Ivory grip."
	icon_state = "coltsaa_bankerspecial"
	base_icon = "peacemaker"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 1.6
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/peacemaker
	name = "Colt Peace Ivory"
	desc = "Officialy a variant of M1873 Colt Single Action Army Revolver with an Ivory grip."
	icon_state = "coltsaa_artillery"
	base_icon = "peacemaker"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 1.6
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/colt1892
	name = "Colt M1892"
	desc = "Officialy the M1892 Colt Single Action Army Revolver."
	icon_state = "colt1892"
	base_icon = "colt1892"
	w_class = ITEM_SIZE_SMALL
	caliber = "a38"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c38
	ammo_type = /obj/item/ammo_casing/a38
	weight = 2.3
	single_action = TRUE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/makeshift
	name = "Makeshift Revolver"
	desc = "A cheap makeshift revolver."
	icon_state = "makeshiftrevolver"
	base_icon = "makeshiftrevolver"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	ammo_type = /obj/item/ammo_casing/a45
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	pocket = TRUE

/obj/item/weapon/gun/projectile/revolver/coltpolicepositive
	name = "Colt Police Positive"
	desc = "Common revolver used by police."
	icon_state = "coltnewpolice"
	w_class = ITEM_SIZE_SMALL
	caliber = "a32"
	fire_sound = 'sound/weapons/guns/fire/32ACP.ogg'
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	equiptimer = 4
	good_mags = list(/obj/item/ammo_magazine/emptyspeedloader)
	magazine_type = /obj/item/ammo_magazine/c32
	ammo_type = /obj/item/ammo_casing/a32
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	pocket = TRUE
	effectiveness_mod = 0.93

/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized

/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/revolver/enfieldno2
	name = "Enfield No. 2"
	desc = "British revolver made with love."
	icon_state = "enfield02"
	w_class = ITEM_SIZE_SMALL
	caliber = "a41"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c41
	ammo_type = /obj/item/ammo_casing/a41
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/webley4
	name = "Webley Mk IV"
	desc = "British revolver chambered in (.455)."
	icon_state = "webley4"
	w_class = ITEM_SIZE_SMALL
	caliber = "a455"
	fire_sound = 'sound/weapons/guns/fire/45ACP.ogg'
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c455
	ammo_type = /obj/item/ammo_casing/a455
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/frontier
	name = "Colt Frontier"
	desc = "Officialy the M1873 Colt Single Action Army Revolver. This one uses .44 Winchester ammuniton."
	icon_state = "peacemaker2"
	base_icon = "peacemaker2"
	w_class = ITEM_SIZE_SMALL
	caliber = "a44"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c44
	ammo_type = /obj/item/ammo_magazine/c44
	weight = 2.3
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/graysonfito12
	name = "Mckellen M12"
	desc = "A expensive revolver made by Mckellen."
	icon_state = "graysonfito"
	base_icon = "graysonfito"
	w_class = ITEM_SIZE_SMALL
	caliber = "a44magnum"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c44magnum
	ammo_type = /obj/item/ammo_magazine/c44magnum
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/taurus
	name = "Taurus Judge Revolver"
	desc = "The Taurus Judge is a five shot revolver designed and produced by Taurus International, chambered for (.45 Colt)."
	icon_state = "judge"
	base_icon = "judge"
	w_class = ITEM_SIZE_SMALL
	caliber = "a45"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c45
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/magnum44
	name = "Magnum 44"
	desc = "A heavy revolver chambered in (magnum .44)."
	icon_state = "magnum58"
	base_icon = "magnum58"
	w_class = ITEM_SIZE_SMALL
	caliber = "a44magnum"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c44magnum

	good_mags = list(/obj/item/ammo_magazine/m44speedloader, /obj/item/ammo_magazine/emptyspeedloader)
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE

/obj/item/weapon/gun/projectile/revolver/magnum44/silenced/New()
	..()

	var/obj/item/weapon/attachment/silencer/pistol/SP = new/obj/item/weapon/attachment/silencer/pistol(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/revolver/smithwesson
	name = "Smith & Wesson Model 30"
	desc = "A smith 'n Wesson revolver, chambered in .32 S&W."
	icon_state = "smithwesson32"
	base_icon = "smithwesson32"
	w_class = ITEM_SIZE_TINY
	caliber = "a32"
	fire_sound = 'sound/weapons/guns/fire/32ACP.ogg'
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c32
	ammo_type = /obj/item/ammo_casing/a32
	weight = 1.6
	equiptimer = 3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	pocket = TRUE
	effectiveness_mod = 0.9

/obj/item/weapon/gun/projectile/revolver/sw3
	name = "Orbea Hermanos"
	desc = "A smith 'n Wesson revolver, chambered in .32 S&W. This being the spanish copy cat."
	icon_state = "snw3"
	base_icon = "snw3"
	w_class = ITEM_SIZE_TINY
	caliber = "a32"
	fire_sound = 'sound/weapons/guns/fire/32ACP.ogg'
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c32
	ammo_type = /obj/item/ammo_casing/a32
	weight = 1.6
	equiptimer = 3
	single_action = TRUE
	blackpowder = FALSE
	cocked = FALSE
	pocket = FALSE
	effectiveness_mod = 0.9
/obj/item/weapon/gun/projectile/revolver/snw10
	name = "Smith & Wesson M.10"
	desc = "A Smith 'n Wesson revolver model 10, chambered in .38 S&W."
	icon_state = "snw10"
	base_icon = "snw10"
	w_class = ITEM_SIZE_TINY
	caliber = "a38"
	fire_sound = 'sound/weapons/guns/fire/32ACP.ogg'
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_magazine/c38
	ammo_type = /obj/item/ammo_casing/a38
	weight = 1.6
	equiptimer = 3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	pocket = FALSE
	effectiveness_mod = 0.9

/obj/item/weapon/gun/projectile/revolver/t26_revolver
	name = "Type 26 revolver"
	desc = "Japanese officer's revolver."
	icon_state = "t26revolver"
	w_class = ITEM_SIZE_SMALL
	caliber = "c9mm_jap_revolver"
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	good_mags = list(/obj/item/ammo_magazine/emptyspeedloader)
	magazine_type = /obj/item/ammo_magazine/c9mm_jap_revolver
	ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
	weight = 2.3
	single_action = FALSE
	blackpowder = FALSE
	cocked = FALSE
	load_delay = 5

/obj/item/weapon/gun/projectile/revolver/panther
	name = "Panther revolver"
	desc = "a .44 caliber revolver."
	icon_state = "panther"
	item_state = "panther"
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/44Mag.ogg'
	caliber = "a44p"
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	magazine_type = /obj/item/ammo_magazine/c44p
	weight = 0.8
	load_delay = 6
	gun_safety = TRUE
	single_action = FALSE
	blackpowder = FALSE

/obj/item/weapon/gun/projectile/revolver/derringer
	name = "Derringer M95 pistol"
	desc = "Officialy the Remington Model 95, this small pistol has two barrels."
	icon_state = "derringer"
	item_state = "pistol"
	w_class = ITEM_SIZE_TINY
	caliber = "a41"
	fire_sound = 'sound/weapons/guns/fire/44Mag.ogg'
	magazine_type = /obj/item/ammo_magazine/c41
	ammo_type = /obj/item/ammo_casing/a41
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
	pocket = TRUE

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
		icon_state = "derringer_open"
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
			icon_state = "derringer_open"
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
	icon = 'icons/obj/guns/rifles.dmi'
	name = "revolving rifle"
	desc = "A simple revolving rifle."
	icon_state = "revolver"
	item_state = "revolver"
	caliber = "a45"
	slot_flags = SLOT_BELT|SLOT_POCKET
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	ammo_type = /obj/item/ammo_casing/a45
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/revolver.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE
	maxhealth = 45
	gtype = "rifle"

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
//	var/mob/living/human/H = user
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

/obj/item/weapon/gun/projectile/revolving/unload_ammo(var/mob/living/human/user, allow_dump=0)
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
	w_class = ITEM_SIZE_SMALL
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
	icon = 'icons/obj/guns/pistols.dmi'
	handle_casings = CYCLE_CASINGS
	max_shells = 7
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	magazine_based = FALSE
	var/single_action = FALSE
	var/cocked = FALSE
	var/base_icon = null
	gtype = "pistol"
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
//	var/mob/living/human/H = user
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

/obj/item/weapon/gun/projectile/capnball/unload_ammo(var/mob/living/human/user, allow_dump=0)
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
	name = "Colt Dragoon M1848"
	desc = "Officialy the M1848 Colt Percussion Cap Revolver."
	icon_state = "colt_dragoon1848"
	base_icon = "dragoon"
	w_class = ITEM_SIZE_SMALL
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

/obj/item/weapon/gun/projectile/capnball/babydragoon
	name = "Colt Baby Dragoon M1848"
	desc = "Officialy the Baby M1848 Colt Percussion Cap Revolver."
	icon_state = "dragoon"
	base_icon = "colt_babydragoon1848"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 1.9
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 45

/obj/item/weapon/gun/projectile/capnball/pocketpistol
	name = "Colt Pocket-Pistol M1849"
	desc = "Officialy the M1849 Colt Percussion Cap Pocket-Pistol."
	icon_state = "dragoon"
	base_icon = "colt_pocketmodel1849"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 1.5
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 30

/obj/item/weapon/gun/projectile/capnball/walker
	name = "Colt Walker M1846"
	desc = "Officialy the M1846 Colt Percussion Cap Walker."
	icon_state = "peacemaker2"
	base_icon = "colt_walker1846"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 2.2
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 40

/obj/item/weapon/gun/projectile/capnball/pocketm1849
	name = "Colt Police Pocket-Pistol M1849"
	desc = "Officialy the M1849 Colt Percussion Cap Pocket-Pistol used by police."
	icon_state = "peacemaker2"
	base_icon = "colt_pocketpolice1849"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 1.5
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 38

/obj/item/weapon/gun/projectile/capnball/navym1851
	name = "Colt Navy Revolver M1851"
	desc = "Officialy the M1851 Colt Navy Percussion Cap Revolver."
	icon_state = "peacemaker2"
	base_icon = "colt_navy1851"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 2.5
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 40

/obj/item/weapon/gun/projectile/capnball/navym1861
	name = "Colt Navy Revolver M1861"
	desc = "Officialy the M1861 Colt Navy Percussion Cap Revolver."
	icon_state = "peacemaker2"
	base_icon = "colt_navy1861"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 2.6
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 37

/obj/item/weapon/gun/projectile/capnball/
	name = "Colt Army Revolver M1860"
	desc = "Officialy the M1860 Colt Army Percussion Cap Revolver."
	icon_state = "peacemaker2"
	base_icon = "colt_army1860"
	w_class = ITEM_SIZE_SMALL
	caliber = "musketball_pistol"
	load_method = SINGLE_CASING
	handle_casings = CYCLE_CASINGS
	max_shells = 6
	magazine_type = /obj/item/ammo_casing/musketball_pistol
	weight = 2.6
	single_action = TRUE
	blackpowder = TRUE
	cocked = FALSE
	load_delay = 37