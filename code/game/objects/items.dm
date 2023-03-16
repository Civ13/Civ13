/obj/item
	name = "item"
	icon = 'icons/obj/items.dmi'
	w_class = ITEM_SIZE_NORMAL
	layer = 3.01 // stops supply drop items from appearing under their crate
	mouse_drag_pointer = MOUSE_ACTIVE_POINTER

	var/nodrop = FALSE
	var/list/actions = list() //list of /datum/action's that this item has.
	var/image/blood_overlay = null //this saves our blood splatter overlay, which will be processed not to go over the edges of the sprite
	var/image/shit_overlay = null
	var/image/piss_overlay = null
	var/abstract = FALSE
	var/r_speed = 1.0
	var/health = null
	var/maxhealth
	var/burn_point = null
	var/burning = null
	var/hitsound = null
	var/storage_cost = null
	var/slot_flags = 0		//This is used to determine on which slots an item can fit.
	var/no_attack_log = FALSE			//If it's an item we don't want to log attack_logs with, set this to TRUE
	pass_flags = PASSTABLE
	var/obj/item/master = null
	var/list/attack_verb = list() //Used in attackby() to say how something was attacked "[x] has been [z.attack_verb] by [y] with [z]"
	var/force = FALSE
	var/amount = 1
	var/value = 0 //the cost of an item.

	var/fertilizer_value = 0 // the value as fertilizer

	var/sharpness = 0

	var/heat_protection = FALSE //flags which determine which body parts are protected from heat. Use the HEAD, UPPER_TORSO, LOWER_TORSO, etc. flags. See setup.dm
	var/cold_protection = FALSE //flags which determine which body parts are protected from cold. Use the HEAD, UPPER_TORSO, LOWER_TORSO, etc. flags. See setup.dm
	var/max_heat_protection_temperature //Set this variable to determine up to which temperature (IN KELVIN) the item protects against heat damage. Keep at null to disable protection. Only protects areas set by heat_protection flags
	var/min_cold_protection_temperature //Set this variable to determine down to which temperature (IN KELVIN) the item protects against cold damage. FALSE is NOT an acceptable number due to if (varname) tests!! Keep at null to disable protection. Only protects areas set by cold_protection flags

	var/datum/action/item_action/action = null
	var/action_button_name //It is also the text which gets displayed on the action button. If not set it defaults to 'Use [name]'. If it's not set, there'll be no button.
	var/action_button_is_hands_free = FALSE //If TRUE, bypass the restrained, lying, and stunned checks action buttons normally test for

	//This flag is used to determine when items in someone's inventory cover others. IE helmets making it so you can't see glasses, etc.
	//It should be used purely for appearance. For gameplay effects caused by items covering body parts, use body_parts_covered.
	var/flags_inv = FALSE
	var/body_parts_covered = FALSE //see setup.dm for appropriate bit flags

	var/item_flags = FALSE //Miscellaneous flags pertaining to equippable objects.

	//var/heat_transfer_coefficient = TRUE //0 prevents all transfers, TRUE is invisible
	var/gas_transfer_coefficient = TRUE // for leaking gas from turf to mask and vice-versa (for masks right now, but at some point, i'd like to include space helmets)
	var/permeability_coefficient = TRUE // for chemicals/diseases
	var/siemens_coefficient = TRUE // for electrical admittance/conductance (electrocution checks and shit)
	var/slowdown = FALSE // How much clothing is slowing you down. Negative values speeds you up
	var/canremove = TRUE //Mostly for Ninja code at this point but basically will not allow the item to be removed if set to 0. /N
	var/list/armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	var/zoomdevicename = null //name used for message when binoculars/scope is used

	var/icon_override = null  //Used to override hardcoded clothing dmis in human clothing proc.

	//** These specify item/icon overrides for _slots_

	var/list/item_state_slots = list() //overrides the default item_state for particular slots.

	// Used to specify the icon file to be used when the item is worn. If not set the default icon for that slot will be used.
	// If icon_override or sprite_sheets are set they will take precendence over this, assuming they apply to the slot in question.
	// Only slot_l_hand/slot_r_hand are implemented at the moment. Others to be implemented as needed.
	var/list/item_icons = list()
	var/wielded_icon = null
	var/worn_state = null

	var/dropsound = 'sound/effects/drop_default.ogg'

	// Weight variable
	var/weight = 0
	var/heavy = FALSE

	var/list/basematerials = list()

	var/equiptimer = 0 //if it takes some time to equip to a active hand (e.g. guns)

	var/dried_type = null //Item, that will appear after drying (or dehydrating) process
	var/dry_size = null //How many units will a drying item take in a dehydrator or dryer; dehydrator have 4 rows with 3 units each

