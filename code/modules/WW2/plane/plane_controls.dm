/* the controls for the plane */

/obj/plane_part/plane_controls
	anchored = TRUE
	icon = null
	icon_state = null
	layer = MOB_LAYER - 0.01
	var/damage = FALSE
	var/max_damage = 100
	var/next_spam_allowed = -1
	var/heal_damage[2]
	var/datum/plane/master = null

/obj/plane_part/plane_controls/New(_master)
	..()
	master = _master
	if (!master)
		qdel(src)
		return

/obj/plane_part/plane_controls/attack_hand(var/mob/user as mob)
	return ..() // todo

/obj/plane_part/plane_controls/attackby(var/obj/item/weapon/W, var/mob/user as mob)

	if (!istype(W))
		return FALSE

	if (isplanevalidtool(W))
		if (istype(W, /obj/item/weapon/wrench) && !user.repairing_plane)
			plane_message("<span class = 'notice'>[user] starts to wrench in some loose parts on [my_name()].</span>")
			playsound(get_turf(src), 'sound/items/Ratchet.ogg', rand(75,100))
			user.repairing_plane = TRUE
			if (do_after(user, 50, src))
				plane_message("<span class = 'notice'>[user] wrenches in some loose parts on [my_name()]. It looks about [health_percentage()] healthy.</span>")
				damage = max(damage - heal_damage["wrench"], FALSE)
				user.repairing_plane = FALSE
			else
				user.repairing_plane = FALSE
		else if (istype(W, /obj/item/weapon/weldingtool) && !user.repairing_plane)
			var/obj/item/weapon/weldingtool/wt = W
			if (!wt.welding)
				return FALSE
			if (health_percentage_num() < 50)
				user << "<span class = 'warning'>The plane is too damaged to fix up with a welding tool. Use a wrench instead.</span>"
				return FALSE
			plane_message("<span class = 'notice'>[user] starts to repair damage on [my_name()] with their welding tool.</span>")
			playsound(get_turf(src), 'sound/items/Welder.ogg', rand(75,100))
			user.repairing_plane = TRUE
			if (do_after(user, 60, src))
				plane_message("<span class = 'notice'>[user] repairs some of the damage on [my_name()]. It looks about [health_percentage()] healthy.</span>")
				playsound(get_turf(src), 'sound/items/Welder2.ogg', rand(75,100))
				damage = max(damage - heal_damage["weldingtool"], FALSE)
				user.repairing_plane = FALSE
			else
				user.repairing_plane = FALSE
	else
		plane_message("<span class = 'danger'>[user] hits [my_name()] with [W]!</span>")
		playsound(get_turf(src), W.hitsound, 100)
		damage += W.force/20
		master.update_damage_status()
		if (prob(master.critical_damage_chance()))
			master.critical_damage()
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	return TRUE

// todo
/obj/plane_part/plane_controls/proc/receive_command_from(var/mob/user, x)
	if (!isliving(user) || user.stat == UNCONSCIOUS || user.stat == DEAD)
		return