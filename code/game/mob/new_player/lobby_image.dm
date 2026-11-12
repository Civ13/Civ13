/var/obj/screen/lobby_image/lobby_image = new/obj/screen/lobby_image()
// The 672x480 picture for the 21x15 widescreen view, when the map has one.
/var/obj/screen/lobby_image/wide/lobby_image_wide = new/obj/screen/lobby_image/wide()

/obj/screen/lobby_image
	name = "Lobby"
	desc = ""
	icon = 'icons/lobby/civ13.dmi'
	icon_state = "civ13"
	screen_loc = "CENTER-7,CENTER-7" // 480x480 picture, centred on the widescreen view
	plane = HUD_PLANE
	layer = 21 // Ensure it is above the black cover objects
	var/list/stored_img = list()

/obj/screen/lobby_image/New()
	..() // Call parent New() to ensure proper initialization of /obj/screen
	spawn(600) // Delay for Battle Royale specific updates
		if (map && map.ID == MAP_BATTLEROYALE_MODERN)
			update_icon_proc()

/obj/screen/lobby_image/proc/lobby_picture()
	return map ? map.lobby_icon : ""

/obj/screen/lobby_image/wide
	screen_loc = "CENTER-10,CENTER-7" // 672x480 picture, edge to edge on the 21x15 view
	var/ready = FALSE // TRUE once the map's wide picture is loaded

/obj/screen/lobby_image/wide/lobby_picture()
	return map ? map.lobby_icon_wide : ""

/obj/screen/lobby_image/wide/initialize()
	if (!map || map.lobby_icon_wide == "" || !file(map.lobby_icon_wide))
		return
	..()
	ready = TRUE

// Shows this player the lobby picture that fits their view: the wide one on the
// 21x15 view when the map has it, otherwise the 480x480 one.
/mob/new_player/proc/show_lobby_image()
	if (!client)
		return
	client.screen -= lobby_image
	client.screen -= lobby_image_wide
	var/list/V = getviewsize(client.default_view())
	if (lobby_image_wide && lobby_image_wide.ready && V[1] >= 21)
		client.screen += lobby_image_wide
	else if (lobby_image)
		client.screen += lobby_image

/obj/screen/lobby_image/initialize()
	var/picture = lobby_picture()
	if (picture != "") // Check if a custom lobby icon is specified
		var/F = file(picture) // Attempt to load the file
		if (F) // If the file exists, use it
			icon = F
		else // If the file doesn't exist, log an error and fall back to the default
			log_admin("Lobby image file not found: [picture]")
			icon = 'icons/lobby/civ13.dmi' // Fallback to the default lobby image
	// A lobby .dmi may carry a still "lobby" state and a looping, mostly
	// transparent "lobby_particles" state that is drawn over it as light.
	var/list/lobby_states = icon_states(icon)
	if ("lobby" in lobby_states)
		icon_state = "lobby"
		if ("lobby_particles" in lobby_states)
			var/image/particles = image(icon = icon, icon_state = "lobby_particles", layer = layer + 0.01)
			particles.blend_mode = BLEND_ADD
			overlays += particles
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