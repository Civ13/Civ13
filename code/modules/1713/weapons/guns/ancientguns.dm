///for fire lances, hand cannons, arquebuses

obj/item/weapon/gun/projectile/ancient
	name = "ancient handgun"
	desc = "An ancient handheld blackpowder gun"
	icon_state = "handcannon"
	item_state = "musket"
	w_class = 5
	throw_range = 3
	throw_speed = 2
	force = 13
	throwforce = 8
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "stoneball"
	recoil = 5 //extra kickback
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/stoneball
	load_shell_sound = 'sound/weapons/clip_reload.ogg'
	accuracy = TRUE
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	move_delay = 5
	fire_delay = 12
	var/lighted = FALSE
	var/gunpowder = FALSE
	var/bullet = FALSE


	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 54,
			SHORT_RANGE_MOVING = 22,

			MEDIUM_RANGE_STILL = 33,
			MEDIUM_RANGE_MOVING = 12,

			LONG_RANGE_STILL = 12,
			LONG_RANGE_MOVING = 5,

			VERY_LONG_RANGE_STILL = 7,
			VERY_LONG_RANGE_MOVING = 3),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 60,
			SHORT_RANGE_MOVING = 29,

			MEDIUM_RANGE_STILL = 38,
			MEDIUM_RANGE_MOVING = 19,

			LONG_RANGE_STILL = 14,
			LONG_RANGE_MOVING = 8,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 72,
			SHORT_RANGE_MOVING = 36,

			MEDIUM_RANGE_STILL = 55,
			MEDIUM_RANGE_MOVING = 29,

			LONG_RANGE_STILL = 40,
			LONG_RANGE_MOVING = 19,

			VERY_LONG_RANGE_STILL = 31,
			VERY_LONG_RANGE_MOVING = 12),
	)

	load_delay = 200
	aim_miss_chance_divider = 3.00

obj/item/weapon/gun/projectile/ancient/firelance
	name = "fire lance"
	desc = "A spear with a gunpowder container near the tip, that can be filled with gunpowder and projectiles."
	icon_state = "firelance0"
	item_state = "firelance"
	recoil = 4
	throw_speed = 4
	throw_range = 7
	cooldownw = 11
	force = 25
	throwforce = 12
	sharp = TRUE
	edge = TRUE
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 54*0.78,
			SHORT_RANGE_MOVING = 22*0.78,

			MEDIUM_RANGE_STILL = 33*0.73,
			MEDIUM_RANGE_MOVING = 12*0.73,

			LONG_RANGE_STILL = 12*0.65,
			LONG_RANGE_MOVING = 5*0.65,

			VERY_LONG_RANGE_STILL = 7*0.5,
			VERY_LONG_RANGE_MOVING = 3*0.5),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 60*0.78,
			SHORT_RANGE_MOVING = 29*0.78,

			MEDIUM_RANGE_STILL = 38*0.73,
			MEDIUM_RANGE_MOVING = 19*0.73,

			LONG_RANGE_STILL = 14*0.65,
			LONG_RANGE_MOVING = 8*0.65,

			VERY_LONG_RANGE_STILL = 12*0.5,
			VERY_LONG_RANGE_MOVING = 5*0.5),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 72*0.78,
			SHORT_RANGE_MOVING = 36*0.78,

			MEDIUM_RANGE_STILL = 55*0.73,
			MEDIUM_RANGE_MOVING = 29*0.73,

			LONG_RANGE_STILL = 40*0.65,
			LONG_RANGE_MOVING = 19*0.65,

			VERY_LONG_RANGE_STILL = 31*0.5,
			VERY_LONG_RANGE_MOVING = 12*0.5),
	)

	load_delay = 150
	aim_miss_chance_divider = 1.50
obj/item/weapon/gun/projectile/ancient/handcannon
	name = "handcannon"
	desc = "A crude handcannon, consisting on a iron barrel with a wood stock attached."
	icon_state = "handcannon"
	item_state = "handcannon"

obj/item/weapon/gun/projectile/ancient/arquebus
	name = "arquebus"
	desc = "A iron barrel attached to a wood stock, with a piece of metal in the middle to hold the arquebus still, increasing accuracy."
	icon_state = "arquebus"
	item_state = "arquebus"
	attachment_slots = ATTACH_IRONSIGHTS | ATTACH_BARREL
	fire_delay = 9
	recoil = 4

	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 54*1.2,
			SHORT_RANGE_MOVING = 22*1.2,

			MEDIUM_RANGE_STILL = 33*1.25,
			MEDIUM_RANGE_MOVING = 12*1.25,

			LONG_RANGE_STILL = 12*1.3,
			LONG_RANGE_MOVING = 5*1.3,

			VERY_LONG_RANGE_STILL = 7*1.3,
			VERY_LONG_RANGE_MOVING = 3*1.3),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 60*1.2,
			SHORT_RANGE_MOVING = 29*1.2,

			MEDIUM_RANGE_STILL = 38*1.25,
			MEDIUM_RANGE_MOVING = 19*1.25,

			LONG_RANGE_STILL = 14*1.3*1.3,
			LONG_RANGE_MOVING = 8*1.3*1.3,

			VERY_LONG_RANGE_STILL = 12*1.3,
			VERY_LONG_RANGE_MOVING = 5*1.3),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 72*1.2,
			SHORT_RANGE_MOVING = 36*1.2,

			MEDIUM_RANGE_STILL = 55*1.25,
			MEDIUM_RANGE_MOVING = 29*1.25,

			LONG_RANGE_STILL = 40*1.3,
			LONG_RANGE_MOVING = 19*1.3,

			VERY_LONG_RANGE_STILL = 31*1.3,
			VERY_LONG_RANGE_MOVING = 12*1.3),
	)