/obj/item/New()
	maxhealth = health
	..()
	maxhealth = health

/obj/item/equipped()
	..()
	var/mob/M = loc
	if (!istype(M))
		return
	if (M.l_hand)
		M.l_hand.update_held_icon()
	if (M.r_hand)
		M.r_hand.update_held_icon()

/obj/item/Destroy()
	actions = list()
	if (ismob(loc))
		var/mob/m = loc
		m.drop_from_inventory(src)
		m.update_inv_r_hand()
		m.update_inv_l_hand()
		loc = null
	return ..()

/obj/item/proc/has_edge()
	. = FALSE
	if (edge)
		. = TRUE
	else
		if (istype(src, /obj/item/weapon/gun))
			var/obj/item/weapon/gun/G = src
			if (G.bayonet)
				. = TRUE

//Checks if the item is being held by a mob, and if so, updates the held icons
/obj/item/proc/update_held_icon()
	if (ismob(loc))
		var/mob/M = loc
		if (M.l_hand == src)
			M.update_inv_l_hand()
		else if (M.r_hand == src)
			M.update_inv_r_hand()

/obj/item/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return
		if (3.0)
			if (prob(5))
				qdel(src)
				return
		else
	return

/obj/item/examine(mob/user, var/distance = -1)
	var/size
	switch(w_class)
		if (1.0)
			size = "tiny"
		if (2.0)
			size = "small"
		if (3.0)
			size = "normal-sized"
		if (4.0)
			size = "bulky"
		if (5.0)
			size = "huge"
	return ..(user, distance, "", "It is a [size] item.")

/obj/item/attack_hand(mob/user as mob)
	if (isturf(loc) && anchored) return
	if (!user) return
	if (istype(user, /mob/living/human))
		var/mob/living/human/HM = user
		if (HM.werewolf && HM.body_build.name != "Default") return
	if (do_after(user,equiptimer, src, can_move = equiptimer))
		if (src in range(1,user))
			if (hasorgans(user))
				var/mob/living/human/H = user
				var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
				if (user.hand)
					temp = H.organs_by_name["l_hand"]
				if (temp && !temp.is_usable())
					user << "<span class='notice'>You try to move your [temp.name], but cannot!</span>"
					return
				if (!temp)
					user << "<span class='notice'>You try to use your hand, but realize it is no longer attached!</span>"
					return
			pickup(user)
			if (istype(loc, /obj/item/weapon/storage))
				var/obj/item/weapon/storage/S = loc
				S.remove_from_storage(src)

			throwing = FALSE
			if (loc == user)
				if (!user.unEquip(src))
					return
			else
				if (isliving(loc))
					return
			user.put_in_active_hand(src)
			pickup(user)
		else
			if (!isturf(src.loc))
				if (hasorgans(user))
					var/mob/living/human/H = user
					var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
					if (user.hand)
						temp = H.organs_by_name["l_hand"]
					if (temp && !temp.is_usable())
						user << "<span class='notice'>You try to move your [temp.name], but cannot!</span>"
						return
					if (!temp)
						user << "<span class='notice'>You try to use your hand, but realize it is no longer attached!</span>"
						return
				pickup(user)
				if (istype(loc, /obj/item/weapon/storage))
					var/obj/item/weapon/storage/S = loc
					S.remove_from_storage(src)

				throwing = FALSE
				if (loc == user)
					if (!user.unEquip(src))
						return
				else
					if (isliving(loc))
						return
				user.put_in_active_hand(src)
				pickup(user)
	return

