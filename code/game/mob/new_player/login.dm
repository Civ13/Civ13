/mob/new_player
	var/client/my_client // Need to keep track of this ourselves, since by the time Logout() is called the client has already been nulled

/mob/new_player/Login()
	winset(src, null, "mainwindow.title='[customserver_name()]'")//For displaying the server name.
	update_Login_details()	//handles setting lastKnownIP and computer_id for use by the ban systems as well as checking for multikeying
	
	/* if our client was deleted (for example if we're banned), don't show the MOTD */
	if (join_motd)
		spawn (10)
			if (src && src.client)
				to_chat(src, "<div class='info'>Game ID: <span style='color:#ff3737'><b>[game_id ? game_id : "Unknown"]</b></span></div>")
				see_personalized_MOTD()

	if (!mind)
		mind = new /datum/mind(key)
		mind.active = TRUE
		mind.current = src

	loc = null

	// Safe handling for adding lobby image
	if (client && lobby_image)
		client.screen += lobby_image
	else if (lobby_image)
		// Fallback if client is not ready yet
		spawn(3)
			if (src && src.client && lobby_image)
				src.client.screen += lobby_image

	my_client = client
	sight |= SEE_TURFS
	player_list |= src
	#ifdef OPENDREAM
	src.client?.load_pregame()
	#endif
	new_player_panel()

	if (client && client.is_preference_enabled(/datum/client_preference/fit_viewport))
		client.fit_viewport()

	spawn (1)
		if (client)
			client.playtitlemusic()
			if (client.is_preference_enabled(/datum/client_preference/fit_viewport))
				client.fit_viewport()

	spawn while(client)
		sleep(35)
		updateTimeToStart()

/mob/new_player/proc/updateTimeToStart()
	if(!client)
		return
//	if(!client.pigReady)
//		return
	client << output(list2params(list("#timestart", "[ticker?.pregame_timeleft]")), "outputwindow.browser:change")
