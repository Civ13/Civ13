// Hotkeys that open worn storage without clicking its HUD slot. Each key
// cycles through the storages of its group: a press opens the first one, the
// next press opens the next, and a press on the last one closes it again.
// Keys are bound through the rebindable action catalog (OOC > Keybindings).

// Storage windows provided by one worn item: the item itself when it is a
// storage container, plus internal storages of the item and its accessories
// (suit pockets, chest webbing, leather harness, pouches, plate carriers).
/proc/worn_item_storages(obj/item/I)
	var/list/found = list()
	if (!I)
		return found
	if (istype(I, /obj/item/weapon/storage))
		found += I
	for (var/obj/item/weapon/storage/internal/S in I)
		found |= S
	if (istype(I, /obj/item/clothing))
		var/obj/item/clothing/C = I
		for (var/obj/item/A in C.accessories)
			for (var/obj/item/weapon/storage/internal/S in A)
				found |= S
	return found

// group: "all", "back", "belt" or "worn" (clothing attachments and pockets).
/mob/living/human/proc/worn_storage_group(group)
	var/list/items = list()
	switch (group)
		if ("back")
			items = list(back)
		if ("belt")
			items = list(belt)
		if ("worn")
			items = list(w_uniform, wear_suit, l_store, r_store)
		else
			items = list(back, belt, w_uniform, wear_suit, l_store, r_store)
	var/list/storages = list()
	for (var/obj/item/I in items)
		storages |= worn_item_storages(I)
	return storages

/mob/living/human/proc/cycle_worn_storage(group, empty_message)
	if (stat != CONSCIOUS || restrained() || incapacitated(INCAPACITATION_DISABLED_NO_REST))
		return
	if (using_look())
		return
	var/list/storages = worn_storage_group(group)
	if (!storages.len)
		to_chat(src, SPAN_NOTICE(empty_message))
		return
	var/index = s_active ? storages.Find(s_active) : 0
	if (index >= storages.len)
		s_active.close(src)
		return
	var/obj/item/weapon/storage/S = storages[index + 1]
	S.open(src)
	S.add_fingerprint(src)

/mob/living/human/verb/open_worn_storage()
	set name = "open-worn-storage"
	set hidden = TRUE
	cycle_worn_storage("all", "You are not wearing anything you can open.")

/mob/living/human/verb/open_back_storage()
	set name = "open-back-storage"
	set hidden = TRUE
	cycle_worn_storage("back", "You have nothing on your back that you can open.")

/mob/living/human/verb/open_belt_storage()
	set name = "open-belt-storage"
	set hidden = TRUE
	cycle_worn_storage("belt", "You have nothing on your belt slot that you can open.")

/mob/living/human/verb/open_clothing_storage()
	set name = "open-clothing-storage"
	set hidden = TRUE
	cycle_worn_storage("worn", "Your clothes have no harness, webbing, pouches or pockets you can open.")