// Due to storage type consolidation this should get used more now.
// I have cleaned it up a little, but it could probably use more.  -Sayu
/obj/item/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/storage))
		var/obj/item/weapon/storage/S = W
		if (S.use_to_pickup)
			if (S.collection_mode) //Mode is set to collect all items on a tile and we clicked on a valid one.
				if (isturf(loc))
					var/list/rejections = list()
					var/success = FALSE
					var/failure = FALSE

					for (var/obj/item/I in loc)
						if (I.type in rejections) // To limit bag spamming: any given type only complains once
							continue
						if (!S.can_be_inserted(I))	// Note can_be_inserted still makes noise when the answer is no
							rejections += I.type	// therefore full bags are still a little spammy
							failure = TRUE
							continue
						success = TRUE
						S.handle_item_insertion(I, TRUE)	//The TRUE stops the "You put the [src] into [S]" insertion message from being displayed.
					if (success && !failure)
						user << "<span class='notice'>You put everything in [S].</span>"
					else if (success)
						user << "<span class='notice'>You put some things in [S].</span>"
					else
						user << "<span class='notice'>You fail to pick anything up with \the [S].</span>"

			else if (S.can_be_inserted(src))
				S.handle_item_insertion(src)

	return

/obj/item/proc/talk_into(mob/M as mob, text)
	return

/obj/item/proc/moved(mob/user as mob, old_loc as turf)
	return

/obj/item/proc/nodrop_special_check()
	return FALSE

/obj/item/proc/nothrow_special_check()
	return FALSE

// apparently called whenever an item is removed from a slot, container, or anything else.
/obj/item/proc/dropped(mob/user as mob)
	..()
	plane = GAME_PLANE
	spawn (1)
		if (dropsound)
			if (!istype(src, /obj/item/clothing/mask/smokable) && !istype(src, /obj/item/weapon/paper) && !istype(src, /obj/item/weapon/pen))
				if (istype(loc, /turf) && (w_class > 1 || dropsound != 'sound/effects/drop_default.ogg'))
					playsound(loc, dropsound, 100, TRUE)
		if (istype(src, /obj/item/weapon/leech))
			new/mob/living/simple_animal/leech(src.loc)
			qdel(src)

// called just as an item is picked up (loc is not yet changed)
/obj/item/proc/pickup(mob/user)
	return

// called when this item is removed from a storage item, which is passed on as S. The loc variable is already set to the new destination before this is called.
/obj/item/proc/on_exit_storage(obj/item/weapon/storage/S as obj)
	return

// called when this item is added into a storage item, which is passed on as S. The loc variable is already set to the storage item.
/obj/item/proc/on_enter_storage(obj/item/weapon/storage/S as obj)
	if(istype(src,/obj))
		var/obj/O = src
		if(O.invisibility >= 100)
			O.invisibility = FALSE //Removes item's invisibility to prevent unclickable items in storage
	return

// called when we're equipped to a slot
/obj/item/proc/on_changed_slot()
	for (var/obj/item/I in contents)
		I.on_changed_slot()

// called when "found" in pockets and storage items. Returns TRUE if the search should end.
/obj/item/proc/on_found(mob/finder as mob)
	return

// called after an item is placed in an equipment slot
// user is mob that equipped it
// slot uses the slot_X defines found in setup.dm
// for items that can be placed in multiple slots
// note this isn't called during the initial dressing of a player
/obj/item/proc/equipped(var/mob/user, var/slot)
	layer = 20
	plane = HUD_PLANE
	if (user.client)	user.client.screen |= src
	if (user.pulling == src) user.stop_pulling()
	return

//Defines which slots correspond to which slot flags
var/list/global/slot_flags_enumeration = list(
	"[slot_wear_mask]" = SLOT_MASK,
	"[slot_back]" = SLOT_BACK,
	"[slot_wear_suit]" = SLOT_OCLOTHING,
	"[slot_gloves]" = SLOT_GLOVES,
	"[slot_shoes]" = SLOT_FEET,
	"[slot_shoulder]" = SLOT_SHOULDER,
	"[slot_belt]" = SLOT_BELT,
	"[slot_head]" = SLOT_HEAD,
	"[slot_l_ear]" = SLOT_EARS|SLOT_TWOEARS,
	"[slot_r_ear]" = SLOT_EARS|SLOT_TWOEARS,
	"[slot_w_uniform]" = SLOT_ICLOTHING,
	"[slot_wear_id]" = SLOT_ID,
	"[slot_eyes]" = SLOT_EYES,
	"[slot_accessory]" = SLOT_ACCESSORY,
	"[slot_shoulder]" = SLOT_SHOULDER,
	)

