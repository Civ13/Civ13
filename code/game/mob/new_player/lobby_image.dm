/var/obj/screen/lobby_image/lobby_image = new/obj/screen/lobby_image()

/obj/screen/lobby_image
	name = "Lobby"
	desc = ""
	icon = 'icons/lobby/civ13.dmi'
	icon_state = "civ13"
	screen_loc = "WEST,SOUTH"
	plane = HUD_PLANE
	layer = 21 // Ensure it is above the black cover objects
	var/list/stored_img = list()

/obj/screen/lobby_image/New()
	..() // Call parent New() to ensure proper initialization of /obj/screen
	spawn(600) // Delay for Battle Royale specific updates
		if (map && map.ID == MAP_BATTLEROYALE_MODERN)
			update_icon_proc()

/obj/screen/lobby_image/initialize()
	if (map && map.lobby_icon != "") // Check if a custom lobby icon is specified
		var/F = file(map.lobby_icon) // Attempt to load the file
		if (F) // If the file exists, use it
			icon = F
		else // If the file doesn't exist, log an error and fall back to the default
			log_admin("Lobby image file not found: [map.lobby_icon]")
			icon = 'icons/lobby/civ13.dmi' // Fallback to the default lobby image
	if (map && map.ID == MAP_LIGHTS_OUT)
		icon = 'icons/lobby/lights_out.dmi'
		icon_state = "lights_out"
/obj/screen/lobby_image/proc/update_icon_proc()
	spawn(100)
		update_icon()
		update_icon_proc()
		
/obj/screen/lobby_image/update_icon()
	..()
	if (map && map.ID == MAP_BATTLEROYALE_MODERN)
		stored_img = list()
		overlays.Cut()
		for(var/mob/living/human/H in player_list)
			if (H.stat != DEAD)
				var/image/ni = image(icon='icons/effects/mapeffects.dmi', icon_state="reddot",layer=src.layer+0.01)
				ni.pixel_x = min(480,ceil(H.x*4.8)-4)
				ni.pixel_y = min(480,ceil(H.y*4.8)-4)
				overlays += ni
				stored_img += ni