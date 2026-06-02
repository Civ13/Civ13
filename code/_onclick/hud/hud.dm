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
		global_hud.gasmask,
		global_hud.fov,
		global_hud.noise,
		global_hud.fishbed,
		)
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
	var/obj/screen/gasmask
	var/obj/screen/thermal
	var/obj/screen/fov
	var/obj/screen/fishbed
	var/obj/screen/noise
	var/obj/screen/cover
	var/obj/screen/aim_cross

/datum/global_hud/proc/setup_overlay(var/icon_state)
	var/obj/screen/screen = new /obj/screen()
	screen.screen_loc = "4,1"
	screen.icon = 'icons/mob/screen1_full.dmi'
	screen.icon_state = icon_state
	screen.layer = 17
	screen.plane = HUD_PLANE
	screen.mouse_opacity = FALSE

	return screen

/datum/global_hud/New()
	//420erryday psychedellic colours screen overlay for when you are high
	druggy = new /obj/screen()
	druggy.icon = 'icons/mob/screen/effects.dmi'
	druggy.screen_loc = ui_entire_screen
	druggy.icon_state = "druggy"
	druggy.layer = 17
	druggy.plane = HUD_PLANE
	druggy.mouse_opacity = FALSE

	//that white blurry effect you get when you eyes are damaged
	blurry = new /obj/screen()
	blurry.icon = 'icons/mob/screen/effects.dmi'
	blurry.screen_loc = ui_entire_screen
	blurry.icon_state = "[rand(1,9)] moderate"
	blurry.layer = 17
	blurry.plane = HUD_PLANE
	blurry.mouse_opacity = FALSE

//	nvg = setup_overlay("nvg_hud")
//	thermal = setup_overlay("thermal_hud")

	nvg = new /obj/screen()
	nvg.icon = 'icons/mob/screen/effects.dmi'
	nvg.screen_loc = ui_entire_screen
	nvg.icon_state = "nvg"
	nvg.layer = 17
	nvg.plane = HUD_PLANE
	nvg.mouse_opacity = FALSE

	thermal = new /obj/screen()
	thermal.icon = 'icons/mob/screen/effects.dmi'
	thermal.screen_loc = ui_entire_screen
	thermal.icon_state = "thermal"
	thermal.layer = 17
	thermal.plane = HUD_PLANE
	thermal.mouse_opacity = FALSE

	gasmask = new /obj/screen/gasmask()
	gasmask.icon = 'icons/mob/screen1_full.dmi'
	gasmask.screen_loc = "4,1"
	gasmask.icon_state = "gasmask"
	gasmask.name = " "
	gasmask.layer = 17
	gasmask.plane = HUD_PLANE
	gasmask.mouse_opacity = FALSE


	fov = new /obj/screen/fov()
	fov.icon = 'icons/mob/hide.dmi'
	fov.icon_state = "combat"
	fov.name = " "
	fov.screen_loc = "4,1"
	fov.mouse_opacity = FALSE
	fov.layer = 18

	aim_cross = new /obj/screen/aiming_cross()
	aim_cross.name = " "
	aim_cross.screen_loc = "1,1"
	aim_cross.mouse_opacity = FALSE
	aim_cross.layer = 21

	cover = new /obj/screen/cover()
	noise = new /obj/screen/noise()
	fishbed = new /obj/screen/fishbed()

	var/obj/screen/O
	var/i
	//that nasty looking dither you get when you're short-sighted
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
		O.icon = 'icons/mob/screen/effects.dmi'
		O.icon_state = "dither50"
		O.layer = 17
		O.mouse_opacity = FALSE

		O = darkMask[i]
		O.icon = 'icons/mob/screen/effects.dmi'
		O.icon_state = "dither50"
		O.layer = 17
		O.mouse_opacity = FALSE

	for (i = 5, i <= 8, i++)
		O = darkMask[i]
		O.icon = 'icons/mob/screen/effects.dmi'
		O.icon_state = "black"
		O.layer = 17
		O.mouse_opacity = FALSE

/mob/proc/instantiate_hud(var/datum/hud/HUD, var/ui_style, var/ui_color, var/ui_alpha)
	return

//Triggered when F11 is pressed (Unless someone changed something in the DMF)
/mob/verb/button_pressed_F11(var/full = FALSE as null)
	set name = "F11"
	set hidden = TRUE

	if (!hud_used)
		to_chat(usr, SPAN_WARNING("This mob type does not use a HUD."))
		return

	if (!ishuman(src))
		to_chat(usr, SPAN_WARNING("Inventory hiding is currently only supported for human mobs, sorry."))
		return

	if (!client) return
	if (client.view != WORLD_VIEW)
		return

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
	if (client.view != WORLD_VIEW)
		return

	update_action_buttons()

/datum/hud
	var/mob/mymob
	var/list/obj/screen/plane_master/plane_masters = list()
	var/list/obj/screen/vehicle/vehicle_hud = list()
	var/list/wizard_hud = list()
	var/obj/screen/spell_selector/spell_selector = null

