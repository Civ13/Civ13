/client/proc/playtitlemusic()
	if (!ticker || !ticker.login_music)	return
	if (ticker.current_state != GAME_STATE_PREGAME) return
	if (!istype(mob, /mob/new_player)) return
	if (prefs && is_preference_enabled(/datum/client_preference/play_lobby_music))
		src << sound(ticker.login_music, repeat = TRUE, wait = FALSE, volume = prefs.lobby_music_volume, channel = 1)
		lobby_music_player.announce(src)

/client/proc/stoptitlemusic()
	src << sound(null, channel = 1)

/proc/stop_lobby_music()
	for(var/client/C in clients)
		C.stoptitlemusic()
