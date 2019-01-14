
/mob/new_player
	var/client/my_client // Need to keep track of this ourselves, since by the time Logout() is called the client has already been nulled

/mob/new_player/Login()
	winset(src, null, "mainwindow.title='[customserver_name()]'")//For displaying the server name.
	update_Login_details()	//handles setting lastKnownIP and computer_id for use by the ban systems as well as checking for multikeying

	/* if our client was deleted (for example if we're banned), don't show the MOTD */
	if (join_motd)
		spawn (1)
			if (client)
				src << "<div class='info'>Game ID: <div class='danger'>[game_id]</div></div>"
				see_personalized_MOTD()

	if (!mind)
		mind = new /datum/mind(key)
		mind.active = TRUE
		mind.current = src

	loc = null
	client.screen += lobby_image
	my_client = client
	sight |= SEE_TURFS
	player_list |= src

	new_player_panel()

	spawn (10)
		while (client && (!client.prefs || !client.prefs.ready))
			sleep(1)
		if (client)
			client.playtitlemusic()