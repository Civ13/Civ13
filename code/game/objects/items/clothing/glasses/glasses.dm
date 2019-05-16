
/obj/item/clothing/mask/glasses
	var/toggleable = FALSE
	var/off_state = ""
	var/on_state = ""
	var/overtype = ""
/obj/item/clothing/mask/glasses/attack_self(mob/living/carbon/human/user)
	if(toggleable && !user.incapacitated())
		if(active)
			active = 0
			icon_state = off_state
			user.update_inv_wear_mask()
			flash_protection = FLASH_PROTECTION_NONE
			tint = TINT_NONE
			usr << "You deactivate the optics on the [src]."
			if (overtype == "nvg")
				user.nvg = FALSE
				user.handle_vision()
			else if (overtype == "thermal")
				user.thermal = FALSE
				user.handle_vision()
		else
			active = 1
			icon_state = on_state
			user.update_inv_wear_mask()
			flash_protection = initial(flash_protection)
			tint = initial(tint)
			usr << "You activate the optics on the [src]."
			if (overtype == "nvg")
				user.nvg = TRUE
				user.handle_vision()
			else if (overtype == "thermal")
				user.thermal = TRUE
				user.handle_vision()
		user.update_action_buttons()

/obj/item/clothing/mask/glasses/verb/toggle()
	set name = "Toggle"
	set category = null
	set src in usr
	if (!toggleable)
		return
	else
		attack_self(usr)
		return
/obj/item/clothing/mask/glasses/eyepatch
	name = "eyepatch"
	desc = "Yarr."
	icon_state = "eyepatch"
	item_state = "eyepatch"
	body_parts_covered = FALSE

/obj/item/clothing/mask/glasses/monocle
	name = "monocle"
	desc = "Such a dapper eyepiece!"
	icon_state = "monocle"
	item_state = "headset" // lol
	body_parts_covered = FALSE

/obj/item/clothing/mask/glasses/regular
	name = "Prescription Glasses"
	desc = "Made by Nerd. Co."
	icon_state = "glasses"
	item_state = "glasses"
	body_parts_covered = FALSE

/obj/item/clothing/mask/glasses/regular/hipster
	name = "Prescription Glasses"
	desc = "Made by Uncool. Co."
	icon_state = "hipster_glasses"
	item_state = "hipster_glasses"

/obj/item/clothing/mask/glasses/gglasses
	name = "Green Glasses"
	desc = "Forest green glasses, like the kind you'd wear when hatching a nasty scheme."
	icon_state = "gglasses"
	item_state = "gglasses"
	body_parts_covered = FALSE

/obj/item/clothing/mask/glasses/sunglasses
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Enhanced shielding blocks many flashes."
	name = "sunglasses"
	icon_state = "sun"
	item_state = "sunglasses"
	darkness_view = -1
	flash_protection = FLASH_PROTECTION_MODERATE

/obj/item/clothing/mask/glasses/sunglasses/blindfold
	name = "blindfold"
	desc = "Covers the eyes, preventing sight."
	icon_state = "blindfold"
	item_state = "blindfold"
	tint = TINT_BLIND