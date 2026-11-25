
/obj/item/weapon/soap
	name = "soap"
	desc = "A cheap bar of soap. Doesn't smell."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "soap"
	w_class = ITEM_SIZE_SMALL
	throwforce = FALSE
	throw_speed = 4
	throw_range = 20
	var/used = 0 //Times it have been used
	var/mood_boost_wait = 9000 //Around 15 minutes
	var/washing = FALSE
	flags = FALSE

/obj/item/weapon/soap/deluxe
	icon_state = "soapdeluxe"

/obj/item/weapon/soap/deluxe/New()
	desc = "A deluxe brand bar of soap. Smells of [pick("lavender", "vanilla", "strawberry")]."
	..()

/obj/item/weapon/soap/New()
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)
	..()

/obj/item/weapon/soap/lard
	name = "lard soap"
	desc = "A bit stinky and oily poorly shaped lard soap."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "soap_lard_1"
	w_class = ITEM_SIZE_SMALL
	throwforce = FALSE
	throw_speed = 4
	throw_range = 20

/mob/living/human
	var/soap_cooldown = 0 //Used to stop abuse from the mood boost that the soap gives

// Use the same reach, clothing and water rules before and after the wash.
/mob/living/human/proc/soap_wash_available(mob/user)
	if (QDELETED(src) || QDELETED(user) || (src != user && !user.Adjacent(src)) || !is_nude())
		return FALSE
	var/turf/T = get_turf(src)
	return T && (istype(user.loc, /turf/floor/beach/water) || bath_water_at(T) || (locate(/obj/structure/sink) in T.contents))

/mob/living/human/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (offline_sleep_refuses(user))
		return TRUE
	if (!istype(W, /obj/item/weapon/soap))
		return ..()
	var/obj/item/weapon/soap/S = W
	if (S.washing || !soap_wash_available(user))
		return
	if (src == user)
		user.visible_message("<span class='notice'>[user] starts to wash with \the [S.name]</span>", "<span class='notice'>You start to wash yourself with \the [S.name].</span>")
	else
		user.visible_message("<span class='notice'>[user] starts to wash [src.name] with \the [S.name]</span>", "<span class='notice'>You start to wash [src.name] with \the [S.name].</span>")
	S.washing = TRUE
	var/finished = do_after(user, 40, src)
	if (QDELETED(S))
		return
	S.washing = FALSE
	if (!finished || !soap_wash_available(user) || user.get_active_hand() != S || offline_sleep_refuses(user))
		return
	hygiene = HYGIENE_LEVEL_CLEAN
	if ((world.time - soap_cooldown >= S.mood_boost_wait) || !soap_cooldown)
		src.adjust_mood(10, "a good wash")
		to_chat(src, "You really enjoy bathing with the [S.name]. You feel much better!")
		soap_cooldown = world.time
	else
		to_chat(src, "You don't really enjoy bathing with the [S.name], you did that not long ago.")
	S.used += 1
	if (S.used >= 30)
		qdel(S)
	else
		S.update_icon()

/obj/item/weapon/soap/lard/update_icon()
	var/x
	switch(used)
		if(0 to 4)
			x = 1
		if(5 to 14)
			x = 2
		if(15 to 24)
			x = 3
		else
			x = 4
	icon_state = "soap_lard_[x]"
