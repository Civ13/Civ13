/client/proc/playtitlemusic()
	if (!ticker || !ticker.login_music)	return
	if (!istype(mob, /mob/new_player)) return
	if (prefs && is_preference_enabled(/datum/client_preference/play_lobby_music))
		src << sound(ticker.login_music, repeat = TRUE, wait = FALSE, volume = prefs.lobby_music_volume, channel = 1)
		lobby_music_player.announce(src)

/client/proc/stoptitlemusic()
	if (!ticker || !ticker.login_music)	return
	if (!istype(mob, /mob/new_player)) return
	if (prefs)
		src << sound(null, repeat = TRUE, wait = FALSE, volume = prefs.lobby_music_volume, channel = 1)