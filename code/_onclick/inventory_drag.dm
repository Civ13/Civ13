/*
	Inventory drag-and-drop.

	Dragging an item onto another inventory moves it there:
	* onto a storage item, an open storage window, or an item shown inside an open
	  storage window: the item goes into that storage
	* onto an empty hand slot: the item is held in that hand
	* onto an empty equipment slot: the item is worn in that slot

	The item and the destination must both be within reach (carried, or in or on
	something on an adjacent tile), and every existing storage and equip rule still
	applies: capacity, can_hold/cant_hold, w_class, mob_can_equip, NODROP and the
	item's pickup delay (equiptimer).

	inventory_drag_transfer() returns TRUE when it handled the drop (moved the item or
	explained why it could not), and FALSE when the drop is not an inventory transfer,
	so the caller's normal MouseDrop behaviour runs instead.
*/

// Returns TRUE if A is carried by user, at any depth of nested items.
/proc/inventory_drag_carried_by(atom/movable/A, mob/user)
	var/atom/current = A.loc
	while (current && !isturf(current))
		if (current == user)
			return TRUE
		current = current.loc
	return FALSE

// Returns TRUE if user can reach A: carried, or inside items resting next to user.
/proc/inventory_drag_in_reach(atom/movable/A, mob/user)
	var/atom/movable/current = A
	while (current)
		var/atom/L = current.loc
		if (L == user)
			return TRUE
		if (isturf(L))
			return current.Adjacent(user)
		if (!istype(L, /obj/item))
			return FALSE
		current = L
	return FALSE

// Returns TRUE if container is A itself or holds A at any depth.
/proc/inventory_drag_contains(atom/container, atom/A)
	var/atom/current = A
	while (current && !isturf(current))
		if (current == container)
			return TRUE
		current = current.loc
	return FALSE

/obj/item/MouseDrop(atom/over_object, src_location, over_location, src_control, over_control, params)
	if (inventory_drag_transfer(over_object, usr))
		return
	return ..()

