//handles setting lastKnownIP and computer_id for use by the ban systems as well as checking for multikeying
/mob/proc/update_Login_details()
	//Multikey checks and logging
	lastKnownIP = client.address

	// these two are new and only exist for making admins' lives easier - Kachnov
	lastKnownCID = client.computer_id
	lastKnownCkey = client.ckey

	computer_id = client.computer_id
	log_access("Login: [key_name(src)] from [lastKnownIP ? lastKnownIP : "localhost"]-[computer_id] || BYOND v[client.byond_version]")
	if (config.log_access)
		for (var/mob/M in player_list)
			if (M == src)	continue
			if ( M.key && (M.key != key) )
				var/matches
				if ( (M.lastKnownIP == client.address) )
					matches += "IP ([client.address])"
				if ( (client.connection != "web") && (M.computer_id == client.computer_id) )
					if (matches)	matches += " and "
					matches += "ID ([client.computer_id])"
					// if one of us is the host, don't show us this warning. Because we're probably testing.
					if (!(M.client.holder.rights == 65535) && !(client.holder.rights == 65535))
						spawn(0) WWalert(src, "You have logged in already with another key this round, please log out of this one NOW or risk being banned!", "Warning!")
				if (matches)
					if (M.client)
						message_admins("<font color='red'><b>Notice: </b></font><span class = 'notice'><A href='?src=\ref[usr];priv_msg=\ref[src]'>[key_name_admin(src)]</A> has the same [matches] as <A href='?src=\ref[usr];priv_msg=\ref[M]'>[key_name_admin(M)]</A>.</span>", TRUE)
						log_access("Notice: [key_name(src)] has the same [matches] as [key_name(M)].")
					else
						message_admins("<font color='red'><b>Notice: </b></font><span class = 'notice'><A href='?src=\ref[usr];priv_msg=\ref[src]'>[key_name_admin(src)]</A> has the same [matches] as [key_name_admin(M)] (no longer logged in). </span>", TRUE)
						log_access("Notice: [key_name(src)] has the same [matches] as [key_name(M)] (no longer logged in).")

/mob/Login()
	winset(src, null, "mainwindow.title='[station_name()]'")
	player_list |= src
	update_Login_details()
	world.update_status()

	update_client_colour(0)

	client.images = null				//remove the images such as AIs being unable to see runes
	client.screen = null				//remove hud items just in case
	if (hud_used)	qdel(hud_used)		//remove the hud objects
	hud_used = new /datum/hud(src)

	next_move = TRUE
	sight |= SEE_SELF
	..()

	if (loc && !isturf(loc))
		client.eye = loc
		client.perspective = EYE_PERSPECTIVE
	else
		client.eye = src
		client.perspective = MOB_PERSPECTIVE

	//set macro to normal incase it was overriden (like cyborg currently does)
	winset(src, null, "mainwindow.macro=macro hotkey_toggle.is-checked=false input.focus=true input.background-color=#D3B5B5")