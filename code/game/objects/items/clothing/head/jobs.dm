
//Bartender
/obj/item/clothing/head/chefhat
	name = "chef's hat"
	desc = "It's a hat used by chefs to keep hair out of your food. Judging by the food in the mess, they don't work."
	icon_state = "chefhat"
	item_state = "chefhat"

//Captain
/obj/item/clothing/head/caphat
	name = "captain's hat"
	icon_state = "captain"
	desc = "It's good being the king."
	item_state_slots = list(
		slot_l_hand_str = "caphat",
		slot_r_hand_str = "caphat",
		)
	body_parts_covered = FALSE

/obj/item/clothing/head/caphat/cap
	name = "captain's cap"
	desc = "You fear to wear it for the negligence it brings."
	icon_state = "capcap"

/obj/item/clothing/head/caphat/formal
	name = "parade hat"
	desc = "No one in a commanding position should be without a perfect, white hat of ultimate authority."
	icon_state = "officercap"

//HOP
/obj/item/clothing/head/caphat/hop
	name = "crew resource's hat"
	desc = "A stylish hat that both protects you from enraged former-crewmembers and gives you a false sense of authority."
	icon_state = "hopcap"

//Chaplain // Nuns & Plague Doctor -> relocated to apparel medieval
/obj/item/clothing/head/chaplain_hood
	name = "preacher's hood"
	desc = "It's hood that covers the head."
	icon_state = "chaplain_hood"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/under/chaplain
	name = "preacher's clothing"
	desc = "Typical priest clothing."
	icon_state = "chaplain"

/obj/item/clothing/suit/storage/jacket/chaplain
	name = "preacher's robe"
	desc = "Typical priest robe."
	icon_state = "chaplain_hoodie"


/*
 * Welding mask
 */
/obj/item/clothing/head/welding
	name = "welding helmet"
	desc = "A head-mounted face cover designed to protect the wearer completely from arc eye."
	icon_state = "welding"
	flags = CONDUCT
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
	w_class = ITEM_SIZE_NORMAL
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
