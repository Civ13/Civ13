/*
	The global hud:
	Uses the same visual objects for all players.
*/
var/datum/global_hud/global_hud = new()
var/list/global_huds = list(
		global_hud.druggy,
		global_hud.blurry,
		global_hud.vimpaired,
		global_hud.darkMask,
		global_hud.nvg,
		global_hud.thermal,
		global_hud.meson,
		global_hud.science)
/*
/datum/hud/var/obj/screen/grab_intent
/datum/hud/var/obj/screen/hurt_intent
/datum/hud/var/obj/screen/disarm_intent
/datum/hud/var/obj/screen/help_intent
*/
/datum/global_hud
	var/obj/screen/druggy
	var/obj/screen/blurry
	var/list/vimpaired
	var/list/darkMask
	var/obj/screen/nvg
	var/obj/screen/thermal
	var/obj/screen/meson
	var/obj/screen/science

/datum/global_hud/proc/setup_overlay(var/icon_state)
	var/obj/screen/screen = new /obj/screen()
	screen.screen_loc = "1,1"
	screen.icon = 'icons/obj/hud_full.dmi'
	screen.icon_state = icon_state
	screen.layer = 17
	screen.mouse_opacity = FALSE

	return screen

/datum/global_hud/New()
	//420erryday psychedellic colours screen overlay for when you are high
	druggy = new /obj/screen()
	druggy.screen_loc = ui_entire_screen
	druggy.icon_state = "druggy"
	druggy.layer = 17
	druggy.mouse_opacity = FALSE

	//that white blurry effect you get when you eyes are damaged
	blurry = new /obj/screen()
	blurry.screen_loc = ui_entire_screen
	blurry.icon_state = "blurry"
	blurry.layer = 17
	blurry.mouse_opacity = FALSE

	nvg = setup_overlay("nvg_hud")
	thermal = setup_overlay("thermal_hud")
	meson = setup_overlay("meson_hud")
	science = setup_overlay("science_hud")

	var/obj/screen/O
	var/i
	//that nasty looking dither you  get when you're short-sighted
	vimpaired = newlist(/obj/screen,/obj/screen,/obj/screen,/obj/screen)
	O = vimpaired[1]
	O.screen_loc = "1,1 to 5,15"
	O = vimpaired[2]
	O.screen_loc = "5,1 to 10,5"
	O = vimpaired[3]
	O.screen_loc = "6,11 to 10,15"
	O = vimpaired[4]
	O.screen_loc = "11,1 to 15,15"

	//welding mask overlay black/dither
	darkMask = newlist(/obj/screen, /obj/screen, /obj/screen, /obj/screen, /obj/screen, /obj/screen, /obj/screen, /obj/screen)
	O = darkMask[1]
	O.screen_loc = "WEST+2,SOUTH+2 to WEST+4,NORTH-2"
	O = darkMask[2]
	O.screen_loc = "WEST+4,SOUTH+2 to EAST-5,SOUTH+4"
	O = darkMask[3]
	O.screen_loc = "WEST+5,NORTH-4 to EAST-5,NORTH-2"
	O = darkMask[4]
	O.screen_loc = "EAST-4,SOUTH+2 to EAST-2,NORTH-2"
	O = darkMask[5]
	O.screen_loc = "WEST,SOUTH to EAST,SOUTH+1"
	O = darkMask[6]
	O.screen_loc = "WEST,SOUTH+2 to WEST+1,NORTH"
	O = darkMask[7]
	O.screen_loc = "EAST-1,SOUTH+2 to EAST,NORTH"
	O = darkMask[8]
	O.screen_loc = "WEST+2,NORTH-1 to EAST-2,NORTH"

	for (i = TRUE, i <= 4, i++)
		O = vimpaired[i]
		O.icon_state = "dither50"
		O.layer = 17
		O.mouse_opacity = FALSE

		O = darkMask[i]
		O.icon_state = "dither50"
		O.layer = 17
		O.mouse_opacity = FALSE

	for (i = 5, i <= 8, i++)
		O = darkMask[i]
		O.icon_state = "black"
		O.layer = 17
		O.mouse_opacity = FALSE

/*
	The hud datum
	Used to show and hide huds for all the different mob types,
	including inventories and item quick actions.
*/