//the mob M is attempting to equip this item into the slot passed through as 'slot'. Return TRUE if it can do this and FALSE if it can't.
//If you are making custom procs but would like to retain partial or complete functionality of this one, include a 'return ..()' to where you want this to happen.
//Set disable_warning to TRUE if you wish it to not give you outputs.
//Should probably move the bulk of this into mob code some time, as most of it is related to the definition of slots and not item-specific
/obj/item/proc/mob_can_equip(M as mob, slot, disable_warning = FALSE)

	if (!slot) return FALSE
	if (!M) return FALSE

	if (!ishuman(M)) return FALSE

	var/mob/living/human/H = M
	var/list/mob_equip = list()
	if (H.species.hud && H.species.hud.equip_slots)
		mob_equip = H.species.hud.equip_slots

	if (H.species && !(slot in mob_equip))
		return FALSE

	if (H.crab && (slot == slot_shoes || slot == slot_gloves))
		return FALSE

	//First check if the item can be equipped to the desired slot.
	if ("[slot]" in slot_flags_enumeration)
		var/req_flags = slot_flags_enumeration["[slot]"]
		if (!(req_flags & slot_flags))
			return FALSE

	//Next check that the slot is free
	if (H.get_equipped_item(slot))
		return FALSE

	//Next check if the slot is accessible.
	var/mob/_user = disable_warning? null : H
	if (!H.slot_is_accessible(slot, src, _user))
		return FALSE
	var/obj/item/clothing/under/uniform = H.w_uniform
	//Lastly, check special rules for the desired slot.
	switch(slot)
		if (slot_l_ear, slot_r_ear)
			var/slot_other_ear = (slot == slot_l_ear)? slot_r_ear : slot_l_ear
			if ( (w_class > 1) && !(slot_flags & SLOT_EARS) )
				return FALSE
			if ( (slot_flags & SLOT_TWOEARS) && H.get_equipped_item(slot_other_ear) )
				return FALSE
		if (slot_wear_id)
			if (!H.w_uniform && (slot_w_uniform in mob_equip))
				if (!disable_warning)
					H << "<span class='warning'>You need clothes before you can hang this [name].</span>"
				return FALSE
		if (slot_l_store, slot_r_store)
			if (!H.w_uniform && (slot_w_uniform in mob_equip))
				if (!disable_warning)
					H << "<span class='warning'>You need clothes to put things in your pockets.</span>"
				return FALSE
			if ( w_class > 2 && (!(slot_flags & SLOT_POCKET) || istype(src,/obj/item/weapon/shield)))
				return FALSE
			if (istype(src, /obj/item/weapon/gun))
				var/obj/item/weapon/gun/G = src
				if (G.silencer || !G.pocket)
					H << "<span class='warning'>[G] doesn't fit in your pockets!</span>"
					return
		if (slot_handcuffed)
			if (!istype(src, /obj/item/weapon/handcuffs))
				return FALSE
		if (slot_legcuffed)
			if (!istype(src, /obj/item/weapon/legcuffs))
				return FALSE
		if (slot_in_backpack) //used entirely for equipping spawned mobs or at round start
			var/allow = FALSE
			if (H.back && istype(H.back, /obj/item/weapon/storage/backpack))
				var/obj/item/weapon/storage/backpack/B = H.back
				if (B.can_be_inserted(src,1))
					allow = TRUE
			if (!allow)
				return FALSE
		if (slot_accessory)
			if (!H.w_uniform && (slot_w_uniform in mob_equip))
				if (!disable_warning)
					H << "<span class='warning'>You need clothes before you can attach this [name].</span>"
				return FALSE
			if (uniform.accessories.len && !uniform.can_attach_accessory(src))
				if (!disable_warning)
					H << "<span class='warning'>You already have an accessory of this type attached to your [uniform].</span>"
				return FALSE
	return TRUE

/obj/item/proc/mob_can_unequip(mob/M, slot, disable_warning = FALSE)
	if (!slot) return FALSE
	if (!M) return FALSE
	if (istype(src, /obj/item/clothing/shoes/football) || istype(src, /obj/item/clothing/under/football))
		return FALSE
	if (!canremove)
		return FALSE
	if (!M.slot_is_accessible(slot, src, disable_warning? null : M))
		return FALSE
	return TRUE

