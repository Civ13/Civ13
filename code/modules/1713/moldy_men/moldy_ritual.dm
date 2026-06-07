/obj/item/weapon/moldy_ritual
	name = "Grand Ritual Scroll"
	desc = "An ancient mold-ridden scroll. Reading it aloud will summon Lord Moldywart."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "scroll_summon"
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/moldy_ritual/attack_self(mob/living/user)
	if (!istype(user) || !user || user.stat)
		return

	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W) || !W.sabotage)
		to_chat(user, "<span class='warning'>The scroll crumbles to dust. The stars are not aligned.</span>")
		qdel(src)
		return

	if (!W.sabotage.ritual_unlocked || W.sabotage.ritual_completed)
		to_chat(user, "<span class='warning'>The scroll crumbles to dust. The ritual has already been completed.</span>")
		qdel(src)
		return

	if (!(user.client && (user.client.ckey in W.sabotage.member_ckeys)))
		to_chat(user, "<span class='warning'>The scroll crumbles to dust. You are not worthy.</span>")
		qdel(src)
		return

	to_chat(user, "<span class='notice'>You begin chanting the ancient words...</span>")

	if (do_after(user, 10 SECONDS))
		W.sabotage.complete_ritual(user)
		qdel(src)
	else
		to_chat(user, "<span class='warning'>Your chant is interrupted!</span>")
