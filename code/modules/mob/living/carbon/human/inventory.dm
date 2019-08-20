/*
Add fingerprints to items when we put them in our hands.
This saves us from having to call add_fingerprint() any time something is put in a human's hands programmatically.
*/

/mob/living/carbon/human/verb/quick_equip()
	set name = "quick-equip"
	set hidden = TRUE

	if (!istype(src))
		return

	if (using_zoom())
		return

	var/obj/item/I = get_active_hand()
	if (!I)
		src << "<span class='notice'>You are not holding anything to equip.</span>"
		return
	if (equip_to_appropriate_slot(I))
		if (hand)
			update_inv_l_hand(0)
		else
			update_inv_r_hand(0)
	else
		src << "<span class = 'red'>You are unable to equip that.</span>"

//secondary Activate-Held-Object, when an object has more than a action possible (i.e. vehicle controls)
/client/verb/secondary_activation()
	set name = "secondary_activation"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return

	var/obj/item/I = mob.get_active_hand()
	if (!I)
		return
	if (!I.secondary_action)
		return
	I.secondary_attack_self(mob)
	return

//NUMPAD 8
/client/verb/zone_sel_head()
	set name = "zone_sel_head"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.targeted_organ != "head" && H.targeted_organ != "mouth" && H.targeted_organ != "eyes")
		H.targeted_organ = "head"
	else if (H.targeted_organ == "head")
		H.targeted_organ = "mouth"
	else if (H.targeted_organ == "mouth")
		H.targeted_organ = "eyes"
	else
		H.targeted_organ = "head"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 4
/client/verb/zone_sel_left_upper()
	set name = "zone_sel_left_upper"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.targeted_organ != "l_hand" && H.targeted_organ != "l_arm")
		H.targeted_organ = "l_arm"
	else if (H.targeted_organ == "l_arm")
		H.targeted_organ = "l_hand"
	else if (H.targeted_organ == "l_hand")
		H.targeted_organ = "l_arm"
	else
		H.targeted_organ = "l_arm"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 5
/client/verb/zone_sel_chest()
	set name = "zone_sel_chest"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	H.targeted_organ = "chest"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 6
/client/verb/zone_sel_right_upper()
	set name = "zone_sel_right_upper"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.targeted_organ != "r_hand" && H.targeted_organ != "r_arm")
		H.targeted_organ = "r_arm"
	else if (H.targeted_organ == "r_arm")
		H.targeted_organ = "r_hand"
	else if (H.targeted_organ == "r_hand")
		H.targeted_organ = "r_arm"
	else
		H.targeted_organ = "r_arm"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 1
/client/verb/zone_sel_left_lower()
	set name = "zone_sel_left_lower"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.targeted_organ != "l_foot" && H.targeted_organ != "l_leg")
		H.targeted_organ = "l_leg"
	else if (H.targeted_organ == "l_leg")
		H.targeted_organ = "l_foot"
	else if (H.targeted_organ == "l_foot")
		H.targeted_organ = "l_leg"
	else
		H.targeted_organ = "l_leg"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 2
/client/verb/zone_sel_groin()
	set name = "zone_sel_groin"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	H.targeted_organ = "groin"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
//NUMPAD 3
/client/verb/zone_sel_right_lower()
	set name = "zone_sel_right_lower"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.targeted_organ != "r_foot" && H.targeted_organ != "r_leg")
		H.targeted_organ = "r_leg"
	else if (H.targeted_organ == "r_leg")
		H.targeted_organ = "r_foot"
	else if (H.targeted_organ == "r_foot")
		H.targeted_organ = "r_leg"
	else
		H.targeted_organ = "r_leg"

	H.HUDneed["damage zone"].update_icon()
	H.HUDneed["random damage zone"].update_icon()
/mob/living/carbon/human/proc/equip_in_one_of_slots(obj/item/W, list/slots, del_on_fail = TRUE)
	for (var/slot in slots)
		if (equip_to_slot_if_possible(W, slots[slot], del_on_fail = FALSE))
			return slot
	if (del_on_fail)
		qdel(W)
	return null


