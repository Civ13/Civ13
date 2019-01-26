/var/obj/effect/lobby_image = new/obj/effect/lobby_image()

/obj/effect/lobby_image
	name = "Lobby"
	desc = ""
	icon = 'icons/_LOBBY.dmi'
	icon_state = "civ13"
	screen_loc = "WEST,SOUTH"

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
