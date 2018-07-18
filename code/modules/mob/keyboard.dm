/mob/verb/on_press_spacebar()

	set category = null

	if (!ishuman(src))
		return FALSE

	if (!istype(loc, /obj/tank))
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