/obj/item/proc/inventory_drag_transfer(atom/over, mob/user)
	if (!over || over == src || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (H.incapacitated() || H.restrained())
		return FALSE
	if (extraction_surface_source)
		return FALSE
	if (!inventory_drag_in_reach(src, H))
		return FALSE
	// An item inside storage can only be dragged out of the storage window being shown.
	if (istype(loc, /obj/item/weapon/storage) && H.s_active != loc)
		return FALSE

	if (istype(over, /obj/screen/inventory))
		var/obj/screen/inventory/slot = over
		if (slot.parentmob != H || !slot.slot_id)
			return FALSE
		if (slot.slot_id == slot_l_hand || slot.slot_id == slot_r_hand)
			return inventory_drag_to_hand(slot.slot_id, H)
		return inventory_drag_to_slot(slot.slot_id, H)

	var/obj/item/weapon/storage/S = inventory_drag_target_storage(over, H)
	if (S)
		return inventory_drag_to_storage(S, H)
	return FALSE

// Works out which storage a drop onto over means, or null if it is not a storage drop.
/obj/item/proc/inventory_drag_target_storage(atom/over, mob/living/human/user)
	if (istype(over, /obj/screen/storage))
		var/obj/screen/storage/box = over
		if (istype(box.master, /obj/item/weapon/storage) && user.s_active == box.master)
			return box.master
		return null
	if (istype(over, /obj/item/weapon/storage))
		return over
	// Dropping onto an item shown in the open storage window means "into that storage".
	if (istype(over, /obj/item) && istype(over.loc, /obj/item/weapon/storage) && user.s_active == over.loc)
		return over.loc
	return null

// Applies the item's pickup delay when it is not already in the user's hands.
/obj/item/proc/inventory_drag_pickup_delay(mob/living/human/user)
	if (equiptimer <= 0 || user.item_is_in_hands(src))
		return TRUE
	if (!do_after(user, equiptimer, src, can_move = equiptimer))
		return FALSE
	return inventory_drag_in_reach(src, user)

// Takes the item out of wherever it is now (storage or floor) so it can be placed elsewhere.
// Returns the storage it came from, src's turf when it was on the floor, or null on failure.
/obj/item/proc/inventory_drag_take_out(mob/living/human/user)
	if (istype(loc, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/from = loc
		if (!from.remove_from_storage(src))
			return null
		return from
	if (isturf(loc))
		if (anchored)
			return null
		var/turf/T = loc
		pickup(user)
		throwing = FALSE
		return T
	return null

// Puts the item back where inventory_drag_take_out() found it after a failed placement.
/obj/item/proc/inventory_drag_put_back(atom/origin)
	if (istype(origin, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/from = origin
		if (loc != from && !from.handle_item_insertion(src, TRUE))
			persistence_set_loc(get_turf(from))

// Storage types whose attackby() adds rules beyond can_be_inserted() can refuse drag insertion here.
/obj/item/weapon/storage/proc/accepts_inventory_drag(obj/item/W, mob/user)
	return TRUE

/obj/item/proc/inventory_drag_to_storage(obj/item/weapon/storage/S, mob/living/human/user)
	if (loc == S || S == src)
		return TRUE
	if (inventory_drag_contains(src, S))
		to_chat(user, SPAN_NOTICE("You can't put \the [src] inside itself."))
		return TRUE
	if (!inventory_drag_in_reach(S, user))
		return FALSE
	if (!S.accepts_inventory_drag(src, user))
		return FALSE
	if (!S.can_be_inserted(src))
		return TRUE
	if (isturf(loc) && !inventory_drag_pickup_delay(user))
		return TRUE
	if (loc == S || !inventory_drag_in_reach(S, user) || !S.can_be_inserted(src, TRUE))
		return TRUE

	var/atom/origin = null
	if (istype(loc, /obj/item/weapon/storage))
		origin = inventory_drag_take_out(user)
		if (!origin)
			return TRUE
	add_fingerprint(user)
	if (!S.handle_item_insertion(src))
		inventory_drag_put_back(origin)
	return TRUE

/obj/item/proc/inventory_drag_hand_usable(slot, mob/living/human/user)
	var/obj/item/organ/external/hand = user.organs_by_name[slot == slot_l_hand ? "l_hand" : "r_hand"]
	if (!hand)
		to_chat(user, SPAN_NOTICE("You try to use your hand, but realise it is no longer attached!"))
		return FALSE
	if (!hand.is_usable())
		to_chat(user, SPAN_NOTICE("You try to move your [hand.name], but cannot!"))
		return FALSE
	return TRUE

/obj/item/proc/inventory_drag_to_hand(slot, mob/living/human/user)
	var/obj/item/held = user.get_equipped_item(slot)
	if (held == src)
		return TRUE
	if (held)
		to_chat(user, SPAN_NOTICE("You are already holding \the [held] in that hand."))
		return TRUE
	if (user.lying)
		return TRUE
	if (!inventory_drag_hand_usable(slot, user))
		return TRUE

	if (loc == user)
		// Already carried: from the other hand or an equipment slot.
		if (!user.canUnEquip(src))
			return TRUE
		user.u_equip(src)
	else
		if (!inventory_drag_pickup_delay(user))
			return TRUE
		if (user.get_equipped_item(slot) || !inventory_drag_in_reach(src, user))
			return TRUE
		var/atom/origin = inventory_drag_take_out(user)
		if (!origin)
			return TRUE
		if (!inventory_drag_put_in_hand(slot, user))
			inventory_drag_put_back(origin)
		return TRUE

	if (!inventory_drag_put_in_hand(slot, user))
		user.remove_from_mob(src)
	return TRUE

/obj/item/proc/inventory_drag_put_in_hand(slot, mob/living/human/user)
	var/placed = (slot == slot_l_hand) ? user.put_in_l_hand(src) : user.put_in_r_hand(src)
	if (placed)
		add_fingerprint(user)
	return placed

/obj/item/proc/inventory_drag_to_slot(slot, mob/living/human/user)
	if (user.get_equipped_item(slot))
		return FALSE
	if (loc == user && !user.item_is_in_hands(src))
		// Moving between two worn slots is left to the normal unequip/equip steps.
		return FALSE
	if (!mob_can_equip(user, slot))
		return TRUE

	if (user.item_is_in_hands(src))
		if (user.equip_to_slot_if_possible(src, slot))
			on_changed_slot()
		return TRUE

	if (!inventory_drag_pickup_delay(user))
		return TRUE
	if (user.get_equipped_item(slot) || !inventory_drag_in_reach(src, user) || !mob_can_equip(user, slot, TRUE))
		return TRUE
	var/atom/origin = inventory_drag_take_out(user)
	if (!origin)
		return TRUE
	if (user.equip_to_slot_if_possible(src, slot))
		add_fingerprint(user)
		on_changed_slot()
	else
		inventory_drag_put_back(origin)
	return TRUE
