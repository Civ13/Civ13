
/obj/item/clothing/glasses
	var/toggleable = FALSE
	var/off_state = ""
	var/on_state = ""
	var/overtype = ""
	var/active = FALSE
	var/blocks_scope = FALSE

/obj/item/clothing/glasses/attack_self(mob/living/human/user)
	if(toggleable && !user.incapacitated())
		if(active)
			active = 0
			icon_state = off_state
			user.update_inv_eyes()
			flash_protection = FLASH_PROTECTION_NONE
			tint = TINT_NONE
			usr << "You deactivate the optics on the [src]."
			if (overtype == "nvg")
				user.nvg = FALSE
				restricts_view = 0
				blocks_scope = FALSE
				user.handle_vision()
			else if (overtype == "thermal")
				user.thermal = FALSE
				restricts_view = 0
				blocks_scope = FALSE
				user.handle_vision()
		else if (src == user.eyes)
			active = 1
			icon_state = on_state
			user.update_inv_eyes()
			flash_protection = initial(flash_protection)
			tint = initial(tint)
			usr << "You activate the optics on the [src]."
			if (overtype == "nvg")
				user.nvg = TRUE
				restricts_view = 2
				blocks_scope = TRUE
				user.handle_vision()
			else if (overtype == "thermal")
				user.thermal = TRUE
				restricts_view = 2
				blocks_scope = TRUE
				user.handle_vision()
		else
			active = 0
			icon_state = off_state
			user.update_inv_eyes()
			flash_protection = FLASH_PROTECTION_NONE
			tint = TINT_NONE
			if (overtype == "nvg")
				user.nvg = FALSE
				restricts_view = 0
				blocks_scope = FALSE
				user.handle_vision()
			else if (overtype == "thermal")
				user.thermal = FALSE
				restricts_view = 0
				blocks_scope = FALSE
				user.handle_vision()
		user.update_action_buttons()

/obj/item/clothing/glasses/verb/toggle()
	set name = "Toggle"
	set category = null
	set src in usr
	if (!toggleable)
		return
	else
		attack_self(usr)
		return
/obj/item/clothing/glasses/eyepatch
	name = "eyepatch"
	desc = "Yarr."
	icon_state = "eyepatch"
	item_state = "eyepatch"
	body_parts_covered = FALSE
	flags = FALSE

/obj/item/clothing/glasses/monocle
	name = "monocle"
	desc = "Such a dapper eyepiece!"
	icon_state = "monocle"
	item_state = "headset" // lol
	body_parts_covered = FALSE

/obj/item/clothing/glasses/regular
	name = "Prescription Glasses"
	desc = "Made by Nerd. Co."
	icon_state = "glasses"
	item_state = "glasses"
	body_parts_covered = FALSE

/obj/item/clothing/glasses/regular/hipster
	name = "Prescription Glasses"
	desc = "Made by Uncool. Co."
	icon_state = "hipster_glasses"
	item_state = "hipster_glasses"

/obj/item/clothing/glasses/gglasses
	name = "Green Glasses"
	desc = "Forest green glasses, like the kind you'd wear when hatching a nasty scheme."
	icon_state = "gglasses"
	item_state = "gglasses"
	body_parts_covered = FALSE

/obj/item/clothing/glasses/sunglasses
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Enhanced lenses blocks deadly sun rays."
	name = "sunglasses"
	icon_state = "sun"
	item_state = "sunglasses"
	darkness_view = -1
	flash_protection = FLASH_PROTECTION_MODERATE
	body_parts_covered = FALSE

/obj/item/clothing/glasses/redglasses
	desc = "A pair of glasses that look like they're from the 60's, Groovy BAY'BE."
	name = "red vintage glasses"
	icon_state = "redlense"
	item_state = "redlense"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisorred
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor red"
	icon_state = "univisor_r"
	item_state = "univisor_r"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisorcyan
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor cyan"
	icon_state = "univisor_c"
	item_state = "univisor_c"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisorgreen
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor green"
	icon_state = "univisor_g"
	item_state = "univisor_g"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisoryellow
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor yellow"
	icon_state = "univisor_y"
	item_state = "univisor_y"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisorwhite
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor white"
	icon_state = "univisor_w"
	item_state = "univisor_w"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/univisorflashy
	desc = "A uni lense visor that look like they're from the 80's, Looks a bit futuristic."
	name = "univisor flashy"
	icon_state = "univisor_flashy"
	item_state = "univisor_flashy"
	darkness_view = -1
	body_parts_covered = FALSE

/obj/item/clothing/glasses/sunglasses/blindfold
	name = "blindfold"
	desc = "Covers the eyes, preventing sight."
	icon_state = "blindfold"
	item_state = "blindfold"
	tint = TINT_BLIND

/obj/item/clothing/glasses/sunglasses/large
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Enhanced shielding blocks many flashes."
	name = "large sunglasses"
	icon_state = "bigsunglasses"
	item_state = "bigsunglasses"
	darkness_view = -1
	flash_protection = FLASH_PROTECTION_MAJOR
	body_parts_covered = FALSE

/obj/item/clothing/glasses/tactical_goggles
	name = "goggles"
	desc = "Standard combat goggles."
	icon_state = "tactical_goggles"
	item_state = "tactical_goggles"
	body_parts_covered = FALSE

/obj/item/clothing/glasses/tactical_goggles/ballistic
	name = "Ballistic goggles"
	desc = "Standard ballistic combat goggles, they protect your eyes from shrapnel."
	icon_state = "tactical_goggles"
	item_state = "tactical_goggles"
	body_parts_covered = EYES
	armor = list(melee = 15, arrow = 90, gun = 25, energy = 15, bomb = 25, bio = 20, rad = 20)