/mob/living/carbon/human/proc/has_organ(name)
	var/obj/item/organ/external/O = organs_by_name[name]

	return (O && !O.is_stump())

/mob/living/carbon/human/proc/has_organ_for_slot(slot)
	switch(slot)
		if (slot_back)
			return has_organ("chest")
		if (slot_wear_mask)
			return has_organ("head")
		if (slot_handcuffed)
			return has_organ("l_hand") && has_organ("r_hand")
		if (slot_legcuffed)
			return has_organ("l_leg") && has_organ("r_leg")
		if (slot_l_hand)
			return has_organ("l_hand")
		if (slot_r_hand)
			return has_organ("r_hand")
		if (slot_belt)
			return has_organ("chest")
		if (slot_wear_id)
			// the only relevant check for this is the uniform check
			return TRUE
		if (slot_l_ear)
			return has_organ("head")
		if (slot_r_ear)
			return has_organ("head")
		if (slot_gloves)
			return has_organ("l_hand") || has_organ("r_hand")
		if (slot_head)
			return has_organ("head")
		if (slot_shoes)
			return has_organ("r_foot") || has_organ("l_foot")
		if (slot_wear_suit)
			return has_organ("chest")
		if (slot_w_uniform)
			return has_organ("chest")
		if (slot_l_store)
			return has_organ("chest")
		if (slot_r_store)
			return has_organ("chest")
		if (slot_in_backpack)
			return TRUE
		if (slot_shoulder)
			return TRUE
		if (slot_accessory)
			return TRUE
		if (slot_eyes)
			return TRUE

/mob/living/carbon/human/u_equip(obj/W as obj)
	if (!W)	return FALSE

	if (W == wear_suit)
		wear_suit = null
		update_inv_wear_suit()
		update_hair()
	else if (W == w_uniform)
		if (r_store)
			drop_from_inventory(r_store)
		if (l_store)
			drop_from_inventory(l_store)
		if (wear_id)
			drop_from_inventory(wear_id)
		if (belt)
			drop_from_inventory(belt)
		w_uniform = null
		update_inv_w_uniform()
	else if (W == gloves)
		gloves = null
		update_inv_gloves()
	else if (W == head)
		head = null
		if (istype(W, /obj/item))
			var/obj/item/I = W
			if (I.flags_inv & (HIDEMASK|BLOCKHAIR|BLOCKHEADHAIR))
				update_hair(0)	//rebuild hair
				update_inv_ears(0)
				update_inv_wear_mask(0)
		update_inv_head()
	else if (W == l_ear)
		l_ear = null
		update_inv_ears()
	else if (W == r_ear)
		r_ear = null
		update_inv_ears()
	else if (W == shoes)
		shoes = null
		update_inv_shoes()
	else if (W == eyes)
		eyes = null
		update_inv_eyes()
	else if (W == shoulder)
		shoulder = null
		update_inv_shoulder()
	else if (W == belt)
		belt = null
		update_inv_belt()
	else if (W == wear_mask)
		wear_mask = null
		if (istype(W, /obj/item))
			var/obj/item/I = W
			if (I.flags_inv & (BLOCKHAIR|BLOCKHEADHAIR))
				update_hair(0)	//rebuild hair
				update_inv_ears(0)
		update_inv_wear_mask()
	else if (W == wear_id)
		wear_id = null
		update_inv_wear_id()
	else if (W == r_store)
		r_store = null
		update_inv_pockets()
	else if (W == l_store)
		l_store = null
		update_inv_pockets()
	else if (W == back)
		back = null
		update_inv_back()
	else if (W == handcuffed)
		handcuffed = null
		if (buckled && buckled.buckle_require_restraints)
			buckled.unbuckle_mob()
		update_inv_handcuffed()
	else if (W == legcuffed)
		legcuffed = null
		update_inv_legcuffed()
	else if (W == r_hand)
		r_hand = null
		if (l_hand)
			l_hand.update_held_icon()
			update_inv_l_hand()
		update_inv_r_hand()
	else if (W == l_hand)
		l_hand = null
		if (r_hand)
			r_hand.update_held_icon()
			update_inv_l_hand()
		update_inv_l_hand()
	else
		return FALSE

	update_action_buttons()
	return TRUE



//This is an UNSAFE proc. Use mob_can_equip() before calling this one! Or rather use equip_to_slot_if_possible() or advanced_equip_to_slot_if_possible()
//set redraw_mob to FALSE if you don't wish the hud to be updated - if you're doing it manually in your own proc.
/mob/living/carbon/human/equip_to_slot(obj/item/W as obj, slot, redraw_mob = TRUE)

	if (!slot) return
	if (!istype(W)) return
	if (!has_organ_for_slot(slot)) return
	if (!species || !species.hud || !(slot in species.hud.equip_slots)) return
	W.forceMove(src)
	switch(slot)
		if (slot_back)
			back = W
			W.equipped(src, slot)
			update_inv_back(redraw_mob)
		if (slot_shoulder)
			shoulder = W
			W.equipped(src, slot)
			update_inv_shoulder(redraw_mob)
		if (slot_wear_mask)
			wear_mask = W
			if (wear_mask.flags_inv & (BLOCKHAIR|BLOCKHEADHAIR))
				update_hair(redraw_mob)	//rebuild hair
				update_inv_ears(0)
			W.equipped(src, slot)
			update_inv_wear_mask(redraw_mob)
		if (slot_handcuffed)
			handcuffed = W
			update_inv_handcuffed(redraw_mob)
		if (slot_legcuffed)
			legcuffed = W
			W.equipped(src, slot)
			update_inv_legcuffed(redraw_mob)
		if (slot_eyes)
			eyes = W
			W.equipped(src, slot)
			update_inv_eyes(redraw_mob)
		if (slot_l_hand)
			l_hand = W
			W.equipped(src, slot)
			update_inv_l_hand(redraw_mob)
		if (slot_r_hand)
			r_hand = W
			W.equipped(src, slot)
			update_inv_r_hand(redraw_mob)
		if (slot_shoulder)
			shoulder = W
			W.equipped(src, slot)
			update_inv_shoulder(redraw_mob)
		if (slot_belt)
			belt = W
			W.equipped(src, slot)
			update_inv_belt(redraw_mob)
		if (slot_wear_id)
			wear_id = W
			W.equipped(src, slot)
			update_inv_wear_id(redraw_mob)
		if (slot_l_ear)
			l_ear = W
			if (l_ear.slot_flags & SLOT_TWOEARS)
				var/obj/item/clothing/ears/offear/O = new(W)
				O.forceMove(src)
				r_ear = O
				O.layer = 20
			W.equipped(src, slot)
			update_inv_ears(redraw_mob)
		if (slot_r_ear)
			r_ear = W
			if (r_ear.slot_flags & SLOT_TWOEARS)
				var/obj/item/clothing/ears/offear/O = new(W)
				O.forceMove(src)
				l_ear = O
				O.layer = 20
			W.equipped(src, slot)
			update_inv_ears(redraw_mob)
		if (slot_gloves)
			gloves = W
			W.equipped(src, slot)
			update_inv_gloves(redraw_mob)
		if (slot_eyes)
			eyes = W
			W.equipped(src, slot)
			update_inv_eyes(redraw_mob)
		if (slot_head)
			head = W
			if (head.flags_inv & (BLOCKHAIR|BLOCKHEADHAIR|HIDEMASK))
				update_hair(redraw_mob)	//rebuild hair
				update_inv_ears(0)
				update_inv_wear_mask(0)
			W.equipped(src, slot)
			update_inv_head(redraw_mob)
		if (slot_shoes)
			shoes = W
			W.equipped(src, slot)
			update_inv_shoes(redraw_mob)
		if (slot_wear_suit)
			wear_suit = W
			if (wear_suit.flags_inv & HIDESHOES)
				update_inv_shoes(0)
			W.equipped(src, slot)
			update_inv_wear_suit(redraw_mob)
		if (slot_w_uniform)
			w_uniform = W
			W.equipped(src, slot)
			update_inv_w_uniform(redraw_mob)
		if (slot_l_store)
			l_store = W
			W.equipped(src, slot)
			update_inv_pockets(redraw_mob)
		if (slot_r_store)
			r_store = W
			W.equipped(src, slot)
			update_inv_pockets(redraw_mob)
		if (slot_in_backpack)
			if (get_active_hand() == W)
				remove_from_mob(W)
			W.forceMove(back)
		if (slot_accessory)
			var/obj/item/clothing/under/uniform = w_uniform
			uniform.attackby(W,src)
		else
			src << "<span class='danger'>You are trying to eqip this item to an unsupported inventory slot. If possible, please write a ticket with steps to reproduce. Slot was: [slot]</span>"
			return

	if ((W == l_hand) && (slot != slot_l_hand))
		l_hand = null
		update_inv_l_hand() //So items actually disappear from hands.
	else if ((W == r_hand) && (slot != slot_r_hand))
		r_hand = null
		update_inv_r_hand()

	W.layer = 20

	if (W.action_button_name)
		update_action_buttons()

	return TRUE