/datum/hud/proc/add_vehicle_hud(var/mob/living/human/H)
	if (vehicle_hud.len)
		return
	var/obj/screen/vehicle/V
	V = new /obj/screen/vehicle/direction()
	V.screen_loc = "14,15"
	V.parentmob = H
	vehicle_hud += V
	H.HUDprocess += V
	V = new /obj/screen/vehicle/turn_left()
	V.screen_loc = "13,15"
	V.parentmob = H
	vehicle_hud += V
	V = new /obj/screen/vehicle/turn_right()
	V.screen_loc = "15,15"
	V.parentmob = H
	vehicle_hud += V
	V = new /obj/screen/vehicle/gear_down()
	V.screen_loc = "13,14"
	V.parentmob = H
	vehicle_hud += V
	V = new /obj/screen/vehicle/current_gear()
	V.screen_loc = "14,14"
	V.parentmob = H
	vehicle_hud += V
	H.HUDprocess += V
	V = new /obj/screen/vehicle/gear_up()
	V.screen_loc = "15,14"
	V.parentmob = H
	vehicle_hud += V
	if (mymob && mymob.client)
		mymob.client.screen |= vehicle_hud

/datum/hud/proc/remove_vehicle_hud(var/mob/living/human/H)
	if (!vehicle_hud.len)
		return
	if (H && H.client)
		H.client.screen -= vehicle_hud
	for (var/obj/screen/vehicle/V in vehicle_hud)
		if (H)
			H.HUDprocess -= V
		qdel(V)
	vehicle_hud.Cut()

/datum/hud/New(mob/owner)
	mymob = owner
	//instantiate()
	for(var/mytype in subtypesof(/obj/screen/plane_master))
		var/obj/screen/plane_master/instance = new mytype()
		plane_masters["[instance.plane]"] = instance
		instance.backdrop(mymob)
		if (mymob)
			mymob.client.screen |= instance
	..()

/datum/hud/Destroy()
	if(plane_masters.len)
		for(var/thing in plane_masters)
			qdel(plane_masters[thing])
		plane_masters.Cut()
	if(vehicle_hud.len)
		remove_vehicle_hud()
	if(wizard_hud.len)
		remove_wizard_hud()
	return ..()

/obj/screen/spell_selector
	icon = 'icons/obj/magic_icon.dmi'
	icon_state = "selected"
	layer = 21
	mouse_opacity = FALSE

/obj/screen/spell
	icon = 'icons/obj/magic_icon.dmi'
	layer = 20
	var/spell_path = null

/obj/screen/spell/Click()
	if(!parentmob || !ishuman(parentmob))
		return
	var/mob/living/human/H = parentmob

	// Only allow interaction if holding a wand
	var/obj/item/weapon/material/magic/wand/W = null
	
	if (!istype(H.get_active_hand(), /obj/item/weapon/material/magic/wand))
		return
	W = H.get_active_hand()
	if(spell_path)
		var/list/spell_list = W.get_usable_spells(H)
		for (var/datum/spell/SP in spell_list)
			if (SP.type == spell_path)
				W.active_spell = SP
				to_chat(H, SPAN_NOTICE("Spell set to <b>[W.active_spell.name]</b>!"))
				if (H.hud_used)
					H.hud_used.update_spell_selector(H)
				return

/// Top Left Spells (Row 15) ///
/obj/screen/spell/zappus
	name = "Zappus"
	icon_state = "zappus"
	screen_loc = "1,15"
	spell_path = /datum/spell/zappus

/obj/screen/spell/blockum
	name = "Blockum"
	icon_state = "blockum"
	screen_loc = "2,15"
	spell_path = /datum/spell/blockum

/obj/screen/spell/lightus
	name = "Lightus"
	icon_state = "lightus"
	screen_loc = "3,15"
	spell_path = /datum/spell/lightus

/obj/screen/spell/dropus
	name = "Dropus"
	icon_state = "dropus"
	screen_loc = "4,15"
	spell_path = /datum/spell/dropus

/obj/screen/spell/stinkaeum
	name = "Stinkaeum"
	icon_state = "stinkaeum"
	screen_loc = "5,15"
	spell_path = /datum/spell/stinkaeum

/// Below Top Left (Row 14) ///
/obj/screen/spell/pushum
	name = "Pushum"
	icon_state = "pushum"
	screen_loc = "1,14"
	spell_path = /datum/spell/pushum

/obj/screen/spell/pullus
	name = "Pullus"
	icon_state = "pullus"
	screen_loc = "2,14"
	spell_path = /datum/spell/pullus

/obj/screen/spell/wallus
	name = "Wallus"
	icon_state = "wallus"
	screen_loc = "3,14"
	spell_path = /datum/spell/wallus

/obj/screen/spell/floatus
	name = "Floatus"
	icon_state = "floatus"
	screen_loc = "4,14"
	spell_path = /datum/spell/floatus

