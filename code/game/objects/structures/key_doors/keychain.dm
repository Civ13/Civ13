/obj/item/weapon/storage/belt/keychain
	var/list/keys = list()
	slot_flags = SLOT_ID|SLOT_BELT|SLOT_POCKET
	icon = 'icons/obj/key.dmi'
	icon_state = "keychain_0"
	name = "keychain"
	desc = "This holds your keys"
	w_class = ITEM_SIZE_TINY
	max_w_class = 1
	storage_slots = 20 // up to 20 keys can spawn
	max_storage_space = 1000 // more or less infinite space for stolen keys
	dropsound = 'sound/effects/drop_knife.ogg'

/obj/item/weapon/storage/belt/keychain/orient2hud(mob/user as mob)
	return FALSE

/obj/item/weapon/storage/belt/keychain/examine(mob/user)
	if (locate(src) in get_step(user, user.dir) || user.contents.Find(src))
		user << "<span class = 'notice'>[desc]. Right now it's holding [print_keys()].</span>"

/obj/item/weapon/storage/belt/keychain/proc/print_keys()
	if (keys.len == FALSE)
		return "nothing"
	else
		var/ret = ""
		for (var/obj/item/weapon/key/key in keys)
			ret = "[ret],[key]"
		return ret

/obj/item/weapon/storage/belt/keychain/New()
	..()
	update_icon_state()

/obj/item/weapon/storage/belt/keychain/open()
	return

/obj/item/weapon/storage/belt/keychain/proc/update_icon_state()
	switch (keys.len)
		if (0 to 3)
			icon_state = "keychain_[keys.len]"
		if (4 to INFINITY)
			icon_state = "keychain_many"

/obj/item/weapon/storage/belt/keychain/attack_hand(mob/user as mob)
	if (loc == user)
		if (!keys.len)
			return
		else
			var/obj/item/weapon/key/which = WWinput(user, "Take out which key?", "Keychain", keys[1], keys)
			if (which && which.loc == src && (loc == user || locate(src) in get_step(user, user.dir) || locate(src) in get_turf(user)))
				user.put_in_hands(which)
				keys -= which
				update_icon_state()
				visible_message("<span class = 'notice'>[user] takes a key from their keychain.</span>", "<span class = 'notice'>You take out [which].</span>")
	else
		..(user)

/obj/item/weapon/storage/belt/keychain/attackby(obj/item/i as obj, mob/user as mob)
	if (!istype(i, /obj/item/weapon/key))
		return FALSE
	else
		var/obj/item/weapon/key/key = i
		if (can_be_inserted(key))
			handle_item_insertion(key)
			keys += key
			update_icon_state()
			visible_message("<span class = 'notice'>[user] puts a key in their keychain.</span>", "<span class = 'notice'>You put a key in your keychain.</span>")
		else
			user << "<span class = 'danger'>There's not enough space in the keychain!</span>"