//Checks if a given slot can be accessed at this time, either to equip or unequip I
/mob/living/carbon/human/slot_is_accessible(var/slot, var/obj/item/I, mob/user=null)
	var/obj/item/covering = null
	var/check_flags = FALSE

	switch(slot)
		if (slot_wear_mask)
			covering = head
			check_flags = FACE
		if (slot_gloves, slot_w_uniform)
			covering = wear_suit

	if (covering && (covering.body_parts_covered & (I.body_parts_covered|check_flags)))
		user << "<span class='warning'>\The [covering] is in the way.</span>"
		return FALSE
	return TRUE

/mob/living/carbon/human/get_equipped_item(var/slot)
	switch(slot)
		if (slot_back)       return back
		if (slot_legcuffed)  return legcuffed
		if (slot_handcuffed) return handcuffed
		if (slot_l_store)    return l_store
		if (slot_r_store)    return r_store
		if (slot_wear_mask)  return wear_mask
		if (slot_l_hand)     return l_hand
		if (slot_r_hand)     return r_hand
		if (slot_wear_id)    return wear_id
		if (slot_gloves)     return gloves
		if (slot_head)       return head
		if (slot_shoes)      return shoes
		if (slot_belt)       return belt
		if (slot_wear_suit)  return wear_suit
		if (slot_w_uniform)  return w_uniform
		if (slot_l_ear)      return l_ear
		if (slot_r_ear)      return r_ear
		if (slot_eyes)       return eyes
		if (slot_shoulder)   return shoulder
	return ..()

/mob/living/carbon/human/get_equipped_items(var/include_carried = FALSE)
	var/list/items = new/list()

	if (back) items += back
	if (belt) items += belt
	if (l_ear) items += l_ear
	if (r_ear) items += r_ear
	if (gloves) items += gloves
	if (head) items += head
	if (shoes) items += shoes
	if (wear_id) items += wear_id
	if (wear_mask) items += wear_mask
	if (wear_suit) items += wear_suit
	if (w_uniform) items += w_uniform

	if (include_carried)
		if (slot_l_hand)     items += l_hand
		if (slot_r_hand)     items += r_hand
		if (slot_l_store)    items += l_store
		if (slot_r_store)    items += r_store
		if (slot_legcuffed)  items += legcuffed
		if (slot_handcuffed) items += handcuffed

	return items

/client/verb/m_intent_change()
	set name = "m-intent-change"
	set hidden = TRUE
	if (!mob)
		return
	if (ishuman(mob))
		if (mob.m_intent == "run")
			mob.m_intent = "proning"
		else if (mob.m_intent == "proning")
			if (mob.facing_dir)
				mob.set_face_dir()
			mob.m_intent = "stealth"
		else if (mob.m_intent == "stealth")
			mob.m_intent = "walk"
		else if (mob.m_intent == "walk")
			mob.m_intent = "run"
		else
			mob.m_intent = "walk"

		if (mob.m_intent == "proning")
			mob.prone = TRUE
			mob.facing_dir = dir
			if (mob.dir == NORTH || mob.dir == NORTHWEST || mob.dir == NORTHEAST || mob.dir == WEST)
				mob.dir = WEST
			else
				mob.dir = EAST
			var/matrix/M = matrix()
			M.Turn(90)
			var/mob/living/carbon/human/H = mob
			M.Scale(H.size_multiplier)
			M.Translate(1,-6)
			mob.transform = M
		else
			mob.prone = FALSE
			var/matrix/M = matrix()
			var/mob/living/carbon/human/H = mob
			M.Scale(H.size_multiplier)
			M.Translate(0, 16*(H.size_multiplier-1))
			mob.transform = M
		if (mob.HUDneed.Find("m_intent"))
			var/obj/screen/intent/I = mob.HUDneed["m_intent"]
			I.update_icon()
			return

/client/verb/secondary_intent_change()
	set name = "secondary-intent-change"
	set hidden = TRUE
	if (!mob)
		return
	if (ishuman(mob))
		var/mob/living/carbon/human/H = mob
		H.resist()
		switch (mob.middle_click_intent)
			if("kick")
				mob.middle_click_intent = "jump"
				mob << "<span class='warning'>You will now jump.</span>"
				var/obj/screen/intent/I = mob.HUDneed["secondary attack"]
				I.update_icon()
			if("jump")
				mob.middle_click_intent = "bite"
				mob << "<span class='warning'>You will now bite.</span>"
				var/obj/screen/intent/I = mob.HUDneed["secondary attack"]
				I.update_icon()
			if("bite")
				mob.middle_click_intent = "kick"
				mob << "<span class='warning'>You will now kick.</span>"
				var/obj/screen/intent/I = mob.HUDneed["secondary attack"]
				I.update_icon()
		return

/client/verb/defense_intent_change()
	set name = "defense-intent-change"
	set hidden = TRUE
	if (!mob)
		return
	if (ishuman(mob))
		if (mob.defense_intent == I_DODGE)
			mob.defense_intent = I_PARRY
			mob << "<span class='warning'>You will now parry.</span>"
			var/obj/screen/intent/I = mob.HUDneed["mode"]
			I.update_icon()
		else
			mob.defense_intent = I_DODGE
			mob << "<span class='warning'>You will now dodge.</span>"
			var/obj/screen/intent/I = mob.HUDneed["mode"]
			I.update_icon()

/client/verb/m_intent_run()
	set name = "m-intent-run"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.m_intent == "walk")
		mob.m_intent = "run"

	else if (H.m_intent == "run")
		mob.m_intent = "walk"

	else if (mob.m_intent == "proning")
		if (mob.facing_dir)
			mob.set_face_dir()
			mob.m_intent = "walk"
	else
		mob.m_intent = "walk"

	if (mob.HUDneed.Find("m_intent"))
		var/obj/screen/intent/I = mob.HUDneed["m_intent"]
		I.update_icon()


/client/verb/tactic_intent()
	set name = "tactic-intent"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = mob

	if (H.tactic == "charge")
		H.tactic = "aim"
		H << "<span class='warning'>You will now focus on aiming.</span>"
	else if (H.tactic == "aim")
		H.tactic = "rush"
		H << "<span class='warning'>You will now focus on rushing.</span>"
	else if (H.tactic == "rush")
		H.tactic = "defend"
		H << "<span class='warning'>You will now focus on defending.</span>"
	else if (H.tactic == "defend")
		H.tactic = "charge"
		H << "<span class='warning'>You will now focus on charging.</span>"
	else
		H.tactic = "charge"

	if (mob.HUDneed.Find("tactic"))
		var/obj/screen/tactic/I = mob.HUDneed["tactic"]
		I.update_icon()