/// Top Right Spells (Row 15) ///
/obj/screen/spell/freezeum
	name = "Freezeum"
	icon_state = "freezeum"
	screen_loc = "15,15"
	spell_path = /datum/spell/freezeum

/obj/screen/spell/blinkae
	name = "Blinkae"
	icon_state = "blinkae"
	screen_loc = "14,15"
	spell_path = /datum/spell/blinkae

/obj/screen/spell/burnus
	name = "Burnus"
	icon_state = "burnus"
	screen_loc = "13,15"
	spell_path = /datum/spell/burnus

/obj/screen/spell/barrelus
	name = "Barrelus"
	icon_state = "barrelus"
	screen_loc = "12,15"
	spell_path = /datum/spell/barrelus

/obj/screen/spell/sliceum
	name = "Sliceum"
	icon_state = "sliceum"
	screen_loc = "11,15"
	spell_path = /datum/spell/sliceum

/// Below Top Right (Row 14) ///
/obj/screen/spell/fixae
	name = "Fixae"
	icon_state = "fixae"
	screen_loc = "15,14"
	spell_path = /datum/spell/fixae

/obj/screen/spell/explodus
	name = "Explodus"
	icon_state = "explodus"
	screen_loc = "14,14"
	spell_path = /datum/spell/explodus

/obj/screen/spell/painum
	name = "Painum"
	icon_state = "painum"
	screen_loc = "13,14"
	spell_path = /datum/spell/painum

/obj/screen/spell/deadum
	name = "Deadum"
	icon_state = "deadum"
	screen_loc = "12,14"
	spell_path = /datum/spell/deadum

/datum/hud/proc/add_wizard_hud(mob/living/human/H)
	if (wizard_hud.len)
		update_spell_selector(H)
		return

	var/obj/item/weapon/material/magic/wand/W = H.get_active_hand()
	if (!istype(W))
		return

	for (var/datum/spell/SP in W.get_usable_spells(H))

		// Only show spells the user has learned and meets the skill requirement for
		if(H.getStat("magic") < SP.skill_level)
			continue
		if (!SP.screen_obj)
			continue
		var/obj/screen/spell/S = new SP.screen_obj
		S.parentmob = H
		wizard_hud += S

	if (!spell_selector)
		spell_selector = new()
		spell_selector.parentmob = H
	wizard_hud += spell_selector

	if (mymob && mymob.client)
		mymob.client.screen |= wizard_hud

	update_spell_selector(H)

/datum/hud/proc/remove_wizard_hud(mob/living/human/H)
	if (!wizard_hud.len)
		return
	if (H && H.client)
		H.client.screen -= wizard_hud
	for (var/obj/screen/S in wizard_hud)
		qdel(S)
	spell_selector = null
	wizard_hud.Cut()

/datum/hud/proc/update_spell_selector(mob/living/human/H)
	if (!spell_selector)
		return

	var/obj/item/weapon/material/magic/wand/W = null
	if (H)
		if (istype(H.get_active_hand(), /obj/item/weapon/material/magic/wand))
			W = H.get_active_hand()

	if (!W || !W.active_spell)
		spell_selector.screen_loc = null
		return

	var/found = FALSE
	for (var/obj/screen/spell/S in wizard_hud)
		if (S.spell_path == W.active_spell.type)
			spell_selector.screen_loc = S.screen_loc
			found = TRUE
			break

	if (!found)
		spell_selector.screen_loc = null


//////////////////SCREEN HELPERS////////////////////////////
/obj/screen/spellshow
	maptext = "<center><font color='red'>No Spell</font></center>"
	maptext_width = 32*8
	maptext_x = (32*8 * -0.5)+32
	maptext_y = 32*0.75
	icon_state = "blank"

/obj/screen/spellshow/New()
	..()
	if (parentmob)
		var/obj/item/weapon/material/magic/wand/W
		if (istype(parentmob.l_hand, /obj/item/weapon/material/magic/wand))
			W = parentmob.l_hand
		else if (istype(parentmob.r_hand, /obj/item/weapon/material/magic/wand))
			W = parentmob.r_hand
		if (W && W.active_spell)
			maptext = "<center><font color='yellow'><b>[W.active_spell.name]</b></font></center>"
		else
			maptext = "<center><font color='red'>No Spell</font></center>"
	icon_state = "blank"
	spawn(30)
		update(TRUE)

/obj/screen/spellshow/proc/update(loop = FALSE)
	if (!parentmob || !src)
		return
	if (parentmob)
		var/obj/item/weapon/material/magic/wand/W
		if (istype(parentmob.l_hand, /obj/item/weapon/material/magic/wand))
			W = parentmob.l_hand
		else if (istype(parentmob.r_hand, /obj/item/weapon/material/magic/wand))
			W = parentmob.r_hand
		if (W && W.active_spell)
			maptext = "<center><font color='yellow'><b>[W.active_spell.name]</b></font></center>"
		else
			maptext = "<center><font color='red'>No Spell</font></center>"
	if (loop)
		spawn(5)
			update(TRUE)