/obj/item/verb/verb_pickup()
	set src in oview(1)
	set category = null
	set name = "Pick up"

	if (!(usr)) //BS12 EDIT
		return
	if (!usr.canmove || usr.stat || usr.restrained() || !Adjacent(usr))
		return
	if ((!istype(usr, /mob/living/human)))//Is humanoid, and is not a brain
		usr << "<span class='warning'>You can't pick things up!</span>"
		return
	if ( usr.stat || usr.restrained() )//Is not asleep/dead and is not restrained
		usr << "<span class='warning'>You can't pick things up!</span>"
		return
	if (anchored) //Object isn't anchored
		usr << "<span class='warning'>You can't pick that up!</span>"
		return
	if (!usr.hand && usr.r_hand) //Right hand is not full
		usr << "<span class='warning'>Your right hand is full.</span>"
		return
	if (usr.hand && usr.l_hand) //Left hand is not full
		usr << "<span class='warning'>Your left hand is full.</span>"
		return
	if (!istype(loc, /turf)) //Object is on a turf
		usr << "<span class='warning'>You can't pick that up!</span>"
		return
	//All checks are done, time to pick it up!
	usr.UnarmedAttack(src)
	return

//This proc is executed when someone clicks the on-screen UI button. To make the UI button show, set the 'icon_action_button' to the icon_state of the image of the button in screen1_action.dmi
//The default action is attack_self().
//Checks before we get to here are: mob is alive, mob is not restrained, paralyzed, asleep, resting, laying, item is on the mob.
/obj/item/proc/ui_action_click()
	attack_self(usr)

