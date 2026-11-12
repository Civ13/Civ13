/mob/observer/ghost/Login()
	..()
	if (ghost_image)
		ghost_image.appearance = src
		ghost_image.appearance_flags = RESET_ALPHA
	if (client && client.admin_ghost_hidden && admin_spectate_allowed(client))
		set_admin_hidden(TRUE)
	updateghostimages()
