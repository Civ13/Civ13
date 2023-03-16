/obj/item/bodybag
	name = "body bag"
	desc = "A folded bag designed for the storage and transportation of cadavers."
	icon = 'icons/obj/bodybag.dmi'
	icon_state = "bodybag_folded"
	w_class = ITEM_SIZE_SMALL

	attack_self(mob/user)
		var/obj/structure/closet/body_bag/R = new /obj/structure/closet/body_bag(user.loc)
		R.add_fingerprint(user)
		qdel(src)

/obj/item/weapon/storage/box/bodybags
	name = "body bags"
	desc = "This box contains body bags."
	New()
		..()
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)
		new /obj/item/bodybag(src)


/obj/structure/closet/body_bag
	name = "body bag"
	desc = "A plastic bag designed for the storage and transportation of cadavers."
	icon = 'icons/obj/bodybag.dmi'
	icon_state = "bodybag_closed"
	icon_closed = "bodybag_closed"
	icon_opened = "bodybag_open"
	open_sound = 'sound/items/zip.ogg'
	close_sound = 'sound/items/zip.ogg'
	var/item_path = /obj/item/bodybag
	density = FALSE
	storage_capacity = (MOB_MEDIUM * 2) - 1
	var/contains_body = FALSE

/obj/structure/closet/body_bag/attackby(W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen))
		var/t = WWinput(user, "What would you like the label to be?", text("[]", name), null, "text")
		if (user.get_active_hand() != W)
			return
		if (!in_range(src, user) && loc != user)
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if (t)
			name = "body bag - "
			name += t
			overlays += image(icon, "bodybag_label")
		else
			name = "body bag"
		return
	else if (istype(W, /obj/item/weapon/wirecutters))
		user << "You cut the tag off the bodybag"
		name = "body bag"
		overlays.Cut()
		return

/obj/structure/closet/body_bag/store_mobs(var/stored_units)
	contains_body = ..()
	return contains_body

/obj/structure/closet/body_bag/close()
	if (..())
		density = FALSE
		return TRUE
	return FALSE

/obj/structure/closet/body_bag/MouseDrop(over_object, src_location, over_location)
	..()
	if ((over_object == usr && (in_range(src, usr) || usr.contents.Find(src))))
		if (!ishuman(usr))	return
		if (opened)	return FALSE
		if (contents.len)	return FALSE
		visible_message("[usr] folds up the [name]")
		new item_path(get_turf(src))
		spawn(0)
			qdel(src)
		return

/obj/structure/closet/body_bag/update_icon()
	if (opened)
		icon_state = icon_opened
	else
		if (contains_body > 0)
			icon_state = "bodybag_closed1"
		else
			icon_state = icon_closed