/obj/item/clothing
	name = "clothing"
	siemens_coefficient = 0.9
	var/flash_protection = FLASH_PROTECTION_NONE	// Sets the item's level of flash protection.
	var/tint = TINT_NONE							// Sets the item's level of visual impairment tint.
	var/list/species_restricted = null				// Only these species can wear this kit.
	var/gunshot_residue								// Used by forensics.
	var/initial_name = "clothing"					// For coloring

	var/list/accessories = list()
	var/list/valid_accessory_slots
	var/list/restricted_accessory_slots
	health = 18
	dropsound = 'sound/effects/drop_clothing.ogg'
	flammable = TRUE
	var/restricts_view = 0 //If it restricts the viewing cone - check hide.dmi: 0 means "combat". 1 means "helmet". 2 means "narrow"

//Updates the icons of the mob wearing the clothing item, if any.
/obj/item/clothing/proc/update_clothing_icon()
	return

// Aurora forensics port.
/obj/item/clothing/clean_blood()
	..()
	gunshot_residue = null

/obj/item/clothing/proc/check_health()
	if (health <= 0)
		visible_message("\The [src] falls apart!")
		if (istype(loc, /mob/living))
			var/mob/living/M = loc
			M.drop_from_inventory(src)
		qdel(src)
		return TRUE
	return FALSE
///////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet
	restricts_view = 1
	health = 35
// Ears: headsets, earmuffs and tiny objects
/obj/item/clothing/ears
	name = "ears"
	w_class = 1.0
	throwforce = 2
	slot_flags = SLOT_EARS

/obj/item/clothing/ears/attack_hand(mob/user as mob)
	if (!user) return

	if (loc != user || !istype(user,/mob/living/carbon/human))
		..()
		return

	var/mob/living/carbon/human/H = user
	if (H.l_ear != src && H.r_ear != src)
		..()
		return

	if (!canremove)
		return

	var/obj/item/clothing/ears/O
	if (slot_flags & SLOT_TWOEARS )
		O = (H.l_ear == src ? H.r_ear : H.l_ear)
		user.u_equip(O)
		if (!istype(src,/obj/item/clothing/ears/offear))
			qdel(O)
			O = src
	else
		O = src

	user.u_equip(src)

	if (O)
		user.put_in_hands(O)
		O.add_fingerprint(user)

	if (istype(src,/obj/item/clothing/ears/offear))
		qdel(src)

/obj/item/clothing/ears/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_ears()

/obj/item/clothing/ears/offear
	name = "Other ear"
	w_class = 5.0
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "block"
	slot_flags = SLOT_EARS | SLOT_TWOEARS

	New(var/obj/O)
		name = O.name
		desc = O.desc
		icon = O.icon
		icon_state = O.icon_state
		set_dir(O.dir)

/obj/item/clothing/ears/earmuffs
	name = "earmuffs"
	desc = "Protects your hearing from loud noises, and quiet ones as well."
	icon_state = "earmuffs"
	item_state = "earmuffs"
	slot_flags = SLOT_EARS | SLOT_TWOEARS

///////////////////////////////////////////////////////////////////////
//Glasses
/*
SEE_SELF  // can see self, no matter what
SEE_MOBS  // can see all mobs, no matter what
SEE_OBJS  // can see all objs, no matter what
SEE_TURFS // can see all turfs (and areas), no matter what
SEE_PIXELS// if an object is located on an unlit area, but some of its pixels are
          // in a lit area (via pixel_x,y or smooth movement), can see those pixels
BLIND     // can't see anything
*/
/obj/item/clothing/glasses
	name = "glasses"
	icon = 'icons/obj/clothing/glasses.dmi'
	w_class = 2.0
	body_parts_covered = EYES
	slot_flags = SLOT_EYES
	var/vision_flags = FALSE
	var/darkness_view = FALSE//Base human is 2
	var/see_invisible = -1
	var/obj/screen/overlay = null

/obj/item/clothing/glasses/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_eyes()

///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
//Gloves
/obj/item/clothing/gloves
	name = "gloves"
	gender = PLURAL //Carn: for grammarically correct text-parsing
	w_class = 2.0
	icon = 'icons/obj/clothing/gloves.dmi'
	icon_state = "leather"
	siemens_coefficient = 0.75
	var/wired = FALSE
	var/obj/item/weapon/cell/cell = FALSE
	var/clipped = FALSE
	body_parts_covered = HANDS
	slot_flags = SLOT_GLOVES
	attack_verb = list("challenged")

