// Shared interaction lifecycle; damage and icons remain trap-specific.
/obj/item/weapon/trap_lifecycle
	var/deployed = FALSE
	var/deploy_time = 60
	var/free_time = 60
	var/disarm_time = 60
	var/deploy_start_sound
	var/deploy_finish_sound
	var/disarm_start_sound
	var/update_on_unhandled_hand = FALSE

/obj/item/weapon/trap_lifecycle/proc/can_use(mob/user)
	return (user.IsAdvancedToolUser() && !user.stat && !user.restrained())

/obj/item/weapon/trap_lifecycle/attack_self(mob/user as mob)
	..()
	if (!deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to deploy \the [src].</span>",
			"<span class='danger'>You begin deploying \the [src]!</span>",
			deploy_start_sound
			)

		if (do_after(user, deploy_time, src))
			user.visible_message(
				"<span class='danger'>\The [user] has deployed \the [src].</span>",
				"<span class='danger'>You have deployed \the [src]!</span>",
				deploy_finish_sound
				)

			deployed = TRUE
			user.drop_from_inventory(src)
			update_icon()
			anchored = TRUE

/obj/item/weapon/trap_lifecycle/attack_hand(mob/user as mob)
	if (buckled_mob && can_use(user))
		user.visible_message(
			"<span class='notice'>[user] begins freeing [buckled_mob] from \the [src].</span>",
			"<span class='notice'>You carefully begin to free [buckled_mob] from \the [src].</span>",
			)
		if (do_after(user, free_time, src))
			user.visible_message("<span class='notice'>[buckled_mob] has been freed from \the [src] by [user].</span>")
			unbuckle_mob()
			anchored = FALSE
	else if (deployed && can_use(user))
		user.visible_message(
			"<span class='danger'>[user] starts to disarm \the [src].</span>",
			"<span class='notice'>You begin disarming \the [src]!</span>",
			disarm_start_sound
			)
		if (do_after(user, disarm_time, src))
			if (!deployed || buckled_mob || !anchored)
				return
			user.visible_message(
				"<span class='danger'>[user] has disarmed \the [src].</span>",
				"<span class='notice'>You have disarmed \the [src]!</span>"
				)
			deployed = FALSE
			anchored = FALSE
			update_icon()
	else
		if (update_on_unhandled_hand)
			update_icon()
		..()

/obj/item/weapon/trap_lifecycle/proc/finish_trigger()
	if (!buckled_mob)
		anchored = FALSE
	deployed = FALSE
	update_icon()

/obj/item/weapon/beartrap
	name = "mechanical trap"
	throw_speed = 2
	throw_range = TRUE
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "beartrap0"
	desc = "A mechanically activated leg trap. Low-tech, but reliable. Looks like it could really hurt if you set it off."
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_NORMAL
	parent_type = /obj/item/weapon/trap_lifecycle
	deploy_start_sound = "You hear the slow creaking of a spring."
	deploy_finish_sound = "You hear a latch click loudly."
	disarm_start_sound = "You hear a latch click followed by the slow creaking of a spring."

/obj/item/weapon/beartrap/armed
	deployed = TRUE
	anchored = TRUE
	icon_state = "beartrap1"
	layer = 2

/obj/item/weapon/beartrap/proc/attack_mob(mob/living/L)

	var/target_zone
	if (L.lying)
		target_zone = ran_zone()
	else
		target_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")

	//armor
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
		to_chat(L, "<span class='danger'>The steel jaws of \the [src] bite into you, trapping you in place!</span>")
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
		finish_trigger()
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
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	parent_type = /obj/item/weapon/trap_lifecycle
	deploy_time = 120
	free_time = 120
	disarm_time = 90
	update_on_unhandled_hand = TRUE
	flags = FALSE

/obj/item/weapon/punji_sticks/proc/attack_mob(mob/living/L)
	var/target_zone
	if (L.lying)
		target_zone = ran_zone()
	else
		target_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")

	if (!L.apply_damage(90, BRUTE, target_zone, 0, used_weapon=src))
		return FALSE

	//trap the victim in place
	set_dir(L.dir)
	can_buckle = TRUE
	buckle_mob(L)
	to_chat(L, "<span class='danger'>You fall into the punji sticks trap, and are stuck!</span>")
	deployed = FALSE
	can_buckle = initial(can_buckle)

/obj/item/weapon/punji_sticks/Crossed(AM as mob|obj)
	if (deployed && isliving(AM))
		var/mob/living/L = AM
		L.visible_message(
			"<span class='danger'>[L] falls into \the [src].</span>",
			"<span class='danger'>You fall into \the [src]!</span>",
			)
		if (istype(L, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = L
			SA.adjustBruteLoss(rand(20,35))
			set_dir(SA.dir)
			can_buckle = TRUE
			buckle_mob(SA)
			can_buckle = initial(can_buckle)
		else
			attack_mob(L)
		finish_trigger()
	..()

/obj/item/weapon/punji_sticks/update_icon()
	..()

	if (!deployed)
		icon_state = "punji2_sand"
	else
		icon_state = "punji1_sand"
