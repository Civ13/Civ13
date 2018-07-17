/*
 * Contents:
 *		Welding mask
 *		Cakehat
 *		Ushanka
 *		Pumpkin head
 *		Kitty ears
 *
 */

/*
 * Welding mask
 */
/obj/item/clothing/head/welding
	name = "welding helmet"
	desc = "A head-mounted face cover designed to protect the wearer completely from space-arc eye."
	icon_state = "welding"
	item_state_slots = list(
		slot_l_hand_str = "welding",
		slot_r_hand_str = "welding",
		)
	matter = list(DEFAULT_WALL_MATERIAL = 3000, "glass" = 1000)
	var/up = FALSE
	armor = list(melee = 10, bullet = FALSE, laser = FALSE,energy = FALSE, bomb = FALSE, bio = FALSE, rad = FALSE)
	flags_inv = (HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE)
	body_parts_covered = HEAD|FACE|EYES
	action_button_name = "Flip Welding Mask"
	siemens_coefficient = 0.9
	w_class = 3
	var/base_state
	flash_protection = FLASH_PROTECTION_MAJOR
	tint = TINT_HEAVY

/obj/item/clothing/head/welding/attack_self()
	if (!base_state)
		base_state = icon_state
	toggle()


/obj/item/clothing/head/welding/verb/toggle()
	set category = null
	set name = "Adjust welding mask"
	set src in usr

	if (usr.canmove && !usr.stat && !usr.restrained())
		if (up)
			up = !up
			body_parts_covered |= (EYES|FACE)
			flags_inv |= (HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE)
			flash_protection = initial(flash_protection)
			tint = initial(tint)
			icon_state = base_state
			usr << "You flip the [src] down to protect your eyes."
		else
			up = !up
			body_parts_covered &= ~(EYES|FACE)
			flash_protection = FLASH_PROTECTION_NONE
			tint = TINT_NONE
			flags_inv &= ~(HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE)
			icon_state = "[base_state]up"
			usr << "You push the [src] up out of your face."
		update_clothing_icon()	//so our mob-overlays
		usr.update_action_buttons()


/*
 * Cakehat
 */
/obj/item/clothing/head/cakehat
	name = "cake-hat"
	desc = "It's tasty looking!"
	icon_state = "cake0"
	item_state = "cake0"
	var/onfire = FALSE
	body_parts_covered = HEAD

/obj/item/clothing/head/cakehat/process()
	if (!onfire)
		processing_objects.Remove(src)
		return

	var/turf/location = loc
	if (istype(location, /mob/))
		var/mob/living/carbon/human/M = location
		if (M.l_hand == src || M.r_hand == src || M.head == src)
			location = M.loc

	if (istype(location, /turf))
		location.hotspot_expose(700, TRUE)

/obj/item/clothing/head/cakehat/attack_self(mob/user as mob)
	onfire = !( onfire )
	if (onfire)
		force = 3
		damtype = "fire"
		icon_state = "cake1"
		item_state = "cake1"
		processing_objects.Add(src)
	else
		force = null
		damtype = "brute"
		icon_state = "cake0"
		item_state = "cake0"
	return


/*
 * Ushanka
 */
/obj/item/clothing/head/ushanka
	name = "ushanka"
	desc = "Perfect for winter in Siberia, da?"
	icon_state = "ushankadown"
	flags_inv = HIDEEARS

/obj/item/clothing/head/ushanka/attack_self(mob/user as mob)
	if (icon_state == "ushankadown")
		icon_state = "ushankaup"
		user << "You raise the ear flaps on the ushanka."
	else
		icon_state = "ushankadown"
		user << "You lower the ear flaps on the ushanka."

/*
 * Pumpkin head
 */
/obj/item/clothing/head/pumpkinhead
	name = "carved pumpkin"
	desc = "A jack o' lantern! Believed to ward off evil spirits."
	icon_state = "hardhat0_pumpkin"//Could stand to be renamed
	flags_inv = HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE|BLOCKHAIR
	body_parts_covered = HEAD|FACE|EYES
	brightness_on = 2
	light_overlay = "helmet_light"
	w_class = 3

/obj/item/clothing/head/richard
	name = "chicken mask"
	desc = "You can hear the distant sounds of rhythmic electronica."
	icon_state = "richard"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHAIR
