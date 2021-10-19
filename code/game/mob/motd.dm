/mob/proc/see_personalized_MOTD()
	if (!client)
		return
	var/_motd = join_motd
	_motd = replacetext(_motd, "{server_map}", map ? map.title : "unknown")
	_motd = replacetext(_motd, "{server_version}", "BYOND [world.byond_version].[world.byond_build]")
	_motd = replacetext(_motd, "{client_version}", "BYOND [client.byond_version].[client.byond_build]")
	src << "<div class=\"motd\">[_motd]</div>"
	client.player_memo_show()