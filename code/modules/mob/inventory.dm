//This proc is called whenever someone clicks an inventory ui slot.
/mob/proc/attack_ui(slot)
	if (lying && !list(slot_l_hand, slot_r_hand).Find(slot))
		return
	var/obj/item/W = get_active_hand()
	var/obj/item/E = get_equipped_item(slot)
	if (istype(E))
		if (istype(W))
			E.attackby(W,src)
		else
			E.attack_hand(src)
	else
		equip_to_slot_if_possible(W, slot)
		if (W)
			W.on_changed_slot()

/mob/proc/put_in_any_hand_if_possible(obj/item/W as obj, del_on_fail = FALSE, disable_warning = TRUE, redraw_mob = TRUE, prioritize_active_hand = FALSE)
	if (!prioritize_active_hand)
		if (equip_to_slot_if_possible(W, slot_l_hand, del_on_fail, disable_warning, redraw_mob))
			return TRUE
		else if (equip_to_slot_if_possible(W, slot_r_hand, del_on_fail, disable_warning, redraw_mob))
			return TRUE
	else
		if (hand)
			if (equip_to_slot_if_possible(W, slot_l_hand, del_on_fail, disable_warning, redraw_mob))
				return TRUE
			else if (equip_to_slot_if_possible(W, slot_r_hand, del_on_fail, disable_warning, redraw_mob))
				return TRUE
		else
			if (equip_to_slot_if_possible(W, slot_r_hand, del_on_fail, disable_warning, redraw_mob))
				return TRUE
			else if (equip_to_slot_if_possible(W, slot_l_hand, del_on_fail, disable_warning, redraw_mob))
				return TRUE

	return FALSE


//This is a SAFE proc. Use this instead of equip_to_slot()!
//set del_on_fail to have it delete W if it fails to equip
//set disable_warning to disable the 'you are unable to equip that' warning.
//unset redraw_mob to prevent the mob from being redrawn at the end.
/mob/proc/equip_to_slot_if_possible(obj/item/W as obj, slot, del_on_fail = FALSE, disable_warning = FALSE, redraw_mob = TRUE)
	if (!istype(W)) return FALSE

	if (!W.mob_can_equip(src, slot))
		if (del_on_fail)
			qdel(W)
		else
			if (!disable_warning)
				src << "<span class = 'red'>You are unable to equip that.</span>" //Only print if del_on_fail is false
		return FALSE

	equip_to_slot(W, slot, redraw_mob) //This proc should not ever fail.
	return TRUE

//This is an UNSAFE proc. It merely handles the actual job of equipping. All the checks on whether you can or can't eqip need to be done before! Use mob_can_equip() for that task.
//In most cases you will want to use equip_to_slot_if_possible()
/mob/proc/equip_to_slot(obj/item/W as obj, slot)
	return FALSE

//This is just a commonly used configuration for the equip_to_slot_if_possible() proc, used to equip people when the rounds tarts and when events happen and such.
/mob/proc/equip_to_slot_or_del(obj/item/W as obj, slot)
	return equip_to_slot_if_possible(W, slot, TRUE, TRUE, FALSE)

/mob/proc/equip_to_slot_or_drop(obj/item/W as obj, slot)
	if (!equip_to_slot_if_possible(W, slot, TRUE, TRUE, FALSE))
		W.loc = get_turf(src)

//The list of slots by priority. equip_to_appropriate_slot() uses this list. Doesn't matter if a mob type doesn't have a slot.
var/list/slot_equipment_priority = list( \
		slot_shoulder,\
		slot_back,\
		slot_wear_id,\
		slot_w_uniform,\
		slot_wear_suit,\
		slot_wear_mask,\
		slot_head,\
		slot_shoes,\
		slot_gloves,\
		slot_eyes,\
		slot_l_ear,\
		slot_r_ear,\
		slot_belt,\
		slot_accessory,\
		slot_l_store,\
		slot_r_store\
	)

//Checks if a given slot can be accessed at this time, either to equip or unequip I
/mob/proc/slot_is_accessible(var/slot, var/obj/item/I, mob/user=null)
	return TRUE

//puts the item "W" into an appropriate slot in a human's inventory
//returns FALSE if it cannot, TRUE if successful
/mob/proc/equip_to_appropriate_slot(obj/item/W)
	if (!istype(W)) return FALSE

	for (var/slot in slot_equipment_priority)
		if (equip_to_slot_if_possible(W, slot, del_on_fail=0, disable_warning=1, redraw_mob=1))
			return TRUE

	return FALSE

