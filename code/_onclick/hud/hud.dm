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
		usr << "<span class='warning'>This mob type does not use a HUD.</span>"
		return

	if (!ishuman(src))
		usr << "<span class='warning'>Inventory hiding is currently only supported for human mobs, sorry.</span>"
		return

	if (!client) return
	if (client.view != world.view)
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
	if (client.view != world.view)
		return

	update_action_buttons()

/datum/hud
	var/mob/mymob
	var/list/obj/screen/plane_master/plane_masters = list()
/datum/hud/New(mob/owner)

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
	return ..()
