/obj/item/weapon/beartrap
	name = "mechanical trap"
	throw_speed = 2
	throw_range = TRUE
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "beartrap0"
	desc = "A mechanically activated leg trap. Low-tech, but reliable. Looks like it could really hurt if you set it off."
	throwforce = WEAPON_FORCE_WEAK
	w_class = 3
//	origin_tech = "materials=1"
	matter = list(DEFAULT_WALL_MATERIAL = 18750)
	var/deployed = FALSE

/obj/item/weapon/beartrap/proc/can_use(mob/user)
	return (user.IsAdvancedToolUser() && !user.stat && !user.restrained())

/obj/item/weapon/beartrap/attack_self(mob/user as mob)
	..()
	if (!deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to deploy \the [src].</span>",
			"<span class='danger'>You begin deploying \the [src]!</span>",
			"You hear the slow creaking of a spring."
			)

		if (do_after(user, 60, src))
			user.visible_message(
				"<span class='danger'>\The [user] has deployed \the [src].</span>",
				"<span class='danger'>You have deployed \the [src]!</span>",
				"You hear a latch click loudly."
				)

			deployed = TRUE
			user.drop_from_inventory(src)
			update_icon()
			anchored = TRUE

/obj/item/weapon/beartrap/attack_hand(mob/user as mob)
	if (buckled_mob && can_use(user))
		user.visible_message(
			"<span class='notice'>[user] begins freeing [buckled_mob] from \the [src].</span>",
			"<span class='notice'>You carefully begin to free [buckled_mob] from \the [src].</span>",
			)
		if (do_after(user, 60, src))
			user.visible_message("<span class='notice'>[buckled_mob] has been freed from \the [src] by [user].</span>")
			unbuckle_mob()
			anchored = FALSE
	else if (deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to disarm \the [src].</span>",
			"<span class='notice'>You begin disarming \the [src]!</span>",
			"You hear a latch click followed by the slow creaking of a spring."
			)
		if (do_after(user, 60, src))
			user.visible_message(
				"<span class='danger'>[user] has disarmed \the [src].</span>",
				"<span class='notice'>You have disarmed \the [src]!</span>"
				)
			deployed = FALSE
			anchored = FALSE
			update_icon()
	else
		..()

/obj/item/weapon/beartrap/proc/attack_mob(mob/living/L)

	var/target_zone
	if (L.lying)
		target_zone = ran_zone()
	else
		target_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")

	//armour
	var/blocked = L.run_armor_check(target_zone, "melee")

	if (blocked >= 2)
		return

	if (!L.apply_damage(30, BRUTE, target_zone, blocked, used_weapon=src))
		return FALSE

	//trap the victim in place
	if (!blocked)
		set_dir(L.dir)
		can_buckle = TRUE
		buckle_mob(L)
		L << "<span class='danger'>The steel jaws of \the [src] bite into you, trapping you in place!</span>"
		deployed = FALSE
		can_buckle = initial(can_buckle)

/obj/item/weapon/beartrap/Crossed(AM as mob|obj)
	if (deployed && isliving(AM))
		var/mob/living/L = AM
		L.visible_message(
			"<span class='danger'>[L] steps on \the [src].</span>",
			"<span class='danger'>You step on \the [src]!</span>",
			"<b>You hear a loud metallic snap!</b>"
			)
		attack_mob(L)
		if (!buckled_mob)
			anchored = FALSE
		deployed = FALSE
		update_icon()
	..()

/obj/item/weapon/beartrap/update_icon()
	..()

	if (!deployed)
		icon_state = "beartrap0"
	else
		icon_state = "beartrap1"


/obj/item/weapon/punji_sticks
	name = "punji sticks trap"
	throw_speed = 2
	throw_range = TRUE
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "punji0"
	desc = "A simple hole with sharp sticks inside, covered with leaves. Deadly."
	throwforce = WEAPON_FORCE_WEAK
	w_class = 3
//	origin_tech = "materials=1"
	matter = list(DEFAULT_WALL_MATERIAL = 18750)
	var/deployed = FALSE

/obj/item/weapon/punji_sticks/proc/can_use(mob/user)
	return (user.IsAdvancedToolUser() && !user.stat && !user.restrained())

/obj/item/weapon/punji_sticks/attack_self(mob/user as mob)
	..()
	if (!deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to deploy \the [src].</span>",
			"<span class='danger'>You begin deploying \the [src]!</span>",
			)

		if (do_after(user, 120, src))
			user.visible_message(
				"<span class='danger'>\The [user] has deployed \the [src].</span>",
				"<span class='danger'>You have deployed \the [src]!</span>",
				)

			deployed = TRUE
			user.drop_from_inventory(src)
			update_icon()
			anchored = TRUE

/obj/item/weapon/punji_sticks/attack_hand(mob/user as mob)
	if (buckled_mob && can_use(user))
		user.visible_message(
			"<span class='notice'>[user] begins freeing [buckled_mob] from \the [src].</span>",
			"<span class='notice'>You carefully begin to free [buckled_mob] from \the [src].</span>",
			)
		if (do_after(user, 120, src))
			user.visible_message("<span class='notice'>[buckled_mob] has been freed from \the [src] by [user].</span>")
			unbuckle_mob()
			anchored = FALSE
	else if (deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to disarm \the [src].</span>",
			"<span class='notice'>You begin disarming \the [src]!</span>",
			)
		if (do_after(user, 90, src))
			user.visible_message(
				"<span class='danger'>[user] has disarmed \the [src].</span>",
				"<span class='notice'>You have disarmed \the [src]!</span>"
				)
			deployed = FALSE
			anchored = FALSE
			update_icon()
	else
		..()

/obj/item/weapon/punji_sticks/proc/attack_mob(mob/living/L)

	var/target_zone
	if (L.lying)
		target_zone = ran_zone()
	else
		target_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")

	//armour
	var/blocked = L.run_armor_check(target_zone, "melee")

	if (blocked >= 2)
		return

	if (!L.apply_damage(30, BRUTE, target_zone, blocked, used_weapon=src))
		return FALSE

	//trap the victim in place
	if (!blocked)
		set_dir(L.dir)
		can_buckle = TRUE
		buckle_mob(L)
		L << "<span class='danger'>You fall into the punji sticks trap, and are stuck!</span>"
		deployed = FALSE
		can_buckle = initial(can_buckle)

/obj/item/weapon/punji_sticks/Crossed(AM as mob|obj)
	if (deployed && isliving(AM))
		var/mob/living/L = AM
		L.visible_message(
			"<span class='danger'>[L] falls into \the [src].</span>",
			"<span class='danger'>You fall into \the [src]!</span>",
			)
		attack_mob(L)
		if (!buckled_mob)
			anchored = FALSE
		deployed = FALSE
		update_icon()
	..()

/obj/item/weapon/punji_sticks/update_icon()
	..()

	if (!deployed)
		icon_state = "punji2_sand"
	else
		icon_state = "punji1_sand"