//RETURN VALUES
//handle_shield should return a positive value to indicate that the attack is blocked and should be prevented.
//If a negative value is returned, it should be treated as a special return value for bullet_act() and handled appropriately.
//For non-projectile attacks this usually means the attack is blocked.
//Otherwise should return FALSE to indicate that the attack is not affected in any way.
/obj/item/proc/handle_shield(mob/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	return FALSE

/obj/item/proc/eyestab(mob/living/human/M as mob, mob/living/human/user as mob)

	var/mob/living/human/H = M
	if (istype(H))
		for (var/obj/item/protection in list(H.head, H.wear_mask))
			if (protection && (protection.body_parts_covered & EYES))
				// you can't stab someone in the eyes wearing a mask!
				user << "<span class='warning'>You're going to need to remove the eye covering first.</span>"
				return

	if (!M.has_eyes())
		user << "<span class='warning'>You cannot locate any eyes on [M]!</span>"
		return

	user.attack_log += "\[[time_stamp()]\]<font color='red'> Attacked [M.name] ([M.ckey],[M.stat]) with [name] (INTENT: [uppertext(user.a_intent)])</font>"
	M.attack_log += "\[[time_stamp()]\]<font color='orange'> Attacked by [user.name] ([user.ckey]) with [name] (INTENT: [uppertext(user.a_intent)])</font>"
	msg_admin_attack("[user.name] ([user.ckey]) attacked [M.name] ([M.ckey]) with [name] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)") //BS12 EDIT ALG
	if (user.tactic == "rush")
		user.setClickCooldown(cooldownw*0.85)
	else
		user.setClickCooldown(cooldownw)
	user.do_attack_animation(M)

	add_fingerprint(user)

	if (istype(H))
		if (prob(80) && H != user)
			for (var/mob/O in (viewers(M) - user - M))
				O.show_message("<span class='warning'>[M] tried to stab [user] in the eyes but missed!</span>", TRUE)
			M << "<span class='warning'>[user] tried to stab you in the eyes but missed!</span>"
			user << "<span class='warning'>You tried to stab [M] in the eyes with [src] but missed!</span>"
			return

		var/obj/item/organ/eyes/eyes = H.internal_organs_by_name["eyes"]

		if (H != user)
			for (var/mob/O in (viewers(M) - user - M))
				O.show_message("<span class='danger'>[M] has been stabbed in the eye with [src] by [user].</span>", TRUE)
			M << "<span class='danger'>[user] stabs you in the eye with [src]!</span>"
			user << "<span class='danger'>You stab [M] in the eye with [src]!</span>"
		else
			user.visible_message( \
				"<span class='danger'>[user] has stabbed themself with [src]!</span>", \
				"<span class='danger'>You stab yourself in the eyes with [src]!</span>" \
			)

		eyes.damage += rand(3,4)
		if (eyes.damage >= eyes.min_bruised_damage)
			if (prob(50))
				if (M.stat != 2)
					M << "<span class='warning'>You drop what you're holding and clutch at your eyes!</span>"
					M.drop_item()
				M.eye_blurry += 10
				M.Paralyse(1)
				M.Weaken(3)
			if (eyes.damage >= eyes.min_broken_damage)
				if (M.stat != 2)
					M << "<span class='warning'>You go blind!</span>"
		var/obj/item/organ/external/affecting = H.get_organ("head")
		if (affecting.take_damage(7))
			M:UpdateDamageIcon()
	else
		M.take_organ_damage(7)
	M.eye_blurry += rand(3,4)
	return

/obj/item/clean_blood()
	. = ..()
	if (blood_overlay)
		overlays.Remove(blood_overlay)
	if (shit_overlay)
		overlays.Remove(shit_overlay)
		shit_overlay = null
	if (piss_overlay)
		overlays.Remove(piss_overlay)
		piss_overlay = null
	if (istype(src, /obj/item/clothing/gloves))
		var/obj/item/clothing/gloves/G = src
		G.transfer_blood = FALSE
	update_icon()
/obj/item/reveal_blood()
	if (was_bloodied && !fluorescent)
		fluorescent = TRUE
		blood_color = COLOR_LUMINOL
		blood_overlay.color = COLOR_LUMINOL
		update_icon()

/obj/item/add_blood(mob/living/human/M as mob)
	if (!..())
		return FALSE

/*	if (istype(src, /obj/item/weapon/melee/energy))
		return*/

	//if we haven't made our blood_overlay already
	if ( !blood_overlay )
		generate_blood_overlay()

	//apply the blood-splatter overlay if it isn't already in there
	if (!blood_DNA.len)
		blood_overlay.color = blood_color
		overlays += blood_overlay

	//if this blood isn't already in the list, add it
	if (istype(M))
		if (blood_DNA[M.dna.unique_enzymes])
			return FALSE //already bloodied with this blood. Cannot add more.
		blood_DNA[M.dna.unique_enzymes] = M.dna.b_type
	return TRUE //we applied blood to the item

/obj/item/proc/generate_blood_overlay()
	if (blood_overlay)
		return

	var/icon/I = new /icon(icon, icon_state)
	I.Blend(new /icon('icons/effects/blood.dmi', rgb(255,255,255)),ICON_ADD) //fills the icon_state with white (except where it's transparent)
	I.Blend(new /icon('icons/effects/blood.dmi', "itemblood"),ICON_MULTIPLY) //adds blood and the remaining white areas become transparant

	//not sure if this is worth it. It attaches the blood_overlay to every item of the same type if they don't have one already made.
	for (var/obj/item/A in world)
		if (A.type == type && !A.blood_overlay)
			A.blood_overlay = image(I)

/obj/item/proc/showoff(mob/user)
	for (var/mob/M in view(user))
		M.show_message("[user] holds up [src]. <a HREF=?src=\ref[M];lookitem=\ref[src]>Take a closer look.</a>",1)

/mob/living/human/verb/showoff()
	set name = "Show Held Item"
	set category = "IC"

	var/obj/item/I = get_active_hand()
	if (I && !I.abstract)
		I.showoff(src)

/obj/item/proc/pwr_drain()
	return FALSE // Process Kill

/obj/item/proc/get_weight()
	return weight


//Kicking an item
/obj/item/kick_act(var/mob/living/user)
	if(!..())
		return
	var/turf/target = get_turf(src.loc)
	var/range = throw_range
	var/throw_dir = get_dir(user, src)
	for(var/i = 1; i < range; i++)
		var/turf/new_turf = get_step(target, throw_dir)
		target = new_turf
		if(new_turf && new_turf.density)
			break
	throw_at(target, rand(1,3), throw_speed)
	user.visible_message("[user] kicks \the [src.name].")
