/obj/item/weapon/storage/belt/keychain
	slot_flags = SLOT_ID|SLOT_BELT|SLOT_POCKET
	icon = 'icons/obj/key.dmi'
	icon_state = "keychain_0"
	name = "keychain"
	desc = "This holds your keys"
	w_class = ITEM_SIZE_TINY
	max_w_class = 1
	can_hold = list(/obj/item/weapon/key)
	merges_stacks = FALSE
	storage_slots = 20 // up to 20 keys can spawn
	max_storage_space = 1000 // more or less infinite space for stolen keys
	dropsound = 'sound/effects/drop_knife.ogg'

/obj/item/weapon/storage/belt/keychain/orient2hud(mob/user as mob)
	return FALSE

/obj/item/weapon/storage/belt/keychain/examine(mob/user)
	if (locate(src) in get_step(user, user.dir) || user.contents.Find(src))
		to_chat(user, "<span class = 'notice'>[desc]. Right now it's holding [print_keys()].</span>")

/obj/item/weapon/storage/belt/keychain/proc/key_items()
	. = list()
	for (var/obj/item/weapon/key/key in contents)
		if (!QDELETED(key))
			. += key

/obj/item/weapon/storage/belt/keychain/proc/print_keys()
	var/list/names = list()
	for (var/obj/item/weapon/key/key in key_items())
		names += "[key]"
	return names.len ? english_list(names) : "nothing"

/obj/item/weapon/storage/belt/keychain/after_load()
	. = ..()
	update_icon()

/obj/item/weapon/storage/belt/keychain/open()
	return

/obj/item/weapon/storage/belt/keychain/update_icon()
	var/key_count = length(key_items())
	icon_state = key_count < 4 ? "keychain_[key_count]" : "keychain_many"
	return ..()

/obj/item/weapon/storage/belt/keychain/attack_hand(mob/user as mob)
	if (loc != user)
		return ..(user)
	var/list/choices = key_items()
	if (!choices.len)
		return
	var/obj/item/weapon/key/which = WWinput(user, "Take out which key?", "Keychain", choices[1], choices)
	if (!which || QDELETED(which) || !(which in choices) || which.loc != src)
		return
	if (!(loc == user || locate(src) in get_step(user, user.dir) || locate(src) in get_turf(user)))
		return
	user.put_in_hands(which)
	if (which.loc == src)
		return
	update_icon()
	visible_message("<span class = 'notice'>[user] takes a key from their keychain.</span>", "<span class = 'notice'>You take out [which].</span>")

// The old inventory drag stays disabled; the Storage Window uses shared storage.
/obj/item/weapon/storage/belt/keychain/accepts_inventory_drag(obj/item/W, mob/user)
	return FALSE

/obj/item/weapon/storage/belt/keychain/attackby(obj/item/key as obj, mob/user as mob)
	if (!istype(key, /obj/item/weapon/key))
		return FALSE
	if (!can_be_inserted(key))
		to_chat(user, "<span class = 'danger'>There's not enough space in the keychain!</span>")
		return FALSE
	if (!handle_item_insertion(key, TRUE))
		return FALSE
	visible_message("<span class = 'notice'>[user] puts a key in their keychain.</span>", "<span class = 'notice'>You put a key in your keychain.</span>")
