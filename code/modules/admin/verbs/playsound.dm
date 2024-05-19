var/list/sounds_cache = list()

/client/proc/play_sound(S as sound)
	set category = "Fun"
	set name = "Play Global Sound"
	if (!check_rights(R_SOUNDS))	return

	var/sound/uploaded_sound = sound(S, repeat = FALSE, wait = TRUE, channel = 777)
	uploaded_sound.priority = 250

	sounds_cache += S

	if (WWinput(src, "Are you ready?\nSong: [S]\nNow you can also play this sound using \"Play Server Sound\".", "Confirmation request", "Play", list("Play", "Cancel")) == "Cancel")
		return

	log_admin("[key_name(src)] played a global sound [S]")
	message_admins("[key_name_admin(src)] played a global sound; [S]", key_name_admin(src))

	for (var/mob/M in player_list)
		if (!new_player_mob_list.Find(M) || !M.is_preference_enabled(/datum/client_preference/play_lobby_music))
			if (M.is_preference_enabled(/datum/client_preference/play_admin_midis))
				M.client << uploaded_sound

/client/proc/play_local_sound(S as sound)
	set category = "Fun"
	set name = "Play Local Sound"
	if (!check_rights(R_SOUNDS))	return

	log_admin("[key_name(src)] played a local sound [S]")
	message_admins("[key_name_admin(src)] played a local sound [S]", key_name_admin(src))
	playsound(get_turf(src.mob), S, 50, 0, 0)


/client/proc/play_server_sound()
	set category = "Fun"
	set name = "Play Server Sound"
	if (!check_rights(R_SOUNDS))	return

	var/list/sounds = file2list("sound/serversound_list.txt");
	sounds += "--CANCEL--"
	sounds += sounds_cache

	var/melody = input("Select a sound from the server to play", "Server sound list", "--CANCEL--") in sounds

	if (melody == "--CANCEL--")	return

	play_sound(melody)

/client/proc/play_world_sound(S as sound)
	set category = "Fun"
	set name = "Play World Sound"
	if (!check_rights(R_SOUNDS))	return

	var/sound/uploaded_sound = sound(S, repeat = FALSE, wait = TRUE, channel = 777)
	uploaded_sound.priority = 250

	sounds_cache += S

	if (WWinput(src, "Are you ready?\nSong: [S]\nNow you can also play this sound using \"Play Server Sound\".", "Confirmation request", "Play", list("Play", "Cancel")) == "Cancel")
		return

	log_admin("[key_name(src)] played world sound [S]")
	message_admins("[key_name_admin(src)] played world sound [S]", TRUE)
	world << uploaded_sound