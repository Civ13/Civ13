/var/obj/effect/lobby_image = new/obj/effect/lobby_image()

/obj/effect/lobby_image
	name = "Lobby"
	desc = ""
	icon = 'icons/lobby/civ13.gif'
	icon_state = ""
	screen_loc = "WEST,SOUTH"
	var/list/stored_img = list()
/obj/effect/lobby_image/initialize()
	if (map && map.lobby_icon)
		var/F = file(map.lobby_icon)
		if (F)
			icon = F

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