/*/datum/hud
	var/mob/mymob

	var/hud_shown = TRUE			//Used for the HUD toggle (F12)
	var/inventory_shown = TRUE		//the inventory
	var/show_intent_icons = FALSE
	var/hotkey_ui_hidden = FALSE	//This is to hide the buttons that can be used via hotkeys. (hotkeybuttons list of buttons)

	var/obj/screen/lingchemdisplay
	var/obj/screen/blobpwrdisplay
	var/obj/screen/blobhealthdisplay
	var/obj/screen/r_hand_hud_object
	var/obj/screen/l_hand_hud_object
	var/obj/screen/action_intent
	var/obj/screen/move_intent

	var/list/adding
	var/list/other
	var/list/obj/screen/hotkeybuttons

	var/obj/screen/movable/action_button/hide_toggle/hide_actions_toggle
	var/action_buttons_hidden = FALSE

datum/hud/New(mob/owner)
	mymob = owner
	instantiate()
	..()

/datum/hud/Destroy()
	..()
	grab_intent = null
	hurt_intent = null
	disarm_intent = null
	help_intent = null
	lingchemdisplay = null
	blobpwrdisplay = null
	blobhealthdisplay = null
	r_hand_hud_object = null
	l_hand_hud_object = null
	action_intent = null
	move_intent = null
	adding = null
	other = null
	hotkeybuttons = null
//	item_action_list = null // ?
	mymob = null

/datum/hud/proc/hidden_inventory_update()
	if (!mymob) return
	if (ishuman(mymob))
		var/mob/living/carbon/human/H = mymob
		for (var/gear_slot in H.species.hud.gear)
			var/list/hud_data = H.species.hud.gear[gear_slot]
			if (inventory_shown && hud_shown)
				switch(hud_data["slot"])
					if (slot_head)
						if (H.head)      H.head.screen_loc =      hud_data["loc"]
					if (slot_shoes)
						if (H.shoes)     H.shoes.screen_loc =     hud_data["loc"]
					if (slot_l_ear)
						if (H.l_ear)     H.l_ear.screen_loc =     hud_data["loc"]
					if (slot_r_ear)
						if (H.r_ear)     H.r_ear.screen_loc =     hud_data["loc"]
					if (slot_gloves)
						if (H.gloves)    H.gloves.screen_loc =    hud_data["loc"]
					if (slot_glasses)
						if (H.glasses)   H.glasses.screen_loc =   hud_data["loc"]
					if (slot_w_uniform)
						if (H.w_uniform) H.w_uniform.screen_loc = hud_data["loc"]
					if (slot_wear_suit)
						if (H.wear_suit) H.wear_suit.screen_loc = hud_data["loc"]
					if (slot_wear_mask)
						if (H.wear_mask) H.wear_mask.screen_loc = hud_data["loc"]
			else
				switch(hud_data["slot"])
					if (slot_head)
						if (H.head)      H.head.screen_loc =      null
					if (slot_shoes)
						if (H.shoes)     H.shoes.screen_loc =     null
					if (slot_l_ear)
						if (H.l_ear)     H.l_ear.screen_loc =     null
					if (slot_r_ear)
						if (H.r_ear)     H.r_ear.screen_loc =     null
					if (slot_gloves)
						if (H.gloves)    H.gloves.screen_loc =    null
					if (slot_glasses)
						if (H.glasses)   H.glasses.screen_loc =   null
					if (slot_w_uniform)
						if (H.w_uniform) H.w_uniform.screen_loc = null
					if (slot_wear_suit)
						if (H.wear_suit) H.wear_suit.screen_loc = null
					if (slot_wear_mask)
						if (H.wear_mask) H.wear_mask.screen_loc = null


/datum/hud/proc/persistant_inventory_update()
	if (!mymob)
		return

	if (ishuman(mymob))
		var/mob/living/carbon/human/H = mymob
		for (var/gear_slot in H.species.hud.gear)
			var/list/hud_data = H.species.hud.gear[gear_slot]
			if (hud_shown)
				switch(hud_data["slot"])
					if (slot_s_store)
						if (H.s_store) H.s_store.screen_loc = hud_data["loc"]
					if (slot_wear_id)
						if (H.wear_id) H.wear_id.screen_loc = hud_data["loc"]
					if (slot_belt)
						if (H.belt)    H.belt.screen_loc =    hud_data["loc"]
					if (slot_back)
						if (H.back)    H.back.screen_loc =    hud_data["loc"]
					if (slot_l_store)
						if (H.l_store) H.l_store.screen_loc = hud_data["loc"]
					if (slot_r_store)
						if (H.r_store) H.r_store.screen_loc = hud_data["loc"]
			else
				switch(hud_data["slot"])
					if (slot_s_store)
						if (H.s_store) H.s_store.screen_loc = null
					if (slot_wear_id)
						if (H.wear_id) H.wear_id.screen_loc = null
					if (slot_belt)
						if (H.belt)    H.belt.screen_loc =    null
					if (slot_back)
						if (H.back)    H.back.screen_loc =    null
					if (slot_l_store)
						if (H.l_store) H.l_store.screen_loc = null
					if (slot_r_store)
						if (H.r_store) H.r_store.screen_loc = null


/datum/hud/proc/instantiate()
	if (!ismob(mymob)) return FALSE
	if (!mymob.client) return FALSE
	var/ui_style = ui_style2icon(mymob.client.prefs.UI_style)
	var/ui_color = mymob.client.prefs.UI_style_color
	var/ui_alpha = mymob.client.prefs.UI_style_alpha
	mymob.instantiate_hud(src, ui_style, ui_color, ui_alpha)
	mymob.HUD_create()
*/
/mob/proc/instantiate_hud(var/datum/hud/HUD, var/ui_style, var/ui_color, var/ui_alpha)
	return

