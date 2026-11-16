/mob/proc/see_personalized_MOTD()
	if (!client)
		return
	var/_motd = join_motd
	_motd = replacetext(_motd, "{server_map}", map ? map.title : "unknown")
	_motd = replacetext(_motd, "{server_version}", "BYOND [world.byond_version].[world.byond_build]")
	_motd = replacetext(_motd, "{client_version}", "BYOND [client.byond_version].[client.byond_build]")
	#ifdef OPENDREAM
	_motd = replacetext(_motd, "{CLIENT_INFO}","Server running on <span style='color:#FF7F50'>OpenDream</span>.")
	#endif
	#ifndef OPENDREAM
	_motd = replacetext(_motd, "{CLIENT_INFO}", "This server is running <span style='color:#009ab4'>BYOND [world.byond_version].[world.byond_build]</span>, and you are running <span style='color:#009ab4'>BYOND [client.byond_version].[client.byond_build]</span>.")
	#endif
	if (config.player_activity)
		// Player activity recorder on (code/modules/player_activity): one line so players know.
		_motd += "<br><i>This server counts play statistics per account (playtime, deaths, travel, research and features used) to see what to improve. No chat, IP addresses or positions are recorded. Staff can delete an account's data on request.</i>"
	//to_chat(src, "<div class='motd'>[_motd]</div>")
	if (client.chat)
		client.chat.send_message_html(_motd)
	client.player_memo_show()