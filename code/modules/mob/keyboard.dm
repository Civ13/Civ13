/mob/verb/on_press_spacebar()

	set category = null

	if (!ishuman(src))
		return FALSE

	if (!istype(loc, /obj/tank))
		if (istype(src, /mob/living/carbon/human/pillarman))
			var/mob/living/carbon/human/pillarman/P = src
			if (!P.frozen && P.client && P.client.canmove)
				if (P.next_shoot_burning_blood > world.time)
					P << "<span class = 'warning'>You can't shoot burning blood again yet.</span>"
					return
				P.shoot_burning_blood()
		else
			var/obj/item/weapon/attachment/scope/S = get_active_hand()
			if (S && istype(S))
				S.zoom(src)
				return
			else if (S && !istype(S) && locate_type(S.contents, /obj/item/weapon/attachment/scope))
				for (var/obj/item/weapon/attachment/scope/SS in S.contents)
					SS.zoom(src)
					return
	else
		var/obj/tank/tank = loc
		tank.receive_command_from(src, "FIRE")
		return TRUE
	return FALSE