/mob/proc/equip_to_storage(obj/item/newitem)
	// Try put it in their backpack
	if (istype(back,/obj/item/weapon/storage))
		var/obj/item/weapon/storage/backpack = back
		if (backpack.can_be_inserted(newitem, TRUE))
			newitem.forceMove(back)
			return TRUE

	// Try to place it in any item that can store stuff, on the mob.
	for (var/obj/item/weapon/storage/S in contents)
		if (S.can_be_inserted(newitem, TRUE))
			newitem.forceMove(S)
			return TRUE

	return FALSE

//These procs handle putting s tuff in your hand. It's probably best to use these rather than setting l_hand = ...etc
//as they handle all relevant stuff like adding it to the player's screen and updating their overlays.

//Returns the thing in our active hand
/mob/proc/get_active_hand()
	if (hand)	return l_hand
	else		return r_hand

//Returns the thing in our inactive hand
/mob/proc/get_inactive_hand()
	if (hand)	return r_hand
	else		return l_hand

//Puts the item into your l_hand if possible and calls all necessary triggers/updates. returns TRUE on success.
/mob/proc/put_in_l_hand(var/obj/item/W)
	if (lying || !istype(W))
		return FALSE
	W.pixel_x = initial(W.pixel_x)
	W.pixel_y = initial(W.pixel_y)
	W.layer = initial(W.layer)
	W.on_changed_slot()
	return TRUE

//Puts the item into your r_hand if possible and calls all necessary triggers/updates. returns TRUE on success.
/mob/proc/put_in_r_hand(var/obj/item/W)
	if (lying || !istype(W))
		return FALSE
	W.pixel_x = initial(W.pixel_x)
	W.pixel_y = initial(W.pixel_y)
	W.layer = initial(W.layer)
	W.on_changed_slot()
	return TRUE

//Puts the item into our active hand if possible. returns TRUE on success.
/mob/proc/put_in_active_hand(var/obj/item/W)
	return FALSE // Moved to human procs because only they need to use hands.

//Puts the item into our inactive hand if possible. returns TRUE on success.
/mob/proc/put_in_inactive_hand(var/obj/item/W)
	return FALSE // As above.

//Puts the item our active hand if possible. Failing that it tries our inactive hand. Returns TRUE on success.
//If both fail it drops it on the floor and returns 0.
//This is probably the main one you need to know :)
/mob/proc/put_in_hands(var/obj/item/W)
	if (!W)
		return FALSE
	W.forceMove(get_turf(src))
	W.layer = initial(W.layer)
	W.dropped()
	return FALSE

//Checks if mob has one or more empty hands, depending on input param:
//	both: if FALSE (false), it returns true if at least one hand is free, otherwise TRUE for checking both
/mob/proc/has_empty_hand(var/both = FALSE)
	if (both)
		return l_hand == null && r_hand == null
	return l_hand == null || r_hand == null

// Removes an item from inventory and places it in the target atom.
// If canremove or other conditions need to be checked then use unEquip instead.
/mob/proc/drop_from_inventory(var/obj/item/W, var/atom/Target = null, var/ignore_nodrop = FALSE)
	if (W)
		if (W.nodrop || W.nodrop_special_check() || ignore_nodrop)
			return FALSE

		if (!Target)
			Target = loc

		if (W.scoped_invisible)
			if (W.invisibility > 0)
				W.invisibility = FALSE

		if (istype(W, /obj/item/clothing/glasses) && ishuman(src))
			var/obj/item/clothing/glasses/G = W
			var/mob/living/carbon/human/user = src
			if(G.toggleable && G.active)
				G.active = 0
				G.icon_state = G.off_state
				user.update_inv_wear_mask()
				user.flash_protection = FLASH_PROTECTION_NONE
				G.tint = TINT_NONE
				if (G.overtype == "nvg")
					user.nvg = FALSE
					G.restricts_view = 0
					G.blocks_scope = FALSE
					user.handle_vision()
				else if (G.overtype == "thermal")
					user.thermal = FALSE
					G.restricts_view = 0
					G.blocks_scope = FALSE
					user.handle_vision()
		remove_from_mob(W)
		if (!(W && W.loc)) return TRUE // self destroying objects (tk, grabs)

		if (W.loc != Target)
			W.forceMove(Target, MOVED_DROP)
		if (istype(W, /obj/item/ammo_casing))
			var/obj/item/ammo_casing/NI = W
			NI.randomrotation()
		update_icons()
		return TRUE
	return FALSE

