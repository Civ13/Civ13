/obj/item/clothing/accessory
	name = "tie"
	desc = "A neosilk clip-on tie."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "bluetie"
	item_state = ""	//no inhands
	slot_flags = SLOT_ACCESSORY
	w_class = ITEM_SIZE_SMALL
	var/slot = "decor"
	var/obj/item/clothing/has_suit = null		//the suit the tie may be attached to
	var/image/inv_overlay = null	//overlay used when attached to clothing.
	var/image/mob_overlay = null
	var/overlay_state = null
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	ripable = TRUE
	rag_amt = 1
/obj/item/clothing/accessory/Destroy()
	if (has_suit)
		on_removed()
	return ..()

/obj/item/clothing/accessory/proc/get_inv_overlay()
	if (!inv_overlay)
		if (!mob_overlay)
			get_mob_overlay()
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		inv_overlay = image(icon = mob_overlay.icon, icon_state = tmp_icon_state, dir = SOUTH)
	return inv_overlay

/obj/item/clothing/accessory/proc/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]")
		else
			mob_overlay = image("icon" = INV_ACCESSORIES_DEF_ICON, "icon_state" = "[tmp_icon_state]")
	return mob_overlay

//when user attached an accessory to S
/obj/item/clothing/accessory/proc/on_attached(var/obj/item/clothing/S, var/mob/user)
	if (!istype(S))
		return
	has_suit = S
	loc = has_suit
	has_suit.overlays += get_inv_overlay()

	user << "<span class='notice'>You attach \the [src] to \the [has_suit].</span>"
	add_fingerprint(user)

/obj/item/clothing/accessory/proc/on_removed(var/mob/user)
	if (!has_suit)
		return
	has_suit.overlays -= get_inv_overlay()
	has_suit = null
	if (user)
		usr.put_in_hands(src)
		add_fingerprint(user)
	else
		forceMove(get_turf(src))

//default attackby behaviour
/obj/item/clothing/accessory/attackby(obj/item/I, mob/user)
	..()

//default attack_hand behaviour
/obj/item/clothing/accessory/attack_hand(mob/user as mob)
	if (has_suit)
		return	//we aren't an object on the ground so don't call parent
	..()