//Triggered when F12 is pressed (Unless someone changed something in the DMF)
/mob/verb/button_pressed_F12(var/full = FALSE as null)
	set name = "F12"
	set hidden = TRUE

	if (!hud_used)
		usr << "<span class='warning'>This mob type does not use a HUD.</span>"
		return

	if (!ishuman(src))
		usr << "<span class='warning'>Inventory hiding is currently only supported for human mobs, sorry.</span>"
		return

	if (!client) return
	if (client.view != world.view)
		return
	/*if (hud_used.hud_shown)
		hud_used.hud_shown = FALSE
		if (hud_used.adding)
			client.screen -= hud_used.adding
		if (hud_used.other)
			client.screen -= hud_used.other
		if (hud_used.hotkeybuttons)
			client.screen -= hud_used.hotkeybuttons

		//Due to some poor coding some things need special treatment:
		//These ones are a part of 'adding', 'other' or 'hotkeybuttons' but we want them to stay
		if (!full)
			client.screen += hud_used.l_hand_hud_object	//we want the hands to be visible
			client.screen += hud_used.r_hand_hud_object	//we want the hands to be visible
			client.screen += hud_used.action_intent		//we want the intent swticher visible
			hud_used.action_intent.screen_loc = ui_acti_alt	//move this to the alternative position, where zone_select usually is.
		else
			client.screen -= healths
			client.screen -= internals
			client.screen -= gun_setting_icon

		//These ones are not a part of 'adding', 'other' or 'hotkeybuttons' but we want them gone.
		client.screen -= zone_sel	//zone_sel is a mob variable for some reason.

	else
		hud_used.hud_shown = TRUE
		if (hud_used.adding)
			client.screen += hud_used.adding
		if (hud_used.other && hud_used.inventory_shown)
			client.screen += hud_used.other
		if (hud_used.hotkeybuttons && !hud_used.hotkey_ui_hidden)
			client.screen += hud_used.hotkeybuttons
		if (healths)
			client.screen |= healths
		if (internals)
			client.screen |= internals
		if (gun_setting_icon)
			client.screen |= gun_setting_icon

		hud_used.action_intent.screen_loc = ui_acti //Restore intent selection to the original position
		client.screen += zone_sel				//This one is a special snowflake
*/
//	hud_used.hidden_inventory_update()
//	hud_used.persistant_inventory_update()
	update_action_buttons()

//Similar to button_pressed_F12() but keeps zone_sel, gun_setting_icon, and healths.
/mob/proc/toggle_zoom_hud()
	if (!hud_used)
		return
	if (!ishuman(src))
		return
	if (!client)
		return
	if (client.view != world.view)
		return

/*	if (hud_used.hud_shown)
		hud_used.hud_shown = FALSE
		if (hud_used.adding)
			client.screen -= hud_used.adding
		if (hud_used.other)
			client.screen -= hud_used.other
		if (hud_used.hotkeybuttons)
			client.screen -= hud_used.hotkeybuttons
		client.screen -= internals
		client.screen += hud_used.action_intent		//we want the intent swticher visible
	else
		hud_used.hud_shown = TRUE
		if (hud_used.adding)
			client.screen += hud_used.adding
		if (hud_used.other && hud_used.inventory_shown)
			client.screen += hud_used.other
		if (hud_used.hotkeybuttons && !hud_used.hotkey_ui_hidden)
			client.screen += hud_used.hotkeybuttons
		if (internals)
			client.screen |= internals
		hud_used.action_intent.screen_loc = ui_acti //Restore intent selection to the original position

	hud_used.hidden_inventory_update()
	hud_used.persistant_inventory_update()*/
	update_action_buttons()