//removes all in a mob to the Target (or loc if no target). Ignores nodrop flags by default.
/mob/proc/strip(var/atom/Target = null, var/ignore_nodrop = FALSE)
	if (!Target)
		Target = loc
	for (var/obj/item/I in contents)
		if (!istype(I,/obj/item/organ))
			unEquip(I,ignore_nodrop,Target)
	return
//skips basic clothes
/mob/proc/strip_nobasics(var/atom/Target = null, var/ignore_nodrop = FALSE)
	if (!Target)
		Target = loc
	for (var/obj/item/I in contents)
		if (!istype(I,/obj/item/organ) && !istype(I,/obj/item/clothing/under))
			unEquip(I,ignore_nodrop,Target)
	return

//Drops the item in our left hand
/mob/proc/drop_l_hand(var/atom/Target)
	return drop_from_inventory(l_hand, Target)

//Drops the item in our right hand
/mob/proc/drop_r_hand(var/atom/Target)
	return drop_from_inventory(r_hand, Target)

/mob/proc/drop_inactive_hand(var/atom/Target)
	if (!hand)
		return drop_r_hand(Target)
	else if (hand)
		return drop_l_hand(Target)
	return FALSE

/mob/proc/drop_active_hand(var/atom/Target)
	return drop_item(Target)

//Drops the item in our active hand. TODO: rename this to drop_active_hand or something
/mob/proc/drop_item(var/atom/Target)
	if (hand)	return drop_l_hand(Target)
	else		return drop_r_hand(Target)

/*
	Removes the object from any slots the mob might have, calling the appropriate icon update proc.
	Does nothing else.

	DO NOT CALL THIS PROC DIRECTLY. It is meant to be called only by other inventory procs.
	It's probably okay to use it if you are transferring the item between slots on the same mob,
	but chances are you're safer calling remove_from_mob() or drop_from_inventory() anyways.

	As far as I can tell the proc exists so that mobs with different inventory slots can override
	the search through all the slots, without having to duplicate the rest of the item dropping.
*/
/mob/proc/u_equip(obj/W as obj)
	if (W == r_hand)
		r_hand = null
		update_inv_r_hand(0)
	else if (W == l_hand)
		l_hand = null
		update_inv_l_hand(0)
	else if (W == back)
		back = null
		update_inv_back(0)
	else if (W == wear_mask)
		wear_mask = null
		update_inv_wear_mask(0)
	else if (W == eyes)
		eyes = null
		update_inv_eyes(0)
	else if (W == shoulder)
		shoulder = null
		update_inv_shoulder(0)
	return

/mob/proc/isEquipped(obj/item/I)
	if (!I)
		return FALSE
	return get_inventory_slot(I) != FALSE

/mob/proc/canUnEquip(obj/item/I)
	if (!I) //If there's nothing to drop, the drop is automatically successful.
		return TRUE
	var/slot = get_inventory_slot(I)
	return slot && I.mob_can_unequip(src, slot)

/mob/proc/get_inventory_slot(obj/item/I)
	var/slot = FALSE
	for (var/s in slot_back to slot_accessory) //kind of worries me
		if (get_equipped_item(s) == I)
			slot = s
			break
	return slot

//This differs from remove_from_mob() in that it checks if the item can be unequipped first.
/mob/proc/unEquip(obj/item/I, force = FALSE, var/atom/Target = null) //Force overrides NODROP for things like wizarditis and admin undress.
	if (!(force || canUnEquip(I)))
		return
	drop_from_inventory(I,Target)
	return TRUE

//Attemps to remove an object on a mob.
/mob/proc/remove_from_mob(var/obj/O)
	u_equip(O)
	if (client)
		client.screen -= O
	O.layer = initial(O.layer)
	O.plane = GAME_PLANE
	O.screen_loc = null
	if (istype(O, /obj/item))
		var/obj/item/I = O
		I.forceMove(loc, MOVED_DROP)
		I.dropped(src)
	return TRUE


//Returns the item equipped to the specified slot, if any.
/mob/proc/get_equipped_item(var/slot)
	switch(slot)
		if (slot_l_hand) return l_hand
		if (slot_r_hand) return r_hand
		if (slot_back) return back
		if (slot_wear_mask) return wear_mask
	return null

//Outdated but still in use apparently. This should at least be a human proc.
/mob/proc/get_equipped_items()
	return list()