/obj/item/clothing/gloves/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_gloves()

// Called just before an attack_hand(), in mob/UnarmedAttack()
/obj/item/clothing/gloves/proc/Touch(var/atom/A, var/proximity)
	return FALSE // return TRUE to cancel attack_hand()

/obj/item/clothing/gloves/attackby(obj/item/weapon/W, mob/user)
	if (istype(W, /obj/item/weapon/wirecutters) || istype(W, /obj/item/weapon/surgery/scalpel))
		if (clipped)
			user << "<span class='notice'>The [src] have already been clipped!</span>"
			update_icon()
			return

		playsound(loc, 'sound/items/Wirecutter.ogg', 100, TRUE)
		user.visible_message("<span class = 'red'>[user] cuts the fingertips off of the [src].</span>","<span class = 'red'>You cut the fingertips off of the [src].</span>")

		clipped = TRUE
		name = "modified [name]"
		desc = "[desc]<br>They have had the fingertips cut off of them."
		return

///////////////////////////////////////////////////////////////////////
//Head
/obj/item/clothing/head
	name = "head"
	icon = 'icons/obj/clothing/hats.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_hats.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_hats.dmi',
		)
	body_parts_covered = HEAD
	slot_flags = SLOT_HEAD
	flags_inv = BLOCKHEADHAIR
	w_class = 2.0

	var/light_overlay = "helmet_light"
	var/light_applied
	var/brightness_on
	var/on = FALSE

/obj/item/clothing/head/attack_self(mob/user)
	if (brightness_on)
		if (!isturf(user.loc))
			user << "You cannot turn the light on while in this [user.loc]"
			return
		on = !on
		user << "You [on ? "enable" : "disable"] the helmet light."
		update_flashlight(user)
	else
		return ..(user)

/obj/item/clothing/head/proc/update_flashlight(var/mob/user = null)
	if (on && !light_applied)
		set_light(brightness_on)
		light_applied = TRUE
	else if (!on && light_applied)
		set_light(0)
		light_applied = FALSE
	update_icon(user)
	user.update_action_buttons()

/obj/item/clothing/head/attack_generic(var/mob/user)
	if (!istype(user) || !mob_wear_hat(user))
		return ..()

/obj/item/clothing/head/proc/mob_wear_hat(var/mob/user)
	return FALSE

/obj/item/clothing/head/update_icon(var/mob/user)

	overlays.Cut()
	var/mob/living/carbon/human/H
	if (istype(user,/mob/living/carbon/human))
		H = user

	if (on)

		// Generate object icon.
		if (!light_overlay_cache["[light_overlay]_icon"])
			light_overlay_cache["[light_overlay]_icon"] = image('icons/obj/light_overlays.dmi', light_overlay)
		overlays |= light_overlay_cache["[light_overlay]_icon"]

		// Generate and cache the on-mob icon, which is used in update_inv_head().
		var/cache_key = "[light_overlay][H ? "_[H.species.get_bodytype()]" : ""]"
		if (!light_overlay_cache[cache_key])
			light_overlay_cache[cache_key] = image('icons/mob/light_overlays.dmi', light_overlay)

	if (H)
		H.update_inv_head()

/obj/item/clothing/head/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_head()

///////////////////////////////////////////////////////////////////////
//Mask
/obj/item/clothing/mask
	name = "mask"
	icon = 'icons/obj/clothing/masks.dmi'
	body_parts_covered = HEAD
	slot_flags = SLOT_MASK
	body_parts_covered = FACE|EYES

	var/voicechange = FALSE
	var/list/say_messages
	var/list/say_verbs
	var/blocks_scope = FALSE

/obj/item/clothing/mask/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_wear_mask()

/obj/item/clothing/mask/proc/filter_air(datum/gas_mixture/air)
	return

///////////////////////////////////////////////////////////////////////
//Shoes
/obj/item/clothing/shoes
	name = "shoes"
	icon = 'icons/obj/clothing/shoes.dmi'
	desc = "Comfortable-looking shoes."
	gender = PLURAL //Carn: for grammarically correct text-parsing
	siemens_coefficient = 0.9
	body_parts_covered = FEET
	slot_flags = SLOT_FEET

	var/can_hold_knife = TRUE
	var/obj/item/holding

	permeability_coefficient = 0.50
	slowdown = SHOES_SLOWDOWN
	force = 2
	var/overshoes = FALSE

