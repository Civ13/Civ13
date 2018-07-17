/client/proc/playsound_personal(var/soundin, var/_volume = 50)
	soundin = get_sfx(soundin)
	var/sound/S = sound(soundin)
	src << sound(S, repeat = FALSE, wait = FALSE, volume = _volume, channel = 1)

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