///for fire lances, hand cannons, arquebuses

obj/item/weapon/gun/projectile/ancient
	name = "ancient handgun"
	desc = "An ancient handheld blackpowder gun"
	icon = 'icons/obj/guns/ancient.dmi'
	icon_state = "handcannon"
	item_state = "musket"
	w_class = ITEM_SIZE_HUGE
	throw_range = 3
	throw_speed = 2
	force = 13
	throwforce = 8
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "stoneball"
	shake_strength = 5 //extra kickback
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/stoneball
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
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
	gtype = "rifle"
	accuracy = 5

	load_delay = 200
	aim_miss_chance_divider = 3.00

obj/item/weapon/gun/projectile/ancient/firelance
	name = "fire lance"
	desc = "A spear with a gunpowder container near the tip, that can be filled with gunpowder and projectiles."
	icon_state = "firelance0"
	item_state = "firelance"
	shake_strength = 4
	throw_speed = 4
	throw_range = 7
	cooldownw = 11
	force = 25
	throwforce = 12
	sharp = TRUE
	edge = TRUE

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
	attachment_slots = ATTACH_IRONSIGHTS
	fire_delay = 9
	shake_strength = 4

obj/item/weapon/gun/projectile/ancient/matchlock
	name = "matchlock musket"
	desc = "A musket using the matchlock system, where lighted match acts as the fuse, activated by a trigger."
	icon_state = "matchlock"
	item_state = "matchlock"
	attachment_slots = ATTACH_IRONSIGHTS
	fire_delay = 3
	shake_strength = 3

obj/item/weapon/gun/projectile/ancient/jezailmatchlock
	name = "Jezail matchlock musket"
	desc = "A Arabic musket using the matchlock system, where lighted match acts as the fuse, activated by a trigger."
	icon_state = "matchlock"
	item_state = "matchlock_jezail"
	attachment_slots = ATTACH_IRONSIGHTS
	fire_delay = 3.2
	shake_strength = 2.8

obj/item/weapon/gun/projectile/ancient/tanegashima
	name = "tanegashima"
	desc = "A musket using the matchlock system, where lighted match acts as the fuse, activated by a trigger. This one being Japanese, introduced to them via the Portuguese."
	icon_state = "tanegashima"
	item_state = "tanegashima"
	attachment_slots = ATTACH_IRONSIGHTS
	fire_delay = 3
	shake_strength = 3

/obj/item/weapon/gun/projectile/ancient/attack_self(mob/user)
	return

/obj/item/weapon/gun/projectile/ancient/attackby(obj/W as obj, mob/user as mob)
	if (istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/FL = W
		if (gunpowder && bullet && !lighted && FL.on)
			lighted = TRUE
			var/turf/target = null
			var/dirpick = 6
			if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
				dirpick = 4
			if (user.dir == NORTH)
				target = locate(user.x,user.y+dirpick,user.z)
			else if (user.dir == SOUTH)
				target = locate(user.x,user.y-dirpick,user.z)
			else if (user.dir == EAST)
				target = locate(user.x+dirpick,user.y,user.z)
			else if (user.dir == WEST)
				target = locate(user.x-dirpick,user.y,user.z)
			if (target)
				afterattack(target, user, FALSE)
			return
	else if (istype(W, /obj/item/weapon/reagent_containers))
		if (gunpowder)
			user << "<span class='notice'>The [src] is already packed with gunpowder.</span>"
			return
		else if (!W.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill \the [src].</span>"
			return
		else
			user << "<span class='notice'>You begin packing \the [src] with gunpowder...</span>"
			if (ishuman(user))
				var/mob/living/human/H = user
				if (do_after(user, (60 / H.getStatCoeff(stat)), src, can_move = TRUE))
					if (!gunpowder)
						if (W.reagents.has_reagent("gunpowder",1))
							user << "<span class='notice'>You finish packing \the [src] with gunpowder.</span>"
							W.reagents.remove_reagent("gunpowder",1)
							gunpowder = TRUE
							return
						else
							user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill \the [src].</span>"
							return
			else
				if (do_after(user, 60, src, can_move = TRUE))
					if (!gunpowder)
						if (W.reagents.has_reagent("gunpowder",1))
							user << "<span class='notice'>You finish packing \the [src] with gunpowder.</span>"
							W.reagents.remove_reagent("gunpowder",1)
							gunpowder = TRUE
							return
						else
							user << "<span class = 'notice'>You need enough gunpowder in a gunpowder container in your hands to fill \the [src].</span>"
							return
	else if (istype(W, /obj/item/stack/ammopart/stoneball))
		var/obj/item/stack/ammopart/stoneball/ST = W
		if (!gunpowder)
			user << "<span class='notice'>You need to put in the gunpowder first.</span>"
		else if (bullet)
			user << "<span class='notice'>There is already a projectile inside.</span>"
			return
		else if (!bullet && gunpowder)
			user << "<span class='notice'>You begin loading \the [src] with \the [W]...</span>"
			if (ishuman(user))
				var/mob/living/human/H = user
				if (do_after(user, (100 / H.getStatCoeff(stat)), src, can_move = TRUE))
					if (!bullet)
						user << "<span class='notice'>You load \the [src].</span>"
						bullet = TRUE
						var/obj/item/ammo_casing/stoneball/SBL = new/obj/item/ammo_casing/stoneball
						loaded += SBL
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
							icon_state = "firelance1"
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
							icon_state = "matchlock_cocked"
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/tanegashima))
							icon_state = "tanegashima_cocked"
							lighted = TRUE
						if (ST.amount == 1)
							qdel(W)
						else
							ST.amount -= 1
						return
				else
					return
			else
				if (do_after(user, 100, src, can_move = TRUE))
					if (!bullet)
						user << "<span class='notice'>You load \the [src].</span>"
						bullet = TRUE
						var/obj/item/ammo_casing/stoneball/SBL = new/obj/item/ammo_casing/stoneball
						loaded += SBL
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/firelance))
							icon_state = "firelance1"
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock))
							icon_state = "matchlock_cocked"
						if (istype(src, /obj/item/weapon/gun/projectile/ancient/tanegashima))
							icon_state = "tanegashima_cocked"
							lighted = TRUE
						if (ST.amount == 1)
							qdel(W)
						else
							ST.amount -= 1
						return
				else
					return
	else
		..()

/obj/item/weapon/gun/projectile/ancient/special_check(mob/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.faction_text == INDIANS)
			user << "<span class='warning'>You don't know how to use this.</span>"
			return FALSE
	if (!gunpowder)
		user << "<span class='warning'>You can't fire \the [src] without gunpowder!</span>"
		return FALSE
	if (!bullet)
		user << "<span class='warning'>You can't fire \the [src] without a projectile!</span>"
		return FALSE
	if (!lighted && !istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock) && (/obj/item/weapon/gun/projectile/ancient/tanegashima))
		user << "<span class='warning'>You can't fire \the [src] without lighting it!</span>"
		return FALSE
	if (!(user.has_empty_hand(both = FALSE)) && istype(src, /obj/item/weapon/gun/projectile/ancient/matchlock) && (/obj/item/weapon/gun/projectile/ancient/tanegashima))
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
	if (istype(src, /obj/item/weapon/gun/projectile/ancient/tanegashima))
		icon_state = "tanegashima"
	spawn (1)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (5)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (12)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))