/obj/item/clothing/shoes/attack_hand(var/mob/M)
	if (holding)
		draw_knife()
	else return ..(M)

/obj/item/clothing/shoes/proc/draw_knife()
	set name = "Draw Hidden Weapon"
	set desc = "Pull out your boot knife or small pistol."
	set category = "IC"
	set src in usr

	if (!holding)
		return FALSE

	if (usr.stat || usr.restrained() || usr.incapacitated())
		return FALSE

	holding.forceMove(get_turf(usr))

	if (usr.put_in_hands(holding))
		usr.visible_message("<span class='danger'>\The [usr] pulls a [holding] out of their boot!</span>")
		holding = null
	else
		usr << "<span class='warning'>Your need an empty, unbroken hand to do that.</span>"
		holding.forceMove(src)

	if (!holding)
		verbs -= /obj/item/clothing/shoes/proc/draw_knife

	update_icon()
	return TRUE


/obj/item/clothing/shoes/attackby(var/obj/item/I, var/mob/user)
	if (can_hold_knife && istype(I, /obj/item/weapon/material/shard) || \
	 istype(I, /obj/item/weapon/material/kitchen/utensil) || \
	 istype(I, /obj/item/weapon/material/knife) || \
	 istype(I, /obj/item/weapon/gun/projectile/revolver/derringer) || \
	 istype(I, /obj/item/weapon/attachment/bayonet))
		if (holding)
			user << "<span class='warning'>\The [src] is already holding \a [holding].</span>"
			return
		user.unEquip(I)
		I.forceMove(src)
		holding = I
		user.visible_message("<span class='notice'>\The [user] shoves \a [I] into \the [src].</span>")
		verbs |= /obj/item/clothing/shoes/proc/draw_knife
		update_icon()
	else
		return ..()

/obj/item/clothing/shoes/proc/handle_movement(var/turf/walking, var/running)
	return

/obj/item/clothing/shoes/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_shoes()

///////////////////////////////////////////////////////////////////////
//Suit
/obj/item/clothing/suit
	icon = 'icons/obj/clothing/suits.dmi'
	name = "suit"
	var/fire_resist = T0C+100
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	slot_flags = SLOT_OCLOTHING
	var/blood_overlay_type = "suit"
	siemens_coefficient = 0.9
	w_class = 3

/obj/item/clothing/suit/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_wear_suit()

///////////////////////////////////////////////////////////////////////
//Under clothing
/obj/item/clothing/under
	icon = 'icons/obj/clothing/uniforms.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_uniforms.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_uniforms.dmi',
		)
	name = "under"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	permeability_coefficient = 0.90
	slot_flags = SLOT_ICLOTHING
	armor = list(melee = FALSE, arrow = FALSE, gun = FALSE, energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	w_class = 3
	//var/has_sensor = TRUE //For the crew computer 2 = unable to change mode
//	var/sensor_mode = FALSE
		/*
		1 = Report living/dead
		2 = Report detailed damages
		3 = Report location
		*/
	var/displays_id = TRUE

	//convenience var for defining the icon state for the overlay used when the clothing is worn.

	valid_accessory_slots = list("utility","armband","decor", "sash", "cape", "overcloth", "tie", "armor", "leg_armor", "arm_armor")
	restricted_accessory_slots = list("utility", "armband", "armor")


/obj/item/clothing/under/attack_hand(var/mob/user)
	if (accessories && accessories.len && (src == user.r_hand || src == user.l_hand))
		if (istype(accessories[1], /obj/item/clothing/accessory/storage/webbing))
			var/obj/item/clothing/accessory/storage/webbing/webbing = accessories[1]
			user << "<span class = 'warning'>You start to remove the webbing from [src].</span>"
			if (do_after(user, 50, get_turf(user)))
				user << "<span class = 'warning'>You finish removing the webbing from [src].</span>"
				accessories -= webbing
				if (overlays.len == TRUE) // hack
					overlays.Cut()
				else
					overlays -= webbing
				update_icon()
				user.put_in_hands(webbing)
	else
		..()

	if ((ishuman(usr) || issmall(usr)) && loc == user)
		return
	..()

/obj/item/clothing/under/New()
	..()
	item_state_slots[slot_w_uniform_str] = icon_state //TODO: drop or gonna use it?

/obj/item/clothing/under/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_w_uniform()


/obj/item/clothing/under/examine(mob/user)
	..(user)