obj/item/weapon/gun/projectile/ancient/matchlock
	name = "matchlock musket"
	desc = "A musket using the matchlock system, where lighted match acts as the fuse, activated by a trigger."
	icon_state = "matchlock"
	item_state = "matchlock"
	attachment_slots = ATTACH_IRONSIGHTS | ATTACH_BARREL
	fire_delay = 3
	recoil = 3

	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 83*0.9,
			SHORT_RANGE_MOVING = 42*0.9,

			MEDIUM_RANGE_STILL = 73*0.9,
			MEDIUM_RANGE_MOVING = 37*0.9,

			LONG_RANGE_STILL = 63*0.9,
			LONG_RANGE_MOVING = 32*0.9,

			VERY_LONG_RANGE_STILL = 53*0.85,
			VERY_LONG_RANGE_MOVING = 27*0.85),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 88*0.9,
			SHORT_RANGE_MOVING = 44*0.9,

			MEDIUM_RANGE_STILL = 78*0.9,
			MEDIUM_RANGE_MOVING = 39*0.9,

			LONG_RANGE_STILL = 68*0.9,
			LONG_RANGE_MOVING = 34*0.9,

			VERY_LONG_RANGE_STILL = 58*0.85,
			VERY_LONG_RANGE_MOVING = 29*0.85),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 93*0.9,
			SHORT_RANGE_MOVING = 47*0.9,

			MEDIUM_RANGE_STILL = 83*0.9,
			MEDIUM_RANGE_MOVING = 42*0.9,

			LONG_RANGE_STILL = 73*0.9,
			LONG_RANGE_MOVING = 37*0.9,

			VERY_LONG_RANGE_STILL = 63*0.85,
			VERY_LONG_RANGE_MOVING = 32*0.85),
	)
/obj/item/weapon/gun/projectile/ancient/attack_self(mob/user)
	return

/obj/item/weapon/gun/projectile/ancient/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/FL = W
		if (gunpowder && bullet && !lighted && FL.on)
			lighted = TRUE
			var/target = 0
			var/dirpick = pick(1,2,3,4,5,6)
			if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
				dirpick = pick(1,2,3)
			if (W.dir == NORTH)
				target = locate(user.x,user.y+dirpick,user.z)
			else if (W.dir == SOUTH)
				target = locate(user.x,user.y-dirpick,user.z)
			else if (W.dir == EAST)
				target = locate(user.x+dirpick,user.y,user.z)
			else if (W.dir == WEST)
				target = locate(user.x-dirpick,user.y,user.z)
			if (target)
				afterattack(target, user, FALSE)
			return
	else if (istype(W, /obj/item/stack/ammopart/stoneball))
		var/obj/item/stack/ammopart/stoneball/ST = W
		if (!bullet && gunpowder)
			user << "<span class='notice'>You begin loading \the [src] with \the [W]...</span>"
			if (do_after(user, 100, src, can_move = TRUE))
				if (bullet == FALSE)
					user << "<span class='notice'>You load \the [src].</span>"
					bullet = TRUE
					var/obj/item/ammo_casing/stoneball/SBL = new/obj/item/ammo_casing/stoneball
					loaded += SBL
					if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
						icon_state = "firelance1"
					if (istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
						icon_state = "matchlock_cocked"
						lighted = TRUE
					if (ST.amount == 1)
						qdel(W)
					else
						ST.amount -= 1
					return
			else
				return
		else if (bullet)
			user << "<span class='notice'>There is already a projectile inside.</span>"
			return
		else if (!gunpowder)
			user << "<span class='notice'>You need to put in the gunpowder first.</span>"
	else if (istype(W, /obj/item/weapon/reagent_containers))
		if (gunpowder)
			user << "<span class='notice'>The [src] is already packed with gunpowder.</span>"
			return
		else if (!W.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill \the [src].</span>"
			return
		else
			user << "<span class='notice'>You begin packing \the [src] with gunpowder...</span>"
			if (do_after(user, 100, src, can_move = TRUE))
				if (gunpowder == FALSE)
					if (W.reagents.has_reagent("gunpowder",1))
						user << "<span class='notice'>You finish packing \the [src] with gunpowder.</span>"
						W.reagents.remove_reagent("gunpowder",1)
						gunpowder = TRUE
						return
					else
						user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill \the [src].</span>"
						return
	else
		..()

/obj/item/weapon/gun/projectile/ancient/special_check(mob/user)
	if (!gunpowder)
		user << "<span class='warning'>You can't fire \the [src] without gunpowder!</span>"
		return FALSE
	if (!bullet)
		user << "<span class='warning'>You can't fire \the [src] without a projectile!</span>"
		return FALSE
	if (!lighted && !istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
		user << "<span class='warning'>You can't fire \the [src] without lighting it!</span>"
		return FALSE
	if (!(user.has_empty_hand(both = FALSE)) && istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/ancient/unload_ammo(mob/user, var/allow_dump=1)
	return
	// you cant, sorry
	..()

/obj/item/weapon/gun/projectile/ancient/handle_post_fire()
	..()
	loaded = list()
	chambered = null
	gunpowder = FALSE
	lighted = FALSE
	bullet = FALSE
	if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
		icon_state = "firelance0"
	if (istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
		icon_state = "matchlock"
	spawn (1)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (5)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (12)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))