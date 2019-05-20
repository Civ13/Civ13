/mob/verb/on_press_spacebar()

	set category = null

	if (!ishuman(src))
		return FALSE
	if (istype(get_active_hand(), /obj/item/weapon/attachment/scope))
		var/obj/item/weapon/attachment/scope/S = get_active_hand()
		if (S && istype(S))
			S.zoom(src)
			return
	else if (istype(get_active_hand(), /obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = get_active_hand()
		if (locate_type(G.contents, /obj/item/weapon/attachment/scope))
			for (var/obj/item/weapon/attachment/scope/SS in G.contents)
				SS.zoom(src)
				return
	return FALSE