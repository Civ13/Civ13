/var/obj/effect/lobby_image = new/obj/effect/lobby_image()

/obj/effect/lobby_image
	name = "Lobby"
	desc = ""
	icon = 'icons/_LOBBY.dmi'
	icon_state = "civ13"
	screen_loc = "WEST,SOUTH"
	var/list/stored_img = list()
/obj/effect/lobby_image/initialize()
	if (map && map.lobby_icon_state)
		icon_state = map.lobby_icon_state
	else
		var/list/known_icon_states = icon_states(icon)
		for (var/lobby_screen in config.lobby_screens)
			if (!(lobby_screen in known_icon_states))
				error("Lobby screen '[lobby_screen]' did not exist in the icon set [icon].")
				config.lobby_screens -= lobby_screen

		if (config.lobby_screens.len)
			icon_state = pick(config.lobby_screens)
		else
			icon_state = known_icon_states[1]

/obj/effect/lobby_image/New()
	..()
	spawn(600)
		if (map && map.ID == MAP_BATTLEROYALE_MODERN)
			update_icon_proc()

/obj/effect/lobby_image/proc/update_icon_proc()
	spawn(100)
		update_icon()
		update_icon_proc()
/obj/effect/lobby_image/update_icon()
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